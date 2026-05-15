# DeepSeek 渠道接入

## 文档目标
本文档说明当前项目如何通过 `NEW-API` 接入 DeepSeek 官方模型矩阵、相关环境变量如何填写、自动 bootstrap 会做什么，以及 LibreChat 如何动态看到并使用 DeepSeek 模型。

## 当前接入方案
- 网关：`NEW-API`
- 上游类型：DeepSeek 官方 OpenAI 兼容 API
- 渠道类型：`1`
- 渠道名称：`deepseek-primary`
- Base URL：`https://api.deepseek.com`
- 运行策略：当 `DEEPSEEK_ENABLED=true` 时，由 `scripts/bootstrap-new-api.sh` 自动创建或更新 DeepSeek 渠道

## DeepSeek 官方模型矩阵

根据 DeepSeek 官方文档当前首页说明，OpenAI 兼容接入可用以下模型：

| 模型 ID | 说明 |
|---------|------|
| `deepseek-v4-flash` | 当前推荐默认模型 |
| `deepseek-v4-pro` | 更强能力版本 |
| `deepseek-chat` | 兼容保留模型名，官方标注将于 2026-07-24 弃用 |
| `deepseek-reasoner` | 兼容保留模型名，官方标注将于 2026-07-24 弃用 |

说明：
- 当前模板默认把这 4 个模型都暴露给 `NEW-API`。
- 若后续 DeepSeek 官方继续扩展模型矩阵，直接更新 `DEEPSEEK_EXPOSED_MODEL` 即可。

## 关键环境变量

```dotenv
DEEPSEEK_ENABLED=true
DEEPSEEK_API_KEY=__FILL_BY_USER__
DEEPSEEK_API_BASE_URL=https://api.deepseek.com
DEEPSEEK_DEFAULT_MODEL=deepseek-v4-flash
DEEPSEEK_TEST_MODEL=deepseek-v4-flash
DEEPSEEK_EXPOSED_MODEL=deepseek-v4-flash,deepseek-v4-pro,deepseek-chat,deepseek-reasoner
DEEPSEEK_CHANNEL_NAME=deepseek-primary
DEEPSEEK_CHANNEL_TYPE=1
DEEPSEEK_CHANNEL_GROUP=default
DEEPSEEK_CHANNEL_PRIORITY=10
DEEPSEEK_CHANNEL_WEIGHT=100
DEEPSEEK_MODEL_MAPPING_JSON='{}'
DEEPSEEK_CHANNEL_REMARK="Primary DeepSeek channel for acceptance"
```

补充建议：
- `NEW_API_SERVICE_TOKEN_UNLIMITED=true` — 服务 token 不再被项目内余额扣减限制
- `NEW_API_PROVIDER_CHANNEL_BALANCE=999999999999` — DeepSeek 渠道余额写成项目内不限额基准
- `NEW_API_RATE_LIMIT_ENABLED=false` — 本项目不再额外限制请求频率
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false` — 让 LibreChat 通过服务 token 直接看到 `NEW-API /v1/models` 的完整返回
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true` — 让 bootstrap 始终按 `.env` 回放 DeepSeek 模型矩阵
- `LIBRECHAT_FETCH_MODELS=true` — 让前端按 `NEW-API` 动态拉取可见模型
- 如果当前只想启用 DeepSeek，不再同时维护智谱，请显式设置 `ZHIPU_ENABLED=false`

## 为什么 Base URL 直接写根域名

DeepSeek 官方文档当前给出的 OpenAI 兼容 `base_url` 是：

```text
https://api.deepseek.com
```

当前仓库按这个地址直接写入 `NEW-API` 渠道配置，不额外手工拼 `/v1`。这样更贴近官方 SDK / OpenAI 兼容客户端的默认配置方式。

## bootstrap 会自动做什么

当 `DEEPSEEK_ENABLED=true` 且 `DEEPSEEK_API_KEY` 为真实值时，执行：

```bash
make bootstrap
```

或：

```bash
bash scripts/bootstrap-new-api.sh
```

bootstrap 会自动完成：
1. 登录 `NEW-API` 管理后台
2. 校正服务用户与服务 token
3. 查找 `deepseek-primary` 渠道
4. 若不存在，则创建 DeepSeek 渠道
5. 若已存在，则按 `.env` 回放：
   - `base_url`
   - `models`
   - `group`
   - `test_model`
   - `model_mapping`
   - `priority`
   - `weight`
   - `balance`
6. 将服务 token 设置为 unlimited，并关闭 token 模型白名单与项目内限流
7. 重新渲染 LibreChat 运行时配置并重启 LibreChat

## LibreChat 如何看到 DeepSeek 模型

当前仓库默认保持：
- `LIBRECHAT_FETCH_MODELS=true`
- `LIBRECHAT_VISIBLE_MODELS=` 留空

因此 LibreChat 不会在前端写死 DeepSeek 列表，而是通过：

```text
LibreChat -> NEW-API /v1/models -> 返回 deepseek-* 模型
```

当 `ZHIPU_ENABLED=true` 与 `DEEPSEEK_ENABLED=true` 同时开启时：
- `NEW-API /v1/models` 会返回两条渠道合并后的模型集合
- LibreChat 会直接看到两家供应商的模型
- 仍由同一个 `NEW_API_SERVICE_TOKEN` 完成鉴权

如果当前只想测试 DeepSeek，不再保留智谱主链路，请把：

```dotenv
ZHIPU_ENABLED=false
```

## 如何验证 DeepSeek 配置

### 方式一：检查模型列表
```bash
source .env
curl -fsS "$NEW_API_PUBLIC_URL/v1/models" \
  -H "Authorization: Bearer $NEW_API_SERVICE_TOKEN" | jq -r '.data[].id'
```

成功时应能看到：
- `deepseek-v4-flash`
- `deepseek-v4-pro`
- `deepseek-chat`
- `deepseek-reasoner`

### 方式二：执行 DeepSeek smoke
```bash
make smoke-deepseek
```

该脚本会：
1. 先跑 bootstrap
2. 检查 `NEW-API /v1/models` 中是否包含 `DEEPSEEK_EXPOSED_MODEL`
3. 用 `DEEPSEEK_TEST_MODEL` 发起一次真实 `chat/completions`

### 方式三：浏览器验证
1. 打开 LibreChat
2. 登录后查看模型列表
3. 选择任意 `deepseek-*` 模型发起对话
4. 确认能收到正常回复

## 常见错误与排查

### `NEW-API /v1/models` 中没有 DeepSeek 模型
优先检查：
- `DEEPSEEK_ENABLED=true`
- `DEEPSEEK_API_KEY` 不是占位值
- `DEEPSEEK_CHANNEL_GROUP=default`
- `make bootstrap` 是否已执行

### DeepSeek 聊天调用失败
优先检查：
- `DEEPSEEK_API_BASE_URL` 是否为 `https://api.deepseek.com`
- `DEEPSEEK_TEST_MODEL` 是否仍是官方支持的真实模型 ID
- `NEW-API` 日志中是否出现 `401`、`404`、`429`

### LibreChat 看不到 DeepSeek 模型
优先检查：
1. `GET /v1/models` 是否已经返回 `deepseek-*`
2. `LIBRECHAT_FETCH_MODELS=true`
3. 若配置了 `LIBRECHAT_VISIBLE_MODELS`，确认白名单中包含 DeepSeek 模型
4. 执行 `make sync-librechat-models`

## 与智谱并存时的建议
- 若两家都启用，优先保持模型名直通，不在 `model_mapping` 中做人为别名折叠
- 若只想前端展示 DeepSeek 子集，使用 `LIBRECHAT_VISIBLE_MODELS`
- 若后续将 DeepSeek 设为主模型，记得同步调整 `LIBRECHAT_TITLE_MODEL`
