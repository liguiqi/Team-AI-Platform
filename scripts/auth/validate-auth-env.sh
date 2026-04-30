#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/_common.sh"

[[ -f "$(env_file)" ]] || die "环境文件不存在: $(env_file)"
prepare_env_file
load_env

has_word() {
  local haystack="$1"
  local needle="$2"
  [[ " ${haystack} " == *" ${needle} "* ]]
}

is_https_url() {
  [[ "${1:-}" =~ ^https:// ]]
}

is_hex_length() {
  local value="$1"
  local length="$2"
  [[ "$value" =~ ^[A-Fa-f0-9]+$ && "${#value}" -eq "$length" ]]
}

warn_if_placeholder_or_short() {
  local key="$1"
  local min_length="$2"
  local value="${!key:-}"

  if is_placeholder "$value"; then
    warn "$key 仍为占位值"
  elif (( ${#value} < min_length )); then
    warn "$key 长度建议 >= ${min_length}"
  fi
}

warn_if_hex_invalid() {
  local key="$1"
  local length="$2"
  local value="${!key:-}"

  if is_placeholder "$value"; then
    warn "$key 仍为占位值"
  elif ! is_hex_length "$value" "$length"; then
    warn "$key 建议为 ${length} 位 hex"
  fi
}

require_auth_bool() {
  local key="$1"
  normalize_bool "${!key:-false}" >/dev/null
}

for key in \
  CASDOOR_ENABLE_SIGNUP \
  CASDOOR_ENABLE_PASSWORD_LOGIN \
  CASDOOR_ENABLE_VERIFICATION_CODE_LOGIN \
  CASDOOR_ENABLE_PASSWORD_GRANT \
  LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP \
  LIBRECHAT_OPENID_PATCH_INSECURE_HTTP; do
  require_auth_bool "$key"
done

[[ "${CASDOOR_OIDC_EXPIRE_IN_HOURS:-}" =~ ^[0-9]+$ ]] || die "CASDOOR_OIDC_EXPIRE_IN_HOURS 必须是非负整数"
[[ "${CASDOOR_OIDC_COOKIE_EXPIRE_IN_HOURS:-}" =~ ^[0-9]+$ ]] || die "CASDOOR_OIDC_COOKIE_EXPIRE_IN_HOURS 必须是非负整数"

has_word "${LIBRECHAT_OPENID_SCOPE:-}" openid || die "LIBRECHAT_OPENID_SCOPE 必须包含 openid"

if [[ "${CASDOOR_USER_ORGANIZATION_NAME:-}" == "built-in" ]]; then
  die "CASDOOR_USER_ORGANIZATION_NAME 不能为 built-in，否则业务用户会进入 Casdoor 全局管理员组织"
fi

if [[ "${CASDOOR_ENABLE_PASSWORD_GRANT:-false}" != "true" && "${CASDOOR_OIDC_GRANT_TYPES:-}" == *password* ]]; then
  die "CASDOOR_ENABLE_PASSWORD_GRANT=false 时，CASDOOR_OIDC_GRANT_TYPES 不应包含 password"
fi

if [[ -n "${AUTH_CLIENTS_JSON:-}" ]]; then
  require_cmd jq
  jq -e 'type == "array"' >/dev/null <<<"${AUTH_CLIENTS_JSON}" || die "AUTH_CLIENTS_JSON 必须是 JSON 数组"
fi

warn_if_placeholder_or_short CASDOOR_CLIENT_SECRET 32
warn_if_placeholder_or_short LIBRECHAT_OPENID_SESSION_SECRET 32
warn_if_hex_invalid LIBRECHAT_JWT_SECRET 64
warn_if_hex_invalid LIBRECHAT_JWT_REFRESH_SECRET 64
warn_if_hex_invalid LIBRECHAT_CREDS_KEY 64
warn_if_hex_invalid LIBRECHAT_CREDS_IV 32

if [[ "$MODE" == "prod" ]]; then
  is_https_url "${LIBRECHAT_PUBLIC_URL:-}" || die "生产环境 LIBRECHAT_PUBLIC_URL 必须使用 https://"
  is_https_url "${CASDOOR_PUBLIC_URL:-}" || die "生产环境 CASDOOR_PUBLIC_URL 必须使用 https://"
  is_https_url "${NEW_API_PUBLIC_URL:-}" || die "生产环境 NEW_API_PUBLIC_URL 必须使用 https://"

  [[ "$(normalize_bool "${LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP:-false}")" == "false" ]] || die "生产环境必须关闭 LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP"
  [[ "$(normalize_bool "${LIBRECHAT_OPENID_PATCH_INSECURE_HTTP:-false}")" == "false" ]] || die "生产环境必须关闭 LIBRECHAT_OPENID_PATCH_INSECURE_HTTP"
  [[ "${LIBRECHAT_NODE_OPTIONS:-}" != *openid-insecure-http.js* ]] || die "生产环境 LIBRECHAT_NODE_OPTIONS 不得加载 openid-insecure-http.js"
  [[ "$(normalize_bool "${CASDOOR_INIT_DATA_NEW_ONLY:-false}")" == "true" ]] || die "生产环境 CASDOOR_INIT_DATA_NEW_ONLY 必须为 true，避免重启反复覆盖线上配置"
elif [[ "$(normalize_bool "${LIBRECHAT_OPENID_PATCH_INSECURE_HTTP:-false}")" == "true" && "${LIBRECHAT_NODE_OPTIONS:-}" != *openid-insecure-http.js* ]]; then
  warn "LIBRECHAT_OPENID_PATCH_INSECURE_HTTP=true，但 LIBRECHAT_NODE_OPTIONS 未加载 openid-insecure-http.js"
fi

info "认证环境变量校验完成"
