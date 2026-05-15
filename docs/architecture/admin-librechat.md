# LibreChat 管理员使用与运维手册

## 文档目标
本文档面向 LibreChat 平台维护人，说明在本项目中 LibreChat 的职责边界、使用方式、管理员应关注的配置项、常见问题与容器侧运维动作。

## 先说结论
在本项目里，LibreChat 主要负责“最终用户界面”，不是网关治理中心。以下事项不应优先在 LibreChat 中解决，而应回到 `NEW-API`：

- 上游渠道配置
- 采购 API Key
- 模型映射
- 服务 token unlimited 状态与渠道余额
- 上游限流
- 供应商错误排查

如果问题是“用户看不到模型”“聊天请求失败”“模型换了要不要前端跟着改”，通常先查 `NEW-API`，再查 LibreChat。

## 平台入口

### 本地
- 地址：`http://localhost:3080`
- Admin Panel：`http://localhost:3001`

### 生产
- 地址：`https://$PUBLIC_CHAT_DOMAIN`
- Admin Panel：当前生产 compose 默认未启用

## 当前项目中的 LibreChat 角色

### 面向最终用户
- 提供聊天页面
- 通过 Casdoor 统一认证后承接会话历史与聊天能力
- 展示平台允许暴露的模型

### 面向平台维护人
- 验证前端是否成功接入 `NEW-API`
- 验证端点和模型是否可见
- 验证用户能否发起真实对话
- 处理用户侧页面故障、上传目录、日志和容器问题

## 当前与 Admin Panel 的关系

- 当前本地 compose 已内置 `librechat-admin` 容器，适合做角色和权限调整。
- LibreChat 主服务仍是聊天入口；Admin Panel 只是额外管理界面，不负责模型网关治理。
- 生产环境默认未启用 Admin Panel，因此生产故障排查仍以 LibreChat 主服务、MongoDB、Redis 和 Casdoor / NEW-API 链路为主。

## 本项目如何给 LibreChat 配置模型端点

### 模板文件
- [deploy/librechat/config/librechat.yaml](/home/lgq/repoWorkProject/TeamAIPlatform/deploy/librechat/config/librechat.yaml)

### 实际运行文件
- 本地：`runtime/local/librechat/librechat.yaml`
- 生产：`runtime/prod/librechat/librechat.yaml`

### 为什么要区分模板和运行文件
因为模板中含有：
- `NEW_API_SERVICE_TOKEN`
- `NEW_API_INTERNAL_URL`
- 各供应商的 `*_EXPOSED_MODEL`

这些变量不能直接以 `${...}` 占位符形式交给容器，否则 LibreChat 实际加载时会拿到字面字符串，而不是正确配置。

### 渲染脚本
- [scripts/render-librechat-config.sh](/home/lgq/repoWorkProject/TeamAIPlatform/scripts/render-librechat-config.sh)

### 什么时候会自动渲染
- `make up`
- `make bootstrap`

## 当前端点设计

### 端点名称
- `API-zhipu`
- `API-deepseek`
- `API-aliyun`

### 实际调用基址
- 容器内部：`http://new-api:3000/v1`

### 模型来源
- 默认情况下，`scripts/render-librechat-config.sh` 会按供应商分别读取 `*_EXPOSED_MODEL`。
- `API-zhipu` 只渲染 `ZHIPU_EXPOSED_MODEL`，`API-deepseek` 只渲染 `DEEPSEEK_EXPOSED_MODEL`，`API-aliyun` 只渲染 `ALIYUN_EXPOSED_MODEL`。
- 每个列表会按 `*_MODEL_ORDER` 做高阶优先排序。
- `scripts/sync-provider-models.sh` 会定期从供应商模型 API 更新 `*_EXPOSED_MODEL`，再回放 bootstrap。

### 模型显示标签
- `API-zhipu`
- `API-deepseek`
- `API-aliyun`

这意味着用户在 LibreChat 中不再看到混杂的 `NEW-API` 单入口，而是按供应商选择模型；底层仍由 `NEW-API` 统一鉴权、计量和转发。

## 管理员账号说明

### 本仓库的事实边界
- 本仓库自动化会创建 `NEW-API` 管理员与服务用户。
- 本仓库不会维护 LibreChat 本地管理员账号体系。

### 这意味着什么
- LibreChat 当前默认关闭本地邮箱登录与注册。
- 用户注册、登录、验证码发送统一由 Casdoor 处理。
- 平台维护人主要通过：
  - 浏览器访问 LibreChat
  - 浏览器访问 Casdoor
  - 容器日志
  - 渲染配置文件
  - MongoDB 持久化目录
  来做维护。

### 管理员视角建议
把 LibreChat 当作“前台入口 + 应用容器”，不要把它当作治理后台。

## 统一认证入口说明

### 当前策略
- LibreChat 登录页固定展示 `openid` 统一认证入口。
- `ALLOW_EMAIL_LOGIN=false`
- `ALLOW_REGISTRATION=false`
- `ALLOW_SOCIAL_LOGIN=true`

### 运维含义
- 若用户无法登录，不要先查 LibreChat 本地用户库。
- 应优先检查 Casdoor OIDC、SMTP、短信 Provider 与回调地址。
- 认证配置的详细说明见 [admin-auth-sso.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-auth-sso.md)
- 当前 compose 已为 LibreChat 开启 RedisStore（DB 1，`REDIS_KEY_PREFIX=librechat`），用于持久化 OIDC state / session。
- 若 LibreChat 重启后浏览器带回旧 callback，运行时 patch 会自动重发授权，正常情况下不应再要求用户做“第二次统一认证登录”。

## 管理员日常检查项

### 1. 页面可访问
浏览器打开：
```text
http://localhost:3080
```
或生产域名。

### 2. 健康接口正常
```bash
curl http://localhost:3080/health
```

返回应为：
```text
OK
```

### 3. 端点配置已生效
```bash
curl http://localhost:3080/api/endpoints
```

正常情况下应能看到：
- `API-zhipu`
- `API-deepseek`（启用 DeepSeek 时）
- `API-aliyun`（启用阿里云百炼时）

如需验证模型是否已同步，继续检查：
```bash
curl -fsS "$NEW_API_PUBLIC_URL/v1/models" \
  -H "Authorization: Bearer $NEW_API_SERVICE_TOKEN" | jq -r '.data[].id'
```

应返回当前已启用供应商渠道同步后的模型集合。

### 4. 配置文件已渲染为真实值
检查：
- `runtime/local/librechat/librechat.yaml`

确认其中不再是 `${NEW_API_SERVICE_TOKEN}` 这类占位符，而是实际值。

### 5. 搜索功能可用
在 LibreChat 对话中启用搜索，确认 Serper/Firecrawl/Jina 正常工作。

### 6. OIDC 会话已落到 Redis
可关注以下事实：
- LibreChat 容器环境中启用了 `USE_REDIS=true`
- `REDIS_URI` 指向 `new-api-redis:6379/1`
- 认证发起后，Redis DB 1 中可看到 `librechat:` 前缀的 session key

## 常见维护动作

### 场景 1：用户反馈没有模型可选
优先检查：
1. `runtime/local/librechat/librechat.yaml` 是否已渲染
2. `curl http://localhost:3080/api/endpoints`
3. `NEW-API /v1/models`
4. 确认 `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
5. LibreChat 日志
6. 必要时执行 `make bootstrap`

### 场景 2：服务 token 更新后前端仍报错
处理：
```bash
make bootstrap
```

原因：
- bootstrap 会重写 `.env` 中的 `NEW_API_SERVICE_TOKEN`
- 重新渲染 LibreChat 配置
- 自动重启 LibreChat

### 场景 3：页面能打开，但提问失败
先区分问题在前台还是网关：

前台检查：
- LibreChat `/health`
- LibreChat 日志
- `runtime/local/librechat/librechat.yaml`

网关检查：
- `make smoke-zhipu`
- `make smoke-deepseek`
- `make smoke-aliyun`
- `NEW-API /v1/models`
- `NEW-API /v1/chat/completions`

### 场景 4：想修改欢迎语、展示标签、是否允许注册
相关变量主要在 `.env`：
- `LIBRECHAT_ALLOW_EMAIL_LOGIN`
- `LIBRECHAT_ALLOW_REGISTRATION`
- `LIBRECHAT_ALLOW_SOCIAL_LOGIN`
- `LIBRECHAT_ALLOW_PASSWORD_RESET`
- `LIBRECHAT_MODEL_LABEL`
- `LIBRECHAT_FETCH_MODELS`

修改后建议执行：
```bash
make up
```
或至少重新渲染配置并重启 LibreChat。

补充说明：
- 当前项目默认不建议重新开启 LibreChat 本地邮箱登录。
- 若要改登录方式，应先从统一认证设计角度评估，而不是直接把本地登录开回去。

## 日志与排查

### 查看 LibreChat 日志
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f librechat
```

### 重点关注的日志现象
- 配置文件 YAML 解析失败
- `Custom config file loaded` 中仍出现 `${...}` 占位符
- 与 MongoDB 的连接异常
- 与 `NEW-API` 的连接异常

## MongoDB 相关说明

### 持久化目录
- `runtime/local/librechat/mongodb`

### 管理建议
- 不建议手工改动底层数据库文件
- 若需迁移或恢复，优先走备份恢复流程

### Chat2DB 本机连接方式
如果你在宿主机本机安装了 `Chat2DB`，推荐通过本地回环地址连接，不要把 MongoDB 暴露到公网。

本仓库本地 Compose 已按以下方式映射：
- `127.0.0.1:${LIBRECHAT_MONGODB_LOCAL_PORT}:27017`

建议在 `Chat2DB` 中填写：
- Database Type：`MongoDB`
- Host：`127.0.0.1`
- Port：读取 `.env` 中的 `LIBRECHAT_MONGODB_LOCAL_PORT`
- Database：`LibreChat`
- Authentication：`No Authentication`

如果本机 `27017` 已被其它 MongoDB 占用，可把 `.env` 中 `LIBRECHAT_MONGODB_LOCAL_PORT` 改成其它端口，例如 `27018`，然后重新执行 `make restart`。

## 上传和文件目录

### 上传目录
- `runtime/local/librechat/uploads`

### 图片目录
- `runtime/local/librechat/images`

### 运维建议
- 定期检查磁盘占用
- 若需要清理，请先确认是否会影响现有会话和上传引用

## 配置变更建议

### 标准变更流程
1. 改 `.env`
2. 重新渲染配置或执行 `make up`
3. 若涉及服务 token、NEW-API 模型矩阵或网关，执行 `make bootstrap`
4. 再执行 `make health`
5. 必要时从浏览器做一次真实发言验证

### 动态模型同步建议
- 推荐保持 `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
- 推荐保持 `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
- 推荐保持 `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true`
- 推荐执行 `make install-model-sync-cron`

这样做的效果是：
- LibreChat 按供应商拆分模型列表
- 服务 token 不再额外把模型收窄成单模型
- 上游模型 API 每日检测后会更新 `.env` 中的模型矩阵，再同步到 `NEW-API` 和 LibreChat

## 多模型动态同步运维说明

### 模式 1：按供应商拆分动态同步
适用场景：
- 希望 LibreChat 前端按 `API-zhipu` / `API-deepseek` / `API-aliyun` 分组展示当前供应商模型

推荐配置：
- `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
- `LIBRECHAT_VISIBLE_MODELS=` 保持为空
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true`

运维动作：
1. 执行 `make sync-provider-models`
2. 刷新 LibreChat 页面
3. 如需每日自动刷新，执行 `make install-model-sync-cron`

### 模式 2：前端白名单筛选
适用场景：
- `NEW-API` 后台允许更多模型
- 但 LibreChat 前端只想显示其中一部分

推荐配置示例：
```dotenv
LIBRECHAT_VISIBLE_MODELS=glm-4-flash,glm-4-plus,glm-5
```

当前实现策略：
- 渲染脚本会请求 `NEW-API /v1/models`
- 按 `LIBRECHAT_VISIBLE_MODELS` 与实际返回模型做交集过滤
- 把过滤后的列表写入 `runtime/local/librechat/librechat.yaml`
- 为了保证白名单生效，前端筛选模式下会自动使用静态渲染结果，不再直接展示 `NEW-API` 全量返回

执行步骤：
1. 修改 `.env` 中 `LIBRECHAT_VISIBLE_MODELS`
2. 执行：
   ```bash
   make sync-provider-models
   ```
3. 刷新 LibreChat 页面确认模型列表

### 推荐同步命令
当你完成以下任一变更后，建议执行：
- 调整了供应商模型 API、模型排序或可见模型规则
- 调整了 `LIBRECHAT_VISIBLE_MODELS`
- 调整了服务 token 或相关配置

命令：
```bash
make sync-provider-models
```

### 常见结论
- 没有配置 `LIBRECHAT_VISIBLE_MODELS`：前端按供应商端点分别显示同步后的模型
- 配置了 `LIBRECHAT_VISIBLE_MODELS`：前端只显示白名单与供应商同步模型的交集
- 白名单里写了一个 `NEW-API` 当前没有的模型：该模型会被自动跳过

### 不建议的做法
- 直接在容器内手工编辑 `/app/librechat.yaml`

原因：
- 容器重建后会丢失
- 与仓库脚本的标准渲染流程不一致

## LibreChat 在本项目中的边界总结

### 适合在 LibreChat 侧处理的问题
- 页面是否可访问
- 用户能否登录/注册
- 端点是否显示
- 模型是否显示
- 会话、上传和前端体验是否正常

### 不适合在 LibreChat 侧处理的问题
- 智谱 key 是否正确
- `zhipu-primary` 映射到哪个真实模型
- 服务 token 是否超额
- 上游返回的 `401/404/429`

这些都应优先回到 `NEW-API` 管理员手册和 runbook 排查。

## 推荐搭配阅读
1. [admin-new-api.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-new-api.md)
2. [deployment-local.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/deployment-local.md)
3. [runbook.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/runbook.md)
