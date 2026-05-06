#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"
require_cmd docker
[[ -f "$(env_file)" ]] || die "环境文件不存在: $(env_file)"
docker_compose down
if [[ "$MODE" == "local" ]]; then
  bash "$ROOT_DIR/scripts/stop-local-smtp-relay.sh"
fi
info "服务已停止"
