#!/usr/bin/env bash
set -euo pipefail

# AI Gateway Chat - systemd 开机自启动卸载脚本

SERVICE_NAME="ai-gateway-chat"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

[[ "$(id -u)" -ne 0 ]] && { echo "请使用 sudo 执行"; exit 1; }

echo "[1/3] 停止并禁用服务..."
systemctl stop "$SERVICE_NAME" 2>/dev/null || true
systemctl disable "$SERVICE_NAME" 2>/dev/null || true

echo "[2/3] 删除 service 文件..."
rm -f "$SERVICE_FILE"

echo "[3/3] 重载 systemd..."
systemctl daemon-reload

echo "卸载完成。"
