#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd docker
require_cmd curl
docker compose version >/dev/null 2>&1 || die "缺少 docker compose"

[[ -f "$(env_file)" ]] || die "环境文件不存在: $(env_file)"
load_env

if docker compose --env-file "$(env_file)" -f "$(compose_file)" config >/dev/null; then
  info "compose 配置校验通过"
else
  die "compose 配置校验失败"
fi

if [[ "$MODE" == "local" ]]; then
  sync_local_env_copy
  for port in "${NEW_API_PORT}" "${LIBRECHAT_PORT}"; do
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${port}$"; then
      warn "端口 ${port} 已被占用或已有服务监听"
    fi
  done
fi

for key in ZHIPU_API_KEY NEW_API_SETUP_PASSWORD NEW_API_SERVICE_PASSWORD; do
  value="$(current_env_value "$key" "$(env_file)")"
  if is_placeholder "$value"; then
    warn "$key 仍为占位值"
  fi
done

info "doctor 检查完成"

