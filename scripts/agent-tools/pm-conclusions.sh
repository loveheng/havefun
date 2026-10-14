#!/bin/sh
# pm-conclusions — 汇总各文档「给 PM 的结论」小节为一份独立交接文档
#
# toolbox-script
# format: v1
# name: pm-conclusions
# summary: 扫描 docs/（公域）各 markdown，抽取「结论（给 PM）」类小节，汇总为一份给 PM 的独立文档
# trigger: manual
# platform: unix
# cat: docs
set -u

REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "[pm-conclusions] 请在 git 仓库内运行"; exit 2; }
cd "$REPO" || exit 2

usage() {
cat <<'EOF'
pm-conclusions — 汇总「给 PM 的结论」小节为独立文档

用法: toolbox run pm-conclusions [-o|--out <file>] [--dry-run] [--json] [-h]

  -o, --out FILE   写入 markdown 文件（缺省打印到 stdout）
  -n, --dry-run    只预览命中情况，不生成正文
  --json           预检结论（单行 JSON，不生成本体）
  -h, --help       本帮助

抽取规则：仅扫描 docs/**/*.md（公域；internal/ 属内部域不汇总，避免谈判底稿流入公域），
命中二级标题含「给 PM」的小节（如「## 结论（给 PM）」），截取到下一个二级标题为止。
-o 写入文件时，自动把小节内指向源文件同目录的裸 .md 相对链接改写为输出目录相对路径（小节搬目录后防断链）。
幂等，可安全重跑。
EOF
}

DRY_RUN=0
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -o|--out) OUT="${2:-}"; [ -n "$OUT" ] || { echo "--out 需要文件路径"; exit 2; }; shift 2 ;;
    --json) JSON_MODE=1; shift ;;
    *) echo "未知参数: $1（见 --help）"; exit 2 ;;
  esac
done

OUT_DIR=""
if [ -n "$OUT" ]; then OUT_DIR=$(dirname "$OUT"); fi

# 收集候选文件：docs/ 全部 md（公域；internal/ 属内部域，不汇总），按路径排序保证稳定输出；排除输出文件自身，避免自引用
if [ -n "$OUT" ]; then
  OUT_BASE=$(basename "$OUT")
  FILES=$( find docs -name '*.md' 2>/dev/null | grep -v -F "/$OUT_BASE" | sort )
else
  FILES=$( find docs -name '*.md' 2>/dev/null | sort )
fi

HITS=0
PREVIEW=""
BODY=""

extract_section() {
  # $1=文件路径；打印标题行与小节正文；无命中则返回非零
  f="$1"
  awk -v file="$f" '
    /^## / {
      if (insec) exit                       # 到下一个二级标题，小节结束
      if ($0 ~ /给 ?PM/) { insec=1; print file "\t" $0 }
      next
    }
    insec { print "\t" $0 }
  ' "$f"
}

for f in $FILES; do
  [ -f "$f" ] || continue
  # frontmatter 的 updated（如有）
  UPDATED=$(sed -n '2,6{s/^updated:[[:space:]]*//p}' "$f" 2>/dev/null | head -1)
  SEC=$(extract_section "$f") || true
  [ -n "$SEC" ] || continue
  HITS=$((HITS+1))
  TITLE_LINE=$(printf '%s\n' "$SEC" | head -1 | cut -f2)
  CONTENT=$(printf '%s\n' "$SEC" | tail -n +2 | sed 's/^\t//')
  # -o 时：小节搬目录后，指向源文件同目录的裸 .md 链接改为输出目录相对路径（防断链）
  if [ -n "$OUT_DIR" ]; then
    SRC_DIR=$(dirname "$f")
    if [ "$SRC_DIR" != "$OUT_DIR" ] && [ "$(dirname "$SRC_DIR")" = "$(dirname "$OUT_DIR")" ]; then
      for t in $(printf '%s\n' "$CONTENT" | grep -oE '\]\([^)]+\.md\)' | sed -E 's/^\]\(//; s/\)$//' | sort -u); do
        case "$t" in */*|.*|*://*) continue ;; esac
        [ -f "$SRC_DIR/$t" ] || continue
        t_pat=$(printf '%s' "$t" | sed 's/\./\\./g')
        CONTENT=$(printf '%s\n' "$CONTENT" | sed -E "s|\\]\\($t_pat\\)|](../$(basename "$SRC_DIR")/$t)|g")
      done
    fi
  fi
  PREVIEW="$PREVIEW
  - $f → $TITLE_LINE"
  # 文档标题取首个一级标题（无则用文件名）
  DOC_TITLE=$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //')
  [ -n "$DOC_TITLE" ] || DOC_TITLE="$f"
  META="（来源：$f"
  [ -n "$UPDATED" ] && META="$META，updated $UPDATED"
  META="$META）"
  BODY="$BODY

## $DOC_TITLE
$META

$CONTENT
---
"
done

if [ "${JSON_MODE:-0}" = "1" ]; then
  msg=$(printf '%s' "$HITS" | tr -d '"')
  if [ "$HITS" -gt 0 ]; then
    printf '{"status":"OK","severity":"info","message":"命中 %s 个给PM结论小节"}\n' "$msg"
    exit 0
  fi
  printf '{"status":"FAIL","severity":"warn","message":"未命中任何给PM结论小节"}\n'
  exit 1
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "[dry-run] 命中 $HITS 个小节："
  echo "$PREVIEW"
  echo "[dry-run] 未写任何文件"
  exit 0
fi

if [ "$HITS" -eq 0 ]; then
  echo "未在任何文档中命中「给 PM」小节，未生成文件"
  exit 1
fi

RESULT="---
status: active
updated: $(date +%F)
---

# 校乐趣 · 各文档结论汇总（给 PM）（$(date +%F)）

> 本文档由 \`toolbox run pm-conclusions\` 机械汇总自 docs/（公域）各文档的「给 PM」结论小节，仅作聚合索引；细节以各源文档为准。
$BODY"

if [ -n "$OUT" ]; then
  printf '%s\n' "$RESULT" > "$OUT"
  echo "已生成: $OUT（命中 $HITS 个小节）"
else
  printf '%s\n' "$RESULT"
fi
exit 0
