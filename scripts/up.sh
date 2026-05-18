#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd docker
[[ -f "$(env_file)" ]] || die "环境文件不存在，请先执行 make init 或创建 $(env_file)"
prepare_env_file

load_env
if [[ "$MODE" == "local" ]]; then
  bash "$ROOT_DIR/scripts/start-local-smtp-relay.sh"
fi
bash "$ROOT_DIR/scripts/render-librechat-config.sh"
bash "$ROOT_DIR/scripts/render-casdoor-config.sh"
docker_compose up -d
bash "$ROOT_DIR/scripts/sync-casdoor-auth-config.sh"
bash "$ROOT_DIR/scripts/sync-casdoor-providers.sh"
bash "$ROOT_DIR/scripts/bootstrap-librechat-admin.sh"

info "服务已启动"
if [[ "$MODE" == "local" ]]; then
  info "LibreChat: ${LIBRECHAT_PUBLIC_URL}"
  info "NEW-API: ${NEW_API_PUBLIC_URL}"
  info "SSO: ${CASDOOR_PUBLIC_URL}"
else
  info "LibreChat: ${LIBRECHAT_PUBLIC_URL}"
  info "NEW-API: ${NEW_API_PUBLIC_URL}"
  info "SSO: ${CASDOOR_PUBLIC_URL}"
fi

if [[ "${BOOTSTRAP_AUTOCONFIGURE:-false}" == "true" ]]; then
  info "检测到 BOOTSTRAP_AUTOCONFIGURE=true，开始自动 bootstrap"
  bash "$ROOT_DIR/scripts/bootstrap-new-api.sh" || true
fi
