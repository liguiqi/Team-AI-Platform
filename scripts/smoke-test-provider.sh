#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

provider_prefix="${1:-}"
provider_label="${2:-}"

[[ -n "$provider_prefix" && -n "$provider_label" ]] || die "用法: smoke-test-provider.sh <PROVIDER_PREFIX> <PROVIDER_LABEL>"

require_cmd curl
require_cmd jq

prepare_env_file
load_env
new_api_url="$(host_new_api_url)"

provider_enabled_var="${provider_prefix}_ENABLED"
provider_api_key_var="${provider_prefix}_API_KEY"
provider_exposed_models_var="${provider_prefix}_EXPOSED_MODEL"
provider_test_model_var="${provider_prefix}_TEST_MODEL"

provider_enabled="$(normalize_bool "${!provider_enabled_var:-false}")"
[[ "$provider_enabled" == "true" ]] || die "${provider_label} 未启用，请先设置 ${provider_enabled_var}=true"

provider_api_key="${!provider_api_key_var:-}"
provider_exposed_models="${!provider_exposed_models_var:-}"
provider_test_model="${!provider_test_model_var:-}"

require_non_placeholder_env "$provider_api_key_var" "$provider_api_key"
require_non_placeholder_env "$provider_test_model_var" "$provider_test_model"
[[ -n "$provider_exposed_models" ]] || die "请先在 $(env_file) 中填写 ${provider_exposed_models_var}"

bash "$ROOT_DIR/scripts/bootstrap-new-api.sh"
load_env

require_non_placeholder_env NEW_API_SERVICE_TOKEN "${NEW_API_SERVICE_TOKEN}"

models_resp="$(curl -fsS "${new_api_url}/v1/models" -H "Authorization: Bearer ${NEW_API_SERVICE_TOKEN}")"
expected_models_tmp="$(mktemp)"
actual_models_tmp="$(mktemp)"
chat_body="$(mktemp)"
trap 'rm -f "$expected_models_tmp" "$actual_models_tmp" "$chat_body"' EXIT

printf '%s' "${provider_exposed_models}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' >"$expected_models_tmp"
printf '%s' "$models_resp" | jq -r '.data[].id' | sed '/^$/d' >"$actual_models_tmp"

missing_models=()
while IFS= read -r model; do
  [[ -n "$model" ]] || continue
  if ! grep -Fxq "$model" "$actual_models_tmp"; then
    missing_models+=("$model")
  fi
done <"$expected_models_tmp"

if (( ${#missing_models[@]} > 0 )); then
  die "NEW-API /v1/models 缺少 ${provider_label} 模型: $(IFS=', '; printf '%s' "${missing_models[*]}")"
fi

payload="$(sed "s/__MODEL__/${provider_test_model}/g" "$ROOT_DIR/tests/smoke/chat-completions.template.json")"
chat_status="$(curl -sS -o "$chat_body" -w '%{http_code}' "${new_api_url}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${NEW_API_SERVICE_TOKEN}" \
  -d "$payload")"
chat_resp="$(cat "$chat_body")"

[[ "$chat_status" == "200" ]] || die "${provider_label} 聊天调用失败 (HTTP ${chat_status}): ${chat_resp}"
[[ "$chat_resp" == *"choices"* ]] || die "${provider_label} 聊天调用失败: ${chat_resp}"
info "${provider_label} smoke test 通过"
