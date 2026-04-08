# 本地部署

## 文档目标
本文档用于指导管理员或验收人在本机从零启动整个平台，并理解每一步在做什么、完成后如何验证、出问题时该从哪里查。

## 本地部署适用范围
- 单台开发机、测试机、验收机。
- 使用 Docker Engine 与 Docker Compose v2。
- 目标是启动 `NEW-API + LibreChat + PostgreSQL + Redis + MongoDB`。

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
```

### 第三步：建议确认的变量
- `NEW_API_SETUP_USERNAME`
- `NEW_API_SETUP_PASSWORD`
- `NEW_API_SERVICE_USER`
- `NEW_API_SERVICE_PASSWORD`
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED`
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV`
- `LIBRECHAT_PORT`
- `LIBRECHAT_FETCH_MODELS`
- `LIBRECHAT_VISIBLE_MODELS`
- `LIBRECHAT_MONGODB_LOCAL_PORT`
- `NEW_API_PORT`

说明：
- `NEW_API_SETUP_USERNAME` / `NEW_API_SETUP_PASSWORD` 决定 `NEW-API` 管理后台 root 登录账号。
- `NEW_API_SERVICE_TOKEN` 不需要手工填写，bootstrap 会自动生成并回写。
- 推荐默认保持：
  - `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
  - `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=false`
  - `LIBRECHAT_FETCH_MODELS=true`
  - `LIBRECHAT_VISIBLE_MODELS=` 留空

## 初始化流程

### 执行命令
```bash
make init
```

### 这一步会做什么
- 若 `.env` 不存在，则从 `.env.example` 复制生成。
- 自动为数据库、Redis、LibreChat JWT 等生成随机值。
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
- 执行 `scripts/render-librechat-config.sh`
- 生成 `runtime/local/librechat/librechat.yaml`
- 启动本地 compose 中的核心服务

### 正常启动后入口
- LibreChat：`http://localhost:3080`
- NEW-API：`http://localhost:13000`

## 初始化网关配置

### 执行命令
```bash
make bootstrap
```

### bootstrap 实际行为
`scripts/bootstrap-new-api.sh` 会自动完成：

1. 检查 `NEW-API /api/status`
2. 若尚未初始化 root，则完成 root 初始化
3. 使用 root 账号登录后台
4. 写入模型请求限流参数
5. 创建或校正服务用户 `NEW_API_SERVICE_USER`
6. 确保服务用户额度足够
7. 创建或校正智谱渠道
8. 通过 PostgreSQL 创建或校正服务 token
9. 把 `NEW_API_SERVICE_TOKEN` 回写 `.env`
10. 重新渲染 LibreChat 配置并重启 LibreChat

### 为什么 bootstrap 后还要重启 LibreChat
因为 LibreChat 使用的是渲染后的 `runtime/local/librechat/librechat.yaml`。服务 token 一旦更新，必须重新渲染配置文件并重启容器，否则 UI 仍会使用旧 token。

### bootstrap 与模型矩阵的当前默认关系
- 默认不会把你在 `NEW-API` 后台维护的模型矩阵压回单模型。
- 默认不会给服务 token 强行加单模型白名单。
- 这使得 `NEW-API /v1/models` 可以直接作为 LibreChat 的模型源。

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
- `LibreChat /health`

### 成功标准
- 输出“应用层健康检查通过”

## 常见入口

### NEW-API 后台
- 地址：`http://localhost:13000`
- 登录账号：读取 `.env` 中的 `NEW_API_SETUP_USERNAME`
- 登录密码：读取 `.env` 中的 `NEW_API_SETUP_PASSWORD`

### LibreChat
- 地址：`http://localhost:3080`
- 默认允许邮箱登录和注册
- 是否有独立管理员角色由 LibreChat 自身用户体系决定，本仓库脚本不自动创建 LibreChat 管理员账号

## 常见问题与处理

### 端口被占用
现象：
- `make up` 失败
- 或 `make doctor` 提示 `13000` / `3080` 已被占用

处理：
```bash
make doctor
ss -ltn | grep 13000
ss -ltn | grep 3080
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
make health
make smoke-zhipu
```

## 建议配套阅读
如果你已经完成本地部署，下一步建议阅读：

1. [admin-new-api.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/admin-new-api.md)
2. [admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/admin-librechat.md)
3. [runbook.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/runbook.md)
4. [acceptance-criteria.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/acceptance-criteria.md)

完成后再在浏览器中：
1. 打开 `http://localhost:3080`
2. 注册或登录 LibreChat
3. 选择 `NEW-API`
4. 选择任一当前授权模型，建议先选 `zhipu-primary`
5. 发起真实对话
