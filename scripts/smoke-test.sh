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

if [[ "$(normalize_bool "${ALIYUN_ENABLED:-false}")" == "true" ]] && ! is_placeholder "${ALIYUN_API_KEY:-}"; then
  bash "$ROOT_DIR/scripts/smoke-test-aliyun.sh"
else
  warn "未检测到真实 ALIYUN_API_KEY，跳过阿里云百炼真实联调，仅完成健康检查"
fi

if [[ "$(normalize_bool "${KIMI_ENABLED:-false}")" == "true" ]] && ! is_placeholder "${KIMI_API_KEY:-}"; then
  bash "$ROOT_DIR/scripts/smoke-test-kimi.sh"
else
  warn "未检测到真实 KIMI_API_KEY，跳过 Kimi 真实联调，仅完成健康检查"
fi

if [[ "$(normalize_bool "${DOUBAO_ENABLED:-false}")" == "true" ]] && ! is_placeholder "${DOUBAO_API_KEY:-}"; then
  bash "$ROOT_DIR/scripts/smoke-test-doubao.sh"
else
  warn "未检测到真实 DOUBAO_API_KEY，跳过火山方舟豆包真实联调，仅完成健康检查"
fi

if [[ "$(normalize_bool "${MIMO_ENABLED:-false}")" == "true" ]] && ! is_placeholder "${MIMO_API_KEY:-}"; then
  bash "$ROOT_DIR/scripts/smoke-test-mimo.sh"
else
  warn "未检测到真实 MIMO_API_KEY，跳过小米 MiMo 真实联调，仅完成健康检查"
fi

if [[ "$(normalize_bool "${MINIMAX_ENABLED:-false}")" == "true" ]] && ! is_placeholder "${MINIMAX_API_KEY:-}"; then
  bash "$ROOT_DIR/scripts/smoke-test-minimax.sh"
else
  warn "未检测到真实 MINIMAX_API_KEY，跳过 MiniMax 真实联调，仅完成健康检查"
fi
