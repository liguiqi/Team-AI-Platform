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
prepare_librechat_runtime_dirs
bash "$ROOT_DIR/scripts/render-librechat-config.sh"
bash "$ROOT_DIR/scripts/render-casdoor-config.sh"
docker_compose_up_retry 3
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
if [[ "$MODE" == "prod" ]]; then
  if prod_domain_proxy_enabled; then
    info "生产入口模式: domain-proxy（Caddy + HTTPS）"
  else
    info "生产入口模式: direct-ip（直连端口，无域名代理）"
  fi
fi

if [[ "${BOOTSTRAP_AUTOCONFIGURE:-false}" == "true" ]]; then
  info "检测到 BOOTSTRAP_AUTOCONFIGURE=true，开始自动 bootstrap"
  bash "$ROOT_DIR/scripts/bootstrap-new-api.sh" || true
fi
