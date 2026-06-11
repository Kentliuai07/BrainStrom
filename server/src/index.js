// BrainStrom AI 代理（Fly.io 常驻）— 契约：阶段二文档 §2.1 SSE 事件 / §3 整合设计 / 附录 F5
// 金钥只读环境变数，绝不落盘。
import http from 'node:http';
import Anthropic from '@anthropic-ai/sdk';

const PORT = Number(process.env.PORT || 3000);
const MODEL = process.env.MODEL || 'claude-sonnet-4-6';
const MAX_TOKENS = Math.min(Number(process.env.MAX_TOKENS_CAP || 8192), 8192);
const AUTH_TOKEN = process.env.AUTH_TOKEN || '';
const ORIGINS = (process.env.FRONTEND_ORIGINS ||
  'https://kentliuai07.github.io,http://localhost:8000,http://127.0.0.1:8000,null')
  .split(',').map(s => s.trim());

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

// 简易限流：60 次/分/IP
const hits = new Map();
function rateLimited(ip) {
  const now = Date.now();
  const arr = (hits.get(ip) || []).filter(t => now - t < 60_000);
  arr.push(now); hits.set(ip, arr);
  return arr.length > 60;
}

function cors(req, res) {
  const origin = req.headers.origin || '';
  res.setHeader('Access-Control-Allow-Origin', ORIGINS.includes(origin) ? origin : ORIGINS[0]);
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
}

function sse(res) {
  res.writeHead(200, {
    'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive',
  });
  return (obj) => res.write(`data: ${JSON.stringify(obj)}\n\n`);
}

// ---- Step 3.5/3.6 · 对话式编辑提议工具（F9 schema：1-4 项可执行提议按钮）----
const PROPOSE_ACTIONS = ['edit_text', 'structure', 'find_github', 'find_youtube', 'find_info'];
const PROPOSE_TOOL = {
  name: 'propose',
  description: '在回答结尾向使用者抛出 1-4 个可执行提议按钮（绝不直接改笔记，必须等使用者点选确认）',
  input_schema: {
    type: 'object',
    properties: {
      items: { type: 'array', minItems: 1, maxItems: 4, items: { type: 'object', properties: {
        action: { type: 'string', enum: PROPOSE_ACTIONS },
        label: { type: 'string', maxLength: 12, description: '按钮文字，≤12 个字' },
        args: { type: 'object', properties: {
          instruction: { type: 'string', description: 'edit_text 用：要 AI 补/改什么的具体指示' },
        } },
      }, required: ['action', 'label'] } },
    },
    required: ['items'],
  },
};

// 教练开场两分支 prompt（F9）：kickoff 时按「笔记有没有内容」分流
const COACH_EMPTY_TASK = `任务（教练开场·笔记还是空的，只有名称）：你是诚实的点子教练，不是彩虹屁。
1. 先用一句话肯定这个点子名称的方向。
2. 名称信息量不足以判断在做什么 → 直接反问 2-3 个定位问题（谁会用？解决什么痛？最小范围是什么？），不准硬掰猜测。
3. 名称已够清楚 → 给起手式建议（需求验证、最小范围、技术选型各一句）。
4. 全文 ≤200 字、繁体中文白话；绝不直接改笔记。
5. 回答结尾必须呼叫 propose 工具抛 2-4 个提议，例如：「帮你起草」= action edit_text、args.instruction 填「按名称《名称》起草目标用户/核心功能/技术选型三段草稿，每段 2-3 句、[待補] 占位」；「整理成卡片」= structure；「找竞品 GitHub」= find_github。`;
const COACH_CONTENT_TASK = `任务（教练开场·笔记已有内容）：你是诚实的点子教练，不是彩虹屁。
1. 先肯定写得最扎实的一点（点名第几块）。
2. 直指 2-3 个缺口，每个缺口用一句话讲清「不补会出事」的理由。
3. 全文 ≤250 字、繁体中文白话；绝不直接改笔记。
4. 回答结尾必须呼叫 propose 工具抛 2-4 个提议（补 XX 段落 = edit_text 带 args.instruction、整理成卡片 = structure、找竞品 GitHub = find_github）。`;
const CHAT_TASK = '任务：回答使用者关于这则笔记的问题；若引用内容请点名第几块。若有具体可执行的改进，可在结尾用 propose 工具提议（可不提）。';

// 三层 system block（附录 F5）：㈠静态人设(快取) ㈡专案全文 ㈢任务指令（kickoff 教练分流，F9）
function buildSystem(note, kickoff) {
  let blocks = Array.isArray(note?.blocks) ? note.blocks : [];
  const N = blocks.length;
  const totalChars = blocks.reduce((s, b) => s + String(b.content || '').length, 0);
  const cap = (N > 50 || totalChars > 30_000) ? 200 : Infinity;
  const body = blocks.map((b, i) =>
    `[${i + 1}·${b.type || 'text'}]${b.pinned ? '📌' : ''} ${String(b.content || '').slice(0, cap)}`
  ).join('\n');
  const hasContent = blocks.some(b => String(b.content || '').trim());
  const task = kickoff ? (hasContent ? COACH_CONTENT_TASK : COACH_EMPTY_TASK) : CHAT_TASK;
  return [
    { type: 'text', cache_control: { type: 'ephemeral' },
      text: '你是 BrainStrom 的笔记助手。只根据使用者提供的笔记内容回答，不编造；用繁体中文、白话、精炼。' },
    { type: 'text', text: `专案《${note?.title || '未命名'}》共 ${N} 块：\n${body}` },
    { type: 'text', text: task },
  ];
}

// ---- 阶段二 Step 3 · 两个 AI 按钮（§1.2/§1.2b/F2/F5）----
// 架构裁定：资料真相在浏览器 localStorage，server 无状态——只收「变动块＋全部块只读上下文」，
// 调 Claude（tool_use 强制 JSON），把结果以 SSE 事件流回；hash gate / diff / 合并 / 安全阀全在前端服务层。

// 优化 patch 三件式 schema（§1.2b）：adds / updates / removes
const OPTIMIZE_TOOL = {
  name: 'emit_patch',
  description: '回传优化笔记的块级 patch（三件式：adds 新增块 / updates 更新块 / removes 删除块）',
  input_schema: {
    type: 'object',
    properties: {
      adds: { type: 'array', items: { type: 'object', properties: {
        type: { type: 'string', enum: ['text', 'heading'] },
        content: { type: 'string', minLength: 1 },
        position: { type: 'integer', description: '插入位置（以目前块顺序的索引为准）' },
      }, required: ['type', 'content', 'position'] } },
      updates: { type: 'array', items: { type: 'object', properties: {
        id: { type: 'string' }, content: { type: 'string', minLength: 1 },
      }, required: ['id', 'content'] } },
      removes: { type: 'array', items: { type: 'string' }, description: '只准用于合并场景的被并块 id' },
    },
    required: ['adds', 'updates', 'removes'],
  },
};

const OPTIMIZE_SYSTEM = `你是 BrainStrom 的笔记整理助手。使用者给你一份笔记的全部块（blocks），每块有 id / type / content / pinned / changed。
规则：
1. 只整理 changed:true 的块：修顺语句、补标点、调整段落让整篇读起来通顺，但不改变原意。
2. changed:false 或 pinned:true 的块是「只读上下文」：一个字不准重写，绝对不准出现在 patch 的 updates / removes 里。
3. groupTopics 为 true 时，可以在 adds 里插入 type:'heading' 的块当主题小标题（position = 要插入的位置索引）；groupTopics 为 false 时不要加任何 heading。
4. removes 只准用于「合并场景」：把两个乱段并成一段时，用一条 update 承接合并后的完整内容、一条 remove 删掉被并掉的块；被删块的内容必须并进那条 update 里，不准凭空删内容。
5. 保留客观事实（数字、名称、连结）；所有 [方括号占位标签] 原样保留。
6. 全部输出使用繁体中文。
7. 必须呼叫 emit_patch 工具回传结果，不要输出任何其他文字；没有需要改的就回三个空阵列。
8. 若 user 讯息含 instruction 栏位（Step 3.5 对话式编辑）：那是使用者亲自下的修改指示，按指示新增/改写内容——此时可以动 changed:false 的未钉选块、可以较大幅改写或新增整段（规则 1/2 的 changed 限制不适用）；但仍然只准透过 emit_patch 回传，且 pinned:true 的块与模组块照样一个字不准碰、不准删。`;

// 卡片结构化 tool（§1.2 / F5）
const STRUCTURE_TOOL = {
  name: 'emit_cards',
  description: '把笔记内容归组成主题卡阵列回传',
  input_schema: {
    type: 'object',
    properties: {
      cards: { type: 'array', items: { type: 'object', properties: {
        type: { type: 'string', description: '卡片类型（参考 20 卡清单，不合适可自取）' },
        title: { type: 'string', minLength: 1 },
        content: { type: 'string', minLength: 1 },
        absorbed: { type: 'array', items: { type: 'string' }, description: '这张卡吸收了哪些块的 id' },
      }, required: ['type', 'title', 'content', 'absorbed'] } },
    },
    required: ['cards'],
  },
};

// 20 卡参考清单（§1.5，hardcode 进 prompt 常量；F5）
const CARD_TYPES_REF = 'systemName 系统名称、techStack 技术栈、techRating 技术评估、platformTools 平台工具、github 开源参考、aiSearch AI 搜寻、video 参考影片、reel 短影音、voice 语音、prompt 提示词、devFlow 开发逻辑、buildSteps 建置步骤、table 表格、htmlPreview 版型示意、refShots 参考截图、devFocus 开发重点、competitors 竞品、estimate 预估、aiAnalysis AI 分析、learningPath 学习路径';

const STRUCTURE_SYSTEM = `你是 BrainStrom 的笔记整理助手。把笔记的全部「未钉选的文字/标题块」归组成主题卡：每个主题一张卡（title 卡标 + content 内容），卡的顺序要能直接串成一篇通顺的文章。
规则：
1. pinned:true 的块与模组块（module:true）是「只读上下文」：不归组、不吸收、不改写它们的内容。
2. 资料不足的主题不要生卡、不准编造内容；每张卡的 content 不可为空。
3. 每张卡的 absorbed 填它吸收了哪些块的 id（只准填未钉选的文字/标题块的 id）。
4. 卡片 type 参考这 20 种卡名（不合适可自取新名）：${CARD_TYPES_REF}。
5. 全部输出使用繁体中文。必须呼叫 emit_cards 工具回传结果，不要输出任何其他文字。`;

function usagePayload(msg) {
  return { type: 'usage',
    input_tokens: msg.usage?.input_tokens, output_tokens: msg.usage?.output_tokens,
    cache_read_input_tokens: msg.usage?.cache_read_input_tokens || 0, model: msg.model };
}
function errCode(e) {
  return e?.status === 429 ? 'rate_limited' : (e?.status >= 500 ? 'upstream_error' : 'ai_error');
}

// POST /ai/optimize：{ note:{title, blocks:[{id,type,content,pinned,changed}]}, groupTopics, instruction? }
// 非串流调 Claude（tool_use 强制），结果以 SSE 逐项 emit：card_done(add/update) / card_removed / usage / done。
async function handleOptimize(req, res, payload) {
  const { note, groupTopics, instruction } = payload || {};
  // 空 blocks 仅在带 instruction 时放行（F9「帮你起草」：空笔记从零起草，patch 全为 adds）
  if (!note || !Array.isArray(note.blocks) || (!note.blocks.length && !String(instruction || '').trim())) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'bad_request', detail: 'need {note:{blocks[]}} or instruction' }));
  }
  const emit = sse(res);
  const ac = new AbortController();
  res.on('close', () => { if (!res.writableEnded) ac.abort(); });
  try {
    const userMsg = JSON.stringify({
      title: String(note.title || '未命名'),
      groupTopics: !!groupTopics,
      ...(instruction ? { instruction: String(instruction).slice(0, 2000) } : {}), // Step 3.5 预留
      blocks: note.blocks.map((b, i) => ({
        index: i, id: String(b.id || ''), type: b.type || 'text',
        pinned: !!b.pinned, changed: !!b.changed, content: String(b.content || ''),
      })),
    });
    const msg = await anthropic.messages.create({
      model: MODEL, max_tokens: MAX_TOKENS, temperature: 0.4,
      system: [{ type: 'text', text: OPTIMIZE_SYSTEM, cache_control: { type: 'ephemeral' } }],
      tools: [OPTIMIZE_TOOL], tool_choice: { type: 'tool', name: 'emit_patch' },
      messages: [{ role: 'user', content: userMsg }],
    }, { signal: ac.signal });
    const tu = (msg.content || []).find(c => c.type === 'tool_use' && c.name === 'emit_patch');
    if (!tu || typeof tu.input !== 'object') {
      emit({ type: 'error', code: 'ai_format', error: 'AI 未回传 emit_patch 工具结果' });
    } else {
      const inp = tu.input; let idx = 0;
      for (const a of Array.isArray(inp.adds) ? inp.adds : [])
        emit({ type: 'card_done', index: idx++, card: { action: 'add', type: a.type, content: a.content, position: a.position } });
      for (const u of Array.isArray(inp.updates) ? inp.updates : [])
        emit({ type: 'card_done', index: idx++, card: { action: 'update', id: u.id, content: u.content } });
      for (const r of Array.isArray(inp.removes) ? inp.removes : [])
        emit({ type: 'card_removed', cardId: r });
      emit(usagePayload(msg));
      emit({ type: 'done' });
    }
  } catch (e) {
    if (!ac.signal.aborted) emit({ type: 'error', code: errCode(e), error: String(e?.message || e) });
  } finally { res.end(); }
}

// POST /ai/structure：{ note:{title, blocks:[...全部块（含 pinned/module 标注）]}, mode:'full' }（incremental 留 Step 5）
async function handleStructure(req, res, payload) {
  const { note, mode } = payload || {};
  if (!note || !Array.isArray(note.blocks) || !note.blocks.length || (mode && mode !== 'full')) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'bad_request', detail: "need {note:{blocks[]}, mode:'full'}（incremental 留 Step 5）" }));
  }
  const emit = sse(res);
  const ac = new AbortController();
  res.on('close', () => { if (!res.writableEnded) ac.abort(); });
  try {
    const userMsg = JSON.stringify({
      title: String(note.title || '未命名'),
      blocks: note.blocks.map((b, i) => ({
        index: i, id: String(b.id || ''), type: b.type || 'text',
        pinned: !!b.pinned, module: !!b.module, content: String(b.content || ''),
      })),
    });
    const msg = await anthropic.messages.create({
      model: MODEL, max_tokens: MAX_TOKENS, temperature: 0.4,
      system: [{ type: 'text', text: STRUCTURE_SYSTEM, cache_control: { type: 'ephemeral' } }],
      tools: [STRUCTURE_TOOL], tool_choice: { type: 'tool', name: 'emit_cards' },
      messages: [{ role: 'user', content: userMsg }],
    }, { signal: ac.signal });
    const tu = (msg.content || []).find(c => c.type === 'tool_use' && c.name === 'emit_cards');
    const cards = tu && Array.isArray(tu.input?.cards) ? tu.input.cards : null;
    if (!cards) {
      emit({ type: 'error', code: 'ai_format', error: 'AI 未回传 emit_cards 工具结果' });
    } else {
      cards.forEach((c, i) => {
        emit({ type: 'card_start', index: i, cardType: c.type, title: c.title }); // 卡片型别用 cardType（与事件 type 撞名，iOS 线发现的 bug）
        emit({ type: 'card_done', index: i, card: { type: c.type, title: c.title, content: c.content, absorbed: Array.isArray(c.absorbed) ? c.absorbed : [] } });
      });
      emit(usagePayload(msg));
      emit({ type: 'done' });
    }
  } catch (e) {
    if (!ac.signal.aborted) emit({ type: 'error', code: errCode(e), error: String(e?.message || e) });
  } finally { res.end(); }
}

// POST /ai/chat/note：{ messages[], note{}, kickoff? }
// Step 3.6：kickoff=true（点子助攻教练开场）时 messages 允许空阵列（F9 校验放宽）。
async function handleChatNote(req, res, payload) {
  const { messages, note } = payload || {};
  const kickoff = !!payload?.kickoff;
  if ((!kickoff && (!Array.isArray(messages) || !messages.length)) || typeof note !== 'object' || note === null) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'bad_request', detail: 'need {messages[], note{}}（kickoff 时 messages 可为空）' }));
  }
  const total = JSON.stringify(payload).length;
  if (total > 100 * 1024) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'bad_request', detail: 'payload too large' }));
  }
  const emit = sse(res);
  const ac = new AbortController();
  // 注意：req 的 'close' 在 body 收完就会触发（Node 行为），不能当断线用。
  // 真正的「客户端断线」= 回应流在我们写完前被关闭。
  res.on('close', () => { if (!res.writableEnded) ac.abort(); });

  try {
    // Anthropic 要求 messages 至少一则：kickoff 空阵列时注入一则触发语（教练 prompt 在 system 第三层）
    const msgs = (Array.isArray(messages) && messages.length) ? messages
      : [{ role: 'user', content: '（使用者按下了「点子助攻」按钮）请开始你的教练开场。' }];
    const stream = anthropic.messages.stream({
      model: MODEL, max_tokens: MAX_TOKENS, temperature: 0.7,
      system: buildSystem(note, kickoff),
      tools: [PROPOSE_TOOL], tool_choice: { type: 'auto' }, // Step 3.5：AI 可在结尾抛提议（kickoff 时 prompt 强制）
      messages: msgs.map(m => ({
        role: m.role === 'ai' ? 'assistant' : 'user', content: String(m.content || ''),
      })),
    }, { signal: ac.signal });

    // SDK 行为：stream.on('text') 只吐 text delta，tool_use 的 input json 不进 text——
    // 开场白由 prompt 要求「先文字后工具」；就算 AI 只回工具没文字，下面也照常 emit proposal/usage/done。
    stream.on('text', (t) => emit({ type: 'delta', text: t }));
    const final = await stream.finalMessage();
    // 从 finalMessage 取 propose tool_use → emit proposal（在 usage 之前，§2.1）；服务端再校验一次不信 AI
    const tu = (final.content || []).find(c => c.type === 'tool_use' && c.name === 'propose');
    if (tu && Array.isArray(tu.input?.items)) {
      const items = tu.input.items
        .filter(it => it && PROPOSE_ACTIONS.includes(it.action))
        .slice(0, 4)
        .map(it => ({
          action: it.action,
          label: String(it.label || '').slice(0, 12) || it.action,
          args: (it.args && typeof it.args === 'object' && it.args.instruction)
            ? { instruction: String(it.args.instruction).slice(0, 2000) } : {},
        }));
      if (items.length) emit({ type: 'proposal', items });
    }
    emit(usagePayload(final)); // 扁平 usage（对齐 §2.1 与 /ai/optimize 同一形状）
    emit({ type: 'done' });
  } catch (e) {
    if (!ac.signal.aborted) {
      const code = e?.status === 429 ? 'rate_limited' : (e?.status >= 500 ? 'upstream_error' : 'ai_error');
      emit({ type: 'error', code, error: String(e?.message || e) });
    }
  } finally { res.end(); }
}

const server = http.createServer(async (req, res) => {
  cors(req, res);
  if (req.method === 'OPTIONS') { res.writeHead(204); return res.end(); }
  const ip = req.socket.remoteAddress || '?';
  const url = new URL(req.url, 'http://x');

  if (req.method === 'GET' && url.pathname === '/ai/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ ok: true, version: 'fly-1', model: MODEL }));
  }
  if (rateLimited(ip)) { res.writeHead(429); return res.end('{"error":"rate_limited"}'); }
  if (AUTH_TOKEN && req.headers.authorization !== `Bearer ${AUTH_TOKEN}`) {
    res.writeHead(401, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'unauthorized' }));
  }
  const ROUTES = { '/ai/chat/note': handleChatNote, '/ai/optimize': handleOptimize, '/ai/structure': handleStructure };
  if (req.method === 'POST' && ROUTES[url.pathname]) {
    let body = '';
    req.on('data', c => { body += c; if (body.length > 220 * 1024) req.destroy(); });
    req.on('end', () => {
      let payload; try { payload = JSON.parse(body); } catch {
        res.writeHead(400); return res.end('{"error":"bad_json"}');
      }
      const t0 = Date.now();
      ROUTES[url.pathname](req, res, payload).then(() =>
        console.log(`[${url.pathname}] ${ip} ${Date.now() - t0}ms`));
    });
    return;
  }
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not_found' }));
});

server.listen(PORT, () => console.log(`BrainStrom AI agent on :${PORT} model=${MODEL}`));
