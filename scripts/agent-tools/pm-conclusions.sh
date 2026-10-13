#!/bin/sh
# pm-conclusions（脚手架——把占位实现替换为真实逻辑）
#
# toolbox-script
# format: v1
# name: pm-conclusions
# summary: pm-conclusions
# trigger: manual
# platform: unix
# self-test: --self-test

set -eu
MSG=""

usage() {
  cat <<'EOF'
用法: pm-conclusions.sh [--json] [--self-test]
  --json       输出一行 JSON 契约结论（message 内禁双引号）
  --self-test  金丝雀自检（guard 类必实现）
EOF
}

run_checks() {
  # TODO: 实现真实检查；失败把人话（问题本身+修复方向）写入 MSG 并 return 1
  MSG="脚手架尚未实现检查逻辑"
  return 1
}

self_test() {
  # TODO: 金丝雀——构造已知坏样本断言能抓到坏；好样本应通过
  echo "self-test: 脚手架占位未实现真实检查，禁止登记"
  return 2
}

case "${1-}" in
  --self-test)
    self_test
    ;;
  --json)
    if run_checks; then
      printf '{"status":"OK","severity":"info","message":"%s"}
' "$MSG"
      exit 0
    fi
    printf '{"status":"FAIL","severity":"warn","message":"%s"}
' "$MSG"
    exit 1
    ;;
  --help|-h)
    usage
    ;;
  "")
    if run_checks; then
      echo "OK: $MSG"
    else
      echo "FAIL: $MSG"
      exit 1
    fi
    ;;
  *)
    usage
    exit 2
    ;;
esac
