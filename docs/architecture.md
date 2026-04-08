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
智谱 ZhipuV4 / 其他未来上游
```

本项目的核心思想是：认证与模型治理分层。用户身份由 `Casdoor` 统一负责，模型能力统一经过 `NEW-API` 治理，再由 LibreChat 提供最终用户体验。

## 组件清单与职责

### LibreChat
- 面向最终用户的聊天界面。
- 通过 Casdoor OIDC 承接统一认证结果。
- 负责会话管理、对话历史展示、模型选择和消息发送。
- 不直接持有智谱采购密钥。
- 通过自定义 OpenAI 兼容端点调用 `NEW-API /v1/*`。
- 在当前方案中，模型列表由 `NEW-API /v1/models` 动态提供，而不是在前端静态写死。

### Casdoor
- 统一身份认证入口。
- 负责用户注册、密码登录、邮箱验证码登录、手机号验证码登录。
- 通过 SMTP Provider 发送邮件验证码。
- 通过阿里云 `PNVS SMS` Provider 发送短信验证码。
- 通过 OIDC 向 LibreChat 提供登录能力。

### NEW-API
- 统一模型网关。
- 负责上游渠道配置、服务 token、模型映射、日志、额度、限流和审计。
- 负责把 LibreChat 的标准 OpenAI 请求转发到智谱等真实上游。
- 管理员后台入口与 OpenAI 兼容 API 使用同一个服务实例。

### PostgreSQL
- 作为 `NEW-API` 的主数据库。
- 保存用户、渠道、token、日志、配置项等核心治理数据。
- 本项目的 bootstrap 脚本也会在必要时直接通过 PostgreSQL 维护服务 token，避免二次登录限流。

### Redis
- 作为 `NEW-API` 的缓存与部分运行态存储。
- 用于加速 token、用户、渠道等查询。
- 也会影响限流、缓存一致性和部分运行时能力。

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
- 模式 A：动态同步模式
  - `LIBRECHAT_FETCH_MODELS=true`
  - `LIBRECHAT_VISIBLE_MODELS=` 留空
  - LibreChat 直接按 `NEW-API /v1/models` 展示当前授权模型
- 模式 B：前端白名单模式
  - 设置 `LIBRECHAT_VISIBLE_MODELS`
  - 渲染脚本先拉取 `NEW-API /v1/models`，再按白名单做交集过滤
  - 前端最终只显示指定模型子集

## 调用链路

### 认证链路
1. 用户访问 LibreChat 登录页。
2. LibreChat 仅展示 `openid` 统一认证入口。
3. 用户跳转到 Casdoor。
4. Casdoor 使用邮箱 SMTP 或阿里云 `PNVS SMS` 完成验证码发送。
5. Casdoor 登录成功后，通过 OIDC 回调 `LibreChat /oauth/openid/callback`。
6. LibreChat 建立自身会话，随后用户才能进入聊天界面。

### 主链路
1. 用户在 LibreChat 页面发起对话。
2. LibreChat 使用 `NEW_API_SERVICE_TOKEN` 请求 `NEW-API /v1/models`，动态获取当前可见模型列表。
3. 用户选择某个模型后，LibreChat 再调用 `NEW-API /v1/chat/completions`。
4. `NEW-API` 根据服务 token 的分组、模型限制和渠道配置做鉴权。
5. `NEW-API` 根据模型映射把外部暴露名解析为真实上游模型，例如 `zhipu-primary -> glm-4-flash`。
6. `NEW-API` 使用智谱渠道配置，把请求转发到智谱 `ZhipuV4` 接口。
7. 智谱返回响应，`NEW-API` 做兼容格式转换后返回给 LibreChat。
8. LibreChat 将结果展示给用户。

### 管理链路
1. 管理员访问 `NEW-API` 后台。
2. 管理员使用 `NEW_API_SETUP_USERNAME` / `NEW_API_SETUP_PASSWORD` 登录。
3. 在后台查看渠道、token、日志、用户和系统配置。
4. 必要时通过 UI 或脚本进行限流、模型映射、渠道启停或密钥更换。

## 模型命名策略

### 外部暴露名
- `zhipu-primary`

### 实际上游名
- `glm-4-flash`

### 映射方式
- `NEW-API` 渠道配置中的 `model_mapping` 字段实现别名映射。
- LibreChat 从 `NEW-API` 动态获取模型后，默认仍只展示平台批准暴露的别名，不直接展示真实上游模型名。

### 好处
- 前端只面向平台批准的模型名。
- 后续替换上游模型时，前端和终端用户无需改动。
- 平台可以逐步收敛不同供应商的模型命名方式。

## 配置与密钥流转

### 上游密钥
- 变量名：`ZHIPU_API_KEY`
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
- 不直接持有 `ZHIPU_API_KEY`
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

### 原因
- `NEW-API` 启动依赖 PostgreSQL 和 Redis。
- Casdoor 启动依赖 PostgreSQL，并在启动时回放认证初始化数据。
- LibreChat 启动依赖 MongoDB、Casdoor 和已经可访问的 `NEW-API`。
- bootstrap 只能在 `NEW-API /api/status` 可用后执行。

## 关键工程结论
- 本项目的核心治理平面在 `NEW-API`，而不是 LibreChat。
- LibreChat 负责用户体验，`NEW-API` 负责安全边界与运维治理。
- 平台的稳定性高度依赖 PostgreSQL 数据目录一致性、服务 token 可用性以及 LibreChat 配置渲染正确。
