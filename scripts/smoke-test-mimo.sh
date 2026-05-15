#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

bash "$ROOT_DIR/scripts/smoke-test-provider.sh" MIMO "小米 MiMo"
