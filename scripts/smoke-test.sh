#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

bash "$ROOT_DIR/scripts/healthcheck.sh"
load_env

if [[ "${ZHIPU_ENABLED:-false}" == "true" ]] && ! is_placeholder "${ZHIPU_API_KEY:-}"; then
  bash "$ROOT_DIR/scripts/smoke-test-zhipu.sh"
else
  warn "未检测到真实 ZHIPU_API_KEY，跳过智谱真实联调，仅完成健康检查"
fi

if [[ "$(normalize_bool "${DEEPSEEK_ENABLED:-false}")" == "true" ]] && ! is_placeholder "${DEEPSEEK_API_KEY:-}"; then
  bash "$ROOT_DIR/scripts/smoke-test-deepseek.sh"
else
  warn "未检测到真实 DEEPSEEK_API_KEY，跳过 DeepSeek 真实联调，仅完成健康检查"
fi
