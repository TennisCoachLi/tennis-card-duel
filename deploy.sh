#!/usr/bin/env bash
# 一键推送到 GitHub + 开启 Pages
#
#   bash deploy.sh                # 用默认仓库名
#   bash deploy.sh my-repo-name   # 指定仓库名
#
# 依赖：gh 已登录（或设 GH_TOKEN），网络能通 github.com
#
# 注意：本脚本用 REST API 直连，不走 gh 的 GraphQL 端点 ——
# GraphQL 在代理不稳定时容易 EOF 失败，REST 稳得多。

set -e
cd "$(dirname "$0")"

REPO="${1:-tennis-card-duel}"
OWNER="$(gh api user --jq .login 2>/dev/null || echo TennisCoachLi)"
REMOTE="https://github.com/$OWNER/$REPO.git"
PROXY="${HTTPS_PROXY:-http://127.0.0.1:7891}"

echo "▸ 仓库：$OWNER/$REPO"
echo "▸ 代理：$PROXY"

# 1) 网络检查（带一次重试）
ok=0
for i in 1 2 3; do
  if curl -sS -o /dev/null --max-time 20 --proxy "$PROXY" https://api.github.com 2>/dev/null; then
    ok=1; break
  fi
  sleep 4
done
if [ "$ok" != "1" ]; then
  echo "✗ 连不上 api.github.com —— 请检查代理（当前 $PROXY）" >&2
  exit 1
fi

# 2) git 走代理
git config http.proxy "$PROXY"
git config https.proxy "$PROXY"

# 3) 建仓（已存在就跳过）
if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  echo "▸ 仓库已存在，跳过创建"
else
  echo "▸ 创建仓库…"
  for i in 1 2 3 4 5; do
    resp=$(curl -sS --max-time 40 --proxy "$PROXY" \
      -X POST "https://api.github.com/user/repos" \
      -H "Authorization: Bearer $(gh auth token)" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"$REPO\",\"description\":\"网球技能卡对战 · 抽一张，把真实训练约束变成场上的一分\",\"private\":false,\"homepage\":\"https://$OWNER.github.io/$REPO/\",\"has_issues\":true,\"has_wiki\":false}" 2>&1)
    if echo "$resp" | grep -q '"html_url"'; then
      echo "  ✅ 已创建"
      break
    fi
    echo "  重试 $i…"; sleep 4
  done
fi

# 4) 推
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE"
git add -A
git diff --cached --quiet || git commit -m "更新"
for i in 1 2 3 4 5; do
  if git push -u origin main 2>&1 | tail -2; then break; fi
  echo "  推送重试 $i…"; sleep 5
done

# 5) 开 Pages
echo "▸ 开启 Pages…"
curl -sS --max-time 40 --proxy "$PROXY" \
  -X POST "https://api.github.com/repos/$OWNER/$REPO/pages" \
  -H "Authorization: Bearer $(gh auth token)" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/json" \
  -d '{"source":{"branch":"main","path":"/"}}' 2>&1 | head -c 120
echo

echo
echo "✅ 完成： https://github.com/$OWNER/$REPO"
echo "   Pages（首次部署约 1-2 分钟）： https://$OWNER.github.io/$REPO/"
