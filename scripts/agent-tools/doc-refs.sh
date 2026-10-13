#!/usr/bin/env bash
# toolbox-script
# format: v1
# name: doc-refs
# summary: docs-spec §5 机械校验：README↔docs 双向覆盖 + 全仓 markdown 相对路径引用断链检测
# trigger: pre-commit
# platform: unix
# self-test: --self-test
# cat: docs
set -u

json_line() { printf '{"status":"%s","severity":"%s","message":"%s","remedy":"%s"}\n' "$1" "$2" "$3" "$4"; }

usage() {
cat <<'EOF'
doc-refs — docs 引用完整性校验（docs-spec §5 双向覆盖 + 断链）

用法: toolbox run doc-refs [--json] [--self-test] [-h|--help] [repo-root]

裸跑 = 对当前仓库 docs/ 执行：
  ① 双向覆盖：docs/ 下每个非 README 的 .md 必须在 docs/README.md 有相对链接；
     README.md 链接的目标文件必须存在；
  ② 断链检测：docs/ 全部 .md 的 [..](相对路径) 引用目标必须存在
     （http(s)/mailto/纯锚点跳过）。

退出码：0=通过 1=检查未通过 2=自身故障。--self-test = 金丝雀自测（内嵌已知坏样本）。
EOF
}

SELF_TEST=0
JSON_MODE=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --json) JSON_MODE=1 ;;
    --self-test) SELF_TEST=1 ;;
    --*) echo "未知参数: $arg（见 --help）"; exit 2 ;;
    *) ROOT_ARG="$arg" ;;
  esac
done

# ---------- 金丝雀自测：临时目录内嵌「断链 + 缺索引」坏样本，证明能抓到坏 ----------
if [ "$SELF_TEST" = "1" ]; then
  T=$(mktemp -d) || exit 2
  mkdir -p "$T/docs/guide"
  printf -- '---\nstatus: active\nupdated: 2026-01-01\n---\n\n# idx\n\n- [good](guide/good.md)\n' > "$T/docs/README.md"
  printf '# good\n' > "$T/docs/guide/good.md"
  printf '# bad\n\n[断链](guide/nope.md)\n' > "$T/docs/guide/orphan.md"   # 坏样本①：链接目标不存在
  printf '# ghost\n' > "$T/docs/guide/ghost.md"                            # 坏样本②：未入 README 索引
  OUT=$("$0" "$T" 2>&1); RC=$?
  rm -rf "$T"
  if [ $RC -eq 1 ] && echo "$OUT" | grep -q 'nope.md' && echo "$OUT" | grep -q 'ghost.md'; then
    echo "self-test OK：断链与缺索引坏样本均被抓到"
    exit 0
  fi
  echo "self-test FAIL：坏样本未被完整抓到（rc=$RC）"; echo "$OUT"
  exit 1
fi

ROOT="${ROOT_ARG:-.}"
[ -d "$ROOT/docs" ] || { echo "[remedy] 未找到 docs/ 目录，请在仓库根运行或传仓库路径作位置参数"; exit 2; }
cd "$ROOT" || exit 2

FAILS=0
report() { FAILS=$((FAILS+1)); echo "✗ $1"; }

# ①b README 链接目标必须存在
README="docs/README.md"
if [ ! -f "$README" ]; then
  report "docs/README.md 不存在（docs-spec §5 结构索引缺失）"
else
  while IFS= read -r link; do
    [ -n "$link" ] || continue
    case "$link" in http://*|https://*|mailto:*|\#*) continue ;; esac
    target="${link%%#*}"
    [ -n "$target" ] || continue
    [ -e "docs/$target" ] || report "README 链接目标不存在: $link"
  done < <(grep -oE '\]\([^)]+\)' "$README" | sed -E 's/^\]\((.*)\)$/\1/' | sort -u)

  # ①a 每个非 README 文档必须在 README 有条目（相对路径匹配）
  while IFS= read -r md; do
    rel="${md#docs/}"
    grep -q "($rel" "$README" || report "未入 README 索引: $md（docs-spec §5 双向覆盖）"
  done < <(find docs -name '*.md' ! -name 'README.md')
fi

# ② 全部 md 的相对链接断链检测
while IFS= read -r md; do
  dir=$(dirname "$md")
  while IFS= read -r link; do
    case "$link" in http://*|https://*|mailto:*|\#*) continue ;; esac
    target="${link%%#*}"
    [ -n "$target" ] || continue
    [ -e "$dir/$target" ] || report "断链: $md -> $link"
  done < <(grep -oE '\]\([^)]+\)' "$md" | sed -E 's/^\]\((.*)\)$/\1/' | sort -u)
done < <(find docs -name '*.md')

if [ "$JSON_MODE" = "1" ]; then
  if [ "$FAILS" -eq 0 ]; then json_line OK info "docs 引用完整性通过" ""; exit 0
  else json_line FAIL warn "${FAILS} 处引用问题" "修复上方 ✗ 项后重跑 toolbox run doc-refs"; exit 1
  fi
fi

if [ "$FAILS" -eq 0 ]; then
  echo "✓ docs 引用完整性通过（双向覆盖 + 断链）"
  exit 0
fi
echo "[remedy] 修复后重跑 toolbox run doc-refs；README 索引维护见 docs-spec §5"
exit 1
