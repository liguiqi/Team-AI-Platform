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

app_name="${CASDOOR_APPLICATION_NAME:-team-ai-librechat}"
user_org_name="${CASDOOR_USER_ORGANIZATION_NAME:-team-ai}"

if [[ "$user_org_name" == "built-in" ]]; then
  die "CASDOOR_USER_ORGANIZATION_NAME 不能为 built-in"
fi

wait_for_casdoor_tables() {
  local timeout="${1:-60}"
  local start now ready
  start="$(date +%s)"

  while true; do
    ready="$(docker_compose exec -T new-api-postgres \
      psql -U "$NEW_API_DB_USER" -d "$CASDOOR_DB_NAME" -qtAc \
      "select count(*) from information_schema.tables where table_schema = 'public' and table_name in ('organization', 'application');" \
      2>/dev/null | tr -d '[:space:]')"

    if [[ "$ready" == "2" ]]; then
      return 0
    fi

    now="$(date +%s)"
    if (( now - start >= timeout )); then
      return 1
    fi
    sleep 2
  done
}

json_string() {
  local json="$1"
  local key="$2"
  jq -r --arg key "$key" '.[$key] // ""' <<<"$json"
}

json_bool_string() {
  local json="$1"
  local key="$2"
  jq -r --arg key "$key" 'if has($key) and .[$key] != null then (.[$key] | tostring) else "" end' <<<"$json"
}

json_number_string() {
  local json="$1"
  local key="$2"
  jq -r --arg key "$key" 'if has($key) and .[$key] != null then (.[$key] | tostring) else "" end' <<<"$json"
}

json_raw_compact() {
  local json="$1"
  local key="$2"
  jq -c --arg key "$key" 'if has($key) and .[$key] != null then .[$key] else empty end' <<<"$json"
}

organization_json="$(jq -c --arg name "$user_org_name" '.organizations[] | select(.name == $name)' "$init_data_file" | head -n 1)"
application_json="$(jq -c --arg name "$app_name" '.applications[] | select(.name == $name)' "$init_data_file" | head -n 1)"

[[ -n "$organization_json" ]] || die "在 $init_data_file 中找不到组织: $user_org_name"
[[ -n "$application_json" ]] || die "在 $init_data_file 中找不到应用: $app_name"

wait_for_casdoor_tables 60 || die "等待 Casdoor organization/application 表就绪超时"

org_owner="$(json_string "$organization_json" owner)"
org_name="$(json_string "$organization_json" name)"
org_display_name="$(json_string "$organization_json" displayName)"
org_website_url="$(json_string "$organization_json" websiteUrl)"
org_logo="$(json_string "$organization_json" logo)"
org_logo_dark="$(json_string "$organization_json" logoDark)"
org_favicon="$(json_string "$organization_json" favicon)"
org_has_privilege_consent="$(json_bool_string "$organization_json" hasPrivilegeConsent)"
org_password_type="$(json_string "$organization_json" passwordType)"
org_password_options="$(json_raw_compact "$organization_json" passwordOptions)"
org_country_codes="$(json_raw_compact "$organization_json" countryCodes)"
org_default_avatar="$(json_string "$organization_json" defaultAvatar)"
org_default_application="$(json_string "$organization_json" defaultApplication)"
org_tags="$(json_raw_compact "$organization_json" tags)"
org_languages="$(json_raw_compact "$organization_json" languages)"
org_theme_data="$(json_raw_compact "$organization_json" themeData)"
org_init_score="$(json_number_string "$organization_json" initScore)"
org_enable_soft_deletion="$(json_bool_string "$organization_json" enableSoftDeletion)"
org_is_profile_public="$(json_bool_string "$organization_json" isProfilePublic)"
org_disable_signin="$(json_bool_string "$organization_json" disableSignin)"

docker_compose exec -T new-api-postgres \
  psql -v ON_ERROR_STOP=1 \
    -v org_owner="$org_owner" \
    -v org_name="$org_name" \
    -v org_display_name="$org_display_name" \
    -v org_website_url="$org_website_url" \
    -v org_logo="$org_logo" \
    -v org_logo_dark="$org_logo_dark" \
    -v org_favicon="$org_favicon" \
    -v org_has_privilege_consent="$org_has_privilege_consent" \
    -v org_password_type="$org_password_type" \
    -v org_password_options="$org_password_options" \
    -v org_country_codes="$org_country_codes" \
    -v org_default_avatar="$org_default_avatar" \
    -v org_default_application="$org_default_application" \
    -v org_tags="$org_tags" \
    -v org_languages="$org_languages" \
    -v org_theme_data="$org_theme_data" \
    -v org_init_score="$org_init_score" \
    -v org_enable_soft_deletion="$org_enable_soft_deletion" \
    -v org_is_profile_public="$org_is_profile_public" \
    -v org_disable_signin="$org_disable_signin" \
    -U "$NEW_API_DB_USER" -d "$CASDOOR_DB_NAME" <<'SQL'
INSERT INTO organization (
  owner,
  name,
  created_time,
  display_name,
  website_url,
  logo,
  logo_dark,
  favicon,
  has_privilege_consent,
  password_type,
  password_salt,
  password_options,
  password_obfuscator_type,
  password_obfuscator_key,
  password_expire_days,
  country_codes,
  default_avatar,
  default_application,
  user_types,
  tags,
  languages,
  theme_data,
  master_password,
  default_password,
  master_verification_code,
  ip_whitelist,
  init_score,
  enable_soft_deletion,
  is_profile_public,
  use_email_as_username,
  enable_tour,
  disable_signin,
  ip_restriction,
  nav_items,
  widget_items,
  mfa_items,
  mfa_remember_in_hours,
  account_items,
  use_permanent_avatar,
  user_nav_items,
  account_menu,
  dcr_policy,
  ldap_attributes,
  kerberos_realm,
  kerberos_kdc_host,
  kerberos_keytab,
  kerberos_service_name,
  org_balance,
  user_balance,
  balance_credit,
  balance_currency
)
SELECT
  :'org_owner',
  :'org_name',
  COALESCE(NULLIF(src.created_time, ''), to_char(timezone('UTC', now()), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')),
  :'org_display_name',
  COALESCE(NULLIF(:'org_website_url', ''), src.website_url),
  COALESCE(NULLIF(:'org_logo', ''), src.logo),
  COALESCE(NULLIF(:'org_logo_dark', ''), src.logo_dark),
  COALESCE(NULLIF(:'org_favicon', ''), src.favicon),
  CASE WHEN :'org_has_privilege_consent' = 'true' THEN true ELSE false END,
  COALESCE(NULLIF(:'org_password_type', ''), src.password_type),
  src.password_salt,
  CASE WHEN :'org_password_options' = '' THEN src.password_options ELSE :'org_password_options' END,
  src.password_obfuscator_type,
  src.password_obfuscator_key,
  src.password_expire_days,
  CASE WHEN :'org_country_codes' = '' THEN src.country_codes ELSE :'org_country_codes' END,
  COALESCE(NULLIF(:'org_default_avatar', ''), src.default_avatar),
  COALESCE(NULLIF(:'org_default_application', ''), src.default_application),
  src.user_types,
  CASE WHEN :'org_tags' = '' THEN src.tags ELSE :'org_tags' END,
  CASE WHEN :'org_languages' = '' THEN src.languages ELSE :'org_languages' END,
  CASE WHEN :'org_theme_data' = '' THEN src.theme_data ELSE CAST(:'org_theme_data' AS json) END,
  src.master_password,
  src.default_password,
  src.master_verification_code,
  src.ip_whitelist,
  CASE WHEN :'org_init_score' = '' THEN src.init_score ELSE CAST(:'org_init_score' AS integer) END,
  CASE
    WHEN :'org_enable_soft_deletion' = '' THEN src.enable_soft_deletion
    WHEN :'org_enable_soft_deletion' = 'true' THEN true
    ELSE false
  END,
  CASE
    WHEN :'org_is_profile_public' = '' THEN src.is_profile_public
    WHEN :'org_is_profile_public' = 'true' THEN true
    ELSE false
  END,
  src.use_email_as_username,
  src.enable_tour,
  CASE
    WHEN :'org_disable_signin' = '' THEN src.disable_signin
    WHEN :'org_disable_signin' = 'true' THEN true
    ELSE false
  END,
  src.ip_restriction,
  src.nav_items,
  src.widget_items,
  src.mfa_items,
  src.mfa_remember_in_hours,
  src.account_items,
  src.use_permanent_avatar,
  src.user_nav_items,
  src.account_menu,
  src.dcr_policy,
  src.ldap_attributes,
  src.kerberos_realm,
  src.kerberos_kdc_host,
  src.kerberos_keytab,
  src.kerberos_service_name,
  src.org_balance,
  src.user_balance,
  src.balance_credit,
  src.balance_currency
FROM organization src
WHERE src.owner = 'admin' AND src.name = 'built-in'
ON CONFLICT (owner, name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  website_url = EXCLUDED.website_url,
  logo = EXCLUDED.logo,
  logo_dark = EXCLUDED.logo_dark,
  favicon = EXCLUDED.favicon,
  has_privilege_consent = EXCLUDED.has_privilege_consent,
  password_type = EXCLUDED.password_type,
  password_options = EXCLUDED.password_options,
  country_codes = EXCLUDED.country_codes,
  default_avatar = EXCLUDED.default_avatar,
  default_application = EXCLUDED.default_application,
  tags = EXCLUDED.tags,
  languages = EXCLUDED.languages,
  theme_data = EXCLUDED.theme_data,
  init_score = EXCLUDED.init_score,
  enable_soft_deletion = EXCLUDED.enable_soft_deletion,
  is_profile_public = EXCLUDED.is_profile_public,
  disable_signin = EXCLUDED.disable_signin;
SQL

app_owner="$(json_string "$application_json" owner)"
app_name_value="$(json_string "$application_json" name)"
app_display_name="$(json_string "$application_json" displayName)"
app_logo="$(json_string "$application_json" logo)"
app_favicon="$(json_string "$application_json" favicon)"
app_homepage_url="$(json_string "$application_json" homepageUrl)"
app_description="$(json_string "$application_json" description)"
app_organization="$(json_string "$application_json" organization)"
app_cert="$(json_string "$application_json" cert)"
app_enable_password="$(json_bool_string "$application_json" enablePassword)"
app_enable_sign_up="$(json_bool_string "$application_json" enableSignUp)"
app_providers="$(json_raw_compact "$application_json" providers)"
app_signin_methods="$(json_raw_compact "$application_json" signinMethods)"
app_signup_items="$(json_raw_compact "$application_json" signupItems)"
app_grant_types="$(json_raw_compact "$application_json" grantTypes)"
app_redirect_uris="$(json_raw_compact "$application_json" redirectUris)"
app_token_format="$(json_string "$application_json" tokenFormat)"
app_token_fields="$(json_raw_compact "$application_json" tokenFields)"
app_expire_in_hours="$(json_number_string "$application_json" expireInHours)"
app_cookie_expire_in_hours="$(json_number_string "$application_json" cookieExpireInHours)"
app_form_offset="$(json_number_string "$application_json" formOffset)"
app_form_css="$(json_string "$application_json" formCss)"
app_theme_data="$(json_raw_compact "$application_json" themeData)"
app_client_id="$(json_string "$application_json" clientId)"
app_client_secret="$(json_string "$application_json" clientSecret)"

docker_compose exec -T new-api-postgres \
  psql -v ON_ERROR_STOP=1 \
    -v app_owner="$app_owner" \
    -v app_name="$app_name_value" \
    -v app_display_name="$app_display_name" \
    -v app_logo="$app_logo" \
    -v app_favicon="$app_favicon" \
    -v app_homepage_url="$app_homepage_url" \
    -v app_description="$app_description" \
    -v app_organization="$app_organization" \
    -v app_cert="$app_cert" \
    -v app_enable_password="$app_enable_password" \
    -v app_enable_sign_up="$app_enable_sign_up" \
    -v app_providers="$app_providers" \
    -v app_signin_methods="$app_signin_methods" \
    -v app_signup_items="$app_signup_items" \
    -v app_grant_types="$app_grant_types" \
    -v app_redirect_uris="$app_redirect_uris" \
    -v app_token_format="$app_token_format" \
    -v app_token_fields="$app_token_fields" \
    -v app_expire_in_hours="$app_expire_in_hours" \
    -v app_cookie_expire_in_hours="$app_cookie_expire_in_hours" \
    -v app_form_offset="$app_form_offset" \
    -v app_form_css="$app_form_css" \
    -v app_theme_data="$app_theme_data" \
    -v app_client_id="$app_client_id" \
    -v app_client_secret="$app_client_secret" \
    -U "$NEW_API_DB_USER" -d "$CASDOOR_DB_NAME" <<'SQL'
INSERT INTO application (
  owner,
  name,
  created_time,
  display_name,
  logo,
  favicon,
  homepage_url,
  description,
  organization,
  cert,
  enable_password,
  enable_sign_up,
  providers,
  signin_methods,
  signup_items,
  grant_types,
  client_id,
  client_secret,
  redirect_uris,
  token_format,
  token_fields,
  expire_in_hours,
  cookie_expire_in_hours,
  form_offset,
  theme_data,
  form_css
) VALUES (
  :'app_owner',
  :'app_name',
  to_char(timezone('UTC', now()), 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  :'app_display_name',
  NULLIF(:'app_logo', ''),
  NULLIF(:'app_favicon', ''),
  :'app_homepage_url',
  NULLIF(:'app_description', ''),
  :'app_organization',
  :'app_cert',
  CASE WHEN :'app_enable_password' = 'true' THEN true ELSE false END,
  CASE WHEN :'app_enable_sign_up' = 'true' THEN true ELSE false END,
  :'app_providers',
  :'app_signin_methods',
  :'app_signup_items',
  :'app_grant_types',
  :'app_client_id',
  :'app_client_secret',
  :'app_redirect_uris',
  :'app_token_format',
  :'app_token_fields',
  CASE WHEN :'app_expire_in_hours' = '' THEN 168 ELSE CAST(:'app_expire_in_hours' AS integer) END,
  CASE WHEN :'app_cookie_expire_in_hours' = '' THEN 720 ELSE CAST(:'app_cookie_expire_in_hours' AS bigint) END,
  CASE WHEN :'app_form_offset' = '' THEN 0 ELSE CAST(:'app_form_offset' AS integer) END,
  CASE WHEN :'app_theme_data' = '' THEN NULL ELSE CAST(:'app_theme_data' AS json) END,
  NULLIF(:'app_form_css', '')
)
ON CONFLICT (owner, name) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  logo = EXCLUDED.logo,
  favicon = EXCLUDED.favicon,
  homepage_url = EXCLUDED.homepage_url,
  description = EXCLUDED.description,
  organization = EXCLUDED.organization,
  cert = EXCLUDED.cert,
  enable_password = EXCLUDED.enable_password,
  enable_sign_up = EXCLUDED.enable_sign_up,
  providers = EXCLUDED.providers,
  signin_methods = EXCLUDED.signin_methods,
  signup_items = EXCLUDED.signup_items,
  grant_types = EXCLUDED.grant_types,
  client_id = EXCLUDED.client_id,
  client_secret = EXCLUDED.client_secret,
  redirect_uris = EXCLUDED.redirect_uris,
  token_format = EXCLUDED.token_format,
  token_fields = EXCLUDED.token_fields,
  expire_in_hours = EXCLUDED.expire_in_hours,
  cookie_expire_in_hours = EXCLUDED.cookie_expire_in_hours,
  form_offset = EXCLUDED.form_offset,
  theme_data = EXCLUDED.theme_data,
  form_css = EXCLUDED.form_css;
SQL

info "Casdoor 组织与应用配置已同步到持久化数据库"
