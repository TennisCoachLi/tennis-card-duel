#!/usr/bin/env bash
# 一键推送到 GitHub + 开启 Pages
#
#   bash deploy.sh              # 用默认仓库名
#   bash deploy.sh my-repo-name # 指定仓库名
#
# 依赖：gh（已登录）、网络能通 github.com

set -e
cd "$(dirname "$0")"

REPO="${1:-tennis-card-duel}"
OWNER="$(gh api user --jq .login)"
REMOTE="https://github.com/$OWNER/$REPO.git"

echo "▸ 仓库：$OWNER/$REPO"

# 1) 先确认网络通
if ! curl -sS -o /dev/null --max-time 15 https://api.github.com; then
  echo "✗ 连不上 api.github.com —— 请先修好代理（当前海外节点不通）" >&2
  exit 1
fi

# 2) 令牌有效？
if ! gh auth status >/dev/null 2>&1; then
  echo "! gh 令牌无效，请先执行： gh auth refresh -h github.com" >&2
  exit 1
fi

# 3) 建仓（已存在就跳过）
if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  echo "▸ 仓库已存在，跳过创建"
else
  gh repo create "$REPO" \
    --public \
    --description "网球技能卡对战 · 抽一张，把真实训练约束变成场上的一分" \
    --homepage "https://$OWNER.github.io/$REPO/" \
    --source=. --remote=origin
fi

# 4) 推
git add -A
git diff --cached --quiet || git commit -m "更新"
git push -u origin main

# 5) 开 Pages
gh api -X PUT "repos/$OWNER/$REPO/pages" \
  -f source[branch]=main -f source[path]=/ 2>/dev/null \
  || gh api -X POST "repos/$OWNER/$REPO/pages" \
     -f source[branch]=main -f source[path]=/ 2>/dev/null \
  || echo "! Pages 开启失败，可到仓库 Settings → Pages 手动选 main / (root)"

echo
echo "✅ 完成： https://github.com/$OWNER/$REPO"
echo "   Pages（首次部署约 1-2 分钟）： https://$OWNER.github.io/$REPO/"
