#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

[[ "$MODE" == "local" ]] || exit 0
[[ -f "$(env_file)" ]] || die "环境文件不存在: $(env_file)"
prepare_env_file
load_env

if [[ "$(normalize_bool "${LOCAL_SMTP_RELAY_ENABLED:-false}")" != "true" ]]; then
  exit 0
fi

require_cmd python3

relay_dir="$ROOT_DIR/runtime/local/smtp-relay"
pid_file="$relay_dir/relay.pid"
log_file="$relay_dir/relay.log"
mkdir -p "$relay_dir"

if [[ -f "$pid_file" ]]; then
  old_pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ -n "${old_pid:-}" ]] && kill -0 "$old_pid" 2>/dev/null; then
    info "本地 SMTP relay 已在运行 (pid=${old_pid})"
    exit 0
  fi
  rm -f "$pid_file"
fi

listen_host="${LOCAL_SMTP_RELAY_BIND_HOST:-0.0.0.0}"
listen_port="${LOCAL_SMTP_RELAY_PORT:-2525}"

LOCAL_SMTP_RELAY_REMOTE_HOST="${CASDOOR_EMAIL_SMTP_HOST}" \
LOCAL_SMTP_RELAY_REMOTE_PORT="${CASDOOR_EMAIL_SMTP_PORT:-465}" \
LOCAL_SMTP_RELAY_REMOTE_USER="${CASDOOR_EMAIL_SMTP_USERNAME}" \
LOCAL_SMTP_RELAY_REMOTE_PASSWORD="${CASDOOR_EMAIL_SMTP_PASSWORD}" \
LOCAL_SMTP_RELAY_REMOTE_SSL_MODE="${CASDOOR_EMAIL_SSL_MODE:-Enable}" \
setsid -f python3 -u "$ROOT_DIR/scripts/local_smtp_relay.py" \
  --listen-host "${listen_host}" \
  --listen-port "${listen_port}" \
  </dev/null >"$log_file" 2>&1

sleep 1

relay_pid="$(pgrep -f "local_smtp_relay.py --listen-host ${listen_host} --listen-port ${listen_port}" | head -n 1 || true)"
if ! kill -0 "$relay_pid" 2>/dev/null; then
  die "本地 SMTP relay 启动失败，请查看日志: $log_file"
fi

echo "$relay_pid" >"$pid_file"
info "本地 SMTP relay 已启动: ${listen_host}:${listen_port}"
