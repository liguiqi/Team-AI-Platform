#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

load_env
require_cmd jq

target_config_file="$(casdoor_config_file)"
target_init_data_file="$(casdoor_init_data_file)"
mkdir -p "$(dirname "$target_config_file")" "$(dirname "$target_init_data_file")"

if [[ "$MODE" == "local" ]]; then
  casdoor_runmode="dev"
else
  casdoor_runmode="prod"
fi

verification_timeout="${CASDOOR_VERIFICATION_CODE_TIMEOUT:-5}"
casdoor_init_data_new_only="$(normalize_bool "${CASDOOR_INIT_DATA_NEW_ONLY:-false}")"
email_port="${CASDOOR_EMAIL_SMTP_PORT:-25}"
admin_phone="${CASDOOR_ADMIN_PHONE:-}"
admin_country_code="${CASDOOR_ADMIN_COUNTRY_CODE:-CN}"
compose_project_name="${COMPOSE_PROJECT_NAME:-ai-gateway-chat}"
new_api_db_user="${NEW_API_DB_USER:-newapi}"
new_api_db_password="${NEW_API_DB_PASSWORD:-}"
casdoor_db_name="${CASDOOR_DB_NAME:-casdoor}"
casdoor_public_url="${CASDOOR_PUBLIC_URL:-http://localhost:18000}"
application_name="${CASDOOR_APPLICATION_NAME:-team-ai-librechat}"
application_display_name="${CASDOOR_APPLICATION_DISPLAY_NAME:-Team AI Platform SSO}"
librechat_public_url="${LIBRECHAT_PUBLIC_URL:-http://localhost:3080}"
client_id="${CASDOOR_CLIENT_ID:-team-ai-librechat}"
client_secret="${CASDOOR_CLIENT_SECRET:-}"
email_provider_name="${CASDOOR_EMAIL_PROVIDER_NAME:-team-ai-email}"
sms_provider_name="${CASDOOR_SMS_PROVIDER_NAME:-team-ai-pnvs}"
admin_password="${CASDOOR_ADMIN_PASSWORD:-}"
admin_email="${CASDOOR_ADMIN_EMAIL:-}"
smtp_host="${CASDOOR_EMAIL_SMTP_HOST:-}"
smtp_user="${CASDOOR_EMAIL_SMTP_USERNAME:-}"
smtp_password="${CASDOOR_EMAIL_SMTP_PASSWORD:-}"
smtp_ssl_mode="${CASDOOR_EMAIL_SSL_MODE:-Disable}"
sms_access_key_id="${CASDOOR_SMS_ACCESS_KEY_ID:-}"
sms_access_key_secret="${CASDOOR_SMS_ACCESS_KEY_SECRET:-}"
sms_sign_name="${CASDOOR_SMS_SIGN_NAME:-}"
sms_template_code="${CASDOOR_SMS_TEMPLATE_CODE:-}"
sms_region_id="${CASDOOR_SMS_REGION_ID:-cn-hangzhou}"
email_from_address="${CASDOOR_EMAIL_FROM_ADDRESS:-${smtp_user}}"
email_from_name="${CASDOOR_EMAIL_FROM_NAME:-Team AI Platform}"
email_subject="${CASDOOR_EMAIL_SUBJECT:-Team AI Platform 验证码}"

cat >"$target_config_file" <<EOF
appname = casdoor
httpport = 8000
runmode = ${casdoor_runmode}
copyrequestbody = true
driverName = postgres
dataSourceName = user=${new_api_db_user} password=${new_api_db_password} host=new-api-postgres port=5432 sslmode=disable dbname=${casdoor_db_name}
dbName = ${casdoor_db_name}
showSql = false
origin = ${casdoor_public_url}
originFrontend = ${casdoor_public_url}
authState = "${compose_project_name}-casdoor"
verificationCodeTimeout = ${verification_timeout}
defaultApplication = ${application_name}
enableGzip = true
logConfig = {"adapter":"file","filename":"/logs/casdoor.log","maxdays":99999,"perm":"0770"}
initDataNewOnly = ${casdoor_init_data_new_only}
initDataFile = "/init_data.json"
EOF

email_content=$(cat <<EOF
<div style="font-family:Arial,'PingFang SC','Microsoft YaHei',sans-serif;line-height:1.7;color:#1f2937">
  <h2 style="margin:0 0 16px">Team AI Platform 登录验证码</h2>
  <p>您正在进行账号验证，本次验证码为：</p>
  <p style="font-size:28px;font-weight:700;letter-spacing:4px">%s</p>
  <p>验证码 ${verification_timeout} 分钟内有效，请勿泄露给他人。</p>
</div>
EOF
)

invitation_content=$(cat <<EOF
<div style="font-family:Arial,'PingFang SC','Microsoft YaHei',sans-serif;line-height:1.7;color:#1f2937">
  <h2 style="margin:0 0 16px">Team AI Platform 邀请通知</h2>
  <p>您已被邀请加入 Team AI Platform。</p>
  <p>邀请码：<strong>%s</strong></p>
  <p>如需继续，请点击：%link</p>
</div>
EOF
)

jq -n \
  --arg application_name "${application_name}" \
  --arg application_display_name "${application_display_name}" \
  --arg librechat_public_url "${librechat_public_url}" \
  --arg client_id "${client_id}" \
  --arg client_secret "${client_secret}" \
  --arg email_provider_name "${email_provider_name}" \
  --arg sms_provider_name "${sms_provider_name}" \
  --arg admin_password "${admin_password}" \
  --arg admin_email "${admin_email}" \
  --arg admin_phone "${admin_phone}" \
  --arg admin_country_code "${admin_country_code}" \
  --arg smtp_host "${smtp_host}" \
  --arg smtp_user "${smtp_user}" \
  --arg smtp_password "${smtp_password}" \
  --arg smtp_ssl_mode "${smtp_ssl_mode}" \
  --arg from_address "${email_from_address}" \
  --arg from_name "${email_from_name}" \
  --arg email_subject "${email_subject}" \
  --arg email_content "${email_content}" \
  --arg invitation_content "${invitation_content}" \
  --arg sms_access_key_id "${sms_access_key_id}" \
  --arg sms_access_key_secret "${sms_access_key_secret}" \
  --arg sms_sign_name "${sms_sign_name}" \
  --arg sms_template_code "${sms_template_code}" \
  --arg sms_region_id "${sms_region_id}" \
  --arg sms_country_code "${admin_country_code}" \
  --argjson smtp_port "${email_port}" \
  '{
    applications: [
      {
        owner: "admin",
        name: $application_name,
        displayName: $application_display_name,
        homepageUrl: $librechat_public_url,
        organization: "built-in",
        cert: "cert-built-in",
        enablePassword: true,
        enableSignUp: true,
        clientId: $client_id,
        clientSecret: $client_secret,
        providers: [
          {
            name: $email_provider_name,
            canSignUp: true,
            canSignIn: true,
            canUnlink: false,
            prompted: false,
            signupGroup: "",
            rule: "All"
          },
          {
            name: $sms_provider_name,
            canSignUp: true,
            canSignIn: true,
            canUnlink: false,
            prompted: false,
            signupGroup: "",
            rule: "All"
          }
        ],
        signinMethods: [
          {
            name: "Password",
            displayName: "Password",
            rule: "All"
          },
          {
            name: "Verification code",
            displayName: "Verification code",
            rule: "All"
          },
          {
            name: "WebAuthn",
            displayName: "WebAuthn",
            rule: "None"
          },
          {
            name: "Face ID",
            displayName: "Face ID",
            rule: "None"
          }
        ],
        signupItems: [
          {
            name: "ID",
            visible: false,
            required: true,
            prompted: false,
            rule: "Random"
          },
          {
            name: "Username",
            visible: true,
            required: true,
            prompted: false,
            rule: "None"
          },
          {
            name: "Display name",
            visible: true,
            required: true,
            prompted: false,
            rule: "None"
          },
          {
            name: "Password",
            visible: true,
            required: true,
            prompted: false,
            rule: "None"
          },
          {
            name: "Confirm password",
            visible: true,
            required: true,
            prompted: false,
            rule: "None"
          },
          {
            name: "Email or Phone",
            visible: true,
            required: true,
            prompted: false,
            rule: "Normal"
          },
          {
            name: "Agreement",
            visible: true,
            required: true,
            prompted: false,
            rule: "None"
          }
        ],
        grantTypes: [
          "authorization_code",
          "password",
          "refresh_token"
        ],
        redirectUris: [
          ($librechat_public_url + "/oauth/openid/callback")
        ],
        tokenFormat: "JWT",
        tokenFields: [],
        expireInHours: 168,
        cookieExpireInHours: 720,
        formOffset: 2
      }
    ],
    users: [
      {
        owner: "built-in",
        name: "admin",
        type: "normal-user",
        password: $admin_password,
        displayName: "Platform Admin",
        email: $admin_email,
        phone: $admin_phone,
        countryCode: $admin_country_code,
        score: 2000,
        ranking: 1,
        isAdmin: true,
        isForbidden: false,
        isDeleted: false,
        signupApplication: $application_name,
        registerType: "Add User",
        registerSource: "built-in/admin",
        createdIp: "127.0.0.1",
        groups: []
      }
    ],
    providers: [
      {
        owner: "admin",
        name: $email_provider_name,
        displayName: "Team AI SMTP",
        category: "Email",
        type: "Default",
        clientId: $smtp_user,
        clientSecret: $smtp_password,
        clientId2: $from_address,
        clientSecret2: $from_name,
        host: $smtp_host,
        port: $smtp_port,
        sslMode: $smtp_ssl_mode,
        title: $email_subject,
        content: $email_content,
        metadata: $invitation_content,
        receiver: $admin_email,
        enableProxy: false
      },
      {
        owner: "admin",
        name: $sms_provider_name,
        displayName: "Team AI PNVS SMS",
        category: "SMS",
        type: "Alibaba Cloud PNVS SMS",
        clientId: $sms_access_key_id,
        clientSecret: $sms_access_key_secret,
        signName: $sms_sign_name,
        templateCode: $sms_template_code,
        regionId: $sms_region_id,
        content: $sms_country_code,
        receiver: $admin_phone,
        enableProxy: false
      }
    ]
  }' >"$target_init_data_file"

info "Casdoor 配置已渲染: ${target_config_file}"
info "Casdoor 初始化数据已渲染: ${target_init_data_file}"
