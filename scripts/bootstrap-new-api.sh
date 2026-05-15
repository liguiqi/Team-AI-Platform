#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd curl
require_cmd docker
require_cmd jq
prepare_env_file
load_env
new_api_url="$(host_new_api_url)"

if [[ "$MODE" == "local" ]]; then
  sync_local_env_copy
fi

new_api_token_model_limits_enabled="$(normalize_bool "${NEW_API_TOKEN_MODEL_LIMITS_ENABLED:-false}")"
new_api_sync_channel_models_from_env="$(normalize_bool "${NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV:-false}")"
new_api_provider_channel_balance="${NEW_API_PROVIDER_CHANNEL_BALANCE:-999999999999}"
require_non_negative_number NEW_API_SERVICE_TOKEN_QUOTA "${NEW_API_SERVICE_TOKEN_QUOTA}"
require_non_negative_number NEW_API_PROVIDER_CHANNEL_BALANCE "${new_api_provider_channel_balance}"

provider_is_enabled() {
  local prefix="$1"
  local enabled_var="${prefix}_ENABLED"
  normalize_bool "${!enabled_var:-false}"
}

ensure_enabled_provider_keys() {
  local enabled_count=0
  local prefix api_key_var api_key_value

  while IFS= read -r prefix; do
    if [[ "$(provider_is_enabled "$prefix")" != "true" ]]; then
      continue
    fi

    api_key_var="${prefix}_API_KEY"
    api_key_value="${!api_key_var:-}"
    require_non_placeholder_env "$api_key_var" "$api_key_value"
    enabled_count=$((enabled_count + 1))
  done < <(provider_prefixes)

  (( enabled_count > 0 )) || die "请至少启用一个模型供应商并填写真实 API Key"
}

upsert_channel_from_env() {
  local prefix="$1"
  local provider_label="$2"
  local channel_name_var="${prefix}_CHANNEL_NAME"
  local channel_type_var="${prefix}_CHANNEL_TYPE"
  local api_key_var="${prefix}_API_KEY"
  local base_url_var="${prefix}_API_BASE_URL"
  local exposed_models_var="${prefix}_EXPOSED_MODEL"
  local channel_group_var="${prefix}_CHANNEL_GROUP"
  local test_model_var="${prefix}_TEST_MODEL"
  local model_mapping_var="${prefix}_MODEL_MAPPING_JSON"
  local channel_priority_var="${prefix}_CHANNEL_PRIORITY"
  local channel_weight_var="${prefix}_CHANNEL_WEIGHT"
  local channel_remark_var="${prefix}_CHANNEL_REMARK"
  local channel_balance_var="${prefix}_CHANNEL_BALANCE"
  local channel_name="${!channel_name_var:-}"
  local channel_type="${!channel_type_var:-}"
  local api_key="${!api_key_var:-}"
  local base_url="${!base_url_var:-}"
  local exposed_models="${!exposed_models_var:-}"
  local channel_group="${!channel_group_var:-}"
  local test_model="${!test_model_var:-}"
  local model_mapping="${!model_mapping_var-}"
  local channel_priority="${!channel_priority_var:-10}"
  local channel_weight="${!channel_weight_var:-100}"
  local channel_remark="${!channel_remark_var:-}"
  local channel_balance="${!channel_balance_var-}"
  local channel_balance_updated_time
  local channel_search_resp channel_json channel_id add_channel_payload add_channel_resp update_channel_payload update_channel_resp

  if [[ "$(provider_is_enabled "$prefix")" != "true" ]]; then
    info "已跳过未启用的 ${provider_label} 渠道"
    return 0
  fi
  [[ -n "$model_mapping" ]] || model_mapping="{}"
  [[ -n "$channel_balance" ]] || channel_balance="${new_api_provider_channel_balance}"

  [[ -n "$channel_name" ]] || die "请先在 $(env_file) 中填写 ${channel_name_var}"
  [[ -n "$channel_type" ]] || die "请先在 $(env_file) 中填写 ${channel_type_var}"
  [[ -n "$base_url" ]] || die "请先在 $(env_file) 中填写 ${base_url_var}"
  [[ -n "$exposed_models" ]] || die "请先在 $(env_file) 中填写 ${exposed_models_var}"
  [[ -n "$channel_group" ]] || die "请先在 $(env_file) 中填写 ${channel_group_var}"
  [[ -n "$test_model" ]] || die "请先在 $(env_file) 中填写 ${test_model_var}"
  require_non_negative_number "${channel_balance_var:-NEW_API_PROVIDER_CHANNEL_BALANCE}" "${channel_balance}"
  channel_balance_updated_time="$(date +%s)"

  channel_search_resp="$(curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -H "New-Api-User: ${ROOT_ID}" "${new_api_url}/api/channel/search?keyword=${channel_name}")"
  channel_json="$(printf '%s' "$channel_search_resp" | jq -c --arg name "${channel_name}" '.data.items[]? | select(.name == $name) | .')"

  if [[ -z "${channel_json:-}" ]]; then
    info "创建${provider_label}渠道 ${channel_name}"
    add_channel_payload="$(cat <<EOF
{"mode":"single","multi_key_mode":"random","batch_add_set_key_prefix_2_name":false,"channel":{"name":"$(json_escape "${channel_name}")","type":${channel_type},"key":"$(json_escape "${api_key}")","base_url":"$(json_escape "${base_url}")","models":"$(json_escape "${exposed_models}")","group":"$(json_escape "${channel_group}")","test_model":"$(json_escape "${test_model}")","model_mapping":"$(json_escape "${model_mapping}")","priority":${channel_priority},"weight":${channel_weight},"balance":${channel_balance},"balance_updated_time":${channel_balance_updated_time},"remark":"$(json_escape "${channel_remark}")"}}
EOF
)"
    add_channel_resp="$(curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -X POST "${new_api_url}/api/channel/" -H 'Content-Type: application/json' -H "New-Api-User: ${ROOT_ID}" -d "$add_channel_payload")"
    printf '%s' "$add_channel_resp" | json_has_true success || die "创建${provider_label}渠道失败: $add_channel_resp"
    ensure_channel_project_balance "$channel_name" "$provider_label" "$channel_balance"
    ensure_channel_model_mapping "$channel_name" "$provider_label" "$model_mapping"
    return 0
  fi

  channel_id="$(printf '%s' "$channel_json" | jq -r '.id')"

  if [[ "$new_api_sync_channel_models_from_env" == "true" ]]; then
    info "更新${provider_label}渠道 ${channel_name}（ID: ${channel_id}），并按环境变量同步模型矩阵"
  else
    info "更新${provider_label}渠道 ${channel_name}（ID: ${channel_id}），保留 NEW-API 后台现有模型矩阵"
    exposed_models="$(printf '%s' "$channel_json" | jq -r '.models // ""')"
    channel_group="$(printf '%s' "$channel_json" | jq -r '.group // ""')"
    test_model="$(printf '%s' "$channel_json" | jq -r '.test_model // ""')"
    model_mapping="$(printf '%s' "$channel_json" | jq -r '.model_mapping // ""')"
  fi

  update_channel_payload="$(printf '%s' "$channel_json" | jq -c \
    --arg key "${api_key}" \
    --arg base_url "${base_url}" \
    --arg models "${exposed_models}" \
    --arg group "${channel_group}" \
    --arg test_model "${test_model}" \
    --arg model_mapping "${model_mapping}" \
    --arg remark "${channel_remark}" \
    --argjson type "${channel_type}" \
    --argjson priority "${channel_priority}" \
    --argjson weight "${channel_weight}" \
    --argjson balance "${channel_balance}" \
    --argjson balance_updated_time "${channel_balance_updated_time}" \
    '. + {type:$type,key:$key,base_url:$base_url,models:$models,group:$group,test_model:$test_model,model_mapping:$model_mapping,priority:$priority,weight:$weight,balance:$balance,balance_updated_time:$balance_updated_time,status:1,remark:$remark,multi_key_mode:"random"}')"
  update_channel_resp="$(curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -X PUT "${new_api_url}/api/channel/" -H 'Content-Type: application/json' -H "New-Api-User: ${ROOT_ID}" -d "$update_channel_payload")"
  printf '%s' "$update_channel_resp" | json_has_true success || die "更新${provider_label}渠道失败: $update_channel_resp"
  ensure_channel_project_balance "$channel_name" "$provider_label" "$channel_balance"
  ensure_channel_model_mapping "$channel_name" "$provider_label" "$model_mapping"
}

ensure_enabled_provider_keys

info "开始执行 NEW-API bootstrap"
wait_for_http "${new_api_url}/api/status" 120 || die "NEW-API 尚未就绪"

ROOT_COOKIE="$(mktemp)"
trap 'rm -f "$ROOT_COOKIE"' EXIT

post_json_retry_429() {
  local url="$1"
  local payload="$2"
  local cookie_file="$3"
  local user_id="${4:-}"
  local response http_code body attempt=1
  local -a extra_headers=()

  if [[ -n "$user_id" ]]; then
    extra_headers=(-H "New-Api-User: ${user_id}")
  fi

  while (( attempt <= 5 )); do
    response="$(
      curl -sS \
        -c "$cookie_file" \
        -b "$cookie_file" \
        -X POST "$url" \
        -H 'Content-Type: application/json' \
        "${extra_headers[@]}" \
        -d "$payload" \
        -w $'\n%{http_code}'
    )"
    http_code="${response##*$'\n'}"
    body="${response%$'\n'*}"
    if [[ "$http_code" == "429" ]]; then
      warn "接口限流，${attempt}/5 次重试: $url"
      sleep 15
      ((attempt++))
      continue
    fi
    [[ "$http_code" == 2* ]] || die "请求失败 (${url}, HTTP ${http_code}): ${body}"
    printf '%s' "$body"
    return 0
  done

  die "接口连续触发限流，稍后再试: $url"
}

sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

psql_exec() {
  local sql="$1"
  local tmp
  tmp="$(mktemp --suffix=.sql)"
  # 用单引号 heredoc 避免 bash 展开双引号
  cat > "$tmp" <<PSQLEOF
$sql
PSQLEOF
  docker cp "$tmp" ai-gateway-new-api-postgres:/tmp/_psql_cmd.sql >/dev/null
  docker exec ai-gateway-new-api-postgres env PGPASSWORD="${NEW_API_DB_PASSWORD}" \
    psql -U "${NEW_API_DB_USER}" -d "${NEW_API_DB_NAME}" -v ON_ERROR_STOP=1 -At -F $'\t' -f /tmp/_psql_cmd.sql
  docker exec ai-gateway-new-api-postgres rm -f /tmp/_psql_cmd.sql >/dev/null
  rm -f "$tmp"
}

ensure_channel_project_balance() {
  local channel_name="$1"
  local provider_label="$2"
  local channel_balance="$3"
  local required="${4:-true}"
  local channel_name_sql actual_balance

  channel_name_sql="$(sql_escape "${channel_name}")"
  actual_balance="$(psql_exec "WITH updated AS (UPDATE channels SET balance = ${channel_balance}, balance_updated_time = $(date +%s) WHERE name = '${channel_name_sql}' RETURNING balance) SELECT balance FROM updated;")"
  if [[ -z "${actual_balance:-}" ]]; then
    if [[ "$required" == "true" ]]; then
      die "校正${provider_label}渠道余额失败: 找不到渠道 ${channel_name}"
    fi
    info "未找到${provider_label}渠道 ${channel_name}，跳过余额校正"
    return 0
  fi
  info "${provider_label}渠道 ${channel_name} 余额已设置为项目内不限额基准 ${actual_balance}"
}

ensure_channel_model_mapping() {
  local channel_name="$1"
  local provider_label="$2"
  local model_mapping="${3-}"
  local channel_name_sql model_mapping_sql normalized_mapping actual_mapping

  [[ -n "$model_mapping" ]] || model_mapping="{}"
  normalized_mapping="$(printf '%s' "$model_mapping" | jq -c 'if type == "object" then . else error("model_mapping must be object") end')" \
    || die "${provider_label}渠道 model_mapping 不是合法 JSON object: ${model_mapping}"
  channel_name_sql="$(sql_escape "${channel_name}")"
  model_mapping_sql="$(sql_escape "${normalized_mapping}")"
  actual_mapping="$(psql_exec "WITH updated AS (UPDATE channels SET model_mapping = '${model_mapping_sql}' WHERE name = '${channel_name_sql}' RETURNING model_mapping) SELECT model_mapping FROM updated;")"
  [[ -n "${actual_mapping:-}" ]] || die "校正${provider_label}渠道 model_mapping 失败: 找不到渠道 ${channel_name}"
  info "${provider_label}渠道 ${channel_name} model_mapping 已校正为 ${actual_mapping}"
}

ensure_known_provider_channel_balances() {
  local prefix provider_label channel_name_var channel_balance_var channel_name channel_balance

  while IFS= read -r prefix; do
    case "$prefix" in
      ZHIPU) provider_label="智谱" ;;
      DEEPSEEK) provider_label="DeepSeek" ;;
      ALIYUN) provider_label="阿里云百炼" ;;
      KIMI) provider_label="Kimi" ;;
      *) provider_label="$prefix" ;;
    esac

    channel_name_var="${prefix}_CHANNEL_NAME"
    channel_balance_var="${prefix}_CHANNEL_BALANCE"
    channel_name="${!channel_name_var:-}"
    channel_balance="${!channel_balance_var-}"
    [[ -n "$channel_balance" ]] || channel_balance="${new_api_provider_channel_balance}"
    [[ -n "$channel_name" ]] || continue
    require_non_negative_number "${channel_balance_var:-NEW_API_PROVIDER_CHANNEL_BALANCE}" "${channel_balance}"
    ensure_channel_project_balance "$channel_name" "$provider_label" "$channel_balance" false
  done < <(provider_prefixes)
}

api_setup_resp="$(curl -fsS "${new_api_url}/api/setup")"
if [[ "$(printf '%s' "$api_setup_resp" | json_get_bool status || true)" == "false" ]]; then
  info "开始初始化 NEW-API"
  setup_payload="$(cat <<EOF
{"username":"$(json_escape "${NEW_API_SETUP_USERNAME}")","password":"$(json_escape "${NEW_API_SETUP_PASSWORD}")","confirmPassword":"$(json_escape "${NEW_API_SETUP_PASSWORD}")","SelfUseModeEnabled":${NEW_API_SELF_USE_MODE_ENABLED},"DemoSiteEnabled":${NEW_API_DEMO_SITE_ENABLED}}
EOF
)"
  setup_resp="$(curl -fsS -X POST "${new_api_url}/api/setup" -H 'Content-Type: application/json' -d "$setup_payload")"
  printf '%s' "$setup_resp" | json_has_true success || die "NEW-API 初始化失败: $setup_resp"
fi

root_login_payload="$(cat <<EOF
{"username":"$(json_escape "${NEW_API_SETUP_USERNAME}")","password":"$(json_escape "${NEW_API_SETUP_PASSWORD}")"}
EOF
)"
root_login_resp="$(post_json_retry_429 "${new_api_url}/api/user/login" "$root_login_payload" "$ROOT_COOKIE")"
printf '%s' "$root_login_resp" | json_has_true success || die "root 登录失败: $root_login_resp"
ROOT_ID="$(printf '%s' "$root_login_resp" | json_get_number id)"
[[ -n "$ROOT_ID" ]] || die "无法从 root 登录响应中解析用户 ID"
info "root 登录成功，准备写入系统配置"

put_option() {
  local key="$1"
  local raw_value="$2"
  local payload
  payload="$(cat <<EOF
{"key":"$(json_escape "$key")","value":$raw_value}
EOF
)"
  curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" \
    -X PUT "${new_api_url}/api/option/" \
    -H 'Content-Type: application/json' \
    -H "New-Api-User: ${ROOT_ID}" \
    -d "$payload" >/dev/null
}

put_option SelfUseModeEnabled "${NEW_API_SELF_USE_MODE_ENABLED}"
put_option DemoSiteEnabled "${NEW_API_DEMO_SITE_ENABLED}"
info "系统配置已写入（SelfUseMode / DemoSite）"

put_option ModelRequestRateLimitEnabled "${NEW_API_RATE_LIMIT_ENABLED}"
put_option ModelRequestRateLimitDurationMinutes "${NEW_API_RATE_LIMIT_WINDOW_MINUTES}"
put_option ModelRequestRateLimitCount "${NEW_API_RATE_LIMIT_TOTAL}"
put_option ModelRequestRateLimitSuccessCount "${NEW_API_RATE_LIMIT_SUCCESS}"
put_option ModelRequestRateLimitGroup "\"$(json_escape "${NEW_API_RATE_LIMIT_GROUP_JSON}")\""
info "项目内请求限流配置已写入，准备处理服务用户"

create_user_payload="$(cat <<EOF
{"username":"$(json_escape "${NEW_API_SERVICE_USER}")","password":"$(json_escape "${NEW_API_SERVICE_PASSWORD}")","display_name":"$(json_escape "${NEW_API_SERVICE_DISPLAY_NAME}")","role":1}
EOF
)"
create_user_resp="$(curl -sS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -X POST "${new_api_url}/api/user/" -H 'Content-Type: application/json' -H "New-Api-User: ${ROOT_ID}" -d "$create_user_payload" || true)"
if [[ -n "$create_user_resp" ]] && ! printf '%s' "$create_user_resp" | json_has_true success; then
  warn "创建服务用户返回: $create_user_resp"
fi

info "服务用户已就绪，准备校正服务用户额度与渠道配置"

service_user_search_resp="$(curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -H "New-Api-User: ${ROOT_ID}" "${new_api_url}/api/user/search?keyword=${NEW_API_SERVICE_USER}")"
SERVICE_USER_RECORD_JSON="$(printf '%s' "$service_user_search_resp" | jq -c --arg username "${NEW_API_SERVICE_USER}" '.data.items[] | select(.username == $username) | .')"
[[ -n "${SERVICE_USER_RECORD_JSON:-}" ]] || die "找不到服务用户 ${NEW_API_SERVICE_USER}"
SERVICE_ID="$(printf '%s' "$SERVICE_USER_RECORD_JSON" | jq -r '.id')"
SERVICE_USER_QUOTA="$(printf '%s' "$SERVICE_USER_RECORD_JSON" | jq -r '.quota // 0')"
if [[ "$SERVICE_USER_QUOTA" != "${NEW_API_SERVICE_TOKEN_QUOTA}" ]]; then
  info "更新服务用户额度 ${NEW_API_SERVICE_USER}: ${SERVICE_USER_QUOTA} -> ${NEW_API_SERVICE_TOKEN_QUOTA}"
  update_user_payload="$(printf '%s' "$SERVICE_USER_RECORD_JSON" | jq -c --argjson quota "${NEW_API_SERVICE_TOKEN_QUOTA}" '{id,username,display_name,role,status,group,quota:$quota,remark:(.remark // "")}')"
  update_user_resp="$(curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -X PUT "${new_api_url}/api/user/" -H 'Content-Type: application/json' -H "New-Api-User: ${ROOT_ID}" -d "$update_user_payload")"
  printf '%s' "$update_user_resp" | json_has_true success || die "更新服务用户额度失败: $update_user_resp"
fi

upsert_channel_from_env ZHIPU "智谱"
upsert_channel_from_env DEEPSEEK "DeepSeek"
upsert_channel_from_env ALIYUN "阿里云百炼"
upsert_channel_from_env KIMI "Kimi"
ensure_known_provider_channel_balances

token_name_sql="$(sql_escape "${NEW_API_SERVICE_TOKEN_NAME}")"
token_models_sql="$(sql_escape "${NEW_API_TOKEN_ALLOWED_MODELS}")"
token_group_sql="$(sql_escape "${NEW_API_SERVICE_TOKEN_GROUP}")"
token_row="$(psql_exec "SELECT id, key FROM tokens WHERE user_id = ${SERVICE_ID} AND name = '${token_name_sql}' ORDER BY id LIMIT 1;")"
TOKEN_ID="$(printf '%s' "$token_row" | cut -f1)"
TOKEN_KEY="$(printf '%s' "$token_row" | cut -f2)"

if [[ "$new_api_token_model_limits_enabled" == "true" ]]; then
  token_model_limits_enabled_sql="true"
  token_model_limits_sql="'${token_models_sql}'"
else
  token_model_limits_enabled_sql="false"
  token_model_limits_sql="''"
fi

if [[ -z "${TOKEN_ID:-}" ]]; then
  info "创建 LibreChat 服务 token"
  TOKEN_KEY="$(random_alnum 48)" || { warn "random_alnum failed"; TOKEN_KEY="fallback$(date +%s)"; }
  token_key_sql="$(sql_escape "${TOKEN_KEY}")" || { warn "sql_escape failed"; token_key_sql="${TOKEN_KEY}"; }
  created_time="$(date +%s)"
  info "token_key_sql=[${token_key_sql}] token_name=[${token_name_sql}]"
  # INSERT 不含 "group" 列
  docker exec \
    -e PGPASSWORD="${NEW_API_DB_PASSWORD}" \
    -e _UID="${NEW_API_DB_USER}" \
    -e _DB="${NEW_API_DB_NAME}" \
    -e _SID="${SERVICE_ID}" \
    -e _KEY="${token_key_sql}" \
    -e _NAME="${token_name_sql}" \
    -e _CT="${created_time}" \
    -e _QUOTA="${NEW_API_SERVICE_TOKEN_QUOTA}" \
    -e _UNL="${NEW_API_SERVICE_TOKEN_UNLIMITED}" \
    -e _MLE="${token_model_limits_enabled_sql}" \
    -e _ML="${token_model_limits_sql}" \
    -e _GRP="${token_group_sql}" \
    ai-gateway-new-api-postgres \
    bash -c 'psql -U "$_UID" -d "$_DB" -v ON_ERROR_STOP=1 -c "INSERT INTO tokens (user_id, key, status, name, created_time, accessed_time, expired_time, remain_quota, unlimited_quota, model_limits_enabled, model_limits, used_quota, cross_group_retry) VALUES ($_SID, '\''$_KEY'\'', 1, '\''$_NAME'\'', $_CT, $_CT, -1, $_QUOTA, $_UNL, $_MLE, '\''$_ML'\'', 0, false);"
psql -U "$_UID" -d "$_DB" -c "UPDATE tokens SET \"group\" = '\''$_GRP'\'' WHERE user_id = $_SID AND name = '\''$_NAME'\'';"'
  # 反查 token
  token_row="$(psql_exec "SELECT id, key FROM tokens WHERE user_id = ${SERVICE_ID} AND name = '${token_name_sql}' ORDER BY id DESC LIMIT 1;" 2>/dev/null || true)"
  TOKEN_ID="$(printf '%s' "$token_row" | cut -f1)"
  TOKEN_KEY="$(printf '%s' "$token_row" | cut -f2)"
else
  info "更新 LibreChat 服务 token（ID: ${TOKEN_ID}）"
  docker exec ai-gateway-new-api-postgres \
    env PGPASSWORD="${NEW_API_DB_PASSWORD}" \
    psql -U "${NEW_API_DB_USER}" -d "${NEW_API_DB_NAME}" -c \
    "UPDATE tokens SET status = 1, expired_time = -1, remain_quota = ${NEW_API_SERVICE_TOKEN_QUOTA}, unlimited_quota = ${NEW_API_SERVICE_TOKEN_UNLIMITED}, model_limits_enabled = ${token_model_limits_enabled_sql}, model_limits = ${token_model_limits_sql}, cross_group_retry = false WHERE id = ${TOKEN_ID};"
  # 单独更新 group 列
  docker exec ai-gateway-new-api-postgres \
    env PGPASSWORD="${NEW_API_DB_PASSWORD}" \
    psql -U "${NEW_API_DB_USER}" -d "${NEW_API_DB_NAME}" -c \
    'UPDATE tokens SET "group" = '"'"''${token_group_sql}''"'"' WHERE id = '${TOKEN_ID}';'
fi

[[ -n "${TOKEN_ID:-}" ]] || { info "反查 token ID 失败，尝试从数据库重新获取"; TOKEN_ID="$(docker exec ai-gateway-new-api-postgres psql -U "${NEW_API_DB_USER}" -d "${NEW_API_DB_NAME}" -At -c "SELECT id FROM tokens WHERE user_id = ${SERVICE_ID} AND name = '${token_name_sql}' ORDER BY id DESC LIMIT 1;" 2>/dev/null)"; }
[[ -n "${TOKEN_KEY:-}" ]] || { info "反查 token key 失败，尝试从数据库重新获取"; TOKEN_KEY="$(docker exec ai-gateway-new-api-postgres psql -U "${NEW_API_DB_USER}" -d "${NEW_API_DB_NAME}" -At -c "SELECT key FROM tokens WHERE user_id = ${SERVICE_ID} AND name = '${token_name_sql}' ORDER BY id DESC LIMIT 1;" 2>/dev/null)"; }
[[ -n "${TOKEN_ID:-}" ]] || die "无法获取服务 token ID"
[[ -n "${TOKEN_KEY:-}" ]] || die "无法获取服务 token 明文"

replace_or_append_env NEW_API_SERVICE_TOKEN "$TOKEN_KEY" "$(env_file)"
if [[ "$MODE" == "local" ]]; then
  sync_local_env_copy
fi

bash "$ROOT_DIR/scripts/render-librechat-config.sh"
if docker ps -a --format '{{.Names}}' | grep -qx 'ai-gateway-librechat'; then
  docker_compose restart librechat >/dev/null 2>&1 || true
  info "LibreChat 已按最新 token 重载配置"
fi

info "bootstrap 完成，NEW_API_SERVICE_TOKEN 已写入 $(env_file)"
