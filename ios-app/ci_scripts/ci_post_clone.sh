#!/bin/sh
# ============================================================
# Xcode Cloud · clone 后置脚本
# 产出 gitignore 的 Config/Config.xcconfig（连线参数），让云端 build 拿得到后端设定。
# Xcode Cloud 会在 clone 完成后自动执行本脚本（位置：与 .xcodeproj 同层的 ci_scripts/）。
# AI_AUTH_TOKEN 由 Xcode Cloud 的「环境变数」注入（在 App Store Connect workflow 设定，建议设为 secret）。
# ============================================================
set -e

CONFIG="$CI_PRIMARY_REPOSITORY_PATH/ios-app/Config/Config.xcconfig"

# 注：xcconfig 把 // 当注解，URL 用 https:/$()/ 写法避开（$() 空插值打断 //）。
{
  echo "AI_BASE_URL = ${AI_BASE_URL:-https:/\$()/brainstrom-ai.fly.dev}"
  echo "AI_AUTH_TOKEN = ${AI_AUTH_TOKEN}"
  echo "AI_USE_STUB = ${AI_USE_STUB:-NO}"
} > "$CONFIG"

if [ -z "$AI_AUTH_TOKEN" ]; then
  echo "⚠️ ci_post_clone: AI_AUTH_TOKEN 未设（Xcode Cloud 环境变数）→ App 会退回 Stub。请在 workflow 设环境变数 AI_AUTH_TOKEN。"
else
  echo "✅ ci_post_clone: 已写 Config.xcconfig（真后端，stub=${AI_USE_STUB:-NO}）"
fi
