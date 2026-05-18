#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"
require_cmd docker
[[ -f "$(env_file)" ]] || die "环境文件不存在: $(env_file)"
prepare_env_file
load_env
if [[ "$MODE" == "local" ]]; then
  bash "$ROOT_DIR/scripts/stop-local-smtp-relay.sh"
fi
bash "$ROOT_DIR/scripts/render-librechat-config.sh"
bash "$ROOT_DIR/scripts/render-casdoor-config.sh"
docker_compose down
if [[ "$MODE" == "local" ]]; then
  bash "$ROOT_DIR/scripts/start-local-smtp-relay.sh"
fi
docker_compose_up_retry 3
bash "$ROOT_DIR/scripts/sync-casdoor-auth-config.sh"
bash "$ROOT_DIR/scripts/sync-casdoor-providers.sh"
bash "$ROOT_DIR/scripts/bootstrap-librechat-admin.sh"
info "服务已重启"
