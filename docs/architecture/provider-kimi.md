# Kimi 渠道接入

## 文档目标
本文档说明当前项目如何通过 `NEW-API` 接入 Kimi 开放平台官方 OpenAI 兼容接口、相关环境变量如何填写、自动 bootstrap 会做什么，以及 LibreChat 如何动态看到并使用 Kimi 模型。

## 当前接入方案
- 网关：`NEW-API`
- 上游类型：Kimi / Moonshot OpenAI 兼容 API
- 渠道类型：`1`
- 渠道名称：`kimi-primary`
- NEW-API Base URL：`https://api.moonshot.cn`
- 模型列表 URL：`https://api.moonshot.cn/v1/models`
- 运行策略：当 `KIMI_ENABLED=true` 时，由 `scripts/bootstrap-new-api.sh` 自动创建或更新 Kimi 渠道

## 关键环境变量

```dotenv
KIMI_ENABLED=true
KIMI_API_KEY=__FILL_BY_USER__
KIMI_API_BASE_URL=https://api.moonshot.cn
KIMI_DEFAULT_MODEL=kimi-k2.6
KIMI_TEST_MODEL=kimi-k2.6
KIMI_EXPOSED_MODEL=kimi-k2.6,kimi-k2.5,kimi-k2-thinking-turbo,kimi-k2-thinking,kimi-k2-turbo-preview,kimi-k2-0905-preview,kimi-k2-0711-preview,moonshot-v1-128k,moonshot-v1-32k,moonshot-v1-8k
KIMI_CHANNEL_NAME=kimi-primary
KIMI_CHANNEL_TYPE=1
KIMI_CHANNEL_GROUP=default
KIMI_CHANNEL_PRIORITY=10
KIMI_CHANNEL_WEIGHT=100
KIMI_MODEL_MAPPING_JSON='{}'
KIMI_CHANNEL_REMARK="Primary Kimi channel for acceptance"
KIMI_LIBRECHAT_ENDPOINT_NAME=API-kimi
KIMI_MODEL_LABEL=API-kimi
KIMI_MODEL_ORDER=kimi-k2.6,kimi-k2.5,kimi-k2-thinking-turbo,kimi-k2-thinking,kimi-k2-turbo-preview,kimi-k2-0905-preview,kimi-k2-0711-preview,moonshot-v1-128k,moonshot-v1-32k,moonshot-v1-8k
KIMI_MODEL_LIST_URLS=https://api.moonshot.cn/v1/models
KIMI_MODEL_INCLUDE_REGEX='^(kimi-|moonshot-v1-)'
KIMI_MODEL_EXCLUDE_REGEX='(vision|embedding|rerank|tts|asr|audio|image|video)'
```

补充建议：
- `NEW_API_SERVICE_TOKEN_UNLIMITED=true` — 服务 token 不再被项目内余额扣减限制
- `NEW_API_PROVIDER_CHANNEL_BALANCE=999999999999` — Kimi 渠道余额写成项目内不限额基准
- `NEW_API_RATE_LIMIT_ENABLED=false` — 本项目不再额外限制请求频率
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false` — 让 LibreChat 通过服务 token 直接看到 `NEW-API /v1/models` 的完整返回
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true` — 让 bootstrap 始终按 `.env` 回放 Kimi 模型矩阵
- `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true` — 在 LibreChat 中以 `API-kimi` 独立分组展示

## 为什么 Base URL 不带 `/v1`

Kimi 官方 OpenAI 兼容 SDK Base URL 是：

```text
https://api.moonshot.cn/v1
```

当前仓库把 `NEW-API` 渠道 Base URL 写为：

```text
https://api.moonshot.cn
```

原因是 `NEW-API` 的 OpenAI 兼容渠道会自行拼接 `/v1/chat/completions`。模型列表检测不走 `NEW-API` 适配器，因此单独使用 `KIMI_MODEL_LIST_URLS=https://api.moonshot.cn/v1/models`。

## bootstrap 会自动做什么

当 `KIMI_ENABLED=true` 且 `KIMI_API_KEY` 为真实值时，执行：

```bash
make bootstrap
```

bootstrap 会自动完成：
1. 登录 `NEW-API` 管理后台
2. 校正服务用户与服务 token
3. 查找 `kimi-primary` 渠道
4. 若不存在，则创建 Kimi 渠道
5. 若已存在，则按 `.env` 回放 `base_url`、`models`、`group`、`test_model`、`model_mapping`、`priority`、`weight`、`balance`
6. 将服务 token 设置为 unlimited，并关闭 token 模型白名单与项目内限流
7. 重新渲染 LibreChat 运行时配置并重启 LibreChat

## LibreChat 如何看到 Kimi 模型

当前仓库默认保持：
- `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
- `LIBRECHAT_FETCH_MODELS=true`
- `LIBRECHAT_VISIBLE_MODELS=` 留空

因此 LibreChat 会渲染：

```text
LibreChat API-kimi -> NEW-API /v1/chat/completions -> kimi-primary
```

`API-kimi` 下只展示 `KIMI_EXPOSED_MODEL`，并按 `KIMI_MODEL_ORDER` 高阶优先排序。

## 如何验证 Kimi 配置

### 方式一：同步模型列表
```bash
make sync-provider-models
```

成功时会看到“Kimi 模型 API 检测完成”，并更新 `.env` 中的 `KIMI_EXPOSED_MODEL`。

### 方式二：执行 Kimi smoke
```bash
make smoke-kimi
```

该脚本会：
1. 先跑 bootstrap
2. 检查 `NEW-API /v1/models` 中是否包含 `KIMI_EXPOSED_MODEL`
3. 用 `KIMI_TEST_MODEL` 发起一次真实 `chat/completions`

### 方式三：浏览器验证
1. 打开 LibreChat
2. 登录后查看模型列表
3. 选择 `API-kimi` 下的 `kimi-*` 或 `moonshot-v1-*` 模型发起对话
4. 确认能收到正常回复

## 常见错误与排查

### `NEW-API /v1/models` 中没有 Kimi 模型
优先检查：
- `KIMI_ENABLED=true`
- `KIMI_API_KEY` 不是占位值
- `KIMI_CHANNEL_GROUP=default`
- `make bootstrap` 是否已执行

### Kimi 聊天调用失败
优先检查：
- `KIMI_API_BASE_URL` 是否为 `https://api.moonshot.cn`
- `KIMI_TEST_MODEL` 是否仍是官方支持的真实模型 ID
- `NEW-API` 日志中是否出现 `401`、`404`、`429`

### LibreChat 看不到 Kimi 入口
优先检查：
1. `runtime/local/librechat/librechat.yaml` 是否包含 `API-kimi`
2. `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
3. 若配置了 `LIBRECHAT_VISIBLE_MODELS`，确认白名单中包含 Kimi 模型
4. 执行 `make sync-provider-models`
