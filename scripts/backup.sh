#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

load_env
mkdir -p "$ROOT_DIR/backups"

timestamp="$(date +%Y%m%d-%H%M%S)"
archive="$ROOT_DIR/backups/${MODE}-${timestamp}.tar.gz"

if [[ "$MODE" == "local" ]]; then
  tar -czf "$archive" \
    -C "$ROOT_DIR" \
    .env \
    deploy \
    runtime/local
else
  tar -czf "$archive" \
    -C "$ROOT_DIR" \
    deploy/env/prod/.env \
    deploy \
    runtime/prod
fi

info "备份完成: $archive"

