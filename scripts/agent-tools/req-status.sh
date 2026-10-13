#!/usr/bin/env bash
# toolbox-script
# format: v1
# name: req-status
# summary: 需求文档体检：提取章节结构与 TODO/待确认/❓ 等未决标记，输出需求覆盖清单
# trigger: manual
# platform: unix
# cat: docs
set -u

DOC="${REQ_DOC:-需求文档.md}"
json_line() { printf '{"status":"%s","severity":"%s","message":"%s","remedy":"%s"}\n' "$1" "$2" "$3" "$4"; }

usage() {
cat <<'EOF'
req-status — 需求文档体检（章节结构 + 未决标记）

用法: toolbox run req-status [--json] [--doc FILE] [-h|--help]

  --doc FILE   指定需求文档（默认环境 REQ_DOC 或根目录 需求文档.md）
  --json       单行 JSON 契约结论（未决项计数）

裸跑 = 输出章节结构清单 + 未决标记明细（TODO/待确认/待定/❓/【待补充】/TBD）。
幂等只读。
EOF
}

DOC_ARG=""
JSON_MODE=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --json) JSON_MODE=1 ;;
    --doc) shift; DOC_ARG="${1:-}"; [ -n "$DOC_ARG" ] || { echo "--doc 需要文件路径"; exit 2; } ;;
    --*) echo "未知参数: $arg（见 --help）"; exit 2 ;;
    *) DOC_ARG="$arg" ;;
  esac
done
[ -n "$DOC_ARG" ] && DOC="$DOC_ARG"

[ -f "$DOC" ] || { echo "[remedy] 找不到 $DOC；用 --doc FILE 指定需求文档路径"; exit 2; }

PATTERN='TODO|待确认|待定|待补充|TBD|❓'
COUNT=$(grep -cE "$PATTERN" "$DOC" || true)

if [ "$JSON_MODE" = "1" ]; then
  if [ "$COUNT" -eq 0 ]; then
    json_line OK info "需求文档无未决标记" ""
  else
    json_line FAIL warn "需求文档有 ${COUNT} 行未决标记" "裸跑 toolbox run req-status 查看明细"
  fi
  exit $([ "$COUNT" -eq 0 ] && echo 0 || echo 1)
fi

echo "# 需求文档体检：$DOC"
echo
echo "## 章节结构"
grep -nE '^#{1,3} ' "$DOC" || echo "（无 markdown 标题）"
echo
echo "## 未决标记（${COUNT} 行）"
if [ "$COUNT" -eq 0 ]; then
  echo "（无）"
else
  grep -nE "$PATTERN" "$DOC" | sed 's/^/  /'
  echo
  echo "[remedy] 未决项应逐条与 PM 对齐；结论落 context/epics/misc/memory.md 或 pending-confirm.md"
fi
exit 0
