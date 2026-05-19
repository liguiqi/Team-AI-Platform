# 云端部署

## 文档目标
本文档用于指导在单台云服务器上部署本项目的生产版或准生产版环境。当前生产方案同时支持：
- **无域名直连模式**：直接开放 `3080 / 13000 / 18000` 给受控内网、堡垒机或安全组，适合 2C2G、少量成员使用的轻量场景。
- **域名代理模式**：通过 Caddy 提供域名 + HTTPS 入口，适合已有公网域名的场景。

## 适用前提
- 单台 Linux 服务器。
- 拥有 root 或 sudo 权限。
- 可安装 Docker 与 Docker Compose。
- 若使用域名代理模式，还需要三个可解析到服务器公网 IP 的域名：
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

### DNS 准备（仅域名代理模式需要）
- `PUBLIC_CHAT_DOMAIN` 解析到服务器公网 IP
- `NEW_API_ADMIN_DOMAIN` 解析到服务器公网 IP
- `AUTH_PUBLIC_DOMAIN` 解析到服务器公网 IP

### 证书准备（仅域名代理模式需要）
- 本项目默认由 Caddy 自动申请 HTTPS 证书
- 必须正确填写 `ACME_EMAIL`
- 必须确保 80/443 端口公网可达

## 生产环境文件

### 创建生产 env
```bash
cp deploy/env/prod/.env.example deploy/env/prod/.env
```

默认模板是 **域名代理模式**。如果你的 Aliyun VPS **不需要域名访问**，请至少把下面这些值改成直连模式：

```dotenv
COMPOSE_PROFILES=
PROD_BIND_ADDRESS=0.0.0.0
LIBRECHAT_PUBLIC_URL=http://SERVER_IP:3080
NEW_API_PUBLIC_URL=http://SERVER_IP:13000
CASDOOR_PUBLIC_URL=http://SERVER_IP:18000
LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP=true
```

说明：
- `COMPOSE_PROFILES=` 为空时，生产 compose **不会启动 Caddy**，从而省掉反向代理的内存占用和域名依赖。
- 直连模式下请务必依赖阿里云安全组、VPN、堡垒机或内网访问范围控制，不要把 HTTP 入口无保护地暴露到公网。
- 如果后续切回域名代理模式，恢复 `COMPOSE_PROFILES=domain-proxy`，并把三个公开 URL 改回 `https://...`，同时将 `LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP=false`。

### 必须重点填写的变量
- `PUBLIC_CHAT_DOMAIN`
- `NEW_API_ADMIN_DOMAIN`
- `ACME_EMAIL`
- `ZHIPU_API_KEY`
- `DEEPSEEK_API_KEY`（启用 DeepSeek 时）
- `ALIYUN_API_KEY`（启用阿里云百炼时）
- `KIMI_API_KEY`（启用 Kimi 时）
- `DOUBAO_API_KEY`（启用火山方舟豆包时）
- `MIMO_API_KEY`（启用小米 MiMo 时）
- `MINIMAX_API_KEY`（启用 MiniMax 时）
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

补充：
- 若使用**无域名直连模式**，`PUBLIC_CHAT_DOMAIN / NEW_API_ADMIN_DOMAIN / AUTH_PUBLIC_DOMAIN / ACME_EMAIL` 可以暂时保留示例值，因为 Caddy profile 不会启动。
- 若使用**域名代理模式**，则这些变量都必须填写真实值，并保持 `COMPOSE_PROFILES=domain-proxy`。

建议：
- 所有密码、secret、token 相关变量都使用高强度随机值。
- 生产 `.env` 不要使用示例值。
- 生产必须保持 `LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP=false`，不要为了省事把 HTTP 调试开关带到公网环境。
- 推荐默认保持：
  - `NEW_API_SERVICE_TOKEN_UNLIMITED=true`
  - `NEW_API_PROVIDER_CHANNEL_BALANCE=999999999999`
  - `NEW_API_RATE_LIMIT_ENABLED=false`
  - `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
  - `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true`
  - `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
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
- 启动 NEW-API、Casdoor、LibreChat、PostgreSQL、Redis、MongoDB
- 当 `COMPOSE_PROFILES=domain-proxy` 时，再额外启动 Caddy
- 创建或校正 LibreChat 默认管理员，并将第一个非默认注册用户自动提升为 `ADMIN`
- 将 Casdoor 业务组织 / 应用 / Provider 配置回放到 PostgreSQL 持久化表
- 让 LibreChat 接入 `new-api-redis` 的 DB 1，用于 OIDC state / session 持久化
- 当前生产 compose **不包含** Admin Panel 服务
- 启动前会自动把 `runtime/prod/librechat/images`、`uploads`、`logs` 校正为 LibreChat `node` 用户对应的 `1000:1000`，避免 OIDC 新用户首次登录时因为头像目录不可写而报 `An unknown error occurred.`

### 第二步：初始化 NEW-API
```bash
MODE=prod bash scripts/bootstrap-new-api.sh
```

这一步会：
- 初始化 root 管理员
- 配置限流
- 创建或校正服务用户
- 创建或校正智谱渠道
- 创建或校正 DeepSeek / 阿里云百炼 / Kimi / 火山方舟豆包 / 小米 MiMo / MiniMax 渠道（启用时）
- 创建或校正服务 token
- 重渲染 LibreChat 配置并重启 LibreChat
- 创建或校正 LibreChat 默认管理员

### 第三步：真实联调
```bash
MODE=prod bash scripts/smoke-test-zhipu.sh
```

如已启用 DeepSeek、阿里云百炼、Kimi、火山方舟豆包、小米 MiMo 或 MiniMax，可继续执行：
```bash
MODE=prod bash scripts/smoke-test-deepseek.sh
MODE=prod bash scripts/smoke-test-aliyun.sh
MODE=prod bash scripts/smoke-test-kimi.sh
MODE=prod bash scripts/smoke-test-doubao.sh
MODE=prod bash scripts/smoke-test-mimo.sh
MODE=prod bash scripts/smoke-test-minimax.sh
```

### 第四步：健康检查
```bash
MODE=prod bash scripts/healthcheck.sh
```

### 第五步：按需同步前端模型列表
当你后续在 `NEW-API` 后台维护了模型矩阵，或修改了生产 `.env` 中的 `LIBRECHAT_VISIBLE_MODELS` 时，执行：
```bash
MODE=prod bash scripts/sync-provider-models.sh
```

## 对外入口

### 无域名直连模式
- LibreChat：`http://SERVER_IP:3080`
- NEW-API：`http://SERVER_IP:13000`
- Casdoor：`http://SERVER_IP:18000`

### 域名代理模式
- 前提：`COMPOSE_PROFILES=domain-proxy`

#### 用户入口
- `https://$PUBLIC_CHAT_DOMAIN`

#### NEW-API 管理后台
- `https://$NEW_API_ADMIN_DOMAIN`

#### Casdoor 统一认证
- `https://$AUTH_PUBLIC_DOMAIN`

### 注意
- `NEW-API` 后台与 OpenAI 兼容 API 共用同一个服务实例。
- 无域名直连模式下，建议直接使用阿里云安全组把 `3080 / 13000 / 18000` 限制在固定办公 IP、VPN 或堡垒机访问范围内。
- 域名代理模式下，建议把后端端口绑定到 `127.0.0.1`，并在 Caddy 之外再加防火墙白名单。
- 如需生产启用 Admin Panel，需要额外扩展 `deploy/docker-compose.prod.yml` 与 Caddy 路由；当前仓库默认未开放。

## 首次上线建议流程
1. 准备服务器；若采用域名代理模式，再准备域名和 80/443 入口。
2. 填写生产 `.env`（默认保持 `BOOTSTRAP_AUTOCONFIGURE=false`；如需首次一键上线再临时改为 `true`）。
3. 执行 `MODE=prod bash scripts/up.sh`。
4. 检查容器状态。
5. 若未启用自动 bootstrap，执行 `MODE=prod bash scripts/bootstrap-new-api.sh`。
6. 浏览器验证当前所选入口模式：
   - 直连模式：`SERVER_IP:3080 / 13000 / 18000`
   - 域名代理模式：`PUBLIC_CHAT_DOMAIN / NEW_API_ADMIN_DOMAIN / AUTH_PUBLIC_DOMAIN`
7. 记录本次上线的镜像版本、env 校验人和联调结果。

## 生产环境内存优化

### 容器内存限制
当前主配置按 **2C2G、实际约 1.6GB 可用内存、同时在线不超过 4 人** 做了进一步收敛：
- LibreChat: 384M（Node old space 默认限制 320MB，`MALLOC_ARENA_MAX=2`）
- MongoDB: 320M（WiredTiger 缓存 0.25GB，MongoDB 8 当前不支持再往下调）
- NEW-API: 96M（同时施加 `GOMEMLIMIT=64MiB`）
- PostgreSQL: 96M（共享缓存下调到 32MB，连接数压到 50）
- Casdoor: 96M（同时施加 `GOMEMLIMIT=72MiB`）
- Redis: 48M（AOF 保留，内存上限收敛到 24MB）
- Caddy: 32M（仅在 `domain-proxy` profile 启用时占用）

推荐保持以下生产 env 默认值：
- `LIBRECHAT_NODE_MAX_OLD_SPACE_SIZE_MB=320`
- `LIBRECHAT_MEMORY_LIMIT=384M`
- `LIBRECHAT_MONGODB_MEMORY_LIMIT=320M`
- `LIBRECHAT_MONGODB_WIREDTIGER_CACHE_GB=0.25`
- `NEW_API_MEMORY_LIMIT=96M`
- `NEW_API_POSTGRES_MEMORY_LIMIT=96M`
- `NEW_API_REDIS_MEMORY_LIMIT=48M`
- `CASDOOR_MEMORY_LIMIT=96M`
- `CADDY_MEMORY_LIMIT=32M`

### 为什么当前参考内存表里会出现 Admin Panel
如果你之前在服务器上看到 `Admin Panel 104/256M`，通常说明运行的不是当前仓库默认的生产 compose，而是：
- 使用了 `local` compose
- 或自己额外扩展了 Admin Panel 服务

当前仓库默认的 `deploy/docker-compose.prod.yml` **不包含** Admin Panel，这本身就是 2C2G 优化的一部分。

### 搜索功能配置
生产环境需配置搜索 API Key：
- `LIBRECHAT_SERPER_API_KEY`：Serper 网络搜索
- `LIBRECHAT_FIRECRAWL_API_KEY`：Firecrawl 网页抓取
- `LIBRECHAT_JINA_API_KEY`：Jina 语义重排序

## 生产环境开机自启动

安装 systemd 服务：
```bash
bash scripts/install-service.sh
```

卸载：
```bash
bash scripts/uninstall-service.sh
```

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

### 关于头像目录权限与 OIDC 首次登录失败
如果你此前在生产环境遇到：
- Casdoor 认证成功后回到 LibreChat 报 `An unknown error occurred.`
- 新注册用户无法自动跳转到聊天页

根因通常是宿主机上的 `runtime/prod/librechat/images` 由 `root` 创建，而 LibreChat 容器实际以 `node(1000:1000)` 运行，首次创建头像目录时没有写权限。

当前仓库已经在 `up / restart / bootstrap-new-api` 前自动修复：
- `runtime/prod/librechat/images`
- `runtime/prod/librechat/uploads`
- `runtime/prod/librechat/logs`

默认会把它们校正为 `1000:1000`；如果你自定义了 LibreChat 镜像用户，可在 `.env` 中改：
- `LIBRECHAT_RUNTIME_UID`
- `LIBRECHAT_RUNTIME_GID`

### 关于模型同步
- 若你只是调整 `NEW-API` 后台模型矩阵，通常执行 `MODE=prod bash scripts/sync-librechat-models.sh` 即可。
- 若你同时调整了服务 token、渠道基础配置或 root 相关配置，仍应优先执行 `MODE=prod bash scripts/bootstrap-new-api.sh`。

## 建议配套阅读
生产部署完成后，建议继续阅读：

1. [admin-new-api.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-new-api.md)
2. [admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-librechat.md)
3. [admin-auth-sso.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-auth-sso.md)
4. [runbook.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/runbook.md)
5. [acceptance-criteria.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/acceptance-criteria.md)
