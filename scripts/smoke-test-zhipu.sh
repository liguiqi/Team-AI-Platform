#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"
require_cmd curl
require_cmd jq

prepare_env_file
load_env
new_api_url="$(host_new_api_url)"
require_non_placeholder_env ZHIPU_API_KEY "${ZHIPU_API_KEY}"
require_non_placeholder_env ZHIPU_TEST_MODEL "${ZHIPU_TEST_MODEL}"

bash "$ROOT_DIR/scripts/bootstrap-new-api.sh"
load_env

require_non_placeholder_env NEW_API_SERVICE_TOKEN "${NEW_API_SERVICE_TOKEN}"

models_resp="$(curl -fsS "${new_api_url}/v1/models" -H "Authorization: Bearer ${NEW_API_SERVICE_TOKEN}")"
expected_models_tmp="$(mktemp)"
actual_models_tmp="$(mktemp)"
chat_body="$(mktemp)"
trap 'rm -f "$expected_models_tmp" "$actual_models_tmp" "$chat_body"' EXIT

printf '%s' "${ZHIPU_EXPOSED_MODEL}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' >"$expected_models_tmp"
printf '%s' "$models_resp" | jq -r '.data[].id' | sed '/^$/d' >"$actual_models_tmp"

missing_models=()
while IFS= read -r model; do
  [[ -n "$model" ]] || continue
  if ! grep -Fxq "$model" "$actual_models_tmp"; then
    missing_models+=("$model")
  fi
done <"$expected_models_tmp"

if (( ${#missing_models[@]} > 0 )); then
  die "NEW-API /v1/models 缺少模型: $(IFS=', '; printf '%s' "${missing_models[*]}")"
fi

payload="$(sed "s/__MODEL__/${ZHIPU_TEST_MODEL}/g" "$ROOT_DIR/tests/smoke/chat-completions.template.json")"
chat_status="$(curl -sS -o "$chat_body" -w '%{http_code}' "${new_api_url}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${NEW_API_SERVICE_TOKEN}" \
  -d "$payload")"
chat_resp="$(cat "$chat_body")"

[[ "$chat_status" == "200" ]] || die "智谱聊天调用失败 (HTTP ${chat_status}): ${chat_resp}"
[[ "$chat_resp" == *"choices"* ]] || die "智谱聊天调用失败: $chat_resp"
info "智谱 smoke test 通过"
