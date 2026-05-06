#!/usr/bin/env bash
set -euo pipefail

# AI Gateway Chat - systemd 开机自启动安装脚本
# 用法: sudo bash scripts/install-service.sh [项目路径]
# 默认路径: /opt/TeamAIPlatform

PROJECT_DIR="${1:-/opt/TeamAIPlatform}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="ai-gateway-chat"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

[[ "$(id -u)" -ne 0 ]] && { echo "请使用 sudo 执行"; exit 1; }
[[ -d "$PROJECT_DIR" ]] || { echo "项目目录不存在: $PROJECT_DIR"; exit 1; }
[[ -f "${PROJECT_DIR}/Makefile" ]] || { echo "Makefile 不存在: ${PROJECT_DIR}/Makefile"; exit 1; }

echo "[1/4] 生成 systemd service 文件..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=AI Gateway Chat - NEW-API + LibreChat + Casdoor SSO
After=docker.service
Requires=docker.service
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${PROJECT_DIR}
ExecStart=/bin/bash -lc 'make up'
ExecStop=/bin/bash -lc 'make down'
ExecReload=/bin/bash -lc 'make restart'
TimeoutStartSec=300
TimeoutStopSec=120

[Install]
WantedBy=multi-user.target
EOF

echo "[2/4] 重载 systemd..."
systemctl daemon-reload

echo "[3/4] 启用开机自启动..."
systemctl enable "$SERVICE_NAME"

echo "[4/4] 启动服务..."
systemctl start "$SERVICE_NAME"

echo ""
echo "安装完成！"
echo "  项目目录: ${PROJECT_DIR}"
echo "  服务名称: ${SERVICE_NAME}"
echo ""
echo "常用命令:"
echo "  启动:   sudo systemctl start ${SERVICE_NAME}"
echo "  停止:   sudo systemctl stop ${SERVICE_NAME}"
echo "  重启:   sudo systemctl restart ${SERVICE_NAME}"
echo "  状态:   sudo systemctl status ${SERVICE_NAME}"
echo "  日志:   journalctl -u ${SERVICE_NAME} -f"
echo "  禁用:   sudo systemctl disable ${SERVICE_NAME}"
