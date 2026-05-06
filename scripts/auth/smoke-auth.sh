#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/_common.sh"

require_cmd curl
require_cmd jq

bash "$ROOT_DIR/scripts/auth/validate-auth-env.sh"
load_env

casdoor_url="$(host_casdoor_url)"
librechat_url="$(host_librechat_url)"
discovery_url="${casdoor_url%/}/.well-known/openid-configuration"
librechat_login_url="${librechat_url%/}/login"
expected_issuer="${CASDOOR_PUBLIC_URL%/}"
expected_callback="${LIBRECHAT_PUBLIC_URL%/}/oauth/openid/callback"

bash "$ROOT_DIR/scripts/render-casdoor-config.sh"

init_data_file="$(casdoor_init_data_file)"
[[ -f "$init_data_file" ]] || die "Casdoor 初始化数据不存在: $init_data_file"

jq -e --arg app "${CASDOOR_APPLICATION_NAME:-team-ai-librechat}" --arg uri "$expected_callback" '
  .applications[]
  | select(.name == $app)
  | .redirectUris
  | index($uri) != null
' "$init_data_file" >/dev/null || die "Casdoor redirectUris 缺少 LibreChat OIDC callback: $expected_callback"

wait_for_http "$discovery_url" 30 || die "Casdoor OIDC discovery 不可访问: $discovery_url"

discovery_json="$(curl -fsS "$discovery_url")"
issuer="$(jq -r '.issuer // ""' <<<"$discovery_json")"
authorization_endpoint="$(jq -r '.authorization_endpoint // ""' <<<"$discovery_json")"
token_endpoint="$(jq -r '.token_endpoint // ""' <<<"$discovery_json")"
jwks_uri="$(jq -r '.jwks_uri // ""' <<<"$discovery_json")"

[[ "$issuer" == "$expected_issuer" ]] || die "Casdoor issuer 不匹配，期望 $expected_issuer，实际 $issuer"
[[ -n "$authorization_endpoint" ]] || die "Casdoor discovery 缺少 authorization_endpoint"
[[ -n "$token_endpoint" ]] || die "Casdoor discovery 缺少 token_endpoint"
[[ -n "$jwks_uri" ]] || die "Casdoor discovery 缺少 jwks_uri"

wait_for_http "$librechat_login_url" 30 || die "LibreChat 登录页不可访问: $librechat_login_url"

if [[ -f "$(librechat_config_file)" ]]; then
  grep -q '"openid"\|'\''openid'\''' "$(librechat_config_file)" || die "LibreChat 配置未启用 openid social login"
else
  warn "LibreChat 配置文件不存在，跳过 openid 配置文件检查: $(librechat_config_file)"
fi

info "认证链路 smoke 检查通过"
