# 小米 MiMo 渠道接入

## 文档目标
本文档说明当前项目如何通过 `NEW-API` 接入小米 MiMo 官方 OpenAI 兼容接口、相关环境变量如何填写、自动 bootstrap 会做什么，以及 LibreChat 如何动态看到并使用 MiMo 模型。

## 当前接入方案
- 网关：`NEW-API`
- 上游类型：小米 MiMo OpenAI 兼容 API
- 渠道类型：`1`
- 渠道名称：`mimo-primary`
- NEW-API Base URL：`https://api.xiaomimimo.com`
- 模型列表 URL：`https://api.xiaomimimo.com/v1/models`
- 运行策略：当 `MIMO_ENABLED=true` 时，由 `scripts/bootstrap-new-api.sh` 自动创建或更新 MiMo 渠道

## 关键环境变量

```dotenv
MIMO_ENABLED=true
MIMO_API_KEY=__FILL_BY_USER__
MIMO_API_BASE_URL=https://api.xiaomimimo.com
MIMO_DEFAULT_MODEL=mimo-v2.5-pro
MIMO_TEST_MODEL=mimo-v2.5-pro
MIMO_EXPOSED_MODEL=mimo-v2.5-pro,mimo-v2.5,mimo-v2-pro,mimo-v2-omni,mimo-v2-flash
MIMO_CHANNEL_NAME=mimo-primary
MIMO_CHANNEL_TYPE=1
MIMO_CHANNEL_GROUP=default
MIMO_CHANNEL_PRIORITY=10
MIMO_CHANNEL_WEIGHT=100
MIMO_MODEL_MAPPING_JSON='{}'
MIMO_CHANNEL_REMARK="Primary Xiaomi MiMo channel for acceptance"
MIMO_LIBRECHAT_ENDPOINT_NAME=API-mimo
MIMO_MODEL_LABEL=API-mimo
MIMO_MODEL_ORDER=mimo-v2.5-pro,mimo-v2.5,mimo-v2-pro,mimo-v2-omni,mimo-v2-flash
MIMO_MODEL_LIST_URLS=https://api.xiaomimimo.com/v1/models
MIMO_MODEL_INCLUDE_REGEX='^mimo-v'
MIMO_MODEL_EXCLUDE_REGEX='(tts|voiceclone|voicedesign|audio|speech)'
```

补充建议：
- `NEW_API_SERVICE_TOKEN_UNLIMITED=true` — 服务 token 不再被项目内余额扣减限制
- `NEW_API_PROVIDER_CHANNEL_BALANCE=999999999999` — MiMo 渠道余额写成项目内不限额基准
- `NEW_API_RATE_LIMIT_ENABLED=false` — 本项目不再额外限制请求频率
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false` — 让 LibreChat 通过服务 token 直接看到 `NEW-API /v1/models` 的完整返回
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true` — 让 bootstrap 始终按 `.env` 回放 MiMo 模型矩阵
- `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true` — 在 LibreChat 中以 `API-mimo` 独立分组展示

## 为什么 Base URL 不带 `/v1`

MiMo 官方 OpenAI 兼容 SDK Base URL 是：

```text
https://api.xiaomimimo.com/v1
```

当前仓库把 `NEW-API` 渠道 Base URL 写为：

```text
https://api.xiaomimimo.com
```

原因是 `NEW-API` 的 OpenAI 兼容渠道会自行拼接 `/v1/chat/completions`。模型列表检测不走 `NEW-API` 适配器，因此单独使用 `MIMO_MODEL_LIST_URLS=https://api.xiaomimimo.com/v1/models`。

## bootstrap 会自动做什么

当 `MIMO_ENABLED=true` 且 `MIMO_API_KEY` 为真实值时，执行：

```bash
make bootstrap
```

bootstrap 会自动完成：
1. 登录 `NEW-API` 管理后台
2. 校正服务用户与服务 token
3. 查找 `mimo-primary` 渠道
4. 若不存在，则创建 MiMo 渠道
5. 若已存在，则按 `.env` 回放 `base_url`、`models`、`group`、`test_model`、`model_mapping`、`priority`、`weight`、`balance`
6. 将服务 token 设置为 unlimited，并关闭 token 模型白名单与项目内限流
7. 重新渲染 LibreChat 运行时配置并重启 LibreChat

## LibreChat 如何看到 MiMo 模型

当前仓库默认保持：
- `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
- `LIBRECHAT_FETCH_MODELS=true`
- `LIBRECHAT_VISIBLE_MODELS=` 留空

因此 LibreChat 会渲染：

```text
LibreChat API-mimo -> NEW-API /v1/chat/completions -> mimo-primary
```

`API-mimo` 下只展示 `MIMO_EXPOSED_MODEL`，并按 `MIMO_MODEL_ORDER` 高阶优先排序。

## 如何验证 MiMo 配置

### 方式一：同步模型列表
```bash
make sync-provider-models
```

成功时会看到“小米 MiMo 模型 API 检测完成”，并更新 `.env` 中的 `MIMO_EXPOSED_MODEL`。

### 方式二：执行 MiMo smoke
```bash
make smoke-mimo
```

该脚本会：
1. 先跑 bootstrap
2. 检查 `NEW-API /v1/models` 中是否包含 `MIMO_EXPOSED_MODEL`
3. 用 `MIMO_TEST_MODEL` 发起一次真实 `chat/completions`

### 方式三：浏览器验证
1. 打开 LibreChat
2. 登录后查看模型列表
3. 选择 `API-mimo` 下的 `mimo-*` 模型发起对话
4. 确认能收到正常回复

## 常见错误与排查

### `NEW-API /v1/models` 中没有 MiMo 模型
优先检查：
- `MIMO_ENABLED=true`
- `MIMO_API_KEY` 不是占位值
- `MIMO_CHANNEL_GROUP=default`
- `make bootstrap` 是否已执行

### MiMo 聊天调用失败
优先检查：
- `MIMO_API_BASE_URL` 是否为 `https://api.xiaomimimo.com`
- `MIMO_CHANNEL_TYPE` 是否为 `1`
- `MIMO_TEST_MODEL` 是否仍是官方支持的真实模型 ID
- `NEW-API` 日志中是否出现 `401`、`404`、`429`

### LibreChat 看不到 MiMo 入口
优先检查：
1. `runtime/local/librechat/librechat.yaml` 是否包含 `API-mimo`
2. `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
3. 若配置了 `LIBRECHAT_VISIBLE_MODELS`，确认白名单中包含 MiMo 模型
4. 执行 `make sync-provider-models`
