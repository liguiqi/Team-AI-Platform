#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd curl
require_cmd docker
require_cmd jq
load_env

if [[ "$MODE" == "local" ]]; then
  sync_local_env_copy
fi

require_non_placeholder_env ZHIPU_API_KEY "${ZHIPU_API_KEY}"

new_api_token_model_limits_enabled="$(normalize_bool "${NEW_API_TOKEN_MODEL_LIMITS_ENABLED:-false}")"
new_api_sync_channel_models_from_env="$(normalize_bool "${NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV:-false}")"

info "开始执行 NEW-API bootstrap"
wait_for_http "${NEW_API_PUBLIC_URL}/api/status" 120 || die "NEW-API 尚未就绪"

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
  docker_compose exec -T new-api-postgres \
    env PGPASSWORD="${NEW_API_DB_PASSWORD}" \
    psql -U "${NEW_API_DB_USER}" -d "${NEW_API_DB_NAME}" -v ON_ERROR_STOP=1 -At -F $'\t' -c "$sql"
}

api_setup_resp="$(curl -fsS "${NEW_API_PUBLIC_URL}/api/setup")"
if [[ "$(printf '%s' "$api_setup_resp" | json_get_bool status || true)" == "false" ]]; then
  info "开始初始化 NEW-API"
  setup_payload="$(cat <<EOF
{"username":"$(json_escape "${NEW_API_SETUP_USERNAME}")","password":"$(json_escape "${NEW_API_SETUP_PASSWORD}")","confirmPassword":"$(json_escape "${NEW_API_SETUP_PASSWORD}")","SelfUseModeEnabled":${NEW_API_SELF_USE_MODE_ENABLED},"DemoSiteEnabled":${NEW_API_DEMO_SITE_ENABLED}}
EOF
)"
  setup_resp="$(curl -fsS -X POST "${NEW_API_PUBLIC_URL}/api/setup" -H 'Content-Type: application/json' -d "$setup_payload")"
  printf '%s' "$setup_resp" | json_has_true success || die "NEW-API 初始化失败: $setup_resp"
fi

root_login_payload="$(cat <<EOF
{"username":"$(json_escape "${NEW_API_SETUP_USERNAME}")","password":"$(json_escape "${NEW_API_SETUP_PASSWORD}")"}
EOF
)"
root_login_resp="$(post_json_retry_429 "${NEW_API_PUBLIC_URL}/api/user/login" "$root_login_payload" "$ROOT_COOKIE")"
printf '%s' "$root_login_resp" | json_has_true success || die "root 登录失败: $root_login_resp"
ROOT_ID="$(printf '%s' "$root_login_resp" | json_get_number id)"
[[ -n "$ROOT_ID" ]] || die "无法从 root 登录响应中解析用户 ID"
info "root 登录成功，准备写入限流配置"

put_option() {
  local key="$1"
  local raw_value="$2"
  local payload
  payload="$(cat <<EOF
{"key":"$(json_escape "$key")","value":$raw_value}
EOF
)"
  curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" \
    -X PUT "${NEW_API_PUBLIC_URL}/api/option/" \
    -H 'Content-Type: application/json' \
    -H "New-Api-User: ${ROOT_ID}" \
    -d "$payload" >/dev/null
}

put_option ModelRequestRateLimitEnabled "${NEW_API_RATE_LIMIT_ENABLED}"
put_option ModelRequestRateLimitDurationMinutes "${NEW_API_RATE_LIMIT_WINDOW_MINUTES}"
put_option ModelRequestRateLimitCount "${NEW_API_RATE_LIMIT_TOTAL}"
put_option ModelRequestRateLimitSuccessCount "${NEW_API_RATE_LIMIT_SUCCESS}"
put_option ModelRequestRateLimitGroup "\"$(json_escape "${NEW_API_RATE_LIMIT_GROUP_JSON}")\""
info "限流配置已写入，准备处理服务用户"

create_user_payload="$(cat <<EOF
{"username":"$(json_escape "${NEW_API_SERVICE_USER}")","password":"$(json_escape "${NEW_API_SERVICE_PASSWORD}")","display_name":"$(json_escape "${NEW_API_SERVICE_DISPLAY_NAME}")","role":1}
EOF
)"
create_user_resp="$(curl -sS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -X POST "${NEW_API_PUBLIC_URL}/api/user/" -H 'Content-Type: application/json' -H "New-Api-User: ${ROOT_ID}" -d "$create_user_payload" || true)"
if [[ -n "$create_user_resp" ]] && ! printf '%s' "$create_user_resp" | json_has_true success; then
  warn "创建服务用户返回: $create_user_resp"
fi

info "服务用户已就绪，准备校正服务用户额度与渠道配置"

service_user_search_resp="$(curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -H "New-Api-User: ${ROOT_ID}" "${NEW_API_PUBLIC_URL}/api/user/search?keyword=${NEW_API_SERVICE_USER}")"
SERVICE_USER_RECORD_JSON="$(printf '%s' "$service_user_search_resp" | jq -c --arg username "${NEW_API_SERVICE_USER}" '.data.items[] | select(.username == $username) | .')"
[[ -n "${SERVICE_USER_RECORD_JSON:-}" ]] || die "找不到服务用户 ${NEW_API_SERVICE_USER}"
SERVICE_ID="$(printf '%s' "$SERVICE_USER_RECORD_JSON" | jq -r '.id')"
SERVICE_USER_QUOTA="$(printf '%s' "$SERVICE_USER_RECORD_JSON" | jq -r '.quota // 0')"
if [[ "$SERVICE_USER_QUOTA" != "${NEW_API_SERVICE_TOKEN_QUOTA}" ]]; then
  info "更新服务用户额度 ${NEW_API_SERVICE_USER}: ${SERVICE_USER_QUOTA} -> ${NEW_API_SERVICE_TOKEN_QUOTA}"
  update_user_payload="$(printf '%s' "$SERVICE_USER_RECORD_JSON" | jq -c --argjson quota "${NEW_API_SERVICE_TOKEN_QUOTA}" '{id,username,display_name,role,status,group,quota:$quota,remark:(.remark // "")}')"
  update_user_resp="$(curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -X PUT "${NEW_API_PUBLIC_URL}/api/user/" -H 'Content-Type: application/json' -H "New-Api-User: ${ROOT_ID}" -d "$update_user_payload")"
  printf '%s' "$update_user_resp" | json_has_true success || die "更新服务用户额度失败: $update_user_resp"
fi

channel_search_resp="$(curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -H "New-Api-User: ${ROOT_ID}" "${NEW_API_PUBLIC_URL}/api/channel/search?keyword=${ZHIPU_CHANNEL_NAME}")"
CHANNEL_JSON="$(printf '%s' "$channel_search_resp" | jq -c --arg name "${ZHIPU_CHANNEL_NAME}" '.data.items[]? | select(.name == $name) | .')"
if [[ -z "${CHANNEL_JSON:-}" ]]; then
  info "创建智谱渠道 ${ZHIPU_CHANNEL_NAME}"
  add_channel_payload="$(cat <<EOF
{"mode":"single","multi_key_mode":"random","batch_add_set_key_prefix_2_name":false,"channel":{"name":"$(json_escape "${ZHIPU_CHANNEL_NAME}")","type":${ZHIPU_CHANNEL_TYPE},"key":"$(json_escape "${ZHIPU_API_KEY}")","base_url":"$(json_escape "${ZHIPU_API_BASE_URL}")","models":"$(json_escape "${ZHIPU_EXPOSED_MODEL}")","group":"$(json_escape "${ZHIPU_CHANNEL_GROUP}")","test_model":"$(json_escape "${ZHIPU_TEST_MODEL}")","model_mapping":"$(json_escape "${ZHIPU_MODEL_MAPPING_JSON}")","priority":${ZHIPU_CHANNEL_PRIORITY},"weight":${ZHIPU_CHANNEL_WEIGHT},"remark":"$(json_escape "${ZHIPU_CHANNEL_REMARK}")"}}
EOF
)"
  add_channel_resp="$(curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -X POST "${NEW_API_PUBLIC_URL}/api/channel/" -H 'Content-Type: application/json' -H "New-Api-User: ${ROOT_ID}" -d "$add_channel_payload")"
  printf '%s' "$add_channel_resp" | json_has_true success || die "创建智谱渠道失败: $add_channel_resp"
else
  CHANNEL_ID="$(printf '%s' "$CHANNEL_JSON" | jq -r '.id')"
  channel_models="${ZHIPU_EXPOSED_MODEL}"
  channel_group="${ZHIPU_CHANNEL_GROUP}"
  channel_test_model="${ZHIPU_TEST_MODEL}"
  channel_model_mapping="${ZHIPU_MODEL_MAPPING_JSON}"

  if [[ "$new_api_sync_channel_models_from_env" == "true" ]]; then
    info "更新智谱渠道 ${ZHIPU_CHANNEL_NAME}（ID: ${CHANNEL_ID}），并按环境变量同步模型矩阵"
  else
    info "更新智谱渠道 ${ZHIPU_CHANNEL_NAME}（ID: ${CHANNEL_ID}），保留 NEW-API 后台现有模型矩阵"
    channel_models="$(printf '%s' "$CHANNEL_JSON" | jq -r '.models // ""')"
    channel_group="$(printf '%s' "$CHANNEL_JSON" | jq -r '.group // ""')"
    channel_test_model="$(printf '%s' "$CHANNEL_JSON" | jq -r '.test_model // ""')"
    channel_model_mapping="$(printf '%s' "$CHANNEL_JSON" | jq -r '.model_mapping // ""')"
  fi

  update_channel_payload="$(printf '%s' "$CHANNEL_JSON" | jq -c \
    --arg key "${ZHIPU_API_KEY}" \
    --arg base_url "${ZHIPU_API_BASE_URL}" \
    --arg models "${channel_models}" \
    --arg group "${channel_group}" \
    --arg test_model "${channel_test_model}" \
    --arg model_mapping "${channel_model_mapping}" \
    --arg remark "${ZHIPU_CHANNEL_REMARK}" \
    --argjson type "${ZHIPU_CHANNEL_TYPE}" \
    --argjson priority "${ZHIPU_CHANNEL_PRIORITY}" \
    --argjson weight "${ZHIPU_CHANNEL_WEIGHT}" \
    '. + {type:$type,key:$key,base_url:$base_url,models:$models,group:$group,test_model:$test_model,model_mapping:$model_mapping,priority:$priority,weight:$weight,status:1,remark:$remark,multi_key_mode:"random"}')"
  update_channel_resp="$(curl -fsS -c "$ROOT_COOKIE" -b "$ROOT_COOKIE" -X PUT "${NEW_API_PUBLIC_URL}/api/channel/" -H 'Content-Type: application/json' -H "New-Api-User: ${ROOT_ID}" -d "$update_channel_payload")"
  printf '%s' "$update_channel_resp" | json_has_true success || die "更新智谱渠道失败: $update_channel_resp"
fi

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
  TOKEN_KEY="$(random_alnum 48)"
  token_key_sql="$(sql_escape "${TOKEN_KEY}")"
  created_time="$(date +%s)"
  insert_token_sql="$(cat <<EOF
INSERT INTO tokens (user_id, key, status, name, created_time, accessed_time, expired_time, remain_quota, unlimited_quota, model_limits_enabled, model_limits, used_quota, "group", cross_group_retry)
VALUES (${SERVICE_ID}, '${token_key_sql}', 1, '${token_name_sql}', ${created_time}, ${created_time}, -1, ${NEW_API_SERVICE_TOKEN_QUOTA}, ${NEW_API_SERVICE_TOKEN_UNLIMITED}, ${token_model_limits_enabled_sql}, ${token_model_limits_sql}, 0, '${token_group_sql}', false)
RETURNING id, key;
EOF
)"
  token_row="$(psql_exec "$insert_token_sql")"
  TOKEN_ID="$(printf '%s' "$token_row" | cut -f1)"
  TOKEN_KEY="$(printf '%s' "$token_row" | cut -f2)"
else
  info "更新 LibreChat 服务 token（ID: ${TOKEN_ID}）"
  psql_exec "UPDATE tokens SET status = 1, expired_time = -1, remain_quota = ${NEW_API_SERVICE_TOKEN_QUOTA}, unlimited_quota = ${NEW_API_SERVICE_TOKEN_UNLIMITED}, model_limits_enabled = ${token_model_limits_enabled_sql}, model_limits = ${token_model_limits_sql}, \"group\" = '${token_group_sql}', cross_group_retry = false WHERE id = ${TOKEN_ID};" >/dev/null
fi

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
