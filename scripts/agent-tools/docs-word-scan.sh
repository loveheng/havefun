#!/bin/sh
# docs-word-scan — docs/ 商务/合同/官方用词扫描自检（词表外置可动态配置）
#
# toolbox-script
# format: v1
# name: docs-word-scan
# summary: docs/ 禁用词扫描：商务价格/合同用词/官方腔三类，词表外置可动态配置，带整行放行白名单
# trigger: manual
# platform: unix
# self-test: --self-test

set -u
MSG=""
HITS=0

usage() {
  cat <<'EOF'
用法: docs-word-scan.sh [--json] [--self-test] [--words <词表文件>] [--dir <扫描目录>]
  裸跑          扫描 docs/ 与 context/pending-confirm.md 中的禁用词，逐条列出 file:line
  --json        一行 JSON 契约结论（快速预检；裸跑才是逐条明细）
  --self-test   金丝雀自检：构造已知坏样本断言能抓到，好样本断言通过
  --words F     指定词表（默认: 本脚本同目录 docs-word-scan.words）
  --dir D       指定扫描目录（默认: docs/；另自动附加 context/pending-confirm.md）
词表格式（每行）: 类别|禁用正则(grep -E)|整行放行正则(可选)
退出码: 0=通过 1=发现禁用词 2=自身故障
EOF
}

# scan_one <words-file> <dir> — 扫描并打印明细；设置全局 HITS
scan_dir() {
  _wf="$1" _dir="$2"
  [ -f "$_wf" ] || { echo "[remedy] 词表不存在: $_wf —— 用 --words 指定或恢复默认词表"; return 2; }
  _files=$(find "$_dir" -name '*.md' -type f 2>/dev/null)
  if [ -f "context/pending-confirm.md" ]; then
    _files="$_files context/pending-confirm.md"
  fi
  [ -n "$_files" ] || { echo "[remedy] 扫描目录无 markdown: $_dir"; return 2; }
  grep -n '^#' "$_wf" >/dev/null 2>&1 || true
  while IFS= read -r _line; do
    case "$_line" in ''|'#'*) continue ;; esac
    _cat=$(printf '%s' "$_line" | cut -d'|' -f1)
    _pat=$(printf '%s' "$_line" | cut -d'|' -f2)
    _allow=$(printf '%s' "$_line" | cut -d'|' -f3-)
    [ -n "$_pat" ] || continue
    for _f in $_files; do
      _matched=$(grep -nHE "$_pat" "$_f" 2>/dev/null || true)
      [ -n "$_matched" ] || continue
      if [ -n "$_allow" ]; then
        _matched=$(printf '%s\n' "$_matched" | grep -vE "$_allow" || true)
      fi
      [ -n "$_matched" ] || continue
      _n=$(printf '%s\n' "$_matched" | grep -c . || true)
      HITS=$((HITS + _n))
      [ "${SCAN_QUIET:-}" = "1" ] || printf '%s\n' "$_matched" | while IFS= read -r _m; do
        printf '  [%s] %s\n' "$_cat" "$_m"
      done
    done
  done < "$_wf"
  return 0
}

run_checks() {
  _words=""
  _dir="docs"
  while [ $# -gt 0 ]; do
    case "$1" in
      --words) _words="$2"; shift 2 ;;
      --dir)   _dir="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -n "$_words" ] || _words="$(cd "$(dirname "$0")" && pwd)/docs-word-scan.words"
  _quiet=0
  case "${SCAN_QUIET:-}" in 1) _quiet=1 ;; esac
  [ "$_quiet" = "1" ] || { echo "词表: $_words"; echo "目录: $_dir"; echo "--- 禁用词明细 ---"; }
  HITS=0
  scan_dir "$_words" "$_dir" || return $?
  [ "$_quiet" = "1" ] || echo "---"
  if [ "$HITS" -gt 0 ]; then
    MSG="发现禁用词 $HITS 处 —— 按上面明细改为平常说法；若属业务必需（领域词/材料名），在词表该行第三段加放行正则"
    return 1
  fi
  MSG="docs 禁用词扫描通过（词表: $(basename "$_words")）"
  return 0
}

self_test() {
  _tmp=$(mktemp -d) || return 2
  trap 'rm -rf "$_tmp"' EXIT
  # 坏样本：两行分别含禁用词（不含任何放行短语）
  printf '这个报价 ¥100 必须改\n这种机制早该定案了\n' > "$_tmp/bad.md"
  # 好样本：整行命中放行白名单（商品价格/买卖双方属业务必需）
  printf '商品上下架（图片/价格/库存/分类）；买卖双方互评各 1 次\n' > "$_tmp/good.md"
  printf '商务价格|报价|价格/库存\n商务价格|成本|\n合同用词|条款|\n合同用词|双方|买卖双方\n官方腔|机制|\n官方腔|定案|\n' > "$_tmp/w.words"
  mkdir -p "$_tmp/docs"
  mv "$_tmp/bad.md" "$_tmp/docs/bad.md"
  mv "$_tmp/good.md" "$_tmp/docs/good.md"
  _out=$(scan_dir "$_tmp/w.words" "$_tmp/docs" 2>&1) || { echo "self-test: scan 执行异常"; echo "$_out"; return 2; }
  # bad.md 两行都应命中（报价/条款/双方/机制 同一行），good.md 应被放行
  printf '%s' "$_out" | grep -q 'docs/bad.md:1' || { echo "self-test: 未抓到坏样本（金丝雀失效）"; return 1; }
  if printf '%s' "$_out" | grep -q 'good.md'; then
    echo "self-test: 好样本被误报（放行白名单失效）"
    return 1
  fi
  echo "self-test: 通过（坏样本命中、白名单放行均符合预期）"
  return 0
}

_WORDS_OPT=""
_DIR_OPT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --json) _JSON=1; shift ;;
    --self-test) self_test; exit $? ;;
    --help|-h) usage; exit 0 ;;
    --words) _WORDS_OPT="$2"; shift 2 ;;
    --dir) _DIR_OPT="$2"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

_ARGS=""
[ -n "$_WORDS_OPT" ] && _ARGS="$_ARGS --words $_WORDS_OPT"
[ -n "$_DIR_OPT" ] && _ARGS="$_ARGS --dir $_DIR_OPT"
# shellcheck disable=SC2086
if [ "${_JSON:-}" = "1" ]; then
  SCAN_QUIET=1
  export SCAN_QUIET
fi
if run_checks $_ARGS; then
  [ "${_JSON:-}" = "1" ] && printf '{"status":"OK","severity":"info","message":"%s"}\n' "$MSG"
  [ "${_JSON:-}" = "1" ] || echo "OK: $MSG"
  exit 0
fi
_RC=$?
if [ "${_JSON:-}" = "1" ]; then
  _MSG_1LINE=$(printf '%s' "$MSG" | tr '\n' ' ' | tr -d '"' | cut -c1-300)
  printf '{"status":"FAIL","severity":"warn","message":"%s","remedy":"改写明细行或更新词表放行段"}\n' "$_MSG_1LINE"
else
  echo "FAIL: $MSG"
  echo "[remedy] 改写上面明细中的用词；业务必需词在词表第三段加放行正则"
fi
exit $_RC
