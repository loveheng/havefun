#!/usr/bin/env bash
# toolbox-script
# format: v1
# name: derived-check
# summary: docs/PM/ 派生件新鲜度自查：源标注/源存在/源 updated 与派生件比对（软）
# trigger: manual
# platform: unix
# self-test: --self-test
# cat: docs
set -u

usage() {
cat <<'EOF'
derived-check — docs/PM/ 派生件新鲜度自查（xiaolequ-docs PM 域派生纪律的机械实现）

用法: toolbox run derived-check [--json] [--self-test] [-h|--help] [repo-root]

裸跑 = 对 docs/PM/ 每个派生件检查：
  ① 源标注：文档须引用至少一个其他文档（硬——派生件必须标注源文档，
     标注形式：链接目标 / 反引号路径 / 「来源」「归并自」行的 docs/、internal/ 相对路径）
  ② 源引用目标：被引用的 .md 必须存在（先按文档所在目录解析，再按仓库根解析）（硬）
  ③ 新鲜度：源文档 frontmatter updated 比派生件新 → 提醒核对应否刷新（软，不拦截）

退出码: 0=通过（含仅软提醒） 1=有硬违规 2=自身故障
--json 单行 JSON 契约结论；--self-test 金丝雀自测（内嵌 stale/orphan/broken 坏样本）。
EOF
}

json_line() { printf '{"status":"%s","severity":"%s","message":"%s","remedy":"%s"}\n' "$1" "$2" "$3" "$4"; }

HARD=0; SOFT=0
hard() { HARD=$((HARD+1)); echo "✗ $1"; }
soft() { SOFT=$((SOFT+1)); echo "⚠ $1"; }

get_updated() {  # $1=文件 → 输出 YYYY-MM-DD 或空
  sed -n '3p' "$1" 2>/dev/null | grep -oE 'updated: [0-9]{4}-[0-9]{2}-[0-9]{2}' | awk '{print $2}'
}

extract_refs() {  # $1=派生件 → 候选 .md 引用列表（去重；含链接目标/反引号路径/来源行裸路径）
  {
    grep -oE '\]\([^)]+\.md\)' "$1" 2>/dev/null | sed -E 's/^\]\((.*)\)$/\1/'
    grep -oE '`[^`]+\.md`' "$1" 2>/dev/null | sed -E 's/^`//; s/`$//'
    grep -oE '(docs|internal)/[^[:space:]`（）、，。；;:：]+\.md' "$1" 2>/dev/null
  } | sed -E 's/#.*$//' | grep -vE '^(https?|mailto):' | grep -vE '^#' | sort -u
}

check_repo() {
  local ROOT="$1" f rel base dupdated tupdated target tpath paths nref
  [ -d "$ROOT/docs/PM" ] || { echo "[remedy] 未找到 docs/PM/：$ROOT/docs/PM（请在仓库根运行或传仓库路径作位置参数）"; return 2; }
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rel="${f#"$ROOT"/}"
    base=$(dirname "$f")
    dupdated=$(get_updated "$f")
    [ -n "$dupdated" ] || hard "$rel: frontmatter 缺 updated，无法比对新鲜度（docs-spec §1）"
    paths=$(extract_refs "$f")
    if [ -z "$paths" ]; then
      hard "$rel: 未找到任何源文档标注（PM 域派生件必须标注源文档）"
      continue
    fi
    nref=0
    while IFS= read -r target; do
      [ -n "$target" ] || continue
      [ "$target" = "$rel" ] && continue
      if [ -f "$base/$target" ]; then tpath="$base/$target"
      elif [ -f "$ROOT/$target" ]; then tpath="$ROOT/$target"
      else
        hard "$rel: 源引用目标不存在: $target"
        continue
      fi
      nref=$((nref+1))
      tupdated=$(get_updated "$tpath")
      if [ -n "$tupdated" ] && [ -n "$dupdated" ] && [[ "$tupdated" > "$dupdated" ]]; then
        soft "$rel: 源文档比派生件新 —— ${tpath#"$ROOT"/}（updated $tupdated > $dupdated），核对应否刷新派生件"
      fi
    done <<< "$paths"
    [ "$nref" -ge 1 ] || hard "$rel: 源引用全部未解析成功"
  done < <(find "$ROOT/docs/PM" -name '*.md' | sort)
}

self_test() {
  local T OUT RC
  T=$(mktemp -d) || return 2
  mkdir -p "$T/docs/requirements" "$T/docs/PM"
  printf -- '---\nstatus: active\nupdated: 2026-02-01\n---\n\n# src\n' > "$T/docs/requirements/src.md"
  printf -- '---\nstatus: active\nupdated: 2026-03-01\n---\n\n# good\n\n见[源](../requirements/src.md)。\n' > "$T/docs/PM/good.md"
  printf -- '---\nstatus: active\nupdated: 2026-01-01\n---\n\n# stale\n\n见[源](../requirements/src.md)。\n' > "$T/docs/PM/stale.md"
  printf -- '---\nstatus: active\nupdated: 2026-03-01\n---\n\n# orphan\n\n无引用。\n' > "$T/docs/PM/orphan.md"
  printf -- '---\nstatus: active\nupdated: 2026-03-01\n---\n\n# broken\n\n见[nope](../requirements/nope.md)。\n' > "$T/docs/PM/broken.md"
  OUT=$("$0" "$T" 2>&1); RC=$?
  rm -rf "$T"
  if [ $RC -eq 1 ] \
     && printf '%s\n' "$OUT" | grep -q 'stale.md.*源文档比派生件新' \
     && printf '%s\n' "$OUT" | grep -q 'orphan.md.*未找到任何源文档标注' \
     && printf '%s\n' "$OUT" | grep -q 'broken.md.*源引用目标不存在' \
     && ! printf '%s\n' "$OUT" | grep -q 'good.md.*源文档比派生件新'; then
    echo "self-test OK：stale/orphan/broken 金丝雀均命中，good 无软告警误报"
    return 0
  fi
  echo "self-test FAIL (rc=$RC)"; printf '%s\n' "$OUT"
  return 1
}

JSON=0; SELF_TEST=0; ROOT_ARG=''
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --json) JSON=1 ;;
    --self-test) SELF_TEST=1 ;;
    --*) echo "未知参数: $arg（见 --help）"; exit 2 ;;
    *) ROOT_ARG="$arg" ;;
  esac
done

if [ "$SELF_TEST" = "1" ]; then self_test; exit $?; fi

ROOT="${ROOT_ARG:-.}"
[ -d "$ROOT/docs" ] || { echo "[remedy] 未找到 docs/ 目录（$ROOT）：请在仓库根运行或传仓库路径作位置参数"; exit 2; }
ROOT=$(cd "$ROOT" && pwd)
check_repo "$ROOT"
RC=$?
if [ $RC -eq 2 ]; then exit 2; fi

if [ "$JSON" = "1" ]; then
  if [ "$HARD" -gt 0 ]; then
    json_line FAIL warn "派生件检查 ${HARD} 处硬违规; 软提醒 ${SOFT} 条" "逐项 ✗ 处理：补源标注/修源路径/刷新派生件，见 xiaolequ-docs PM 域派生纪律；修复后重跑 toolbox run derived-check"
    exit 1
  fi
  if [ "$SOFT" -gt 0 ]; then
    json_line OK info "派生件检查通过; 软提醒 ${SOFT} 条（源文档比派生件新，需人工核对）" ""
  else
    json_line OK info "派生件检查通过（源标注+源存在+新鲜度）" ""
  fi
  exit 0
fi

if [ "$HARD" -gt 0 ]; then
  echo "[remedy] 逐项 ✗ 处理：补源标注/修源路径/刷新派生件，见 xiaolequ-docs PM 域派生纪律；修复后重跑 toolbox run derived-check"
  exit 1
fi
if [ "$SOFT" -gt 0 ]; then
  echo "⚠ ${SOFT} 条软提醒（源文档比派生件新）：请人工核对派生件是否需刷新（不拦截）"
else
  echo "✓ 派生件检查通过（源标注 + 源存在 + 新鲜度）"
fi
exit 0
