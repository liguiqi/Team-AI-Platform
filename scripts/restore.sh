#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

BACKUP_FILE="${BACKUP_FILE:-${1:-}}"
[[ -n "$BACKUP_FILE" ]] || die "请通过 BACKUP_FILE=/path/to/archive.tar.gz 或第一个参数指定备份文件"
[[ -f "$BACKUP_FILE" ]] || die "备份文件不存在: $BACKUP_FILE"

tar -xzf "$BACKUP_FILE" -C "$ROOT_DIR"
if [[ "$MODE" == "local" ]]; then
  sync_local_env_copy
fi
info "恢复完成: $BACKUP_FILE"

