#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd docker
require_cmd curl
docker compose version >/dev/null 2>&1 || die "缺少 docker compose"

[[ -f "$(env_file)" ]] || die "环境文件不存在: $(env_file)"
prepare_env_file
load_env
env_path="$(env_file)"

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

if [[ "$MODE" == "prod" ]]; then
  librechat_public_url="$(current_env_value LIBRECHAT_PUBLIC_URL "$env_path")"
  new_api_public_url="$(current_env_value NEW_API_PUBLIC_URL "$env_path")"
  casdoor_public_url="$(current_env_value CASDOOR_PUBLIC_URL "$env_path")"
  librechat_allow_insecure_http="$(normalize_bool "$(current_env_value LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP "$env_path")")"

  if prod_domain_proxy_enabled; then
    [[ "$librechat_public_url" == https://* ]] || warn "domain-proxy 模式下建议 LIBRECHAT_PUBLIC_URL 使用 https:// 域名地址"
    [[ "$new_api_public_url" == https://* ]] || warn "domain-proxy 模式下建议 NEW_API_PUBLIC_URL 使用 https:// 域名地址"
    [[ "$casdoor_public_url" == https://* ]] || warn "domain-proxy 模式下建议 CASDOOR_PUBLIC_URL 使用 https:// 域名地址"
    [[ "$librechat_allow_insecure_http" == "false" ]] || warn "domain-proxy 模式下建议 LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP=false"
  else
    [[ "$librechat_public_url" == http://* ]] || warn "直连端口模式下建议 LIBRECHAT_PUBLIC_URL 使用 http://IP:PORT"
    [[ "$new_api_public_url" == http://* ]] || warn "直连端口模式下建议 NEW_API_PUBLIC_URL 使用 http://IP:PORT"
    [[ "$casdoor_public_url" == http://* ]] || warn "直连端口模式下建议 CASDOOR_PUBLIC_URL 使用 http://IP:PORT"
    [[ "$librechat_allow_insecure_http" == "true" ]] || warn "直连端口模式下需要 LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP=true，否则 OIDC 回调可能失败"
  fi
fi

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
