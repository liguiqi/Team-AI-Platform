#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "[ERROR] 当前目录不是 Git 仓库" >&2
  exit 1
fi

if ! git ls-files | grep -q .; then
  echo "[INFO] 当前没有已纳入 Git 的文件，跳过扫描"
  exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if git ls-files -z | xargs -0 rg -n --no-heading \
  -e 'BEGIN (RSA|EC|OPENSSH) PRIVATE KEY' \
  -e 'AKIA[0-9A-Z]{16}' \
  -e 'LTAI[0-9A-Za-z]{12,}' \
  -e 'sk-[A-Za-z0-9_-]{20,}' \
  -e '[A-Za-z0-9]{32}\.[A-Za-z0-9]{10,}' >"$tmp"; then
  echo "[ERROR] 发现疑似敏感信息，请处理后再提交:" >&2
  cat "$tmp" >&2
  exit 1
fi

echo "[INFO] 未在已纳入 Git 的文件中发现明显敏感信息"
