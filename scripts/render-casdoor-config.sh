#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

load_env
require_cmd jq

resolve_public_asset_url() {
  local base_url="$1"
  local asset_path="$2"

  if [[ -z "$asset_path" ]]; then
    printf ''
    return 0
  fi

  if [[ "$asset_path" =~ ^https?:// ]]; then
    printf '%s' "$asset_path"
    return 0
  fi

  printf '%s%s' "$base_url" "$asset_path"
}

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
casdoor_public_url="${casdoor_public_url%/}"
application_name="${CASDOOR_APPLICATION_NAME:-team-ai-librechat}"
application_display_name="${CASDOOR_APPLICATION_DISPLAY_NAME:-Team AI Platform SSO}"
librechat_public_url="${LIBRECHAT_PUBLIC_URL:-http://localhost:3080}"
librechat_public_url="${librechat_public_url%/}"
user_org_name="${CASDOOR_USER_ORGANIZATION_NAME:-team-ai}"
user_org_display_name="${CASDOOR_USER_ORGANIZATION_DISPLAY_NAME:-Team AI Platform}"
user_org_website_url="${CASDOOR_USER_ORGANIZATION_WEBSITE_URL:-${librechat_public_url}}"
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
platform_theme_mode="${PLATFORM_THEME_MODE:-dark}"
platform_brand_name="${PLATFORM_BRAND_NAME:-Team AI Platform}"
platform_brand_logo_path="${PLATFORM_BRAND_LOGO_PATH:-/images/team-ai-platform-logo.svg}"
platform_brand_favicon_path="${PLATFORM_BRAND_FAVICON_PATH:-/images/team-ai-platform-mark.svg}"
casdoor_theme_enabled="$(normalize_bool "${CASDOOR_THEME_IS_ENABLED:-true}")"
casdoor_theme_type="${CASDOOR_THEME_TYPE:-${platform_theme_mode}}"
casdoor_theme_color_primary="${CASDOOR_THEME_COLOR_PRIMARY:-#10a37f}"
casdoor_theme_border_radius="${CASDOOR_THEME_BORDER_RADIUS:-10}"
casdoor_theme_is_compact="$(normalize_bool "${CASDOOR_THEME_IS_COMPACT:-false}")"
casdoor_app_theme_enabled="$(normalize_bool "${CASDOOR_APPLICATION_THEME_IS_ENABLED:-${casdoor_theme_enabled}}")"
casdoor_app_theme_type="${CASDOOR_APPLICATION_THEME_TYPE:-${casdoor_theme_type}}"
casdoor_app_theme_color_primary="${CASDOOR_APPLICATION_THEME_COLOR_PRIMARY:-${casdoor_theme_color_primary}}"
casdoor_app_theme_border_radius="${CASDOOR_APPLICATION_THEME_BORDER_RADIUS:-${casdoor_theme_border_radius}}"
casdoor_app_theme_is_compact="$(normalize_bool "${CASDOOR_APPLICATION_THEME_IS_COMPACT:-${casdoor_theme_is_compact}}")"
brand_logo_url="$(resolve_public_asset_url "${librechat_public_url}" "${platform_brand_logo_path}")"
brand_favicon_url="$(resolve_public_asset_url "${librechat_public_url}" "${platform_brand_favicon_path}")"

if [[ "$user_org_name" == "built-in" ]]; then
  die "CASDOOR_USER_ORGANIZATION_NAME 不能为 built-in，否则注册用户会进入 Casdoor 全局管理员组织"
fi

if [[ "$MODE" == "local" && "$(normalize_bool "${LOCAL_SMTP_RELAY_ENABLED:-false}")" == "true" ]]; then
  smtp_host="${LOCAL_SMTP_RELAY_HOST:-host.docker.internal}"
  email_port="${LOCAL_SMTP_RELAY_PORT:-2525}"
  smtp_ssl_mode="Disable"
fi

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

casdoor_form_css=$(cat <<EOF
:root {
  color-scheme: dark;
}

html,
body,
#root {
  background:
    radial-gradient(circle at top left, rgba(16, 163, 127, 0.22), transparent 28%),
    radial-gradient(circle at 82% 10%, rgba(45, 212, 191, 0.14), transparent 24%),
    #0d0d0d !important;
  color: #f8fafc !important;
}

body {
  min-height: 100vh;
}

.login-content {
  max-width: 460px !important;
  margin: 48px auto !important;
  padding: 28px 32px !important;
  border-radius: 24px !important;
  background: rgba(18, 18, 18, 0.92) !important;
  border: 1px solid rgba(255, 255, 255, 0.08) !important;
  box-shadow: 0 30px 90px rgba(0, 0, 0, 0.5) !important;
  color: #f8fafc !important;
}

.login-content img {
  max-height: 56px !important;
  width: auto !important;
  object-fit: contain !important;
}

.login-content .ant-tabs-tab,
.login-content .ant-tabs-tab-btn,
.login-content .ant-checkbox-wrapper,
.login-content .ant-form-item-explain,
.login-content .ant-form-item-label > label,
.login-content .ant-typography,
.login-content .ant-typography a,
.login-content a,
.login-content span,
.login-content label {
  color: #f8fafc !important;
}

.login-content .ant-input,
.login-content .ant-input-affix-wrapper,
.login-content .ant-input-password,
.login-content .ant-select-selector,
.login-content .ant-input-number,
.login-content .ant-input-number-input {
  background: #111827 !important;
  border-color: #2b3440 !important;
  color: #f8fafc !important;
  box-shadow: none !important;
}

.login-content .ant-input::placeholder,
.login-content .ant-input-affix-wrapper input::placeholder,
.login-content .ant-input-number-input::placeholder {
  color: #94a3b8 !important;
}

.login-content .ant-input-affix-wrapper .anticon,
.login-content .ant-input-prefix,
.login-content .ant-input-suffix,
.login-content .ant-select-arrow,
.login-content .ant-checkbox-inner::after {
  color: #cbd5e1 !important;
}

.login-content .ant-tabs-ink-bar,
.login-content .ant-checkbox-checked .ant-checkbox-inner,
.login-content .ant-radio-checked .ant-radio-inner,
.login-content .ant-switch-checked {
  background: ${casdoor_app_theme_color_primary} !important;
  border-color: ${casdoor_app_theme_color_primary} !important;
}

.login-content .ant-btn-primary,
.login-content button.ant-btn-primary {
  background: ${casdoor_app_theme_color_primary} !important;
  border-color: ${casdoor_app_theme_color_primary} !important;
  color: #f8fafc !important;
  box-shadow: none !important;
}

.login-content .ant-btn-primary:hover,
.login-content .ant-btn-primary:focus,
.login-content button.ant-btn-primary:hover,
.login-content button.ant-btn-primary:focus {
  background: #0c8b6c !important;
  border-color: #0c8b6c !important;
}

.login-content .ant-divider,
.login-content .ant-form-item {
  border-color: rgba(255, 255, 255, 0.08) !important;
}
EOF
)

jq -n \
  --arg application_name "${application_name}" \
  --arg application_display_name "${application_display_name}" \
  --arg user_org_name "${user_org_name}" \
  --arg user_org_display_name "${user_org_display_name}" \
  --arg user_org_website_url "${user_org_website_url}" \
  --arg librechat_public_url "${librechat_public_url}" \
  --arg platform_brand_name "${platform_brand_name}" \
  --arg brand_logo_url "${brand_logo_url}" \
  --arg brand_favicon_url "${brand_favicon_url}" \
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
  --arg casdoor_form_css "${casdoor_form_css}" \
  --arg casdoor_theme_type "${casdoor_theme_type}" \
  --arg casdoor_theme_color_primary "${casdoor_theme_color_primary}" \
  --argjson casdoor_theme_border_radius "${casdoor_theme_border_radius}" \
  --argjson casdoor_theme_enabled "${casdoor_theme_enabled}" \
  --argjson casdoor_theme_is_compact "${casdoor_theme_is_compact}" \
  --arg casdoor_app_theme_type "${casdoor_app_theme_type}" \
  --arg casdoor_app_theme_color_primary "${casdoor_app_theme_color_primary}" \
  --argjson casdoor_app_theme_border_radius "${casdoor_app_theme_border_radius}" \
  --argjson casdoor_app_theme_enabled "${casdoor_app_theme_enabled}" \
  --argjson casdoor_app_theme_is_compact "${casdoor_app_theme_is_compact}" \
  --argjson smtp_port "${email_port}" \
  '{
    organizations: [
      {
        owner: "admin",
        name: $user_org_name,
        displayName: $user_org_display_name,
        websiteUrl: $user_org_website_url,
        logo: $brand_logo_url,
        logoDark: $brand_logo_url,
        favicon: $brand_favicon_url,
        hasPrivilegeConsent: false,
        passwordType: "bcrypt",
        passwordOptions: [
          "AtLeast6"
        ],
        countryCodes: [
          "US","ES","FR","DE","GB","CN","JP","KR","VN","ID","SG","IN"
        ],
        defaultAvatar: "https://cdn.casbin.org/img/casbin.svg",
        defaultApplication: $application_name,
        tags: [],
        languages: [
          "en","zh","es","fr","de","id","ja","ko","ru","vi","pt"
        ],
        themeData: {
          isEnabled: $casdoor_theme_enabled,
          themeType: $casdoor_theme_type,
          colorPrimary: $casdoor_theme_color_primary,
          borderRadius: $casdoor_theme_border_radius,
          isCompact: $casdoor_theme_is_compact
        },
        initScore: 2000,
        enableSoftDeletion: false,
        isProfilePublic: false,
        disableSignin: false
      }
    ],
    applications: [
      {
        owner: "admin",
        name: $application_name,
        displayName: $application_display_name,
        logo: $brand_logo_url,
        favicon: $brand_favicon_url,
        homepageUrl: $librechat_public_url,
        description: ($platform_brand_name + " 统一认证入口"),
        organization: $user_org_name,
        cert: "cert-built-in",
        enablePassword: true,
        enableSignUp: true,
        clientId: $client_id,
        clientSecret: $client_secret,
        formCss: $casdoor_form_css,
        themeData: {
          isEnabled: $casdoor_app_theme_enabled,
          themeType: $casdoor_app_theme_type,
          colorPrimary: $casdoor_app_theme_color_primary,
          borderRadius: $casdoor_app_theme_border_radius,
          isCompact: $casdoor_app_theme_is_compact
        },
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
          $librechat_public_url,
          ($librechat_public_url + "/login"),
          ($librechat_public_url + "/login?redirect=false"),
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
