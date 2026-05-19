#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

[[ "$MODE" == "local" ]] || die "init-local.sh 仅支持 MODE=local"

require_cmd docker
docker compose version >/dev/null 2>&1 || die "缺少 docker compose"

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  info "已创建本地环境文件: $ROOT_DIR/.env"
fi

prepare_env_file

ensure_random_if_placeholder() {
  local key="$1"
  local generator="$2"
  local current
  current="$(current_env_value "$key" "$ROOT_DIR/.env")"
  if is_placeholder "$current"; then
    replace_or_append_env "$key" "$($generator)" "$ROOT_DIR/.env"
    info "已生成 $key"
  fi
}

ensure_random_if_placeholder NEW_API_DB_PASSWORD 'random_alnum 24'
ensure_random_if_placeholder NEW_API_REDIS_PASSWORD 'random_alnum 24'
ensure_random_if_placeholder NEW_API_SESSION_SECRET 'random_alnum 48'
ensure_random_if_placeholder CASDOOR_CLIENT_SECRET 'random_alnum 48'
ensure_random_if_placeholder CASDOOR_ADMIN_PASSWORD 'random_alnum 24'
ensure_random_if_placeholder LIBRECHAT_MEILI_MASTER_KEY 'random_alnum 48'
ensure_random_if_placeholder LIBRECHAT_CREDS_KEY 'random_hex 64'
ensure_random_if_placeholder LIBRECHAT_CREDS_IV 'random_hex 32'
ensure_random_if_placeholder LIBRECHAT_JWT_SECRET 'random_hex 64'
ensure_random_if_placeholder LIBRECHAT_JWT_REFRESH_SECRET 'random_hex 64'
ensure_random_if_placeholder LIBRECHAT_OPENID_SESSION_SECRET 'random_alnum 48'
ensure_random_if_placeholder LIBRECHAT_ADMIN_PANEL_SESSION_SECRET 'random_alnum 48'

mkdir -p \
  "$ROOT_DIR/runtime/local/new-api/data" \
  "$ROOT_DIR/runtime/local/new-api/logs" \
  "$ROOT_DIR/runtime/local/new-api/postgres" \
  "$ROOT_DIR/runtime/local/new-api/redis" \
  "$ROOT_DIR/runtime/local/casdoor" \
  "$ROOT_DIR/runtime/local/casdoor/logs" \
  "$ROOT_DIR/runtime/local/librechat/images" \
  "$ROOT_DIR/runtime/local/librechat/uploads" \
  "$ROOT_DIR/runtime/local/librechat/logs" \
  "$ROOT_DIR/runtime/local/librechat/mongodb" \
  "$ROOT_DIR/runtime/local/librechat/meilisearch" \
  "$ROOT_DIR/backups"

sync_local_env_copy

if docker compose --env-file "$ROOT_DIR/.env" -f "$ROOT_DIR/deploy/docker-compose.local.yml" config >/dev/null; then
  info "compose 配置校验通过"
else
  die "compose 配置校验失败，请检查 .env"
fi

load_env
prepare_librechat_runtime_dirs
while IFS= read -r prefix; do
  api_key_var="${prefix}_API_KEY"
  if [[ "$(provider_is_enabled_env "$prefix")" == "true" ]] && is_placeholder "${!api_key_var:-}"; then
    warn "$api_key_var 仍是占位值，后续执行对应 smoke test 前需要填写真实值"
  fi
done < <(provider_prefixes)

info "初始化完成"
