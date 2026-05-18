#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${MODE:-local}"
PROJECT_UNLIMITED_QUOTA="${PROJECT_UNLIMITED_QUOTA:-1000000000000}"
PROJECT_PROVIDER_CHANNEL_BALANCE="${PROJECT_PROVIDER_CHANNEL_BALANCE:-999999999999}"

if [[ "$MODE" != "local" && "$MODE" != "prod" ]]; then
  echo "MODE 只能是 local 或 prod，当前为: $MODE" >&2
  exit 1
fi

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

compose_file() {
  printf '%s/deploy/docker-compose.%s.yml\n' "$ROOT_DIR" "$MODE"
}

env_file() {
  if [[ "$MODE" == "local" ]]; then
    printf '%s/.env\n' "$ROOT_DIR"
  else
    printf '%s/deploy/env/prod/.env\n' "$ROOT_DIR"
  fi
}

example_env_file() {
  if [[ "$MODE" == "local" ]]; then
    printf '%s/.env.example\n' "$ROOT_DIR"
  else
    printf '%s/deploy/env/prod/.env.example\n' "$ROOT_DIR"
  fi
}

librechat_config_file() {
  if [[ "$MODE" == "local" ]]; then
    printf '%s/runtime/local/librechat/librechat.yaml\n' "$ROOT_DIR"
  else
    printf '%s/runtime/prod/librechat/librechat.yaml\n' "$ROOT_DIR"
  fi
}

casdoor_config_file() {
  if [[ "$MODE" == "local" ]]; then
    printf '%s/runtime/local/casdoor/app.conf\n' "$ROOT_DIR"
  else
    printf '%s/runtime/prod/casdoor/app.conf\n' "$ROOT_DIR"
  fi
}

casdoor_init_data_file() {
  if [[ "$MODE" == "local" ]]; then
    printf '%s/runtime/local/casdoor/init_data.json\n' "$ROOT_DIR"
  else
    printf '%s/runtime/prod/casdoor/init_data.json\n' "$ROOT_DIR"
  fi
}

load_env() {
  local file
  file="$(env_file)"
  [[ -f "$file" ]] || die "环境文件不存在: $file"
  set -a
  # shellcheck disable=SC1090
  source "$file"
  set +a
}

docker_compose() {
  docker compose --env-file "$(env_file)" -f "$(compose_file)" "$@"
}

docker_compose_up_retry() {
  local attempts="${1:-3}"
  shift || true
  local delay="${TEAMAI_DOCKER_UP_RETRY_DELAY:-5}"
  local attempt

  for attempt in $(seq 1 "$attempts"); do
    if docker_compose up -d "$@"; then
      return 0
    fi
    if (( attempt == attempts )); then
      return 1
    fi
    warn "docker compose up 第 ${attempt} 次失败，${delay} 秒后重试"
    sleep "$delay"
  done
}

host_new_api_url() {
  if [[ "$MODE" == "local" ]]; then
    printf 'http://127.0.0.1:%s' "${NEW_API_PORT}"
  else
    printf '%s' "${NEW_API_PUBLIC_URL}"
  fi
}

host_casdoor_url() {
  if [[ "$MODE" == "local" ]]; then
    printf 'http://127.0.0.1:%s' "${CASDOOR_PORT}"
  else
    printf '%s' "${CASDOOR_PUBLIC_URL}"
  fi
}

host_librechat_url() {
  if [[ "$MODE" == "local" ]]; then
    printf 'http://127.0.0.1:%s' "${LIBRECHAT_PORT}"
  else
    printf '%s' "${LIBRECHAT_PUBLIC_URL}"
  fi
}

random_hex() {
  local length="$1"
  local result="" attempt
  for attempt in 1 2 3; do
    result="$(LC_ALL=C tr -dc 'a-f0-9' </dev/urandom 2>/dev/null | head -c "$length" 2>/dev/null)" || true
    if [[ ${#result} -eq "$length" ]]; then
      printf '%s' "$result"
      return 0
    fi
  done
  while (( ${#result} < length )); do
    result="${result}$(printf '%04x' "$(( RANDOM % 65536 ))")"
  done
  printf '%s' "${result:0:$length}"
}

random_alnum() {
  local length="$1"
  local result="" attempt
  for attempt in 1 2 3; do
    result="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c "$length" 2>/dev/null)" || true
    if [[ ${#result} -eq "$length" ]]; then
      printf '%s' "$result"
      return 0
    fi
  done
  # Fallback: use $RANDOM concatenation
  while (( ${#result} < length )); do
    result="${result}$(printf '%05d' "$(( RANDOM % 100000 ))")"
  done
  printf '%s' "${result:0:$length}"
}

replace_or_append_env() {
  local key="$1"
  local value="$2"
  local file="$3"
  local tmp
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { done = 0 }
    $0 ~ "^" key "=" {
      print key "=" value
      done = 1
      next
    }
    { print }
    END {
      if (!done) {
        print key "=" value
      }
    }
  ' "$file" >"$tmp"
  mv "$tmp" "$file"
}

current_env_value() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, "", $0); print $0; exit }' "$file"
}

has_env_key() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 == key { found = 1; exit } END { exit(found ? 0 : 1) }' "$file"
}

append_missing_env_keys_from_example() {
  local target_file="$1"
  local example_file="$2"
  local line key added_count
  added_count=0

  while IFS= read -r line; do
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    if ! has_env_key "$key" "$target_file"; then
      printf '%s\n' "$line" >>"$target_file"
      added_count=$((added_count + 1))
    fi
  done <"$example_file"

  printf '%s' "$added_count"
}

is_placeholder() {
  local value="${1:-}"
  [[ -z "$value" || "$value" == __FILL_* || "$value" == __AUTO_* ]]
}

migrate_legacy_librechat_auth_flags() {
  local file="$1"
  local allow_email_login allow_registration allow_social_login

  allow_email_login="$(current_env_value LIBRECHAT_ALLOW_EMAIL_LOGIN "$file")"
  allow_registration="$(current_env_value LIBRECHAT_ALLOW_REGISTRATION "$file")"
  allow_social_login="$(current_env_value LIBRECHAT_ALLOW_SOCIAL_LOGIN "$file")"

  if [[ "$allow_email_login" == "true" && "$allow_registration" == "true" && "$allow_social_login" == "false" ]]; then
    replace_or_append_env LIBRECHAT_ALLOW_EMAIL_LOGIN false "$file"
    replace_or_append_env LIBRECHAT_ALLOW_REGISTRATION false "$file"
    replace_or_append_env LIBRECHAT_ALLOW_SOCIAL_LOGIN true "$file"
    replace_or_append_env LIBRECHAT_ALLOW_PASSWORD_RESET false "$file"
    info "检测到旧版 LibreChat 登录开关，已迁移为 Casdoor OIDC 模式"
  fi
}

migrate_legacy_casdoor_version() {
  local file="$1"
  local casdoor_version

  casdoor_version="$(current_env_value CASDOOR_VERSION "$file")"
  if [[ "$casdoor_version" == "v2.99.0" ]]; then
    replace_or_append_env CASDOOR_VERSION 2.396.1 "$file"
    info "检测到旧版 Casdoor 镜像标签 v2.99.0，已迁移到支持 PNVS 的 2.396.1"
  fi
}

enforce_librechat_default_admin_policy() {
  local file="$1"
  local default_admin_enabled allow_email_login

  default_admin_enabled="$(normalize_bool "$(current_env_value LIBRECHAT_DEFAULT_ADMIN_ENABLED "$file")")"
  allow_email_login="$(normalize_bool "$(current_env_value LIBRECHAT_ALLOW_EMAIL_LOGIN "$file")")"

  if [[ "$default_admin_enabled" == "true" && "$allow_email_login" != "true" ]]; then
    replace_or_append_env LIBRECHAT_ALLOW_EMAIL_LOGIN true "$file"
    info "检测到默认 LibreChat 管理员启用，已开启 LIBRECHAT_ALLOW_EMAIL_LOGIN"
  fi
}

detect_local_host_ip() {
  local host_ip

  if command -v ip >/dev/null 2>&1; then
    host_ip="$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i == "src") { print $(i + 1); exit }}')"
  fi

  if [[ -z "$host_ip" ]]; then
    host_ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  fi

  printf '%s' "$host_ip"
}

migrate_local_public_urls_for_oidc() {
  local file="$1"
  local allow_insecure_http host_ip current changed

  [[ "$MODE" == "local" ]] || return 0

  allow_insecure_http="$(current_env_value LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP "$file")"
  [[ "${allow_insecure_http,,}" == "true" ]] || return 0

  host_ip="$(detect_local_host_ip)"
  [[ -n "$host_ip" ]] || return 0

  changed=0

  current="$(current_env_value LIBRECHAT_PUBLIC_URL "$file")"
  if [[ "$current" == "http://localhost:3080" || "$current" == "http://127.0.0.1:3080" ]]; then
    replace_or_append_env LIBRECHAT_PUBLIC_URL "http://${host_ip}:3080" "$file"
    changed=1
  fi

  current="$(current_env_value NEW_API_PUBLIC_URL "$file")"
  if [[ "$current" == "http://localhost:13000" || "$current" == "http://127.0.0.1:13000" ]]; then
    replace_or_append_env NEW_API_PUBLIC_URL "http://${host_ip}:13000" "$file"
    changed=1
  fi

  current="$(current_env_value CASDOOR_PUBLIC_URL "$file")"
  if [[ "$current" == "http://localhost:18000" || "$current" == "http://127.0.0.1:18000" ]]; then
    replace_or_append_env CASDOOR_PUBLIC_URL "http://${host_ip}:18000" "$file"
    changed=1
  fi

  if (( changed == 1 )); then
    info "已将本地公开 URL 迁移为宿主机 IP (${host_ip})，确保 LibreChat 与 Casdoor OIDC 可互通"
  fi
}

wait_for_http() {
  local url="$1"
  local timeout="${2:-60}"
  local start
  start="$(date +%s)"
  while true; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    if (( "$(date +%s)" - start >= timeout )); then
      return 1
    fi
    sleep 2
  done
}

sync_local_env_copy() {
  if [[ "$MODE" == "local" && -f "$ROOT_DIR/.env" ]]; then
    cp "$ROOT_DIR/.env" "$ROOT_DIR/deploy/env/local/.env"
  fi
}

prepare_env_file() {
  local file example_file added_count
  file="$(env_file)"
  example_file="$(example_env_file)"

  [[ -f "$file" ]] || return 0

  if [[ -f "$example_file" ]]; then
    added_count="$(append_missing_env_keys_from_example "$file" "$example_file")"
    if (( added_count > 0 )); then
      info "已从模板补齐 ${added_count} 个缺失环境变量"
    fi
  fi

  migrate_legacy_librechat_auth_flags "$file"
  migrate_legacy_casdoor_version "$file"
  enforce_librechat_default_admin_policy "$file"
  migrate_local_public_urls_for_oidc "$file"
  enforce_project_unlimited_new_api_policy "$file"

  if [[ "$MODE" == "local" ]]; then
    sync_local_env_copy
  fi
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

normalize_bool() {
  local value="${1:-}"
  case "${value,,}" in
    1|true|yes|on)
      printf 'true'
      ;;
    0|false|no|off|'')
      printf 'false'
      ;;
    *)
      die "非法布尔值: $value"
      ;;
  esac
}

extract_json_number() {
  local key="$1"
  sed -nE "s/.*\"$key\"[[:space:]]*:[[:space:]]*([0-9]+).*/\\1/p" | head -n 1
}

extract_json_string() {
  local key="$1"
  sed -nE "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]+)\".*/\\1/p" | head -n 1
}

json_get_number() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg key "$key" '.. | objects | .[$key]? | numbers' 2>/dev/null | head -n 1
  else
    extract_json_number "$key"
  fi
}

json_get_string() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg key "$key" '.. | objects | .[$key]? | strings' 2>/dev/null | head -n 1
  else
    extract_json_string "$key"
  fi
}

json_get_bool() {
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg key "$key" '.. | objects | .[$key]? | booleans' 2>/dev/null | head -n 1
  else
    sed -nE "s/.*\"$key\"[[:space:]]*:[[:space:]]*(true|false).*/\\1/p" | head -n 1
  fi
}

json_has_true() {
  local key="$1"
  local value
  value="$(json_get_bool "$key" || true)"
  [[ "$value" == "true" ]]
}

require_non_placeholder_env() {
  local key="$1"
  local value="$2"
  if is_placeholder "$value"; then
    die "请先在 $(env_file) 中填写 $key"
  fi
}

require_non_negative_number() {
  local key="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    die "${key} 必须是非负数字，当前为: ${value}"
  fi
}

enforce_project_unlimited_new_api_policy() {
  local file="$1"

  replace_or_append_env NEW_API_SERVICE_TOKEN_QUOTA "$PROJECT_UNLIMITED_QUOTA" "$file"
  replace_or_append_env NEW_API_SERVICE_TOKEN_UNLIMITED true "$file"
  replace_or_append_env NEW_API_TOKEN_MODEL_LIMITS_ENABLED false "$file"
  replace_or_append_env NEW_API_RATE_LIMIT_ENABLED false "$file"
  replace_or_append_env NEW_API_PROVIDER_CHANNEL_BALANCE "$PROJECT_PROVIDER_CHANNEL_BALANCE" "$file"
}

trim_csv_item() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

append_csv_values() {
  local existing_csv="${1:-}"
  local incoming_csv="${2:-}"
  local combined="$existing_csv"
  local item normalized

  IFS=',' read -r -a incoming_items <<<"$incoming_csv"
  for item in "${incoming_items[@]}"; do
    normalized="$(trim_csv_item "$item")"
    [[ -n "$normalized" ]] || continue

    case ",${combined}," in
      *,"${normalized}",*)
        continue
        ;;
      *)
        if [[ -n "$combined" ]]; then
          combined="${combined},${normalized}"
        else
          combined="${normalized}"
        fi
        ;;
    esac
  done

  printf '%s' "$combined"
}

provider_prefixes() {
  printf '%s\n' ZHIPU DEEPSEEK ALIYUN KIMI DOUBAO MIMO MINIMAX
}

provider_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

provider_display_label() {
  case "$1" in
    ZHIPU) printf '智谱' ;;
    DEEPSEEK) printf 'DeepSeek' ;;
    ALIYUN) printf '阿里云百炼' ;;
    KIMI) printf 'Kimi' ;;
    DOUBAO) printf '火山方舟豆包' ;;
    MIMO) printf '小米 MiMo' ;;
    MINIMAX) printf 'MiniMax' ;;
    *) provider_slug "$1" ;;
  esac
}

provider_is_enabled_env() {
  local prefix="$1"
  local enabled_var="${prefix}_ENABLED"
  normalize_bool "${!enabled_var:-false}"
}

provider_endpoint_name() {
  local prefix="$1"
  local endpoint_name_var="${prefix}_LIBRECHAT_ENDPOINT_NAME"
  local legacy_endpoint_name_var="${prefix}_ENDPOINT_NAME"
  local endpoint_name="${!endpoint_name_var-}"

  if [[ -z "$endpoint_name" ]]; then
    endpoint_name="${!legacy_endpoint_name_var-}"
  fi

  if [[ -n "$endpoint_name" ]]; then
    printf '%s' "$endpoint_name"
  else
    printf 'API-%s' "$(provider_slug "$prefix")"
  fi
}

provider_model_label() {
  local prefix="$1"
  local label_var="${prefix}_MODEL_LABEL"
  local label="${!label_var:-}"

  if [[ -n "$label" ]]; then
    printf '%s' "$label"
  else
    provider_endpoint_name "$prefix"
  fi
}

csv_to_lines() {
  tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' | awk '!seen[$0]++'
}

csv_contains_value() {
  local csv="$1"
  local value="$2"
  printf '%s' "$csv" | csv_to_lines | grep -Fxq "$value"
}

filter_csv_by_allowlist() {
  local models_csv="${1:-}"
  local allow_csv="${2:-}"
  local result="" model

  if [[ -z "$allow_csv" ]]; then
    printf '%s' "$models_csv"
    return 0
  fi

  while IFS= read -r model; do
    if csv_contains_value "$allow_csv" "$model"; then
      result="$(append_csv_values "$result" "$model")"
    fi
  done < <(printf '%s' "$models_csv" | csv_to_lines)

  printf '%s' "$result"
}

sort_models_by_priority() {
  local models_csv="${1:-}"
  local order_csv="${2:-}"
  local result="" model tmp_models tmp_used tmp_remaining

  tmp_models="$(mktemp)"
  tmp_used="$(mktemp)"
  tmp_remaining="$(mktemp)"

  printf '%s' "$models_csv" | csv_to_lines >"$tmp_models"
  : >"$tmp_used"

  while IFS= read -r model; do
    [[ -n "$model" ]] || continue
    if grep -Fxq "$model" "$tmp_models" && ! grep -Fxq "$model" "$tmp_used"; then
      result="$(append_csv_values "$result" "$model")"
      printf '%s\n' "$model" >>"$tmp_used"
    fi
  done < <(printf '%s' "$order_csv" | csv_to_lines)

  while IFS= read -r model; do
    [[ -n "$model" ]] || continue
    if ! grep -Fxq "$model" "$tmp_used"; then
      printf '%s\n' "$model" >>"$tmp_remaining"
    fi
  done <"$tmp_models"

  while IFS= read -r model; do
    [[ -n "$model" ]] || continue
    result="$(append_csv_values "$result" "$model")"
  done < <(sort -Vr "$tmp_remaining")

  rm -f "$tmp_models" "$tmp_used" "$tmp_remaining"
  printf '%s' "$result"
}

provider_sorted_exposed_models() {
  local prefix="$1"
  local exposed_var="${prefix}_EXPOSED_MODEL"
  local order_var="${prefix}_MODEL_ORDER"
  local visible_models="${LIBRECHAT_VISIBLE_MODELS:-}"
  local exposed_models sorted_models

  exposed_models="${!exposed_var:-}"
  sorted_models="$(sort_models_by_priority "$exposed_models" "${!order_var:-}")"
  filter_csv_by_allowlist "$sorted_models" "$visible_models"
}

provider_title_model() {
  local prefix="$1"
  local title_var="${prefix}_TITLE_MODEL"
  local default_var="${prefix}_DEFAULT_MODEL"
  local sorted_models="${2:-}"
  local title_model="${!title_var-}"

  if [[ -z "$title_model" ]]; then
    title_model="${!default_var-}"
  fi

  if [[ -n "$title_model" ]]; then
    if [[ -z "$sorted_models" ]] || csv_contains_value "$sorted_models" "$title_model"; then
      printf '%s' "$title_model"
      return 0
    fi
  fi

  if [[ -n "$sorted_models" ]]; then
    printf '%s' "$sorted_models" | csv_to_lines | head -n 1
  fi
}

enabled_provider_exposed_models() {
  local combined=""
  local prefix enabled_var exposed_var enabled_value exposed_value

  while IFS= read -r prefix; do
    enabled_var="${prefix}_ENABLED"
    exposed_var="${prefix}_EXPOSED_MODEL"
    enabled_value="$(normalize_bool "${!enabled_var:-false}")"
    exposed_value="${!exposed_var:-}"

    if [[ "$enabled_value" == "true" && -n "$exposed_value" ]]; then
      combined="$(append_csv_values "$combined" "$exposed_value")"
    fi
  done < <(provider_prefixes)

  printf '%s' "$combined"
}
