#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

[[ "$MODE" == "local" ]] || exit 0

relay_dir="$ROOT_DIR/runtime/local/smtp-relay"
pid_file="$relay_dir/relay.pid"

[[ -f "$pid_file" ]] || exit 0

relay_pid="$(cat "$pid_file" 2>/dev/null || true)"
if [[ -n "${relay_pid:-}" ]] && kill -0 "$relay_pid" 2>/dev/null; then
  kill "$relay_pid"
  for _ in $(seq 1 10); do
    if ! kill -0 "$relay_pid" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  if kill -0 "$relay_pid" 2>/dev/null; then
    kill -9 "$relay_pid" 2>/dev/null || true
  fi
  info "本地 SMTP relay 已停止"
fi

rm -f "$pid_file"
