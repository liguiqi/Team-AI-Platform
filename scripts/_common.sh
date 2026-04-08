#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${MODE:-local}"

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

random_hex() {
  local length="$1"
  LC_ALL=C tr -dc 'a-f0-9' </dev/urandom | head -c "$length"
}

random_alnum() {
  local length="$1"
  LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$length"
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

is_placeholder() {
  local value="${1:-}"
  [[ -z "$value" || "$value" == __FILL_* || "$value" == __AUTO_* ]]
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
