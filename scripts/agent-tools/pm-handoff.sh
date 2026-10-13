#!/usr/bin/env bash
# toolbox-script
# format: v1
# name: pm-handoff
# summary: 生成与项目经理的交接摘要（docs/ 变更 + 未决决策 + 待办），可输出 markdown 或 --dry-run 预览
# trigger: manual
# platform: unix
# cat: docs
set -u

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "[remedy] 请在 git 仓库内运行"; exit 2; }
cd "$REPO" || exit 2

usage() {
cat <<'EOF'
pm-handoff — 与项目经理的交接摘要生成器

用法: toolbox run pm-handoff [-n|--dry-run] [-o|--out <file>] [--since <ref>]

  -n, --dry-run    只预览将包含的内容（[dry-run] 前缀），不写文件
  -o, --out FILE   写入 markdown 文件（缺省打印到 stdout）
  --since REF      git 变更起点（默认 HEAD~10）
  --json           预检结论（单行 JSON，不生成本体）
  -h, --help       本帮助

裸跑 = 生成交接摘要本体；--json = 只做快速预检。幂等，可安全重跑。
EOF
}

DRY_RUN=0
OUT=""
SINCE="HEAD~10"
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -o|--out) OUT="${2:-}"; [ -n "$OUT" ] || { echo "--out 需要文件路径"; exit 2; }; shift 2 ;;
    --since) SINCE="${2:-HEAD~10}"; shift 2 ;;
    --json) JSON_MODE=1; shift ;;
    *) echo "未知参数: $1（见 --help）"; exit 2 ;;
  esac
done

json_line() { printf '{"status":"%s","severity":"%s","message":"%s","remedy":"%s"}\n' "$1" "$2" "$3" "$4"; }

# --json = 快速预检：只判断有没有可交接的内容，不生成本体
if [ "${JSON_MODE:-0}" = "1" ]; then
  CHG=$(git log --oneline "$SINCE" -- docs/ 2>/dev/null | wc -l | tr -d ' ')
  PEND=$([ -s context/pending-confirm.md ] && echo 1 || echo 0)
  if [ "${CHG:-0}" -gt 0 ] || [ "$PEND" = "1" ]; then
    json_line OK info "docs 近期变更 ${CHG} 条可交接" ""
    exit 0
  else
    json_line FAIL warn "范围 ${SINCE} 内 docs/ 无变更且无未决决策" "调整 --since 或确认 docs/ 已同步"
    exit 1
  fi
fi

TITLE="# 校乐趣 · PM 交接摘要（$(date +%F)）"
CHG=$(git log --oneline "$SINCE" -- docs/ 2>/dev/null)
DOCS_STATUS=$(find docs -name '*.md' -newer README.md 2>/dev/null)

BODY="$TITLE

## 一、docs/ 近期变更（since ${SINCE}）
"
if [ -n "$CHG" ]; then BODY="$BODY
$CHG
"; else BODY="$BODY
（无）
"; fi

BODY="$BODY
## 二、文档时效状态（frontmatter 非最新者）
"
if [ -n "$DOCS_STATUS" ]; then BODY="$BODY
$DOCS_STATUS
"; else BODY="$BODY
（无相对 README 更新的文档）
"; fi

BODY="$BODY
## 三、未决决策（context/pending-confirm.md）
"
if [ -f context/pending-confirm.md ]; then
  BODY="$BODY
$(sed -n '1,40p' context/pending-confirm.md)
"
else
  BODY="$BODY
（无未决决策台账）
"
fi

BODY="$BODY
## 四、待办（context/todos.md 未完成项）
"
if [ -f context/todos.md ]; then
  OPEN=$(grep -E '^\s*-\s*\[' context/todos.md | grep -v '\[x\]' || true)
  if [ -n "$OPEN" ]; then BODY="$BODY
$OPEN
"; else BODY="$BODY
（全部完成）
"; fi
else
  BODY="$BODY
（无全局待办台账）
"
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "[dry-run] 将生成以下交接摘要（未写任何文件）："
  echo "$BODY"
  exit 0
fi

if [ -n "$OUT" ]; then
  printf '%s\n' "$BODY" > "$OUT"
  echo "已生成: $OUT"
else
  printf '%s\n' "$BODY"
fi
exit 0
