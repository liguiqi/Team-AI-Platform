# 火山方舟豆包渠道接入

## 文档目标
本文档说明当前项目如何通过 `NEW-API` 接入火山方舟豆包、相关环境变量如何填写、自动 bootstrap 会做什么，以及 LibreChat 如何动态看到并使用豆包模型。

## 当前接入方案
- 网关：`NEW-API`
- 上游类型：火山方舟豆包
- 渠道类型：`45`（NEW-API v0.12.1 内置 VolcEngine 适配器）
- 渠道名称：`doubao-primary`
- NEW-API Base URL：`https://ark.cn-beijing.volces.com`
- 模型列表 URL：`https://ark.cn-beijing.volces.com/api/v3/models`
- 运行策略：当 `DOUBAO_ENABLED=true` 时，由 `scripts/bootstrap-new-api.sh` 自动创建或更新豆包渠道

## 关键环境变量

```dotenv
DOUBAO_ENABLED=true
DOUBAO_API_KEY=__FILL_BY_USER__
DOUBAO_API_BASE_URL=https://ark.cn-beijing.volces.com
DOUBAO_DEFAULT_MODEL=doubao-seed-1-6-250615
DOUBAO_TEST_MODEL=doubao-seed-1-6-250615
DOUBAO_EXPOSED_MODEL=doubao-seed-2-0-pro-260215,doubao-seed-2-0-lite-260428,doubao-seed-2-0-mini-260428,doubao-seed-1-8-251228,doubao-seed-1-6-251015,doubao-seed-1-6-250615,doubao-seed-1-6-flash-250828,doubao-1-5-pro-32k-250115,doubao-1-5-lite-32k-250115
DOUBAO_CHANNEL_NAME=doubao-primary
DOUBAO_CHANNEL_TYPE=45
DOUBAO_CHANNEL_GROUP=default
DOUBAO_CHANNEL_PRIORITY=10
DOUBAO_CHANNEL_WEIGHT=100
DOUBAO_MODEL_MAPPING_JSON='{}'
DOUBAO_CHANNEL_REMARK="Primary Volcengine Doubao channel for acceptance"
DOUBAO_LIBRECHAT_ENDPOINT_NAME=API-doubao
DOUBAO_MODEL_LABEL=API-doubao
DOUBAO_MODEL_ORDER=doubao-seed-2-0-pro-260215,doubao-seed-2-0-lite-260428,doubao-seed-2-0-mini-260428,doubao-seed-2-0-code-preview-260215,doubao-seed-1-8-251228,doubao-seed-1-6-251015,doubao-seed-1-6-250615,doubao-seed-1-6-flash-250828,doubao-seed-1-6-flash-250615,doubao-seed-code-preview-251028,doubao-smart-router-250928,doubao-1-5-pro-32k-250115,doubao-1-5-lite-32k-250115
DOUBAO_MODEL_LIST_URLS=https://ark.cn-beijing.volces.com/api/v3/models
DOUBAO_MODEL_INCLUDE_REGEX='^(doubao-(seed-[0-9]|seed-code|smart-router|1-5-(pro|lite))|ep-|bot-)'
DOUBAO_MODEL_EXCLUDE_REGEX='(embedding|vision|seedream|seedance|translation|character|3d|audio|image|video|tts|asr|t2i|i2v|seededit|ui-tars|seaweed)'
```

补充建议：
- `NEW_API_SERVICE_TOKEN_UNLIMITED=true` — 服务 token 不再被项目内余额扣减限制
- `NEW_API_PROVIDER_CHANNEL_BALANCE=999999999999` — 豆包渠道余额写成项目内不限额基准
- `NEW_API_RATE_LIMIT_ENABLED=false` — 本项目不再额外限制请求频率
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false` — 让 LibreChat 通过服务 token 直接看到 `NEW-API /v1/models` 的完整返回
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true` — 让 bootstrap 始终按 `.env` 回放豆包模型矩阵
- `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true` — 在 LibreChat 中以 `API-doubao` 独立分组展示

## 为什么 Base URL 不带 `/api/v3`

火山方舟官方 OpenAI 兼容调用地址是：

```text
https://ark.cn-beijing.volces.com/api/v3
```

当前仓库使用的是 NEW-API 的火山方舟原生适配器 `type=45`，渠道 Base URL 写为：

```text
https://ark.cn-beijing.volces.com
```

原因是该适配器会自行拼接 `/api/v3/chat/completions`。模型列表检测不走 NEW-API 适配器，因此单独使用 `DOUBAO_MODEL_LIST_URLS=https://ark.cn-beijing.volces.com/api/v3/models`。

## bootstrap 会自动做什么

当 `DOUBAO_ENABLED=true` 且 `DOUBAO_API_KEY` 为真实值时，执行：

```bash
make bootstrap
```

bootstrap 会自动完成：
1. 登录 `NEW-API` 管理后台
2. 校正服务用户与服务 token
3. 查找 `doubao-primary` 渠道
4. 若不存在，则创建豆包渠道
5. 若已存在，则按 `.env` 回放 `base_url`、`models`、`group`、`test_model`、`model_mapping`、`priority`、`weight`、`balance`
6. 将服务 token 设置为 unlimited，并关闭 token 模型白名单与项目内限流
7. 重新渲染 LibreChat 运行时配置并重启 LibreChat

## LibreChat 如何看到豆包模型

当前仓库默认保持：
- `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
- `LIBRECHAT_FETCH_MODELS=true`
- `LIBRECHAT_VISIBLE_MODELS=` 留空

因此 LibreChat 会渲染：

```text
LibreChat API-doubao -> NEW-API /v1/chat/completions -> doubao-primary
```

`API-doubao` 下只展示 `DOUBAO_EXPOSED_MODEL`，并按 `DOUBAO_MODEL_ORDER` 高阶优先排序。

## 如何验证豆包配置

### 方式一：同步模型列表
```bash
make sync-provider-models
```

成功时会看到“火山方舟豆包 模型 API 检测完成”，并更新 `.env` 中的 `DOUBAO_EXPOSED_MODEL`。

### 方式二：执行豆包 smoke
```bash
make smoke-doubao
```

该脚本会：
1. 先跑 bootstrap
2. 检查 `NEW-API /v1/models` 中是否包含 `DOUBAO_EXPOSED_MODEL`
3. 用 `DOUBAO_TEST_MODEL` 发起一次真实 `chat/completions`

## 火山方舟模型开通说明

火山方舟 API key 可以用于查询 `/api/v3/models`，但真实聊天调用还要求账号已在控制台开通对应模型服务，或创建了可调用的推理接入点。若 chat 返回类似“账号未开通该模型服务”的 `404`，说明项目配置已经到达上游，但火山方舟账号侧还需要开通模型或提供可调用的 `ep-*` 推理接入点。

如果使用推理接入点 ID：
- 将 `DOUBAO_EXPOSED_MODEL` 与 `DOUBAO_TEST_MODEL` 改为对应 `ep-*` 或控制台别名
- 保持 `DOUBAO_CHANNEL_TYPE=45`
- 重新执行 `make bootstrap` 或 `make sync-provider-models`

## 常见错误与排查

### `NEW-API /v1/models` 中没有豆包模型
优先检查：
- `DOUBAO_ENABLED=true`
- `DOUBAO_API_KEY` 不是占位值
- `DOUBAO_CHANNEL_GROUP=default`
- `make bootstrap` 是否已执行

### 豆包聊天调用失败
优先检查：
- `DOUBAO_CHANNEL_TYPE` 是否为 `45`
- `DOUBAO_API_BASE_URL` 是否为 `https://ark.cn-beijing.volces.com`
- `DOUBAO_TEST_MODEL` 是否为账号已开通的模型或有效推理接入点
- `NEW-API` 日志中是否出现 `401`、`404`、`429`

### LibreChat 看不到豆包入口
优先检查：
1. `runtime/local/librechat/librechat.yaml` 是否包含 `API-doubao`
2. `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
3. 若配置了 `LIBRECHAT_VISIBLE_MODELS`，确认白名单中包含豆包模型
4. 执行 `make sync-provider-models`
