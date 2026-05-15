#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/_common.sh"

bash "$ROOT_DIR/scripts/smoke-test-provider.sh" DOUBAO "火山方舟豆包"
