// config.js — 前后端整合开关（阶段二文档 §3「前后端整合与切换设计」）
// ai: 'mock' = 浏览器内模拟引擎（离线后备）；'real' = Fly.io 真 AI 代理。
// authToken 在静态页是公开的，仅防路人扫描；真鉴权阶段三接 Supabase Auth（文档已载明）。
// 金钥（ANTHROPIC_API_KEY）只存在后端环境变数，永不出现在前端。
export const BACKEND = {
  ai: 'mock', // Fly 部署后改 'real'（见 server/README-deploy.md）
  aiBaseUrl: 'https://brainstrom-ai.fly.dev', // Fly.io 部署后改成 https://<app>.fly.dev
  authToken: '',         // 与后端 AUTH_TOKEN 一致
};
