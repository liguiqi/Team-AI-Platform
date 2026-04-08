# 智谱渠道接入

## 文档目标
本文档专门解释本项目如何通过 `NEW-API` 接入智谱、为什么采用当前字段组合、脚本如何自动化处理，以及出现问题时应该怎样排查。

## 当前接入方案
- 网关：`NEW-API`
- 上游类型：原生 `ZhipuV4`
- 渠道类型：`26`
- 默认真实模型：`glm-4-flash`
- 前端暴露模型别名：`zhipu-primary`

## 为什么使用 ZhipuV4
- `NEW-API` 已内建智谱原生适配器，能够直接走兼容路由。
- 适配器对智谱返回结构、计费字段和缓存字段有原生处理逻辑。
- 不需要额外自研代理层或定制转换逻辑。

## 模型命名设计

### 外部暴露名
```text
zhipu-primary
```

### 实际上游模型
```text
glm-4-flash
```

### 映射关系
```text
zhipu-primary -> glm-4-flash
```

### 这样设计的原因
- 让 LibreChat 只展示平台批准暴露的模型名。
- 后续如果上游从 `glm-4-flash` 切到别的智谱模型，只需改网关映射。
- 平台管理员可以在不影响终端用户的前提下完成模型切换。

## 关键环境变量

```dotenv
ZHIPU_ENABLED=true
ZHIPU_API_KEY=__FILL_BY_USER__
ZHIPU_API_BASE_URL=https://open.bigmodel.cn
ZHIPU_DEFAULT_MODEL=glm-4-flash
ZHIPU_TEST_MODEL=glm-4-flash
ZHIPU_EXPOSED_MODEL=zhipu-primary
ZHIPU_CHANNEL_NAME=zhipu-primary
ZHIPU_CHANNEL_TYPE=26
ZHIPU_CHANNEL_GROUP=default
ZHIPU_CHANNEL_PRIORITY=10
ZHIPU_CHANNEL_WEIGHT=100
ZHIPU_MODEL_MAPPING_JSON={"zhipu-primary":"glm-4-flash"}
```

补充建议：
- 如果你希望 LibreChat 动态同步 `NEW-API` 当前维护的多模型矩阵，推荐同时保持：
  - `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
  - `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=false`
  - `LIBRECHAT_FETCH_MODELS=true`

## 最容易写错的字段

### `ZHIPU_API_BASE_URL`
必须写：
```text
https://open.bigmodel.cn
```

不要写：
```text
https://open.bigmodel.cn/api/paas/v4
```

原因：
- `NEW-API` 的 `ZhipuV4` 渠道适配器会自动补上 `/api/paas/v4`
- 如果你手工也写完整路径，最终请求会变成双重路径，返回 `404 Not Found`

### `ZHIPU_TEST_MODEL`
应填写真实上游模型名，例如：
```text
glm-4-flash
```

而不是填写暴露名 `zhipu-primary`。

原因：
- 渠道测试和部分后台能力需要真实模型名
- 暴露名和真实名混用时，容易出现“模型可见但路由失败”的问题

## 仓库中与智谱相关的落地文件
- 渠道模板：[deploy/new-api/config/channel-zhipu-v4.template.json](/home/lgq/repoWorkProject/TeamAIPlatform/deploy/new-api/config/channel-zhipu-v4.template.json)
- 服务 token 模板：[deploy/new-api/config/service-token.template.json](/home/lgq/repoWorkProject/TeamAIPlatform/deploy/new-api/config/service-token.template.json)
- 限流模板：[deploy/new-api/config/options-rate-limit.template.json](/home/lgq/repoWorkProject/TeamAIPlatform/deploy/new-api/config/options-rate-limit.template.json)
- bootstrap 脚本：[scripts/bootstrap-new-api.sh](/home/lgq/repoWorkProject/TeamAIPlatform/scripts/bootstrap-new-api.sh)
- smoke 脚本：[scripts/smoke-test-zhipu.sh](/home/lgq/repoWorkProject/TeamAIPlatform/scripts/smoke-test-zhipu.sh)

## bootstrap 如何处理智谱渠道
`make bootstrap` 或 `make smoke-zhipu` 会触发以下动作：

1. 登录 `NEW-API` root 管理后台。
2. 检查服务用户是否存在。
3. 检查服务用户额度是否满足平台需要。
4. 查询名为 `zhipu-primary` 的渠道是否已存在。
5. 若不存在，则创建渠道。
6. 若已存在，则按 `.env` 中的配置做校正：
   - `base_url`
   - `models`
   - `group`
   - `test_model`
   - `model_mapping`
   - `priority`
   - `weight`
   - `remark`
7. 将渠道状态强制设为启用。

## 如何验证智谱链路

### 方式一：脚本验证
```bash
make smoke-zhipu
```

### 方式二：手工检查模型列表
```bash
source .env
curl -fsS "$NEW_API_PUBLIC_URL/v1/models" \
  -H "Authorization: Bearer $NEW_API_SERVICE_TOKEN"
```

成功时应能看到：
- `zhipu-primary`

### 方式三：手工发送聊天请求
```bash
source .env
payload=$(sed "s/__MODEL__/${ZHIPU_EXPOSED_MODEL}/g" tests/smoke/chat-completions.template.json)
curl -fsS "$NEW_API_PUBLIC_URL/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $NEW_API_SERVICE_TOKEN" \
  -d "$payload"
```

成功特征：
- 返回 `choices`
- HTTP 状态码为 `200`
- 实际响应 `model` 多数情况下为真实上游模型名 `glm-4-flash`

## 常见错误与排查

### `401 Unauthorized`
可能原因：
- `ZHIPU_API_KEY` 无效
- 智谱 key 已过期或被禁用

排查建议：
- 先确认 `.env` 中是否填了真实 key
- 再确认是否重新执行过 bootstrap

### `404 Not Found`
最常见原因：
- `ZHIPU_API_BASE_URL` 写成了完整 `/api/paas/v4` 路径，导致重复拼接

### `model_not_found`
可能原因：
- `ZHIPU_EXPOSED_MODEL` 与 `ZHIPU_MODEL_MAPPING_JSON` 不一致
- 渠道未创建成功
- 渠道组别不是 `default`

### `insufficient_user_quota`
可能原因：
- 服务用户额度被消耗或被手工改小

处理：
- 重新执行 `make bootstrap`

### `429`
可能原因：
- 智谱上游限流
- `NEW-API` 模型请求限流命中
- 管理后台登录接口限流

处理思路：
- 先看 `NEW-API` 日志
- 区分是后台登录限流还是模型请求限流

## 运营建议
- 前端始终只暴露一个稳定别名，例如 `zhipu-primary`
- 真实上游模型切换优先通过 `model_mapping` 完成
- 改完智谱 key 后必须重新执行 bootstrap
- 重要变更后必须至少执行一次 `make smoke-zhipu`
