# 架构说明

## 文档目的
本文档解释本项目的组件关系、调用链路、配置流转、持久化方案和安全边界。它回答的问题不是“怎么部署”，而是“为什么这样接”和“数据是如何流动的”。

## 总体架构

```text
最终用户浏览器
    ->
LibreChat Web / API
    ->
NEW-API OpenAI 兼容接口
    ->
智谱 ZhipuV4 / 其他未来上游
```

本项目的核心思想是：前端不直连上游，所有模型能力统一经过 `NEW-API` 进行治理，再由 LibreChat 提供最终用户体验。

## 组件清单与职责

### LibreChat
- 面向最终用户的聊天界面。
- 负责用户注册、登录、会话管理、对话历史展示、模型选择和消息发送。
- 不直接持有智谱采购密钥。
- 通过自定义 OpenAI 兼容端点调用 `NEW-API /v1/*`。
- 在当前方案中，模型列表由 `NEW-API /v1/models` 动态提供，而不是在前端静态写死。

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
- 对外暴露两个域名：
  - `PUBLIC_CHAT_DOMAIN` 对应 LibreChat
  - `NEW_API_ADMIN_DOMAIN` 对应 `NEW-API`
- 负责 TLS 证书申请和反向代理。

### 运行时渲染配置
- 仓库保留模板文件 [deploy/librechat/config/librechat.yaml](/home/lgq/repoWorkProject/TeamAIPlatform/deploy/librechat/config/librechat.yaml)。
- 实际运行时，脚本会把 `.env` 中的变量渲染为真实文件：
  - 本地：`runtime/local/librechat/librechat.yaml`
  - 生产：`runtime/prod/librechat/librechat.yaml`
- 这样可以避免容器内部读取到未替换的 `${...}` 占位符。

## 调用链路

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

## 持久化设计

### 本地
- `runtime/local/new-api/postgres`
- `runtime/local/new-api/redis`
- `runtime/local/new-api/data`
- `runtime/local/new-api/logs`
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
- 只与 LibreChat 交互

### LibreChat
- 只知道 `NEW_API_SERVICE_TOKEN`
- 不负责治理上游渠道

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
4. MongoDB
5. LibreChat

### 原因
- `NEW-API` 启动依赖 PostgreSQL 和 Redis。
- LibreChat 启动依赖 MongoDB 和已经可访问的 `NEW-API`。
- bootstrap 只能在 `NEW-API /api/status` 可用后执行。

## 关键工程结论
- 本项目的核心治理平面在 `NEW-API`，而不是 LibreChat。
- LibreChat 负责用户体验，`NEW-API` 负责安全边界与运维治理。
- 平台的稳定性高度依赖 PostgreSQL 数据目录一致性、服务 token 可用性以及 LibreChat 配置渲染正确。
