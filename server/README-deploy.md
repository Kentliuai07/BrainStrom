# Fly.io 部署（Kent 在 Mac 上跑，约 3 分钟）

```bash
cd server
fly launch --no-deploy --copy-config --name brainstrom-ai   # 名字被占就换一个
fly secrets set ANTHROPIC_API_KEY=<你的金钥> AUTH_TOKEN=$(openssl rand -hex 16)
fly deploy
curl https://brainstrom-ai.fly.dev/ai/health                # 应回 {"ok":true,...}
```

然后把 `web/src/config.js` 改两行：`ai: 'real'`、`aiBaseUrl: 'https://brainstrom-ai.fly.dev'`、
`authToken` 填上面 rand 出来的值（`fly secrets` 不会显示，rand 时自己先记下）。

铁律：ANTHROPIC_API_KEY 只进 fly secrets，绝不写进任何档案/commit。
