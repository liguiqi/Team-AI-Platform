#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"
require_cmd curl

prepare_env_file
load_env
new_api_url="$(host_new_api_url)"
require_non_placeholder_env ZHIPU_API_KEY "${ZHIPU_API_KEY}"

bash "$ROOT_DIR/scripts/bootstrap-new-api.sh"
load_env

require_non_placeholder_env NEW_API_SERVICE_TOKEN "${NEW_API_SERVICE_TOKEN}"

models_resp="$(curl -fsS "${new_api_url}/v1/models" -H "Authorization: Bearer ${NEW_API_SERVICE_TOKEN}")"
[[ "$models_resp" == *"${ZHIPU_EXPOSED_MODEL}"* ]] || die "NEW-API /v1/models 未返回 ${ZHIPU_EXPOSED_MODEL}"

payload="$(sed "s/__MODEL__/${ZHIPU_EXPOSED_MODEL}/g" "$ROOT_DIR/tests/smoke/chat-completions.template.json")"
chat_body="$(mktemp)"
trap 'rm -f "$chat_body"' EXIT
chat_status="$(curl -sS -o "$chat_body" -w '%{http_code}' "${new_api_url}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${NEW_API_SERVICE_TOKEN}" \
  -d "$payload")"
chat_resp="$(cat "$chat_body")"

[[ "$chat_status" == "200" ]] || die "智谱聊天调用失败 (HTTP ${chat_status}): ${chat_resp}"
[[ "$chat_resp" == *"choices"* ]] || die "智谱聊天调用失败: $chat_resp"
info "智谱 smoke test 通过"
