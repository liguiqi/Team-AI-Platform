#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd curl
require_cmd jq

prepare_env_file
load_env

provider_model_list_urls() {
  local prefix="$1"
  local urls_var="${prefix}_MODEL_LIST_URLS"
  local base_url_var="${prefix}_API_BASE_URL"
  local configured_urls="${!urls_var:-}"
  local base_url="${!base_url_var:-}"

  if [[ -n "$configured_urls" ]]; then
    printf '%s' "$configured_urls" | csv_to_lines
    return 0
  fi

  base_url="${base_url%/}"
  case "$prefix" in
    ZHIPU)
      printf '%s\n' \
        "${base_url}/api/paas/v4/models" \
        "${base_url}/v1/models" \
        "${base_url}/models"
      ;;
    DEEPSEEK)
      printf '%s\n' \
        "${base_url}/models" \
        "${base_url}/v1/models"
      ;;
    ALIYUN)
      printf '%s\n' \
        "${base_url}/v1/models" \
        "${base_url}/models"
      ;;
    *)
      printf '%s\n' \
        "${base_url}/models" \
        "${base_url}/v1/models"
      ;;
  esac
}

extract_model_ids() {
  jq -r '
    def model_id:
      if type == "string" then .
      elif type == "object" then (.id // .name // .model // empty)
      else empty end;
    if type == "object" and (.data? | type == "array") then
      .data[] | model_id
    elif type == "object" and (.models? | type == "array") then
      .models[] | model_id
    elif type == "array" then
      .[] | model_id
    else
      empty
    end
  ' 2>/dev/null | sed '/^$/d' | awk '!seen[$0]++'
}

filter_models_for_provider() {
  local prefix="$1"
  local include_regex_var="${prefix}_MODEL_INCLUDE_REGEX"
  local exclude_regex_var="${prefix}_MODEL_EXCLUDE_REGEX"
  local include_regex="${!include_regex_var:-}"
  local exclude_regex="${!exclude_regex_var:-}"
  local model

  while IFS= read -r model; do
    [[ -n "$model" ]] || continue
    if [[ -n "$include_regex" ]] && ! [[ "$model" =~ $include_regex ]]; then
      continue
    fi
    if [[ -n "$exclude_regex" ]] && [[ "$model" =~ $exclude_regex ]]; then
      continue
    fi
    printf '%s\n' "$model"
  done
}

fetch_provider_models() {
  local prefix="$1"
  local api_key_var="${prefix}_API_KEY"
  local api_key="${!api_key_var:-}"
  local url resp_tmp models_tmp model_count

  require_non_placeholder_env "$api_key_var" "$api_key"

  resp_tmp="$(mktemp)"
  models_tmp="$(mktemp)"

  while IFS= read -r url; do
    [[ -n "$url" ]] || continue
    if curl -fsS --connect-timeout 10 --max-time 30 \
      -H "Authorization: Bearer ${api_key}" \
      -H 'Accept: application/json' \
      "$url" -o "$resp_tmp" 2>/dev/null; then
      extract_model_ids <"$resp_tmp" | filter_models_for_provider "$prefix" >"$models_tmp"
      model_count="$(wc -l <"$models_tmp" | tr -d ' ')"
      if (( model_count > 0 )); then
        paste -sd, "$models_tmp"
        rm -f "$resp_tmp" "$models_tmp"
        return 0
      fi
    fi
  done < <(provider_model_list_urls "$prefix")

  rm -f "$resp_tmp" "$models_tmp"
  return 1
}

sync_provider_models() {
  local prefix="$1"
  local provider_label
  local enabled exposed_var order_var default_model_var test_model_var current_models fetched_models sorted_models first_model default_model test_model

  provider_label="$(provider_display_label "$prefix")"
  enabled="$(provider_is_enabled_env "$prefix")"
  [[ "$enabled" == "true" ]] || {
    info "已跳过未启用的 ${provider_label} 模型同步"
    return 0
  }

  exposed_var="${prefix}_EXPOSED_MODEL"
  order_var="${prefix}_MODEL_ORDER"
  default_model_var="${prefix}_DEFAULT_MODEL"
  test_model_var="${prefix}_TEST_MODEL"
  current_models="${!exposed_var:-}"

  if fetched_models="$(fetch_provider_models "$prefix")"; then
    sorted_models="$(sort_models_by_priority "$fetched_models" "${!order_var:-}")"
    info "${provider_label} 模型 API 检测完成: $(printf '%s' "$sorted_models" | csv_to_lines | wc -l | tr -d ' ') 个模型"
  else
    warn "${provider_label} 模型 API 检测失败，保留当前 ${exposed_var}"
    sorted_models="$(sort_models_by_priority "$current_models" "${!order_var:-}")"
  fi

  [[ -n "$sorted_models" ]] || die "${provider_label} 模型列表为空，无法同步"

  if [[ "$sorted_models" != "$current_models" ]]; then
    replace_or_append_env "$exposed_var" "$sorted_models" "$(env_file)"
    info "已更新 ${exposed_var}"
  else
    info "${exposed_var} 无变化"
  fi

  first_model="$(printf '%s' "$sorted_models" | csv_to_lines | head -n 1)"
  default_model="${!default_model_var:-}"
  test_model="${!test_model_var:-}"

  if [[ -n "$first_model" ]]; then
    if [[ -z "$default_model" ]] || ! csv_contains_value "$sorted_models" "$default_model"; then
      replace_or_append_env "$default_model_var" "$first_model" "$(env_file)"
      info "已将 ${default_model_var} 更新为 ${first_model}"
    fi

    if [[ -z "$test_model" ]] || ! csv_contains_value "$sorted_models" "$test_model"; then
      replace_or_append_env "$test_model_var" "$first_model" "$(env_file)"
      info "已将 ${test_model_var} 更新为 ${first_model}"
    fi
  fi
}

while IFS= read -r prefix; do
  sync_provider_models "$prefix"
done < <(provider_prefixes)

if [[ "$MODE" == "local" ]]; then
  sync_local_env_copy
fi

if [[ "$(normalize_bool "${SYNC_PROVIDER_MODELS_BOOTSTRAP:-true}")" == "true" ]]; then
  bash "$ROOT_DIR/scripts/bootstrap-new-api.sh"
else
  bash "$ROOT_DIR/scripts/render-librechat-config.sh"
fi

info "供应商模型同步完成"
