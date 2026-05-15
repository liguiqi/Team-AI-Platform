#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd docker
require_cmd curl
docker compose version >/dev/null 2>&1 || die "缺少 docker compose"

[[ -f "$(env_file)" ]] || die "环境文件不存在: $(env_file)"
prepare_env_file
load_env

if docker compose --env-file "$(env_file)" -f "$(compose_file)" config >/dev/null; then
  info "compose 配置校验通过"
else
  die "compose 配置校验失败"
fi

if [[ "$MODE" == "local" ]]; then
  sync_local_env_copy
  for port in "${NEW_API_PORT}" "${LIBRECHAT_PORT}" "${CASDOOR_PORT}"; do
    if ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":${port}$"; then
      warn "端口 ${port} 已被占用或已有服务监听"
    fi
  done
fi

while IFS= read -r prefix; do
  api_key_var="${prefix}_API_KEY"
  if [[ "$(provider_is_enabled_env "$prefix")" == "true" ]] && is_placeholder "${!api_key_var:-}"; then
    warn "$api_key_var 仍为占位值"
  fi
done < <(provider_prefixes)

for key in \
  NEW_API_SETUP_PASSWORD \
  NEW_API_SERVICE_PASSWORD \
  CASDOOR_CLIENT_SECRET \
  CASDOOR_ADMIN_PASSWORD \
  CASDOOR_EMAIL_SMTP_HOST \
  CASDOOR_EMAIL_SMTP_USERNAME \
  CASDOOR_EMAIL_SMTP_PASSWORD \
  CASDOOR_SMS_ACCESS_KEY_ID \
  CASDOOR_SMS_ACCESS_KEY_SECRET \
  CASDOOR_SMS_SIGN_NAME \
  CASDOOR_SMS_TEMPLATE_CODE \
  LIBRECHAT_OPENID_SESSION_SECRET; do
  value="$(current_env_value "$key" "$(env_file)")"
  if is_placeholder "$value"; then
    warn "$key 仍为占位值"
  fi
done

info "doctor 检查完成"
