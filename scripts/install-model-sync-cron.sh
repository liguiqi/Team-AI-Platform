#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd crontab

schedule="${PROVIDER_MODEL_SYNC_CRON:-17 4 * * *}"
tag="TeamAIPlatform provider model sync"
log_dir="$ROOT_DIR/runtime/${MODE}"
log_file="$log_dir/provider-model-sync.log"
entry="${schedule} cd ${ROOT_DIR} && MODE=${MODE} bash scripts/sync-provider-models.sh >> ${log_file} 2>&1 # ${tag}"

mkdir -p "$log_dir"

(
  crontab -l 2>/dev/null | grep -Fv "# ${tag}" || true
  printf '%s\n' "$entry"
) | crontab -

info "已安装每日供应商模型同步 cron: ${schedule}"
