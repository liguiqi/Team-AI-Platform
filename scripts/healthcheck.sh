#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"
require_cmd docker
require_cmd curl
load_env

if [[ "$MODE" == "local" ]]; then
  sync_local_env_copy
fi

docker_compose ps

wait_for_http "${NEW_API_PUBLIC_URL}/api/status" 90 || die "NEW-API /api/status 不可用"
wait_for_http "${LIBRECHAT_PUBLIC_URL}/health" 90 || die "LibreChat /health 不可用"

status_resp="$(curl -fsS "${NEW_API_PUBLIC_URL}/api/status")"
[[ "$status_resp" =~ \"success\"[[:space:]]*:[[:space:]]*true ]] || die "NEW-API 状态检查失败: $status_resp"

librechat_resp="$(curl -fsS "${LIBRECHAT_PUBLIC_URL}/health")"
[[ "$librechat_resp" == "OK" ]] || die "LibreChat 健康检查失败: $librechat_resp"

info "应用层健康检查通过"

