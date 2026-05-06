#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd docker
require_cmd jq

[[ -f "$(env_file)" ]] || die "环境文件不存在: $(env_file)"
prepare_env_file
load_env

init_data_file="$(casdoor_init_data_file)"
[[ -f "$init_data_file" ]] || die "Casdoor 初始化数据不存在: $init_data_file"

wait_for_provider_table() {
  local timeout="${1:-60}"
  local start now
  start="$(date +%s)"

  while true; do
    if docker_compose exec -T new-api-postgres \
      psql -U "$NEW_API_DB_USER" -d "$CASDOOR_DB_NAME" -qtAc \
      "select 1 from information_schema.tables where table_schema = 'public' and table_name = 'provider';" \
      2>/dev/null | grep -q 1; then
      return 0
    fi

    now="$(date +%s)"
    if (( now - start >= timeout )); then
      return 1
    fi
    sleep 2
  done
}

provider_json() {
  local provider_name="$1"
  jq -c --arg name "$provider_name" '.providers[] | select(.name == $name)' "$init_data_file" | head -n 1
}

json_string() {
  local json="$1"
  local key="$2"
  jq -r --arg key "$key" '.[$key] // ""' <<<"$json"
}

upsert_email_provider() {
  local json="$1"
  local owner name display_name provider_type client_id client_secret client_id2 client_secret2
  local host port ssl_mode title content metadata receiver enable_proxy

  owner="$(json_string "$json" owner)"
  name="$(json_string "$json" name)"
  display_name="$(json_string "$json" displayName)"
  provider_type="$(json_string "$json" type)"
  client_id="$(json_string "$json" clientId)"
  client_secret="$(json_string "$json" clientSecret)"
  client_id2="$(json_string "$json" clientId2)"
  client_secret2="$(json_string "$json" clientSecret2)"
  host="$(json_string "$json" host)"
  port="$(json_string "$json" port)"
  ssl_mode="$(json_string "$json" sslMode)"
  title="$(json_string "$json" title)"
  content="$(json_string "$json" content)"
  metadata="$(json_string "$json" metadata)"
  receiver="$(json_string "$json" receiver)"
  enable_proxy="$(json_string "$json" enableProxy)"

  docker_compose exec -T new-api-postgres \
    psql -v ON_ERROR_STOP=1 \
      -v owner="$owner" \
      -v name="$name" \
      -v display_name="$display_name" \
      -v provider_type="$provider_type" \
      -v client_id="$client_id" \
      -v client_secret="$client_secret" \
      -v client_id2="$client_id2" \
      -v client_secret2="$client_secret2" \
      -v host="$host" \
      -v port="$port" \
      -v ssl_mode="$ssl_mode" \
      -v title="$title" \
      -v content="$content" \
      -v metadata="$metadata" \
      -v receiver="$receiver" \
      -v enable_proxy="$enable_proxy" \
      -U "$NEW_API_DB_USER" -d "$CASDOOR_DB_NAME" <<'SQL'
INSERT INTO provider (
  owner,
  name,
  display_name,
  category,
  type,
  client_id,
  client_secret,
  client_id2,
  client_secret2,
  host,
  port,
  disable_ssl,
  title,
  content,
  receiver,
  metadata,
  ssl_mode,
  enable_proxy
) VALUES (
  :'owner',
  :'name',
  :'display_name',
  'Email',
  :'provider_type',
  :'client_id',
  :'client_secret',
  :'client_id2',
  :'client_secret2',
  :'host',
  CAST(:'port' AS integer),
  CASE WHEN :'ssl_mode' = 'Disable' THEN true ELSE false END,
  :'title',
  :'content',
  :'receiver',
  :'metadata',
  :'ssl_mode',
  CASE WHEN :'enable_proxy' = 'true' THEN true ELSE false END
)
ON CONFLICT (name) DO UPDATE SET
  owner = EXCLUDED.owner,
  display_name = EXCLUDED.display_name,
  category = EXCLUDED.category,
  type = EXCLUDED.type,
  client_id = EXCLUDED.client_id,
  client_secret = EXCLUDED.client_secret,
  client_id2 = EXCLUDED.client_id2,
  client_secret2 = EXCLUDED.client_secret2,
  host = EXCLUDED.host,
  port = EXCLUDED.port,
  disable_ssl = EXCLUDED.disable_ssl,
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  receiver = EXCLUDED.receiver,
  metadata = EXCLUDED.metadata,
  ssl_mode = EXCLUDED.ssl_mode,
  enable_proxy = EXCLUDED.enable_proxy;
SQL
}

upsert_sms_provider() {
  local json="$1"
  local owner name display_name provider_type client_id client_secret region_id sign_name
  local template_code content receiver enable_proxy

  owner="$(json_string "$json" owner)"
  name="$(json_string "$json" name)"
  display_name="$(json_string "$json" displayName)"
  provider_type="$(json_string "$json" type)"
  client_id="$(json_string "$json" clientId)"
  client_secret="$(json_string "$json" clientSecret)"
  region_id="$(json_string "$json" regionId)"
  sign_name="$(json_string "$json" signName)"
  template_code="$(json_string "$json" templateCode)"
  content="$(json_string "$json" content)"
  receiver="$(json_string "$json" receiver)"
  enable_proxy="$(json_string "$json" enableProxy)"

  docker_compose exec -T new-api-postgres \
    psql -v ON_ERROR_STOP=1 \
      -v owner="$owner" \
      -v name="$name" \
      -v display_name="$display_name" \
      -v provider_type="$provider_type" \
      -v client_id="$client_id" \
      -v client_secret="$client_secret" \
      -v region_id="$region_id" \
      -v sign_name="$sign_name" \
      -v template_code="$template_code" \
      -v content="$content" \
      -v receiver="$receiver" \
      -v enable_proxy="$enable_proxy" \
      -U "$NEW_API_DB_USER" -d "$CASDOOR_DB_NAME" <<'SQL'
INSERT INTO provider (
  owner,
  name,
  display_name,
  category,
  type,
  client_id,
  client_secret,
  region_id,
  sign_name,
  template_code,
  content,
  receiver,
  enable_proxy
) VALUES (
  :'owner',
  :'name',
  :'display_name',
  'SMS',
  :'provider_type',
  :'client_id',
  :'client_secret',
  :'region_id',
  :'sign_name',
  :'template_code',
  :'content',
  :'receiver',
  CASE WHEN :'enable_proxy' = 'true' THEN true ELSE false END
)
ON CONFLICT (name) DO UPDATE SET
  owner = EXCLUDED.owner,
  display_name = EXCLUDED.display_name,
  category = EXCLUDED.category,
  type = EXCLUDED.type,
  client_id = EXCLUDED.client_id,
  client_secret = EXCLUDED.client_secret,
  region_id = EXCLUDED.region_id,
  sign_name = EXCLUDED.sign_name,
  template_code = EXCLUDED.template_code,
  content = EXCLUDED.content,
  receiver = EXCLUDED.receiver,
  enable_proxy = EXCLUDED.enable_proxy;
SQL
}

email_json="$(provider_json "${CASDOOR_EMAIL_PROVIDER_NAME:-team-ai-email}")"
sms_json="$(provider_json "${CASDOOR_SMS_PROVIDER_NAME:-team-ai-pnvs}")"

[[ -n "$email_json" ]] || die "在 $init_data_file 中找不到邮箱 Provider: ${CASDOOR_EMAIL_PROVIDER_NAME:-team-ai-email}"
[[ -n "$sms_json" ]] || die "在 $init_data_file 中找不到短信 Provider: ${CASDOOR_SMS_PROVIDER_NAME:-team-ai-pnvs}"

wait_for_provider_table 60 || die "等待 Casdoor provider 表就绪超时"

upsert_email_provider "$email_json"
upsert_sms_provider "$sms_json"

info "Casdoor Provider 已同步到持久化数据库"
