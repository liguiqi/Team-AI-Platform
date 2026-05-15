# 架构说明

## 文档目的
本文档解释本项目的组件关系、调用链路、配置流转、持久化方案和安全边界。它回答的问题不是“怎么部署”，而是“为什么这样接”和“数据是如何流动的”。

## 总体架构

```text
最终用户浏览器
    -> 统一认证
Casdoor OIDC / 邮箱 SMTP / 阿里云 PNVS SMS
    -> 登录回调
LibreChat Web / API
    -> 模型访问
NEW-API OpenAI 兼容接口
    -> 上游转发
智谱 ZhipuV4 / DeepSeek / 阿里云百炼 / 其他未来上游
```

本项目的核心思想是：认证与模型治理分层。用户身份由 `Casdoor` 统一负责，模型能力统一经过 `NEW-API` 治理，再由 LibreChat 提供最终用户体验。

## 组件清单与职责

### LibreChat
- 面向最终用户的聊天界面。
- 通过 Casdoor OIDC 承接统一认证结果。
- 负责会话管理、对话历史展示、模型选择和消息发送。
- 不直接持有智谱、DeepSeek、阿里云百炼等上游采购密钥。
- 通过自定义 OpenAI 兼容端点调用 `NEW-API /v1/*`。
- 在当前方案中，模型列表由 `NEW-API /v1/models` 动态提供，而不是在前端静态写死。
- 当前还把 OIDC state / session 持久化到 Redis，避免 LibreChat 重启后丢失认证上下文。

### LibreChat Admin Panel
- 当前仅在本地 compose 中启用的独立管理界面。
- 通过 LibreChat 的 `/api/admin/*` API 管理用户、角色、权限和配置。
- 生产 compose 默认未包含该服务，避免未规划入口时直接暴露。

### Casdoor
- 统一身份认证入口。
- 负责用户注册、密码登录、邮箱验证码登录、手机号验证码登录。
- 通过 SMTP Provider 发送邮件验证码。
- 通过阿里云 `PNVS SMS` Provider 发送短信验证码。
- 通过 OIDC 向 LibreChat 提供登录能力。
- 登录页样式由仓库脚本统一生成，并随浏览器 `light / dark` 主题自适应。
- 当前登录方式只保留 `Password` 与 `Verification code`。

### NEW-API
- 统一模型网关。
- 负责上游渠道配置、服务 token、模型映射、日志、额度、限流和审计。
- 负责把 LibreChat 的标准 OpenAI 请求转发到智谱、DeepSeek、阿里云百炼等真实上游。
- 管理员后台入口与 OpenAI 兼容 API 使用同一个服务实例。

### PostgreSQL
- 作为 `NEW-API` 的主数据库。
- 保存用户、渠道、token、日志、配置项等核心治理数据。
- 本项目的 bootstrap 脚本也会在必要时直接通过 PostgreSQL 维护服务 token，避免二次登录限流。

### Redis
- 作为 `NEW-API` 的缓存与部分运行态存储。
- DB 0 主要服务 `NEW-API` 的 token、用户、渠道查询与限流缓存。
- DB 1 由 LibreChat 使用，保存 OIDC state / session，`REDIS_KEY_PREFIX=librechat`。
- 因此 Redis 现在同时承担网关缓存和认证会话持久化两类职责。

### MongoDB
- 作为 LibreChat 的会话、用户、历史消息和上传信息存储。
- 与 `NEW-API` 的治理数据库分离，避免职责混淆。

### Caddy
- 仅在生产方案中启用。
- 对外暴露三个域名：
  - `PUBLIC_CHAT_DOMAIN` 对应 LibreChat
  - `NEW_API_ADMIN_DOMAIN` 对应 `NEW-API`
  - `AUTH_PUBLIC_DOMAIN` 对应 Casdoor
- 负责 TLS 证书申请和反向代理。

### 运行时渲染配置
- 仓库保留模板文件 [deploy/librechat/config/librechat.yaml](/home/lgq/repoWorkProject/TeamAIPlatform/deploy/librechat/config/librechat.yaml)。
- 实际运行时，脚本会把 `.env` 中的变量渲染为真实文件：
  - 本地：`runtime/local/librechat/librechat.yaml`
  - 生产：`runtime/prod/librechat/librechat.yaml`
- 这样可以避免容器内部读取到未替换的 `${...}` 占位符。

### 前端模型展示模式
- 默认模式：供应商拆分模式
  - `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
  - LibreChat 渲染 `API-zhipu` / `API-deepseek` / `API-aliyun`
  - 每个入口只展示对应供应商的 `*_EXPOSED_MODEL`
- 前端白名单模式
  - 设置 `LIBRECHAT_VISIBLE_MODELS`
  - 渲染脚本按白名单与供应商模型列表做交集过滤
  - 前端最终只显示指定模型子集

## 调用链路

### 认证链路
1. 用户访问 LibreChat 登录页。
2. LibreChat 仅展示 `openid` 统一认证入口。
3. 用户跳转到 Casdoor。
4. Casdoor 使用邮箱 SMTP 或阿里云 `PNVS SMS` 完成验证码发送。
5. Casdoor 登录成功后，通过 OIDC 回调 `LibreChat /oauth/openid/callback`。
6. LibreChat 从 RedisStore 中校验并恢复 OIDC state / session，随后建立自身会话。
7. 若浏览器带回的是 LibreChat 重启前已经失效的旧 callback，运行时 patch 会自动回到 `/oauth/openid` 重新发起授权。

### 主链路
1. 用户在 LibreChat 页面发起对话。
2. LibreChat 使用 `NEW_API_SERVICE_TOKEN` 请求 `NEW-API /v1/models`，动态获取当前可见模型列表。
3. 用户选择某个模型后，LibreChat 再调用 `NEW-API /v1/chat/completions`。
4. `NEW-API` 根据服务 token 的分组、模型限制和渠道配置做鉴权。
5. `NEW-API` 根据匹配到的渠道配置，把请求转发到智谱、DeepSeek、阿里云百炼等真实上游。
6. 上游返回响应后，`NEW-API` 做兼容格式转换并返回给 LibreChat。
7. LibreChat 将结果展示给用户。

### 管理链路
1. 管理员访问 `NEW-API` 后台。
2. 管理员使用 `NEW_API_SETUP_USERNAME` / `NEW_API_SETUP_PASSWORD` 登录。
3. 在后台查看渠道、token、日志、用户和系统配置。
4. 必要时通过 UI 或脚本进行限流、模型映射、渠道启停或密钥更换。
5. 本地如需管理 LibreChat 用户角色，可访问 `librechat-admin`。

## 模型策略

### 当前方案：直通模式
当前使用直通模式（passthrough），各供应商默认 `*_MODEL_MAPPING_JSON='{}'`，即 LibreChat 中展示的模型名与上游真实模型名一致。

### 已接入模型
- 智谱：由 `scripts/sync-provider-models.sh` 从智谱模型 API 动态刷新，当前本地同步结果为 `glm-5.1,glm-5,glm-5-turbo,glm-4.7,glm-4.6,glm-4.5-air,glm-4.5`。
- DeepSeek：由 `scripts/sync-provider-models.sh` 从 DeepSeek 模型 API 动态刷新，当前本地同步结果为 `deepseek-v4-pro,deepseek-v4-flash`。
- 阿里云百炼：由 `scripts/sync-provider-models.sh` 从百炼 OpenAI 兼容模型 API 动态刷新，LibreChat 展示为 `API-aliyun`。

### 好处
- 用户可以直接选择具体模型，精确控制使用哪个模型。
- 新模型上线时可通过 `make sync-provider-models` 自动刷新对应供应商的 `*_EXPOSED_MODEL`。
- `NEW-API` 的 `ZhipuV4` 适配器直接处理模型名匹配。

## 配置与密钥流转

### 上游密钥
- 变量名：`ZHIPU_API_KEY`、`DEEPSEEK_API_KEY`、`ALIYUN_API_KEY`
- 存放位置：本地 `.env` 或生产环境变量文件
- 使用位置：bootstrap 写入 `NEW-API` 渠道配置
- 不进入 Git

### 服务 token
- 变量名：`NEW_API_SERVICE_TOKEN`
- 作用：LibreChat 访问 `NEW-API` 的内部凭证
- 来源：`scripts/bootstrap-new-api.sh`
- 存放位置：写回 `.env`，随后用于渲染 LibreChat 运行时配置
- 推荐策略：默认关闭 token 自身的模型白名单，让 `NEW-API` 成为模型列表的唯一来源

### 管理员账号
- 变量名：`NEW_API_SETUP_USERNAME` / `NEW_API_SETUP_PASSWORD`
- 作用：登录 `NEW-API` 管理后台与执行 bootstrap
- 风险点：如果后台修改密码但 `.env` 未同步，后续 bootstrap 会失败

### 统一认证配置
- 变量名：`CASDOOR_CLIENT_ID` / `CASDOOR_CLIENT_SECRET`
- 作用：LibreChat 连接 Casdoor 的 OIDC 客户端凭据
- 存放位置：`.env` 或 `deploy/env/prod/.env`
- 配套变量：
  - `CASDOOR_EMAIL_*` 用于 SMTP 邮件验证码
  - `CASDOOR_SMS_*` 用于阿里云 `PNVS SMS`
  - `LIBRECHAT_OPENID_*` 用于 LibreChat OIDC 会话和按钮展示

## 持久化设计

### 本地
- `runtime/local/new-api/postgres`
- `runtime/local/new-api/redis`
- `runtime/local/new-api/data`
- `runtime/local/new-api/logs`
- `runtime/local/casdoor/app.conf`
- `runtime/local/casdoor/init_data.json`
- `runtime/local/casdoor/logs`
- `runtime/local/librechat/mongodb`
- `runtime/local/librechat/uploads`
- `runtime/local/librechat/images`
- `runtime/local/librechat/logs`
- `runtime/local/librechat/librechat.yaml`

### 生产
- 对应目录迁移到 `runtime/prod/...`
- 可进一步映射到独立磁盘、云盘或备份卷

## 安全边界

### 浏览器侧
- 不直接持有 `ZHIPU_API_KEY`、`DEEPSEEK_API_KEY`、`ALIYUN_API_KEY`
- 不直接持有短信或邮件服务密钥
- 只通过 LibreChat 和 Casdoor 页面交互

### Casdoor
- 持有 SMTP 和阿里云短信 Provider 配置
- 是用户真实身份认证的唯一入口
- 当前仓库默认会持续回放认证配置，因此不建议只在 UI 中手工改 Provider 后不回写环境变量

### LibreChat
- 只知道 `NEW_API_SERVICE_TOKEN`
- 只知道 Casdoor OIDC 客户端凭据
- 不负责治理上游渠道
- 默认关闭本地邮箱密码登录，避免绕过统一认证

### NEW-API
- 是唯一面向上游供应商的统一出口
- 持有渠道配置、服务 token、限流与日志

### 仓库侧
- `.env`、运行数据、备份包都不纳入 Git
- 文档与模板不应包含真实密钥

## 启动依赖顺序

### 本地推荐顺序
1. PostgreSQL
2. Redis
3. NEW-API
4. Casdoor
5. MongoDB
6. LibreChat
7. LibreChat Admin Panel（仅本地）

### 原因
- `NEW-API` 启动依赖 PostgreSQL 和 Redis。
- Casdoor 启动依赖 PostgreSQL，并在启动时回放认证初始化数据。
- LibreChat 启动依赖 MongoDB、Redis、Casdoor 和已经可访问的 `NEW-API`。
- Admin Panel 仅在本地启用，依赖 LibreChat 已启动。
- bootstrap 只能在 `NEW-API /api/status` 可用后执行。

## 搜索能力

LibreChat 集成了网络搜索与内容抓取能力：

### 搜索 Provider
- **Serper**：网页搜索，`LIBRECHAT_SERPER_API_KEY`
- **Firecrawl**：网页内容抓取，`LIBRECHAT_FIRECRAWL_API_KEY`
- **Jina**：重排序/语义搜索，`LIBRECHAT_JINA_API_KEY`

### 配置方式
所有搜索相关变量通过 `.env` 注入到 LibreChat 容器环境变量，由 LibreChat 原生支持。

## 资源限制

### 容器内存限制
| 容器 | 内存限制 |
|------|---------|
| LibreChat | 512M |
| MongoDB | 256M |
| NEW-API | 128M |
| PostgreSQL | 128M |
| Casdoor | 128M |
| Redis | 64M |
| Caddy（生产） | 64M |

### 数据库缓存优化
- MongoDB：`--wiredTigerCacheSizeGB=0.25`，适合 2C2G ECS
- Redis：`--maxmemory 32mb --maxmemory-policy allkeys-lru`

## 自动 Bootstrap
- 当 `BOOTSTRAP_AUTOCONFIGURE=true` 时，`make up` 会自动执行 bootstrap
- 完成 NEW-API 初始化、渠道创建、服务用户/token 管理
- 实现一键部署，无需手动操作

## systemd 开机自启动
- 提供 `deploy/systemd/ai-gateway-chat.service` 服务单元
- 安装脚本：`bash scripts/install-service.sh`
- 卸载脚本：`bash scripts/uninstall-service.sh`
- 适用于生产环境 VPS 开机自动拉起服务

## 关键工程结论
- 本项目的核心治理平面在 `NEW-API`，而不是 LibreChat。
- LibreChat 负责用户体验，`NEW-API` 负责安全边界与运维治理。
- 平台的稳定性高度依赖 PostgreSQL 数据目录一致性、服务 token 可用性以及 LibreChat 配置渲染正确。
- 自动 bootstrap 确保部署后立即可用，无需手动操作后台。
- 资源限制配置使平台可在 2C2G ECS 上稳定运行。
