# LibreChat Admin Panel 管理员手册

## 文档目标
本文档面向平台管理员，说明 LibreChat v0.8.5 对应的 Admin Panel（管理后台）在当前仓库中的实际部署状态、权限体系与日常运维操作。

## 概述

LibreChat Admin Panel 是一个**独立 Web 服务**（独立容器），提供图形化界面来管理 LibreChat 的用户、角色、权限和系统配置。当前仓库已经在本地 compose 中内置该服务，生产 compose 默认未启用；它始终通过 API 与 LibreChat 主服务交互。

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

## 当前部署方式

### 当前状态
- 本地 `deploy/docker-compose.local.yml` 已内置 `librechat-admin` 服务。
- 使用镜像：`ghcr.io/clickhouse/librechat-admin-panel:${LIBRECHAT_ADMIN_PANEL_VERSION:-latest}`。
- Admin Panel 通过 `VITE_API_BASE_URL=${LIBRECHAT_PUBLIC_URL}` 面向浏览器，通过 `API_SERVER_URL=http://librechat:3080` 访问 Docker 内部 LibreChat。
- 当前 `deploy/docker-compose.prod.yml` **没有**启用 Admin Panel；生产如需暴露，需要额外扩展 compose 和反向代理。

### 当前相关环境变量

| 变量 | 说明 |
|------|------|
| `LIBRECHAT_ADMIN_PANEL_VERSION` | Admin Panel 镜像版本，当前主配置为 `latest` |
| `LIBRECHAT_ADMIN_PANEL_PORT` | 本地映射端口，模板默认 `3002`；当前 main 本机部署为 `3003` |
| `LIBRECHAT_ADMIN_PANEL_SESSION_SECRET` | Admin Panel 自身的 Session Secret |
| `LIBRECHAT_PUBLIC_URL` | 浏览器访问 LibreChat 的公网/本机地址，Admin Panel 前端会复用它 |
| `LIBRECHAT_DEFAULT_ADMIN_ENABLED` | 是否自动创建 LibreChat 默认管理员 |
| `LIBRECHAT_DEFAULT_ADMIN_EMAIL` | 默认管理员登录邮箱，当前默认 `__PLACEHOLDER_EMAIL__` |
| `LIBRECHAT_DEFAULT_ADMIN_PASSWORD` | 默认管理员登录密码，当前默认 `__PLACEHOLDER_PASSWORD__` |
| `LIBRECHAT_DEFAULT_ADMIN_CASDOOR_ENABLED` | 是否把默认管理员同步到 Casdoor 业务组织 |
| `LIBRECHAT_FIRST_USER_ADMIN_ENABLED` | 是否把第一个非默认注册用户自动设置为 `ADMIN` |

### 启动方式

本地环境直接执行：

```bash
make up
```

如只想单独重建 Admin Panel：

```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml up -d librechat-admin
```

## 访问 Admin Panel

### 本地访问
- 地址：`http://localhost:3002`（端口取决于 `LIBRECHAT_ADMIN_PANEL_PORT` 配置；当前 main 本机为 `3003`）

### 生产访问
- 当前生产 compose 默认**没有**该入口。
- 如需上生产，建议单独规划子域名或内网入口，再扩展 compose / Caddy 配置。

### 登录方式

Admin Panel 支持两种登录方式：

#### 方式一：本地账号登录
- 使用 LibreChat 中 `role: 'ADMIN'` 的用户凭据
- 本项目会自动创建默认管理员：`__PLACEHOLDER_EMAIL__` / `__PLACEHOLDER_PASSWORD__`
- `make up` / `make bootstrap` 会同步校正该账号在 MongoDB 中的 `role: 'ADMIN'`

#### 方式二：SSO 登录
- Admin Panel 支持 OpenID Connect / SAML / OAuth 登录
- 可配置 `ADMIN_SSO_ONLY=true` 强制仅使用 SSO
- 本项目会把默认管理员同步到 Casdoor `team-ai` 业务组织，因此默认管理员也可以从统一认证入口登录
- 本项目还会把第一个非默认注册用户自动提升为 `ADMIN`，适合用 Casdoor 注册调试用户组管理功能

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

### 默认策略
本项目同时保留 Casdoor SSO 与一个本地默认管理员：

- `LIBRECHAT_ALLOW_EMAIL_LOGIN=true`
- `LIBRECHAT_ALLOW_REGISTRATION=false`
- `LIBRECHAT_ALLOW_SOCIAL_LOGIN=true`
- `LIBRECHAT_DEFAULT_ADMIN_ENABLED=true`
- `LIBRECHAT_DEFAULT_ADMIN_CASDOOR_ENABLED=true`
- `LIBRECHAT_FIRST_USER_ADMIN_ENABLED=true`

默认管理员会同时写入 LibreChat MongoDB 与 Casdoor `team-ai` 业务组织，可直接通过统一认证入口登录；如需绕过 Casdoor 使用本地登录，可访问：

```bash
http://localhost:3081/login?redirect=false
```

### 自动初始化

`make up` 与 `make bootstrap` 会自动执行：

```bash
scripts/bootstrap-librechat-admin.sh
```

该脚本会：
1. 等待 `ai-gateway-main-librechat-mongodb` 就绪
2. 使用 LibreChat 容器内的 `bcryptjs` 生成默认管理员密码哈希
3. 创建或更新默认本地 ADMIN 用户
4. 创建或更新 Casdoor `team-ai` 业务组织下的默认管理员用户
5. 将第一个非默认注册用户设置为 `ADMIN`
6. 补齐 `ADMIN` 角色的 `access:admin` system grant
7. 将 `USER` 角色的 `MARKETPLACE.USE` 与 `AGENTS.USE` 保持开启，确保普通用户可见智能体市场

也可以单独执行：

```bash
make bootstrap-librechat-admin
```

### 手动设置管理员
如果需要临时提升某个用户：

```bash
docker exec ai-gateway-main-librechat-mongodb mongosh --eval '
  db = db.getSiblingDB("LibreChat");
  db.users.updateOne(
    { email: "target@example.com" },
    { $set: { role: "ADMIN", updatedAt: new Date() } }
  );
'
```

验证：
```bash
docker exec ai-gateway-main-librechat-mongodb mongosh --eval '
  db = db.getSiblingDB("LibreChat");
  db.users.find({ role: "ADMIN" }, { name: 1, email: 1, provider: 1, role: 1 });
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
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f librechat-admin
```

### 常见问题

#### Admin Panel 打不开
1. 检查容器是否运行：`docker compose ps librechat-admin`
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

### 本地已启用
- `deploy/docker-compose.local.yml` 已内置 `librechat-admin`
- `.env.example` / 本地主配置已补齐 Admin Panel 相关变量
- 本地默认访问入口为 `http://localhost:3002`

### 生产仍需按需扩展
- 当前 `deploy/docker-compose.prod.yml` 未包含 Admin Panel 服务
- 如要在生产开放，需补充服务定义、反向代理入口和管理员访问控制

### 当前建议

1. 本地调试和角色配置优先使用当前已集成的 Admin Panel。
2. 若要生产启用，先在测试环境验证 `ADMIN` 角色、反向代理和访问控制，再复制到生产编排。

## 推荐联读
1. [admin-librechat.md](docs/architecture/admin-librechat.md) — LibreChat 主服务运维
2. [admin-new-api.md](docs/architecture/admin-new-api.md) — NEW-API 网关管理
3. [admin-auth-sso.md](docs/architecture/admin-auth-sso.md) — Casdoor 统一认证
4. [architecture.md](docs/architecture/architecture.md) — 整体架构
