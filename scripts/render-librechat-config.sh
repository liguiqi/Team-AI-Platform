#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

prepare_env_file
load_env
require_cmd sed
new_api_url="$(host_new_api_url)"

target_file="$(librechat_config_file)"
mkdir -p "$(dirname "$target_file")"

if is_placeholder "${CASDOOR_CLIENT_SECRET:-}" || is_placeholder "${LIBRECHAT_OPENID_SESSION_SECRET:-}" || is_placeholder "${CASDOOR_PUBLIC_URL:-}"; then
  warn "Casdoor OIDC 变量仍为占位值，LibreChat 登录页将显示统一认证入口，但无法完成真实登录"
fi

librechat_fetch_models="$(normalize_bool "${LIBRECHAT_FETCH_MODELS:-true}")"
default_models_raw="${LIBRECHAT_DEFAULT_MODELS:-${ZHIPU_EXPOSED_MODEL}}"
visible_models_raw="${LIBRECHAT_VISIBLE_MODELS:-}"
default_models_yaml=""

IFS=',' read -r -a default_models_array <<<"$default_models_raw"
for raw_model in "${default_models_array[@]}"; do
  model="$(printf '%s' "$raw_model" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -n "$model" ]] || continue
  default_models_yaml="${default_models_yaml}"$'\n'"          - \"$(json_escape "$model")\""
done

if [[ -z "$default_models_yaml" ]]; then
  default_models_yaml=$'\n'"          - \"$(json_escape "${ZHIPU_EXPOSED_MODEL}")\""
fi

if [[ -n "$visible_models_raw" ]]; then
  require_cmd curl
  require_cmd jq
  filtered_models_yaml=""
  fetched_models_tmp="$(mktemp)"
  trap 'rm -f "$fetched_models_tmp"' EXIT

  if [[ -n "${NEW_API_SERVICE_TOKEN:-}" ]] && ! is_placeholder "${NEW_API_SERVICE_TOKEN}" && wait_for_http "${new_api_url}/api/status" 3; then
    if curl -fsS "${new_api_url}/v1/models" -H "Authorization: Bearer ${NEW_API_SERVICE_TOKEN}" | jq -r '.data[].id' >"$fetched_models_tmp" 2>/dev/null; then
      info "已从 NEW-API 拉取模型列表，准备按 LIBRECHAT_VISIBLE_MODELS 过滤"
    else
      warn "拉取 NEW-API 模型列表失败，将按 LIBRECHAT_VISIBLE_MODELS 原样渲染前端模型"
      : >"$fetched_models_tmp"
    fi
  else
    warn "NEW-API 尚未就绪或缺少可用 token，将按 LIBRECHAT_VISIBLE_MODELS 原样渲染前端模型"
    : >"$fetched_models_tmp"
  fi

  IFS=',' read -r -a visible_models_array <<<"$visible_models_raw"
  for raw_model in "${visible_models_array[@]}"; do
    model="$(printf '%s' "$raw_model" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$model" ]] || continue

    if [[ -s "$fetched_models_tmp" ]] && ! grep -Fxq "$model" "$fetched_models_tmp"; then
      warn "模型未出现在 NEW-API /v1/models 中，已跳过: $model"
      continue
    fi

    filtered_models_yaml="${filtered_models_yaml}"$'\n'"          - \"$(json_escape "$model")\""
  done

  if [[ -n "$filtered_models_yaml" ]]; then
    default_models_yaml="$filtered_models_yaml"
    librechat_fetch_models="false"
    info "已启用 LibreChat 前端模型白名单过滤"
  elif [[ -s "$fetched_models_tmp" ]]; then
    warn "白名单过滤后模型列表为空，LibreChat 将显示空模型列表"
    default_models_yaml=" []"
    librechat_fetch_models="false"
  else
    warn "未能从 NEW-API 校验白名单模型，暂按 LIBRECHAT_VISIBLE_MODELS 原样渲染"
    default_models_yaml=""
    for raw_model in "${visible_models_array[@]}"; do
      model="$(printf '%s' "$raw_model" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      [[ -n "$model" ]] || continue
      default_models_yaml="${default_models_yaml}"$'\n'"          - \"$(json_escape "$model")\""
    done
    librechat_fetch_models="false"
  fi
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
    share: false
    public: false

registration:
  socialLogins:
    - "openid"

endpoints:
  custom:
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

info "LibreChat 配置已渲染: ${target_file}"
