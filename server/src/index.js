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
const PROPOSE_ACTIONS = ['edit_text', 'structure', 'update_spec', 'find_github', 'find_youtube', 'find_info'];
const PROPOSE_TOOL = {
  name: 'propose',
  description: '在回答结尾向使用者抛出 1-4 个可执行提议按钮（绝不直接改笔记，必须等使用者点选确认）',
  input_schema: {
    type: 'object',
    properties: {
      items: { type: 'array', minItems: 1, maxItems: 4, items: { type: 'object', properties: {
        action: { type: 'string', enum: PROPOSE_ACTIONS },
        label: { type: 'string', maxLength: 40, description: '按钮文字（一般 ≤12 字；update_spec 候选选项可到 ≤40 字）' },
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

// 阶段三 · 系统结构（身份证）侦测：对话出现硬需求时，用 propose 抛 update_spec（绝不直接改，等点选）
const SPEC_DETECT = `

【系統結構偵測】若這次對話明確出現專案的「身份證資訊」（不只硬規格，也包含理念/市場），就在 propose 的 items 裡「額外」加一個 { action:'update_spec', label:'記入結構：X'(≤40字), args:{ instruction: <一段 JSON 字串> } }。
JSON 鍵只能用這些（只填這次明確提到的，其餘省略）：
· 理念/市場：oneLiner(一句話簡介) / targetUser(目標用戶) / painPoint(解決痛點) / coreValue(核心價值) / marketStrategy(市場策略) / businessModel(商業模式) / coreFeatures(核心功能)
· 技術：name / frontend / backend / apis(字串陣列) / database / server / deployMethod
範例 args.instruction 值（整個是字串）："{\\"painPoint\\":\\"健身新手不會排課\\",\\"targetUser\\":\\"剛上手的健身族\\"}"。
沒有明確身份證資訊時，不要加 update_spec。它與其它提議可並存，但 items 最多 4 個。`;

// build7 · 引导式访谈 prompt（mode=guided）：一次一题、出候选选项、核心4优先
const GUIDED_INTERVIEW_PROMPT = `任務（引導式訪談）：你是產品教練，幫使用者一步步把「系統身份證」填好。
1. 一次只問一個核心問題，順序：一句話簡介 → 目標用戶 → 解決痛點 → 核心功能；看「身份證現況」跳過已填的，問第一個還沒填的（下方會告訴你「現在問哪題」）。
2. 先用 1-2 句白話說「為什麼問這題」，然後呼叫 propose 抛 2-4 個「候選答案」當選項：每個 item action='update_spec'、label=該候選的精簡可讀文字(≤40字)、args.instruction= 一段 JSON 字串如 {"painPoint":"健身新手不知道怎麼排課"}。候選要具體、貼合這個專案、互不重複。
3. 結尾告訴使用者：可以點一個候選，或自己打字補充。
4. 全文 ≤180 字、繁體中文白話；絕不直接改筆記。
5. 若「現在問哪題」顯示『核心4已填齊』→ 不要再問核心題，改說「基礎清楚了！」並引導往技術選型/功能拆解推敲（此時 propose 可含 structure / 一般 update_spec）。`;

// 系统身份证（L1）转成可读文字（只列已填栏位；build7 扩 5 区）
function formatSpec(spec) {
  if (!spec || typeof spec !== 'object') return '';
  const f = (k, v) => (v && String(v).trim()) ? `${k}：${v}` : '';
  const apis = Array.isArray(spec.apis) && spec.apis.length ? `API：${spec.apis.join('、')}` : '';
  return [
    f('一句話', spec.oneLiner), f('目標用戶', spec.targetUser),
    f('解決痛點', spec.painPoint), f('核心價值', spec.coreValue),
    f('市場策略', spec.marketStrategy), f('商業模式', spec.businessModel),
    f('核心功能', spec.coreFeatures),
    f('名稱', spec.name), f('前端', spec.frontend), f('後端', spec.backend),
    apis, f('資料庫', spec.database), f('伺服器', spec.server), f('部署方式', spec.deployMethod),
  ].filter(Boolean).join('\n');
}

// system block：㈠静态人设(快取) ㈡身份证 L1(快取) ㈢当前笔记全文 ㈣其他笔记摘要 L3 ㈤任务指令(含结构侦测)
// project = { spec, otherNotes:[{title,summary}] }（AI 教练模式才有；单笔记聊天为 null，行为不变）
function buildSystem(note, kickoff, project, mode) {
  let blocks = Array.isArray(note?.blocks) ? note.blocks : [];
  const N = blocks.length;
  const totalChars = blocks.reduce((s, b) => s + String(b.content || '').length, 0);
  const cap = (N > 50 || totalChars > 30_000) ? 200 : Infinity;
  const body = blocks.map((b, i) =>
    `[${i + 1}·${b.type || 'text'}]${b.pinned ? '📌' : ''} ${String(b.content || '').slice(0, cap)}`
  ).join('\n');
  const hasContent = blocks.some(b => String(b.content || '').trim());

  let task;
  if (mode === 'guided') {
    // 算「现在问哪个核心题」：一句话→目标用户→痛点→核心功能，跳过已填的
    const spec = project?.spec || {};
    const coreOrder = [['oneLiner', '一句話簡介'], ['targetUser', '目標用戶'], ['painPoint', '解決痛點'], ['coreFeatures', '核心功能']];
    const next = coreOrder.find(([k]) => !String(spec[k] || '').trim());
    const hint = next ? `\n\n【現在問哪題】${next[1]}（JSON 鍵 ${next[0]}）` : '\n\n【現在問哪題】核心4已填齊';
    task = GUIDED_INTERVIEW_PROMPT + hint + SPEC_DETECT;
  } else {
    task = (kickoff ? (hasContent ? COACH_CONTENT_TASK : COACH_EMPTY_TASK) : CHAT_TASK) + SPEC_DETECT;
  }

  const sys = [
    { type: 'text', cache_control: { type: 'ephemeral' },
      text: '你是 BrainStrom 的笔记助手。只根据使用者提供的笔记内容回答，不编造；用繁体中文、白话、精炼。' },
  ];
  const specText = formatSpec(project?.spec);
  if (specText) {  // L1 身份证（稳定，挂快取）
    sys.push({ type: 'text', cache_control: { type: 'ephemeral' },
      text: `這個專案的系統身份證（目前已知硬規格）：\n${specText}` });
  }
  sys.push({ type: 'text', text: `专案《${note?.title || '未命名'}》共 ${N} 块：\n${body}` });
  const others = Array.isArray(project?.otherNotes) ? project.otherNotes : [];
  if (others.length) {  // L3 其他笔记摘要（不快取）
    const list = others.slice(0, 8).map((d, i) =>
      `〔${i + 1}〕${String(d.title || '未命名')}：${String(d.summary || '').slice(0, 200)}`).join('\n');
    sys.push({ type: 'text', text: `這個專案還有其他筆記（摘要，回答時可參照全局）：\n${list}` });
  }
  sys.push({ type: 'text', text: task });
  return sys;
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
    cache_read_input_tokens: msg.usage?.cache_read_input_tokens || 0,
    cache_creation_input_tokens: msg.usage?.cache_creation_input_tokens || 0, model: msg.model };
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
        emit({ type: 'card_start', index: i, type: c.type, title: c.title });
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
      system: buildSystem(note, kickoff, payload?.project, payload?.mode),
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
          label: String(it.label || '').slice(0, 40) || it.action,
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

// build7 · 竞品搜寻：免费 iTunes + GitHub Search API，纯 HTTP 聚合（不调 Claude、不升 SDK）
// POST /find/competitors { brief, sources?:['app_store','github'] } → { items:[{source,title,url,subtitle,score}] }
const EXA_API_KEY = process.env.EXA_API_KEY || '';

// Exa 神经搜寻(语意,中文也准)。失败/无 key 回 null。
async function exaSearch(query, { type = 'auto', category, numResults = 8, summaryQuery } = {}) {
  if (!EXA_API_KEY) return null;
  const body = { query, type, numResults };
  if (category) body.category = category;
  if (summaryQuery) body.contents = { summary: { query: summaryQuery } };
  try {
    const r = await fetch('https://api.exa.ai/search', {
      method: 'POST',
      headers: { 'x-api-key': EXA_API_KEY, 'content-type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(12000),
    });
    if (!r.ok) return null;
    const d = await r.json();
    return Array.isArray(d.results) ? d.results : [];
  } catch { return null; }
}
const hostOf = (u) => { try { return new URL(u).host.replace(/^www\./, ''); } catch { return ''; } };
const repoName = (u) => { const m = String(u).match(/github\.com\/([^/]+\/[^/?#]+)/); return m ? m[1] : null; };

// 保底:GitHub 关键字搜(Exa github 轨失败/空时用;免费无 key)。尊重 seen 去重。
async function githubKeywordSearch(term, seen) {
  const out = [];
  try {
    const headers = { Accept: 'application/vnd.github+json', 'User-Agent': 'brainstrom-ai' };
    if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
    const q = `${term} in:name,description stars:>10`;
    const r = await fetch(`https://api.github.com/search/repositories?q=${encodeURIComponent(q)}&sort=stars&order=desc&per_page=6`, { headers, signal: AbortSignal.timeout(10000) });
    if (r.ok) {
      const d = await r.json();
      for (const repo of (d.items || [])) {
        if (!repo.html_url || seen.has(repo.html_url)) continue;
        seen.add(repo.html_url);
        out.push({ source: 'github', title: repo.full_name, url: repo.html_url,
          subtitle: String(repo.description || '').slice(0, 80), summary: null, score: `⭐${repo.stargazers_count}` });
        if (out.length >= 6) break;
      }
    }
  } catch { /* ignore */ }
  return out;
}

// build11：竞品/开源改用 Exa 神经搜寻。竞品轨=Exa web+一句话简介(source 'web')；开源轨=Exa github，失败 fallback GitHub 关键字。
async function handleFindCompetitors(req, res, payload) {
  const kw = String(payload?.keywords || payload?.brief || '').trim();
  if (!kw) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'bad_request', detail: 'need {keywords|brief}' }));
  }
  const term = kw.slice(0, 60);
  const seen = new Set();
  const competitors = [], articles = [], openSource = [];
  let partial = false;

  // build12：拆 3 轨。query 直接用产品词本身(Exa 神经搜=找相似产品);文章轨才加「評測」偏向评测文。
  // 解构名 [company, articlesRes, repos]——刻意与收集阵列 articles 不同名,否则同作用域重复宣告会 SyntaxError。
  const [company, articlesRes, repos] = await Promise.allSettled([
    exaSearch(term, { type: 'auto', numResults: 8, summaryQuery: '這個產品/App 一句話在做什麼？用繁體中文，30字內' }),
    exaSearch(term + ' 評測', { type: 'auto', numResults: 8, summaryQuery: '這篇文章在講什麼？用繁體中文一句話' }),
    exaSearch(term, { category: 'github', type: 'auto', numResults: 8, summaryQuery: '這個開源專案在做什麼？用繁體中文，30字內' }),
  ]);

  // 竞品轨噪声过滤:百科/wiki 页永远不是竞品产品,直接跳过(笼统关键字时 Exa 易召回这些)。
  const isReferenceNoise = (u) => /wikipedia\.org|baike\.baidu|\.wikipedia\.|百科/.test(String(u));

  // 轨1 竞品产品轨(Exa company/neural) source 'web'
  if (company.status === 'fulfilled' && Array.isArray(company.value)) {
    for (const r of company.value) {
      if (!r.url || seen.has(r.url)) continue;
      if (isReferenceNoise(r.url)) continue;
      seen.add(r.url);
      competitors.push({ source: 'web', title: String(r.title || hostOf(r.url)).slice(0, 80), url: r.url,
        subtitle: hostOf(r.url), summary: (String(r.summary || '').trim() || null), score: null });
      if (competitors.length >= 5) break;
    }
  } else { partial = true; }

  // 轨2 相关文章轨(Exa neural) source 'article'——跳过 github 链接(交给开源轨)
  if (articlesRes.status === 'fulfilled' && Array.isArray(articlesRes.value)) {
    for (const r of articlesRes.value) {
      if (!r.url || seen.has(r.url)) continue;
      if (repoName(r.url)) continue;
      seen.add(r.url);
      articles.push({ source: 'article', title: String(r.title || hostOf(r.url)).slice(0, 80), url: r.url,
        subtitle: hostOf(r.url), summary: (String(r.summary || r.text || '').trim() || null), score: null });
      if (articles.length >= 5) break;
    }
  } else { partial = true; }

  // 轨3 相关开源轨(Exa github)——按 repo 名去重(避免 repo 页+README 页重复)。summary 来自轨3 的 summaryQuery。
  if (repos.status === 'fulfilled' && Array.isArray(repos.value)) {
    for (const r of repos.value) {
      const rn = repoName(r.url);
      if (!rn || seen.has('gh:' + rn)) continue;
      seen.add('gh:' + rn);
      openSource.push({ source: 'github', title: rn, url: `https://github.com/${rn}`,
        subtitle: (String(r.summary || r.text || '').slice(0, 80) || null),
        summary: (String(r.summary || r.text || '').trim() || null), score: null });
      if (openSource.length >= 5) break;
    }
  }
  // 开源保底:Exa github 空/失败 → GitHub 关键字搜
  if (openSource.length === 0) {
    if (repos.status !== 'fulfilled' || !repos.value) partial = true;
    openSource.push(...(await githubKeywordSearch(term, seen)));
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ items: [...competitors, ...articles, ...openSource], competitors, articles, openSource, partial }));
}

// build11：findSimilar — 给一个竞品网址，找更多类似的(Exa)。
async function handleFindSimilar(req, res, payload) {
  const url = String(payload?.url || '').trim();
  if (!url || !EXA_API_KEY) {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'bad_request', detail: 'need {url} and EXA_API_KEY' }));
  }
  const items = [];
  try {
    const r = await fetch('https://api.exa.ai/findSimilar', {
      method: 'POST',
      headers: { 'x-api-key': EXA_API_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({ url, numResults: 8, contents: { summary: { query: '這個產品一句話在做什麼？繁體中文30字內' } } }),
      signal: AbortSignal.timeout(12000),
    });
    if (r.ok) {
      const d = await r.json();
      const seen = new Set([url]);
      for (const x of (Array.isArray(d.results) ? d.results : [])) {
        if (!x.url || seen.has(x.url)) continue;
        seen.add(x.url);
        const isGh = /github\.com/.test(x.url);
        items.push({ source: isGh ? 'github' : 'web', title: String(x.title || hostOf(x.url)).slice(0, 80),
          url: x.url, subtitle: hostOf(x.url), summary: (String(x.summary || '').trim() || null), score: null });
        if (items.length >= 8) break;
      }
    }
  } catch { /* ignore */ }
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ items }));
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
  const ROUTES = { '/ai/chat/note': handleChatNote, '/ai/optimize': handleOptimize, '/ai/structure': handleStructure, '/find/competitors': handleFindCompetitors, '/find/similar': handleFindSimilar };
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
