# LibreChat Admin Panel 管理员手册

## 文档目标
本文档面向平台管理员，说明 LibreChat v0.8.5 引入的 Admin Panel（管理后台）的功能、部署方式、权限体系与日常运维操作。

## 概述

LibreChat Admin Panel 是一个**独立 Web 服务**（独立容器），提供图形化界面来管理 LibreChat 的用户、角色、权限和系统配置。它不嵌入在 LibreChat 主容器中，而是通过 API 与 LibreChat 交互。

### 核心能力

| 功能 | 说明 |
|------|------|
| 用户管理 | 查看、搜索、禁用、删除用户；修改用户角色 |
| 角色管理 | 内置 ADMIN / USER 角色；v0.8.5 支持自定义角色 |
| 权限矩阵 | 控制各角色可使用的功能（Agent、搜索、代码执行等） |
| 系统配置 | 通过 Config 管理界面修改 LibreChat 运行时配置 |
| 分级配置覆盖 | 可按用户、组、角色维度覆盖默认配置 |
| 系统授权 (System Grants) | 授予特定用户管理员能力（如 admin 访问、文件管理） |

## 架构位置

```
浏览器 ──> Admin Panel 容器 (独立服务)
                  │
                  │ API 调用 (/api/admin/*)
                  ▼
           LibreChat 主容器 ──> MongoDB
```

关键点：
- Admin Panel 与 LibreChat 共享同一个 MongoDB 实例
- Admin Panel 通过 LibreChat 的 `/api/admin/*` API 端点进行操作
- Admin Panel 有自己的 Session 管理，与 LibreChat 登录状态独立

## 部署方式

### Docker 环境变量

Admin Panel 容器需要以下环境变量：

| 变量 | 必填 | 说明 |
|------|------|------|
| `SESSION_SECRET` | 是 | Admin Panel 自身的会话密钥，至少 32 字符 |
| `VITE_API_BASE_URL` | 是 | 浏览器可访问的 LibreChat 地址（如 `http://__YOUR_SERVER_IP__:3080`） |
| `API_SERVER_URL` | 否 | 服务端调用 LibreChat 的地址（默认同 `VITE_API_BASE_URL`） |
| `PORT` | 否 | Admin Panel 监听端口，默认 `3000` |
| `ADMIN_SSO_ONLY` | 否 | 设为 `true` 则禁用本地账号登录，仅允许 SSO |
| `ADMIN_SESSION_IDLE_TIMEOUT_MS` | 否 | 会话空闲超时（毫秒） |

### .env 新增配置

在项目 `.env` 中添加以下配置：

```dotenv
# Admin Panel
ADMIN_PANEL_ENABLED=true
ADMIN_PANEL_VERSION=latest
ADMIN_PANEL_PORT=3001
ADMIN_PANEL_SESSION_SECRET=<32字符以上的随机字符串>
ADMIN_PANEL_VITE_API_BASE_URL=http://__YOUR_SERVER_IP__:3080
ADMIN_PANEL_API_SERVER_URL=http://librechat:3080
```

说明：
- `ADMIN_PANEL_VITE_API_BASE_URL`：浏览器访问 LibreChat 的地址，用于前端 API 调用
- `ADMIN_PANEL_API_SERVER_URL`：Docker 内部网络访问 LibreChat 的地址，用于服务端 API 调用

### Docker Compose 集成

在 `deploy/docker-compose.local.yml` 中添加 Admin Panel 服务：

```yaml
admin-panel:
  image: ghcr.io/librechat/admin-panel:${ADMIN_PANEL_VERSION:-latest}
  container_name: ${CONTAINER_NAME_PREFIX:-ai-gateway}-admin-panel
  restart: unless-stopped
  ports:
    - "${ADMIN_PANEL_PORT:-3001}:3000"
  environment:
    SESSION_SECRET: ${ADMIN_PANEL_SESSION_SECRET}
    VITE_API_BASE_URL: ${ADMIN_PANEL_VITE_API_BASE_URL}
    API_SERVER_URL: ${ADMIN_PANEL_API_SERVER_URL:-http://librechat:3080}
  extra_hosts:
    - "host.docker.internal:host-gateway"
  depends_on:
    librechat:
      condition: service_healthy
  networks:
    - default
  deploy:
    resources:
      limits:
        memory: 256M
```

注意：
- `extra_hosts` 在 Linux 上是必要的，否则容器无法解析 `host.docker.internal`
- Admin Panel 必须在 LibreChat 健康之后启动（`depends_on: condition: service_healthy`）
- 建议设置内存限制为 256M，Admin Panel 资源消耗不大

### 启动

```bash
# 在 .env 中配置好变量后
make up
```

或手动启动：
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml up -d admin-panel
```

## 访问 Admin Panel

### 本地访问
- 地址：`http://localhost:3001`（端口取决于 `ADMIN_PANEL_PORT` 配置）

### 生产访问
- 地址：`https://$PUBLIC_CHAT_DOMAIN/admin`（如果配置了反向代理）
- 或独立端口：`https://admin.example.com`

### 登录方式

Admin Panel 支持两种登录方式：

#### 方式一：本地账号登录
- 使用 LibreChat 中 `role: 'ADMIN'` 的用户凭据
- 首次注册的用户自动获得 ADMIN 角色
- 在本项目 Casdoor SSO 场景下，需通过 MongoDB 手动设置管理员角色（见下文）

#### 方式二：SSO 登录
- Admin Panel 支持 OpenID Connect / SAML / OAuth 登录
- 可配置 `ADMIN_SSO_ONLY=true` 强制仅使用 SSO

## 权限体系

### 三层访问控制

LibreChat v0.8.5 的权限体系分为三层：

#### 第一层：功能权限 (Feature Permissions)
控制角色可以使用哪些功能。

| 权限标识 | 功能 | 说明 |
|---------|------|------|
| `AGENTS` | 自定义 Agent | 创建和使用自定义 Agent |
| `PROMPTS` | 提示词管理 | 创建和管理提示词 |
| `MCP_SERVERS` | MCP 服务器 | 连接和使用 MCP 服务器 |
| `REMOTE_AGENTS` | 远程 Agent | 使用远程 Agent |
| `MEMORIES` | 记忆功能 | 使用对话记忆 |
| `BOOKMARKS` | 书签 | 保存和管理书签 |
| `MULTI_CONVO` | 多轮对话 | 在同一会话中切换模型 |
| `TEMPORARY_CHAT` | 临时对话 | 不保存历史的临时对话 |
| `RUN_CODE` | 代码执行 | 运行代码片段 |
| `WEB_SEARCH` | 网络搜索 | 使用 Serper/Firecrawl 搜索 |
| `FILE_SEARCH` | 文件搜索 | 在上传文件中搜索 |
| `FILE_CITATIONS` | 文件引用 | 引用上传文件内容 |
| `MARKETPLACE` | 市场 | 访问提示词/Agent 市场 |
| `PEOPLE_PICKER` | 人员选择器 | 在共享时选择其他用户 |

#### 第二层：资源 ACL (Resource Access Control)
控制特定用户/角色对特定资源的访问权限（如某个 Agent 只允许特定组使用）。

#### 第三层：系统授权 (System Grants)
授予特定用户管理能力。

| 授权 | 说明 |
|------|------|
| `access:admin` | 允许访问 Admin Panel |
| `access:files` | 允许管理所有用户文件 |
| `access:prompts` | 允许管理所有用户提示词 |

### 角色说明

| 角色 | 说明 |
|------|------|
| `ADMIN` | 系统管理员，可访问 Admin Panel，管理所有用户和配置 |
| `USER` | 普通用户，默认角色，权限由功能权限矩阵控制 |
| 自定义角色 | v0.8.5 支持，可自行定义权限组合 |

## 在本项目中设置管理员

### 前提
本项目使用 Casdoor SSO 统一认证，LibreChat 本地邮箱登录已关闭（`ALLOW_EMAIL_LOGIN=false`）。通过 Casdoor 注册的用户默认角色为 `USER`。

### 设置管理员

通过 MongoDB 将用户角色提升为 `ADMIN`：

```bash
# 方法一：通过 docker exec
docker exec ai-gateway-mongodb mongosh --eval '
  db = db.getSiblingDB("LibreChat");
  db.users.updateOne(
    { email: "target@example.com" },
    { $set: { role: "ADMIN" } }
  );
'
```

```bash
# 方法二：通过本地端口连接（需要 LIBRECHAT_MONGODB_LOCAL_PORT 映射）
mongosh "mongodb://127.0.0.1:27017/LibreChat" --eval '
  db.users.updateOne(
    { email: "target@example.com" },
    { $set: { role: "ADMIN" } }
  );
'
```

验证：
```bash
docker exec ai-gateway-mongodb mongosh --eval '
  db = db.getSiblingDB("LibreChat");
  db.users.find({ role: "ADMIN" }, { name: 1, email: 1, role: 1 });
'
```

## 日常运维操作

### 查看用户列表
1. 登录 Admin Panel
2. 进入「Users」页面
3. 可按角色、邮箱、注册时间筛选

### 修改用户角色
1. 在「Users」页面找到目标用户
2. 点击编辑
3. 修改角色（ADMIN / USER / 自定义角色）
4. 保存

### 调整功能权限
1. 进入「Permissions」或「Roles」页面
2. 选择目标角色
3. 开启或关闭具体功能权限
4. 保存后立即生效

### 管理系统配置
1. 进入「Config」页面
2. 可修改 LibreChat 运行时配置（如模型列表、搜索设置等）
3. 支持按用户/组/角色维度覆盖默认配置

### 禁用用户
1. 在「Users」页面找到目标用户
2. 点击禁用
3. 该用户将被锁定，无法登录

## 日志与排查

### 查看 Admin Panel 日志
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f admin-panel
```

### 常见问题

#### Admin Panel 打不开
1. 检查容器是否运行：`docker compose ps admin-panel`
2. 检查端口是否正确映射
3. 检查 `VITE_API_BASE_URL` 是否可从浏览器访问
4. 查看容器日志是否有报错

#### 登录后显示无权限
1. 确认用户在 MongoDB 中的 `role` 为 `ADMIN`
2. 或确认用户拥有 `access:admin` 系统授权
3. SSO 场景下，Casdoor 返回的用户信息需正确映射到 LibreChat 用户

#### Admin Panel 无法连接 LibreChat
1. 检查 `API_SERVER_URL` 是否正确（Docker 内部网络）
2. 检查 LibreChat 是否健康：`curl http://librechat:3080/health`
3. 确认两个容器在同一 Docker 网络中

#### 功能权限修改不生效
1. 用户需要重新登录 LibreChat
2. 清除浏览器缓存后重试
3. 检查是否有用户级别的配置覆盖

## 与 NEW-API 管理的关系

Admin Panel 与 NEW-API 后台是两个独立的管理界面：

| 管理范围 | Admin Panel | NEW-API 后台 |
|---------|-------------|-------------|
| 用户管理 | 是 | 否 |
| 角色权限 | 是 | 否 |
| 前端功能开关 | 是 | 否 |
| 模型渠道 | 否 | 是 |
| API Key / Token | 否 | 是 |
| 限流策略 | 否 | 是 |
| 调用日志 | 否 | 是 |

原则：
- 用户能否登录、能用哪些功能 → Admin Panel
- 模型调用、渠道管理、Token 配额 → NEW-API 后台

## 安全建议

1. Admin Panel 端口不要直接暴露到公网，应通过反向代理并启用 HTTPS
2. `SESSION_SECRET` 使用强随机字符串，至少 32 字符
3. 定期审查管理员列表，避免过多 ADMIN 角色
4. 生产环境建议启用 `ADMIN_SSO_ONLY=true`，统一走 Casdoor 认证
5. Admin Panel 访问日志应纳入审计

## 当前部署状态

### 已就绪
- LibreChat 已升级到 v0.8.5，支持 Admin Panel API
- MongoDB 可通过容器内或本地端口访问
- 网络搜索功能（Serper + Firecrawl + Jina）已配置

### 待部署（按需）
- Admin Panel 独立容器（需在 docker-compose 中添加服务）
- Admin Panel 环境变量（需在 .env 中添加）
- 管理员角色设置（需通过 MongoDB 授权首个管理员）

### 快速启用步骤

如需立即启用 Admin Panel：

1. 在 `.env` 中添加 Admin Panel 变量
2. 在 `deploy/docker-compose.local.yml` 中添加 Admin Panel 服务定义
3. 执行 `make up`
4. 通过 MongoDB 设置首个管理员用户
5. 访问 `http://localhost:3001` 登录

## 推荐联读
1. [admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-librechat.md) — LibreChat 主服务运维
2. [admin-new-api.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-new-api.md) — NEW-API 网关管理
3. [admin-auth-sso.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-auth-sso.md) — Casdoor 统一认证
4. [architecture.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/architecture.md) — 整体架构
