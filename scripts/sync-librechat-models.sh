#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

require_cmd docker
require_cmd curl
[[ -f "$(env_file)" ]] || die "环境文件不存在: $(env_file)"

prepare_env_file
load_env
new_api_url="$(host_new_api_url)"
wait_for_http "${new_api_url}/api/status" 60 || die "NEW-API 尚未就绪，无法同步 LibreChat 模型列表"

bash "$ROOT_DIR/scripts/render-librechat-config.sh"
docker_compose restart librechat >/dev/null

info "LibreChat 模型列表已同步并重启生效"
