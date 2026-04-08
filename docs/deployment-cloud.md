# 云端部署

## 文档目标
本文档用于指导在单台云服务器上部署本项目的生产版或准生产版环境。默认方案是 Docker Compose + Caddy，适用于中小规模内部平台，不包含多机高可用。

## 适用前提
- 单台 Linux 服务器。
- 拥有 root 或 sudo 权限。
- 可安装 Docker 与 Docker Compose。
- 拥有三个可解析到服务器公网 IP 的域名：
  - 面向用户：`PUBLIC_CHAT_DOMAIN`
  - 面向管理员：`NEW_API_ADMIN_DOMAIN`
  - 面向统一认证：`AUTH_PUBLIC_DOMAIN`

## 推荐目录规划

```text
/opt/ai-gateway-chat/
  ├─ repo/                       # 仓库代码
  ├─ deploy/env/prod/.env        # 生产环境变量
  ├─ runtime/prod/               # 生产运行数据
  └─ backups/                    # 备份文件
```

建议把仓库 clone 到 `/opt/ai-gateway-chat/repo`，然后在该目录执行所有命令。

## 生产前准备

### 系统准备
- 安装 Docker Engine
- 安装 Docker Compose v2
- 确认 `80`、`443`、`27017`、`5432` 等端口不会被外部直接暴露
- 配置服务器时区、磁盘空间和日志轮转策略

### DNS 准备
- `PUBLIC_CHAT_DOMAIN` 解析到服务器公网 IP
- `NEW_API_ADMIN_DOMAIN` 解析到服务器公网 IP
- `AUTH_PUBLIC_DOMAIN` 解析到服务器公网 IP

### 证书准备
- 本项目默认由 Caddy 自动申请 HTTPS 证书
- 必须正确填写 `ACME_EMAIL`
- 必须确保 80/443 端口公网可达

## 生产环境文件

### 创建生产 env
```bash
cp deploy/env/prod/.env.example deploy/env/prod/.env
```

### 必须重点填写的变量
- `PUBLIC_CHAT_DOMAIN`
- `NEW_API_ADMIN_DOMAIN`
- `ACME_EMAIL`
- `ZHIPU_API_KEY`
- `NEW_API_SETUP_USERNAME`
- `NEW_API_SETUP_PASSWORD`
- `NEW_API_SERVICE_PASSWORD`
- `CASDOOR_ADMIN_EMAIL`
- `CASDOOR_ADMIN_PASSWORD`
- `CASDOOR_CLIENT_SECRET`
- `CASDOOR_EMAIL_SMTP_HOST`
- `CASDOOR_EMAIL_SMTP_USERNAME`
- `CASDOOR_EMAIL_SMTP_PASSWORD`
- `CASDOOR_SMS_ACCESS_KEY_ID`
- `CASDOOR_SMS_ACCESS_KEY_SECRET`
- `CASDOOR_SMS_SIGN_NAME`
- `CASDOOR_SMS_TEMPLATE_CODE`
- `NEW_API_DB_PASSWORD`
- `NEW_API_REDIS_PASSWORD`
- `NEW_API_SESSION_SECRET`
- `LIBRECHAT_JWT_SECRET`
- `LIBRECHAT_JWT_REFRESH_SECRET`
- `LIBRECHAT_CREDS_KEY`
- `LIBRECHAT_CREDS_IV`
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED`
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV`
- `LIBRECHAT_FETCH_MODELS`
- `LIBRECHAT_VISIBLE_MODELS`

建议：
- 所有密码、secret、token 相关变量都使用高强度随机值。
- 生产 `.env` 不要使用示例值。
- 生产必须保持 `LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP=false`，不要为了省事把 HTTP 调试开关带到公网环境。
- 推荐默认保持：
  - `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
  - `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=false`
  - `LIBRECHAT_FETCH_MODELS=true`
  - `LIBRECHAT_VISIBLE_MODELS=` 留空

## 生产持久化目录

### NEW-API
- `runtime/prod/new-api/postgres`
- `runtime/prod/new-api/redis`
- `runtime/prod/new-api/data`
- `runtime/prod/new-api/logs`

### Casdoor
- `runtime/prod/casdoor/app.conf`
- `runtime/prod/casdoor/init_data.json`
- `runtime/prod/casdoor/logs`

### LibreChat
- `runtime/prod/librechat/mongodb`
- `runtime/prod/librechat/uploads`
- `runtime/prod/librechat/images`
- `runtime/prod/librechat/logs`
- `runtime/prod/librechat/librechat.yaml`

### Caddy
- `runtime/prod/caddy/data`
- `runtime/prod/caddy/config`

## 启动流程

### 第一步：启动基础服务
```bash
MODE=prod bash scripts/up.sh
```

这一步会：
- 读取 `deploy/env/prod/.env`
- 渲染 `runtime/prod/librechat/librechat.yaml`
- 渲染 `runtime/prod/casdoor/app.conf`
- 渲染 `runtime/prod/casdoor/init_data.json`
- 启动 Caddy、NEW-API、Casdoor、LibreChat、PostgreSQL、Redis、MongoDB

### 第二步：初始化 NEW-API
```bash
MODE=prod bash scripts/bootstrap-new-api.sh
```

这一步会：
- 初始化 root 管理员
- 配置限流
- 创建或校正服务用户
- 创建或校正智谱渠道
- 创建或校正服务 token
- 重渲染 LibreChat 配置并重启 LibreChat

### 第三步：真实联调
```bash
MODE=prod bash scripts/smoke-test-zhipu.sh
```

### 第四步：健康检查
```bash
MODE=prod bash scripts/healthcheck.sh
```

### 第五步：按需同步前端模型列表
当你后续在 `NEW-API` 后台维护了模型矩阵，或修改了生产 `.env` 中的 `LIBRECHAT_VISIBLE_MODELS` 时，执行：
```bash
MODE=prod bash scripts/sync-librechat-models.sh
```

## 对外入口

### 用户入口
- `https://$PUBLIC_CHAT_DOMAIN`

### NEW-API 管理后台
- `https://$NEW_API_ADMIN_DOMAIN`

### Casdoor 统一认证
- `https://$AUTH_PUBLIC_DOMAIN`

### 注意
- `NEW-API` 后台与 OpenAI 兼容 API 共用同一个服务实例。
- 若只允许内网或 VPN 管理，建议在 Caddy 之外再加防火墙白名单。

## 首次上线建议流程
1. 准备服务器与域名。
2. 填写生产 `.env`。
3. 执行 `MODE=prod bash scripts/up.sh`。
4. 检查容器状态。
5. 执行 `MODE=prod bash scripts/bootstrap-new-api.sh`。
6. 执行 `MODE=prod bash scripts/smoke-test-zhipu.sh`。
7. 浏览器验证 `PUBLIC_CHAT_DOMAIN`、`NEW_API_ADMIN_DOMAIN` 与 `AUTH_PUBLIC_DOMAIN`。
8. 记录本次上线的镜像版本、env 校验人和联调结果。

## 升级流程

### 推荐步骤
1. 备份当前环境：
   ```bash
   MODE=prod bash scripts/backup.sh
   ```
2. 拉取最新仓库代码。
3. 对比 `.env` 模板新增项。
4. 若有需要，补充新的 env 变量。
5. 执行：
   ```bash
   MODE=prod bash scripts/up.sh
   MODE=prod bash scripts/bootstrap-new-api.sh
   MODE=prod bash scripts/sync-librechat-models.sh
   MODE=prod bash scripts/healthcheck.sh
   ```

### 升级重点检查
- Compose 结构是否变更
- PostgreSQL 版本是否变化
- LibreChat 运行时配置路径是否变化
- Casdoor OIDC 与 SMTP/SMS Provider 是否仍按仓库配置回放
- `NEW-API` bootstrap 是否需要新配置项

## 回滚流程

### 适用场景
- 升级后健康检查失败
- 智谱主链路调用失败
- 管理后台可访问但实际聊天不可用

### 推荐步骤
1. 停止当前服务：
   ```bash
   MODE=prod bash scripts/down.sh
   ```
2. 切回旧代码版本。
3. 必要时恢复备份：
   ```bash
   MODE=prod BACKUP_FILE=/path/to/backup.tar.gz bash scripts/restore.sh
   ```
4. 重新执行：
   ```bash
   MODE=prod bash scripts/up.sh
   MODE=prod bash scripts/bootstrap-new-api.sh
   MODE=prod bash scripts/healthcheck.sh
   ```

## 生产安全建议
- 不要让生产 `.env` 进入 Git。
- 生产管理域名建议加 IP 白名单、VPN 或堡垒机限制。
- 定期轮换 `NEW_API_SERVICE_TOKEN`、管理员密码和上游采购密钥。
- 定期执行 `bash scripts/verify-no-secrets.sh` 检查已纳入 Git 的文件。
- 备份文件建议异机保存。

## 生产运维注意事项

### 关于备份一致性
当前 `scripts/backup.sh` 是目录级打包，不是数据库热备份系统。对于生产环境，建议：
- 至少在低峰期执行
- 更稳妥的做法是在 `down` 后或结合底层卷快照使用

### 关于日志
- `runtime/prod/new-api/logs`
- `runtime/prod/librechat/logs`
- `runtime/prod/casdoor/logs`

建议配合宿主机日志轮转与磁盘监控。

### 关于 LibreChat 配置
生产环境下 LibreChat 实际读取的是：
- `runtime/prod/librechat/librechat.yaml`

不要直接把模板文件当作运行配置修改；应优先改 `.env` 并重新执行渲染或 bootstrap。

### 关于模型同步
- 若你只是调整 `NEW-API` 后台模型矩阵，通常执行 `MODE=prod bash scripts/sync-librechat-models.sh` 即可。
- 若你同时调整了服务 token、渠道基础配置或 root 相关配置，仍应优先执行 `MODE=prod bash scripts/bootstrap-new-api.sh`。

## 建议配套阅读
生产部署完成后，建议继续阅读：

1. [admin-new-api.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/admin-new-api.md)
2. [admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/admin-librechat.md)
3. [admin-auth-sso.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/admin-auth-sso.md)
4. [runbook.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/runbook.md)
5. [acceptance-criteria.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/acceptance-criteria.md)
