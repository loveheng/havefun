#!/usr/bin/env bash
# toolbox-script
# format: v1
# name: docs-key-facts
# summary: 关键事实一致性报告：按 docs-key-facts.tsv 逐条 grep docs/，列每个关键事实全部出现处
# trigger: manual
# platform: unix
# self-test: --self-test
# cat: docs
set -u

usage() {
cat <<'EOF'
docs-key-facts — 关键事实一致性报告（xiaolequ-docs 关键事实规程的机械实现）

用法: toolbox run docs-key-facts [关键词] [--data FILE] [--json] [--self-test] [-h|--help] [repo-root]

数据表: 脚本同目录 docs-key-facts.tsv（TSV：pattern<TAB>事实名<TAB>已知值；# 开头为注释行）。
裸跑 = 逐条 grep docs/ 并列出每个事实的全部出现处（file:line: 内容）——改关键事实前用它
核对其余出现处，防「改一处漏其余」。关键词按事实名或 pattern 过滤表行。
--data FILE 指定自定义表（自测用）；--json = 快速预检（事实总数 + 0 命中事实清单，
0 命中 = 表需维护，FAIL）；--self-test 金丝雀自测。

退出码: 0=通过 1=有 0 命中事实（--json 语义） 2=自身故障
EOF
}

json_line() { printf '{"status":"%s","severity":"%s","message":"%s","remedy":"%s"}\n' "$1" "$2" "$3" "$4"; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DATA="${DATA_OVERRIDE:-$SCRIPT_DIR/docs-key-facts.tsv}"

G_TOTAL=0; G_ZERO=0; G_FACTS=0; G_ZEROLIST=''

scan_repo() {
  local ROOT="$1" KEYWORD="$2" pattern name value hits n
  [ -f "$DATA" ] || { echo "[remedy] 事实表缺失: $DATA"; return 2; }
  [ -d "$ROOT/docs" ] || { echo "[remedy] 未找到 docs/ 目录（$ROOT）：请在仓库根运行或传仓库路径作位置参数"; return 2; }
  while IFS=$'\t' read -r pattern name value; do
    case "$pattern" in ''|\#*) continue ;; esac
    [ -n "$name" ] || continue
    if [ -n "$KEYWORD" ]; then
      case "$name$pattern" in *"$KEYWORD"*) ;; *) continue ;; esac
    fi
    G_FACTS=$((G_FACTS+1))
    hits=$(grep -rnE "$pattern" "$ROOT/docs" 2>/dev/null | sed "s|^$ROOT/||" || true)
    if [ -n "$hits" ]; then
      n=$(printf '%s\n' "$hits" | grep -c .)
      G_TOTAL=$((G_TOTAL+n))
      echo "【$name】$value"
      printf '%s\n' "$hits" | sed 's/^/  /'
      echo
    else
      G_ZERO=$((G_ZERO+1))
      G_ZEROLIST="${G_ZEROLIST}${G_ZEROLIST:+; }$name"
      echo "【$name】⚠ 0 处命中 —— 该事实可能已不在 docs/ 中，或 pattern 需更新（$value）"
      echo
    fi
  done < "$DATA"
  [ "$G_FACTS" -ge 1 ] || { echo "[remedy] 事实表无有效行（或关键词未命中任何行）: $DATA"; return 2; }
  return 0
}

self_test() {
  local T TDATA OUT RC
  T=$(mktemp -d) || return 2
  mkdir -p "$T/docs/x"
  printf -- '---\nstatus: active\nupdated: 2026-01-01\n---\n\n# a\n\n常驻 3 后端 + 2 App，前端机动。\n' > "$T/docs/x/a.md"
  TDATA="$T/facts.tsv"
  printf '3 后端 \\+ 2 App\t人力配置\t测试值\n不存在的\t缺席事实\t测试值\n' > "$TDATA"
  DATA="$TDATA"
  OUT=$("$0" --data "$TDATA" --json "$T" 2>&1); RC=$?
  rm -rf "$T"
  if [ $RC -eq 1 ] && printf '%s\n' "$OUT" | grep -q 'FAIL' && printf '%s\n' "$OUT" | grep -q '缺席事实'; then
    echo "self-test OK：命中事实被统计、0 命中事实被报 FAIL"
    return 0
  fi
  echo "self-test FAIL (rc=$RC)"; printf '%s\n' "$OUT"
  return 1
}

JSON=0; SELF_TEST=0; ROOT_ARG=''; KEYWORD=''; DATA_OVERRIDE=''
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --json) JSON=1; shift ;;
    --self-test) SELF_TEST=1; shift ;;
    --data) DATA_OVERRIDE="${2:-}"; shift 2; [ -n "$DATA_OVERRIDE" ] || { echo "--data 需要文件路径"; exit 2; } ;;
    --*) echo "未知参数: $1（见 --help）"; exit 2 ;;
    *)
      if [ -d "$1" ]; then ROOT_ARG="$1"
      elif [ -z "$KEYWORD" ]; then KEYWORD="$1"
      else echo "多余的参数: $1（见 --help）"; exit 2; fi
      shift ;;
  esac
done
DATA="${DATA_OVERRIDE:-$SCRIPT_DIR/docs-key-facts.tsv}"

if [ "$SELF_TEST" = "1" ]; then self_test; exit $?; fi

ROOT="${ROOT_ARG:-.}"
ROOT=$(cd "$ROOT" 2>/dev/null && pwd) || { echo "[remedy] 仓库路径不存在: $ROOT_ARG"; exit 2; }
scan_repo "$ROOT" "$KEYWORD"
RC=$?
if [ $RC -eq 2 ]; then exit 2; fi

if [ "$JSON" = "1" ]; then
  if [ "$G_ZERO" -gt 0 ]; then
    json_line FAIL warn "关键事实预检: ${G_FACTS} 条事实, ${G_ZERO} 条 0 命中（表需维护）: ${G_ZEROLIST}" "更新 docs-key-facts.tsv 的 pattern/行，或确认该事实已移出 docs/；维护后重跑 toolbox run docs-key-facts --json"
    exit 1
  fi
  json_line OK info "关键事实预检: ${G_FACTS} 条事实, 共 ${G_TOTAL} 处命中, 无 0 命中" ""
  exit 0
fi

echo "—— 关键事实报告（${G_FACTS} 条事实, 共 ${G_TOTAL} 处命中${G_ZERO:+, ⚠ ${G_ZERO} 条 0 命中}）——"
[ "$G_ZERO" -gt 0 ] && { echo "[remedy] 0 命中的事实：更新 scripts/agent-tools/docs-key-facts.tsv 或确认该事实已移出 docs/"; exit 1; }
exit 0
