#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

prepare_env_file
load_env
require_cmd sed
new_api_url="$(host_new_api_url)"

target_file="$(librechat_config_file)"
prepare_runtime_file_path "$target_file"

if is_placeholder "${CASDOOR_CLIENT_SECRET:-}" || is_placeholder "${LIBRECHAT_OPENID_SESSION_SECRET:-}" || is_placeholder "${CASDOOR_PUBLIC_URL:-}"; then
  warn "Casdoor OIDC 变量仍为占位值，LibreChat 登录页将显示统一认证入口，但无法完成真实登录"
fi

librechat_fetch_models="$(normalize_bool "${LIBRECHAT_FETCH_MODELS:-true}")"
librechat_split_provider_endpoints="$(normalize_bool "${LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS:-true}")"

models_default_yaml() {
  local models_csv="${1:-}"
  local indent="${2:-10}"
  local spaces model yaml=""

  spaces="$(printf '%*s' "$indent" '')"
  while IFS= read -r model; do
    [[ -n "$model" ]] || continue
    yaml="${yaml}"$'\n'"${spaces}- \"$(json_escape "$model")\""
  done < <(printf '%s' "$models_csv" | csv_to_lines)

  if [[ -n "$yaml" ]]; then
    printf '%s' "$yaml"
  else
    printf ' []'
  fi
}

render_provider_endpoints() {
  local endpoints_yaml="" prefix enabled models_csv endpoint_name title_model model_label models_yaml

  while IFS= read -r prefix; do
    enabled="$(provider_is_enabled_env "$prefix")"
    [[ "$enabled" == "true" ]] || continue

    models_csv="$(provider_sorted_exposed_models "$prefix")"
    if [[ -z "$models_csv" ]]; then
      warn "已跳过 ${prefix} LibreChat endpoint：模型列表为空"
      continue
    fi

    endpoint_name="$(provider_endpoint_name "$prefix")"
    title_model="$(provider_title_model "$prefix" "$models_csv")"
    model_label="$(provider_model_label "$prefix")"
    models_yaml="$(models_default_yaml "$models_csv" 10)"

    endpoints_yaml="${endpoints_yaml}"$'\n'"    - name: \"$(json_escape "$endpoint_name")\""
    endpoints_yaml="${endpoints_yaml}"$'\n'"      apiKey: \"$(json_escape "${NEW_API_SERVICE_TOKEN}")\""
    endpoints_yaml="${endpoints_yaml}"$'\n'"      baseURL: \"$(json_escape "${NEW_API_INTERNAL_URL}")/v1\""
    endpoints_yaml="${endpoints_yaml}"$'\n'"      models:"
    endpoints_yaml="${endpoints_yaml}"$'\n'"        default:${models_yaml}"
    endpoints_yaml="${endpoints_yaml}"$'\n'"        fetch: false"
    endpoints_yaml="${endpoints_yaml}"$'\n'"      titleConvo: true"
    endpoints_yaml="${endpoints_yaml}"$'\n'"      titleModel: \"$(json_escape "$title_model")\""
    endpoints_yaml="${endpoints_yaml}"$'\n'"      modelDisplayLabel: \"$(json_escape "$model_label")\""
  done < <(provider_prefixes)

  printf '%s' "$endpoints_yaml"
}

render_single_endpoint() {
  local default_models_fallback default_models_raw default_models_yaml

  default_models_fallback="$(enabled_provider_exposed_models)"
  if [[ -z "$default_models_fallback" ]]; then
    default_models_fallback="${LIBRECHAT_TITLE_MODEL:-}"
  fi
  default_models_raw="${LIBRECHAT_DEFAULT_MODELS:-${default_models_fallback}}"
  default_models_yaml="$(models_default_yaml "$(sort_models_by_priority "$default_models_raw" "")" 10)"

  cat <<EOF
    - name: "$(json_escape "${LIBRECHAT_ENDPOINT_NAME}")"
      apiKey: "$(json_escape "${NEW_API_SERVICE_TOKEN}")"
      baseURL: "$(json_escape "${NEW_API_INTERNAL_URL}")/v1"
      models:
        default:${default_models_yaml}
        fetch: ${librechat_fetch_models}
      titleConvo: true
      titleModel: "$(json_escape "${LIBRECHAT_TITLE_MODEL}")"
      modelDisplayLabel: "$(json_escape "${LIBRECHAT_MODEL_LABEL}")"
EOF
}

if [[ "$librechat_split_provider_endpoints" == "true" ]]; then
  endpoints_yaml="$(render_provider_endpoints)"
  if [[ -z "$endpoints_yaml" ]]; then
    warn "没有可渲染的供应商 endpoint，回退到单一 ${LIBRECHAT_ENDPOINT_NAME} endpoint"
    endpoints_yaml="$(render_single_endpoint)"
  fi
else
  endpoints_yaml="$(render_single_endpoint)"
fi

cat >"$target_file" <<EOF
version: 1.3.6
cache: true

interface:
  customWelcome: "欢迎使用 Team AI Platform"
  endpointsMenu: true
  modelSelect: true
  parameters: true
  sidePanel: true
  prompts:
    use: true
    create: true
    share: false
    public: false
  agents:
    use: true
    create: true
    share: true
    public: true

registration:
  socialLogins:
    - "openid"

endpoints:
  custom:
${endpoints_yaml}
EOF

info "LibreChat 配置已渲染: ${target_file}"
