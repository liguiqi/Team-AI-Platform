# 本地部署

## 文档目标
本文档用于指导管理员或验收人在本机从零启动整个平台，并理解每一步在做什么、完成后如何验证、出问题时该从哪里查。

## 本地部署适用范围
- 单台开发机、测试机、验收机。
- 使用 Docker Engine 与 Docker Compose v2。
- 目标是启动 `NEW-API + Casdoor + LibreChat + LibreChat Admin Panel + PostgreSQL + Redis + MongoDB`。

## 前置依赖
- Docker Engine 24+
- Docker Compose v2
- `bash`
- `curl`
- 建议安装 `jq`

建议先检查：
```bash
docker --version
docker compose version
curl --version
```

## 关键目录

### 仓库内重要目录
- `deploy/`：Compose 文件和模板配置。
- `scripts/`：初始化、启动、联调、运维脚本。
- `runtime/local/`：本地运行时数据目录。
- `backups/`：备份压缩包目录。

### 本地运行时目录说明
- `runtime/local/new-api/postgres`：`NEW-API` PostgreSQL 数据。
- `runtime/local/new-api/redis`：`NEW-API` Redis 数据。
- `runtime/local/new-api/data`：`NEW-API` 运行数据。
- `runtime/local/new-api/logs`：`NEW-API` 日志。
- `runtime/local/casdoor/app.conf`：Casdoor 运行时配置。
- `runtime/local/casdoor/init_data.json`：Casdoor 初始化数据。
- `runtime/local/casdoor/logs`：Casdoor 日志。
- `runtime/local/librechat/mongodb`：LibreChat MongoDB 数据。
- `runtime/local/librechat/uploads`：LibreChat 上传文件。
- `runtime/local/librechat/images`：LibreChat 图片资源。
- `runtime/local/librechat/logs`：LibreChat 日志。
- `runtime/local/librechat/librechat.yaml`：运行时渲染后的 LibreChat 配置。

## 环境文件准备

### 第一步：复制模板
```bash
cp .env.example .env
```

### 第二步：必须填写的变量
至少确认以下变量：

```dotenv
ZHIPU_API_KEY=你的真实智谱密钥
CASDOOR_EMAIL_SMTP_HOST=你的 SMTP 主机
CASDOOR_EMAIL_SMTP_USERNAME=你的 SMTP 账号
CASDOOR_EMAIL_SMTP_PASSWORD=你的 SMTP 密码
CASDOOR_SMS_ACCESS_KEY_ID=你的阿里云 AK
CASDOOR_SMS_ACCESS_KEY_SECRET=你的阿里云 SK
CASDOOR_SMS_SIGN_NAME=短信签名
CASDOOR_SMS_TEMPLATE_CODE=短信模板编号
```

同时确认：
- `CASDOOR_VERSION=2.396.1`
- 若使用 163 企业邮，推荐 `CASDOOR_EMAIL_SMTP_PORT=465`
- 若使用 163 企业邮，推荐 `CASDOOR_EMAIL_SSL_MODE=Enable`
- 若容器直连企业邮箱 SMTP 报连接重置，可启用 `LOCAL_SMTP_RELAY_ENABLED=true`

### 第三步：建议确认的变量
- `NEW_API_SETUP_USERNAME`
- `NEW_API_SETUP_PASSWORD`
- `NEW_API_SERVICE_USER`
- `NEW_API_SERVICE_PASSWORD`
- `CASDOOR_USER_ORGANIZATION_NAME`
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED`
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV`
- `LIBRECHAT_PORT`
- `LIBRECHAT_ADMIN_PANEL_PORT`
- `CASDOOR_PORT`
- `LIBRECHAT_FETCH_MODELS`
- `LIBRECHAT_VISIBLE_MODELS`
- `PLATFORM_THEME_MODE`
- `PLATFORM_THEME_LOCK`
- `PLATFORM_HIDE_THEME_SELECTOR`
- `BOOTSTRAP_AUTOCONFIGURE`
- `LIBRECHAT_MONGODB_LOCAL_PORT`
- `NEW_API_PORT`

说明：
- `NEW_API_SETUP_USERNAME` / `NEW_API_SETUP_PASSWORD` 决定 `NEW-API` 管理后台 root 登录账号。
- `NEW_API_SERVICE_TOKEN` 不需要手工填写，bootstrap 会自动生成并回写。
- `CASDOOR_ADMIN_PASSWORD` 与 `CASDOOR_CLIENT_SECRET` 在 `make init` 时会自动生成随机值。
- 当前仓库默认关闭 LibreChat 本地邮箱注册与登录，统一走 Casdoor OIDC。
- 当前仓库默认把注册用户放到独立业务组织 `CASDOOR_USER_ORGANIZATION_NAME`，不会放到 `built-in`。
- 本地模板默认 `LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP=true`，用于允许 `http://localhost` 下的 OIDC 调试。
- `make init` / `make up` 会把本地 `LIBRECHAT_PUBLIC_URL`、`NEW_API_PUBLIC_URL`、`CASDOOR_PUBLIC_URL` 从默认 `localhost` 自动迁移为宿主机 IP，避免容器内访问不到宿主机回调地址。
- 当前主配置建议保持：
  - `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
  - `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true`
  - `LIBRECHAT_FETCH_MODELS=true`
  - `LIBRECHAT_VISIBLE_MODELS=` 留空
  - `PLATFORM_THEME_MODE=system`
  - `PLATFORM_THEME_LOCK=false`
  - `PLATFORM_HIDE_THEME_SELECTOR=false`
  - `BOOTSTRAP_AUTOCONFIGURE=true`

## 初始化流程

### 执行命令
```bash
make init
```

### 这一步会做什么
- 若 `.env` 不存在，则从 `.env.example` 复制生成。
- 若仓库升级后 `.env` 缺少新变量，会自动按最新模板补齐缺失项。
- 若检测到旧版 LibreChat 直登开关组合，会自动迁移到 Casdoor OIDC 模式。
- 自动为数据库、Redis、Casdoor 客户端密钥、Casdoor 管理员密码、LibreChat JWT 等生成随机值。
- 创建 `runtime/local/` 所需目录。
- 同步一份 `deploy/env/local/.env` 供 compose 使用。
- 校验 `deploy/docker-compose.local.yml` 是否能被当前 `.env` 正确解析。

### 正常输出特征
- 提示若干个“已生成 XXX”。
- 最后看到“compose 配置校验通过”和“初始化完成”。

## 启动流程

### 执行命令
```bash
make up
```

### 这一步会做什么
- 先读取 `.env`
- 本地模式下先按需启动宿主机 SMTP relay
- 执行 `scripts/render-librechat-config.sh`
- 执行 `scripts/render-casdoor-config.sh`
- 生成 `runtime/local/librechat/librechat.yaml`
- 生成 `runtime/local/casdoor/app.conf` 与 `runtime/local/casdoor/init_data.json`
- 启动本地 compose 中的核心服务
- 当前会同时启动 `librechat-admin`
- 将 Casdoor 业务组织与应用配置同步到 PostgreSQL 持久化表
- 将 Casdoor 邮件与短信 Provider 同步到 PostgreSQL 持久化表
- LibreChat 会连接 `new-api-redis` 的 DB 1 持久化 OIDC state / session

### 正常启动后入口
- LibreChat：`http://localhost:3080`
- Admin Panel：`http://localhost:3001`
- NEW-API：`http://localhost:13000`
- Casdoor：`http://localhost:18000`

## 初始化网关配置

### 自动 Bootstrap（推荐）
当 `.env` 中 `BOOTSTRAP_AUTOCONFIGURE=true` 时，`make up` 会自动执行 bootstrap，无需手动操作。

### 手动 Bootstrap
如需单独执行：
```bash
bash scripts/bootstrap-new-api.sh
```

### bootstrap 实际行为
`scripts/bootstrap-new-api.sh` 会自动完成：

1. 等待 `NEW-API /api/status` 就绪
2. 若尚未初始化 root，则完成 root 初始化
3. 使用 root 账号登录后台
4. 写入系统配置（SelfUseMode、DemoSite）
5. 写入模型请求限流参数
6. 创建或校正服务用户 `NEW_API_SERVICE_USER`
7. 确保服务用户额度足够
8. 创建或校正智谱渠道（19 个模型）
9. 通过 PostgreSQL 创建或校正服务 token（48 字符强随机）
10. 把 `NEW_API_SERVICE_TOKEN` 回写 `.env`
11. 重新渲染 LibreChat 配置并重启 LibreChat

补充说明：
- 当前 LibreChat 使用 RedisStore 保存 OIDC state / session，重启后不会再因内存 session 丢失而要求重复登录。
- 若浏览器命中 LibreChat 重启前的旧 OIDC callback，运行时 patch 会自动回到 `/oauth/openid` 重新发起授权，而不是停留在错误页。

## 前端模型同步

### 执行命令
```bash
make sync-librechat-models
```

### 适用场景
- 你在 `NEW-API` 后台新增或移除了模型
- 你修改了 `.env` 中的 `LIBRECHAT_VISIBLE_MODELS`
- 你调整了服务 token 或前端模型同步策略

### 这一步会做什么
- 读取当前 `.env`
- 请求 `NEW-API /v1/models`
- 按 `LIBRECHAT_VISIBLE_MODELS` 决定是否做前端白名单过滤
- 重渲染 `runtime/local/librechat/librechat.yaml`
- 重启 LibreChat

## 主链路联调

### 执行命令
```bash
make smoke-zhipu
```

### 这一步会做什么
- 自动执行 bootstrap
- 请求 `NEW-API /v1/models`
- 检查返回中至少包含 `zhipu-primary`
- 发送一次最小 `chat/completions` 请求到智谱

### 成功标准
- 输出“智谱 smoke test 通过”
- 不出现 `401`、`404`、`429`、`insufficient_user_quota`

## 健康检查

### 执行命令
```bash
make health
```

### 检查内容
- `docker compose ps`
- `NEW-API /api/status`
- `Casdoor /.well-known/openid-configuration`
- `LibreChat /health`

### 成功标准
- 输出“应用层健康检查通过”

## 常见入口

### NEW-API 后台
- 地址：`http://localhost:13000`
- 登录账号：读取 `.env` 中的 `NEW_API_SETUP_USERNAME`
- 登录密码：读取 `.env` 中的 `NEW_API_SETUP_PASSWORD`

### Casdoor 统一认证后台
- 地址：`http://localhost:18000`
- 管理员账号：`built-in/admin`
- 管理员邮箱：读取 `.env` 中的 `CASDOOR_ADMIN_EMAIL`
- 管理员密码：读取 `.env` 中的 `CASDOOR_ADMIN_PASSWORD`

### LibreChat
- 地址：`http://localhost:3080`
- 默认只保留 `统一认证登录`
- 本地邮箱密码登录与注册已关闭
- 是否有用户能登录，取决于 Casdoor OIDC、SMTP 与短信 Provider 是否可用

## 常见问题与处理

### 端口被占用
现象：
- `make up` 失败
- 或 `make doctor` 提示 `13000` / `3080` / `18000` 已被占用

处理：
```bash
make doctor
ss -ltn | grep 13000
ss -ltn | grep 3080
ss -ltn | grep 18000
```

### PostgreSQL 起不来
现象：
- `new-api-postgres` 反复重启
- `NEW-API` 无法连接数据库

重点排查：
- `runtime/local/new-api/postgres` 是否由别的 PostgreSQL 主版本初始化
- `.env` 中 `POSTGRES_VERSION` 是否与数据目录版本匹配

### LibreChat 页面可打开但没有模型
现象：
- UI 空白，或没有显示你预期的模型集合

处理顺序：
1. `curl -fsS "$NEW_API_PUBLIC_URL/v1/models" -H "Authorization: Bearer $NEW_API_SERVICE_TOKEN" | jq -r '.data[].id'`
2. 确认 `.env` 中 `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
3. 若配置了 `LIBRECHAT_VISIBLE_MODELS`，确认目标模型确实包含在白名单中
4. 执行 `make sync-librechat-models`
5. 必要时再执行 `make bootstrap`
6. `docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f librechat`

### 统一认证按钮点击后失败，或重启后要求再次登录
重点检查：
- `curl http://localhost:18000/.well-known/openid-configuration`
- `runtime/local/casdoor/init_data.json` 中 `redirectUris` 是否包含 `http://localhost:3080/oauth/openid/callback`
- `.env` 中 `CASDOOR_PUBLIC_URL` 是否与本地入口一致
- `deploy/docker-compose.local.yml` 中 LibreChat 是否启用了 `USE_REDIS=true`
- `REDIS_URI` 是否指向 `new-api-redis:6379/1`，且 Redis DB 1 中能看到 `librechat:` 前缀 session key
- 若浏览器仍落到 `/oauth/error`，优先查看 LibreChat 日志中是否存在 `Unable to verify authorization request state`

### 收不到邮箱或短信验证码
重点检查：
- 先登录 Casdoor 后台单独测试 Provider，不要直接先查 LibreChat。
- 邮箱验证码失败：检查 `CASDOOR_EMAIL_SMTP_*`
- 若使用 163 企业邮，确认当前不是 `25 + Disable`，推荐 `465 + Enable`
- 修改 `.env` 后重新执行 `make up`，它会自动把 Provider 配置同步进 Casdoor 数据库
- 若容器直连 SMTP 仍然被服务端 reset，启用 `LOCAL_SMTP_RELAY_ENABLED=true`
- 短信验证码失败：检查 `CASDOOR_SMS_*`，并确认当前使用的是 `Alibaba Cloud PNVS SMS`

### 智谱返回 404
重点检查：
- `ZHIPU_API_BASE_URL` 必须是 `https://open.bigmodel.cn`
- 不要写成 `https://open.bigmodel.cn/api/paas/v4`

### 智谱返回额度不足
重点检查：
- 重新执行 `make bootstrap`
- 查看服务用户额度和服务 token 配额是否被消耗或改小

## 调试命令

### 查看容器状态
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml ps
```

### 查看 NEW-API 日志
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f new-api
```

### 查看 Casdoor 日志
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f casdoor
```

### 查看 LibreChat 日志
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f librechat
```

### 查看 PostgreSQL 日志
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f new-api-postgres
```

## 停止与重启

### 停止
```bash
make down
```

### 重启
```bash
make restart
```

说明：
- `make restart` 会执行 `down` 再 `up`，不会删除持久化目录。

## 推荐本地验收顺序
```bash
make init
make up
```

当 `BOOTSTRAP_AUTOCONFIGURE=true` 时，以上两步即完成全部部署。

若未启用自动 bootstrap，需额外执行：
```bash
make bootstrap
make health
make smoke-zhipu
```

## 搜索功能

### 已配置的搜索能力
- **Serper**：网络搜索，通过 `LIBRECHAT_SERPER_API_KEY` 配置
- **Firecrawl**：网页抓取，通过 `LIBRECHAT_FIRECRAWL_API_KEY` 配置
- **Jina**：语义重排序，通过 `LIBRECHAT_JINA_API_KEY` 配置

### 使用方式
用户在 LibreChat 对话中可启用搜索功能，由平台统一提供搜索能力。

## 内存限制

本地开发环境已配置容器内存限制：
- LibreChat: 512M
- MongoDB: 256M（WiredTiger 缓存 0.25GB）
- NEW-API: 128M
- PostgreSQL: 128M
- Casdoor: 128M
- Redis: 64M（LRU 淘汰策略）

## 开机自启动（可选）

如需开机自动启动服务：
```bash
bash scripts/install-service.sh
```

卸载：
```bash
bash scripts/uninstall-service.sh
```

## 建议配套阅读
如果你已经完成本地部署，下一步建议阅读：

1. [admin-new-api.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-new-api.md)
2. [admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-librechat.md)
3. [admin-auth-sso.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-auth-sso.md)
4. [runbook.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/runbook.md)
5. [acceptance-criteria.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/acceptance-criteria.md)

完成后再在浏览器中：
1. 打开 `http://localhost:3080`
2. 点击 `统一认证登录` 并跳转到 Casdoor
3. 选择 `NEW-API`
4. 在模型列表中选择任一智谱模型（共 19 个可用）
5. 发起真实对话
