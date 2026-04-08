#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"
require_cmd docker
[[ -f "$(env_file)" ]] || die "环境文件不存在: $(env_file)"
docker_compose down
docker_compose up -d
info "服务已重启"

