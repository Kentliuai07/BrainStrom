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

// 三层 system block（附录 F5）：㈠静态人设(快取) ㈡专案全文 ㈢任务指令
function buildSystem(note) {
  let blocks = Array.isArray(note?.blocks) ? note.blocks : [];
  const N = blocks.length;
  const totalChars = blocks.reduce((s, b) => s + String(b.content || '').length, 0);
  const cap = (N > 50 || totalChars > 30_000) ? 200 : Infinity;
  const body = blocks.map((b, i) =>
    `[${i + 1}·${b.type || 'text'}]${b.pinned ? '📌' : ''} ${String(b.content || '').slice(0, cap)}`
  ).join('\n');
  return [
    { type: 'text', cache_control: { type: 'ephemeral' },
      text: '你是 BrainStrom 的笔记助手。只根据使用者提供的笔记内容回答，不编造；用繁体中文、白话、精炼。' },
    { type: 'text', text: `专案《${note?.title || '未命名'}》共 ${N} 块：\n${body}` },
    { type: 'text', text: '任务：回答使用者关于这则笔记的问题；若引用内容请点名第几块。' },
  ];
}

async function handleChatNote(req, res, payload) {
  const { messages, note } = payload || {};
  if (!Array.isArray(messages) || !messages.length || typeof note !== 'object') {
    res.writeHead(400, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify({ error: 'bad_request', detail: 'need {messages[], note{}}' }));
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
    const stream = anthropic.messages.stream({
      model: MODEL, max_tokens: MAX_TOKENS, temperature: 0.7,
      system: buildSystem(note),
      messages: messages.map(m => ({
        role: m.role === 'ai' ? 'assistant' : 'user', content: String(m.content || ''),
      })),
    }, { signal: ac.signal });

    stream.on('text', (t) => emit({ type: 'delta', text: t }));
    const final = await stream.finalMessage();
    emit({ type: 'usage', usage: {
      input_tokens: final.usage?.input_tokens, output_tokens: final.usage?.output_tokens,
      cache_read_input_tokens: final.usage?.cache_read_input_tokens || 0, model: final.model,
    }});
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
  if (req.method === 'POST' && url.pathname === '/ai/chat/note') {
    let body = '';
    req.on('data', c => { body += c; if (body.length > 120 * 1024) req.destroy(); });
    req.on('end', () => {
      let payload; try { payload = JSON.parse(body); } catch {
        res.writeHead(400); return res.end('{"error":"bad_json"}');
      }
      const t0 = Date.now();
      handleChatNote(req, res, payload).then(() =>
        console.log(`[chat/note] ${ip} ${Date.now() - t0}ms`));
    });
    return;
  }
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not_found' }));
});

server.listen(PORT, () => console.log(`BrainStrom AI agent on :${PORT} model=${MODEL}`));
