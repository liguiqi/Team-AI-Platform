#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"
require_cmd docker
require_cmd curl
prepare_env_file
load_env
new_api_url="$(host_new_api_url)"
casdoor_url="$(host_casdoor_url)"
librechat_url="$(host_librechat_url)"

docker_compose ps

wait_for_http "${new_api_url}/api/status" 90 || die "NEW-API /api/status 不可用"
wait_for_http "${casdoor_url}/.well-known/openid-configuration" 90 || die "Casdoor OIDC discovery 不可用"
wait_for_http "${librechat_url}/health" 90 || die "LibreChat /health 不可用"

status_resp="$(curl -fsS "${new_api_url}/api/status")"
[[ "$status_resp" =~ \"success\"[[:space:]]*:[[:space:]]*true ]] || die "NEW-API 状态检查失败: $status_resp"

casdoor_resp="$(curl -fsS "${casdoor_url}/.well-known/openid-configuration")"
[[ "$casdoor_resp" =~ \"issuer\"[[:space:]]*: ]] || die "Casdoor discovery 返回异常: $casdoor_resp"

librechat_resp="$(curl -fsS "${librechat_url}/health")"
[[ "$librechat_resp" == "OK" ]] || die "LibreChat 健康检查失败: $librechat_resp"

info "应用层健康检查通过"
