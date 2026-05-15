# 智谱渠道接入

## 文档目标
本文档专门解释本项目如何通过 `NEW-API` 接入智谱、当前模型矩阵配置、脚本如何自动化处理，以及出现问题时应该怎样排查。

## 当前接入方案
- 网关：`NEW-API`
- 上游类型：原生 `ZhipuV4`
- 渠道类型：`26`
- 模型映射模式：直通（passthrough），`ZHIPU_MODEL_MAPPING_JSON='{}'`
- 渠道名称：`zhipu-primary`
- 默认测试模型：同步脚本会选择当前智谱模型 API 返回列表中的高阶可用模型
- 运行策略：由 `scripts/sync-provider-models.sh` 动态检测智谱模型 API，并在 LibreChat 的 `API-zhipu` 入口独立展示

## 为什么使用 ZhipuV4
- `NEW-API` 已内建智谱原生适配器，能够直接走兼容路由。
- 适配器对智谱返回结构、计费字段和缓存字段有原生处理逻辑。
- 不需要额外自研代理层或定制转换逻辑。

## 模型矩阵

### 当前动态同步模型

| 模型 ID | 说明 |
|---------|------|
| `glm-5.1` | 智谱最新旗舰 |
| `glm-5` | 智谱旗舰 |
| `glm-5-turbo` | 旗舰高速版 |
| `glm-4.7` | 高性能模型 |
| `glm-4.6` | 均衡模型 |
| `glm-4.5-air` | 轻量模型 |
| `glm-4.5` | 通用模型 |

### 模型映射策略
当前使用**直通模式**（`ZHIPU_MODEL_MAPPING_JSON='{}'`），即 LibreChat 中展示的模型名与智谱上游真实模型名一致。

好处：
- 用户可以直接选择具体模型，精确控制使用哪个模型。
- 新模型上线时优先执行 `make sync-provider-models`，由模型 API 自动刷新，无需长期手工维护映射关系。
- `NEW-API` 的 `ZhipuV4` 适配器直接处理模型名匹配。

### 模型列表更新
当智谱发布新模型时，优先执行：

```bash
make sync-provider-models
```

然后执行：
```bash
make install-model-sync-cron
```

同步脚本会检测智谱模型 API，更新 `.env` 中的 `ZHIPU_EXPOSED_MODEL`，并通过 bootstrap 同步到 `NEW-API` 渠道配置。

## 关键环境变量

```dotenv
ZHIPU_ENABLED=true
ZHIPU_API_KEY=__FILL_BY_USER__
ZHIPU_API_BASE_URL=https://open.bigmodel.cn
ZHIPU_DEFAULT_MODEL=glm-5.1
ZHIPU_TEST_MODEL=glm-5.1
ZHIPU_EXPOSED_MODEL=glm-5.1,glm-5,glm-5-turbo,glm-4.7,glm-4.6,glm-4.5-air,glm-4.5
ZHIPU_CHANNEL_NAME=zhipu-primary
ZHIPU_CHANNEL_TYPE=26
ZHIPU_CHANNEL_GROUP=default
ZHIPU_CHANNEL_PRIORITY=10
ZHIPU_CHANNEL_WEIGHT=100
ZHIPU_MODEL_MAPPING_JSON='{}'
ZHIPU_LIBRECHAT_ENDPOINT_NAME=API-zhipu
ZHIPU_MODEL_ORDER=glm-5.1,glm-5,glm-5-turbo,glm-4.7,glm-4.7-flashx,glm-4.7-flash,glm-4.6,glm-4.5-airx,glm-4.5-air,glm-4.5-flash,glm-4-long,glm-4-flashx-250414,glm-4-flash-250414,glm-5v-turbo,glm-4.6v,glm-4.6v-flash,glm-4.1v-thinking-flashx,glm-4.1v-thinking-flash,glm-4v-flash
```

补充配置建议：
- `NEW_API_SERVICE_TOKEN_UNLIMITED=true` — 服务 token 不再被项目内余额扣减限制
- `NEW_API_PROVIDER_CHANNEL_BALANCE=999999999999` — 智谱渠道余额写成项目内不限额基准
- `NEW_API_RATE_LIMIT_ENABLED=false` — 本项目不再额外限制请求频率
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false` — 不限制 token 可用模型
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true` — bootstrap 时从 env 同步模型矩阵
- `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true` — LibreChat 以 `API-zhipu` 独立入口展示智谱模型

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
应填写当前 `ZHIPU_EXPOSED_MODEL` 中存在的真实上游模型名，例如：
```text
glm-5.1
```

### `ZHIPU_EXPOSED_MODEL`
模型名之间用英文逗号分隔，不要有空格。确保每个模型名都是智谱真实模型 ID。

## 仓库中与智谱相关的落地文件
- bootstrap 脚本：[scripts/bootstrap-new-api.sh](/home/lgq/repoWorkProject/TeamAIPlatform/scripts/bootstrap-new-api.sh)
- smoke 脚本：[scripts/smoke-test-zhipu.sh](/home/lgq/repoWorkProject/TeamAIPlatform/scripts/smoke-test-zhipu.sh)
- 渲染脚本：[scripts/render-librechat-config.sh](/home/lgq/repoWorkProject/TeamAIPlatform/scripts/render-librechat-config.sh)
- LibreChat 配置模板：[deploy/librechat/config/librechat.yaml](/home/lgq/repoWorkProject/TeamAIPlatform/deploy/librechat/config/librechat.yaml)

## bootstrap 如何处理智谱渠道
`bash scripts/bootstrap-new-api.sh` 会自动完成：

1. 等待 `NEW-API /api/status` 就绪
2. 若尚未初始化 root，则完成 root 初始化
3. root 登录并写入系统配置（SelfUseMode、DemoSite）
4. 写入项目内请求限流配置（当前默认关闭）
5. 创建或校正服务用户
6. 将服务用户额度校正为项目内不限额基准
7. 查询名为 `zhipu-primary` 的渠道是否已存在
8. 若不存在，则创建渠道
9. 若已存在，则按 `.env` 配置校正：
   - 当前主配置 `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true`，会同步 `models`、`group`、`test_model`、`model_mapping`
   - 若显式改成 `false`，则保留后台现有模型矩阵
10. 将渠道 `balance` 校正为 `NEW_API_PROVIDER_CHANNEL_BALANCE`
11. 通过 PostgreSQL 创建或校正服务 token，并设置为 unlimited
12. 把 `NEW_API_SERVICE_TOKEN` 回写 `.env`
13. 重新渲染 LibreChat 配置并重启 LibreChat

## 如何验证智谱链路

### 方式一：查看模型列表
```bash
source .env
curl -fsS "$NEW_API_PUBLIC_URL/v1/models" \
  -H "Authorization: Bearer $NEW_API_SERVICE_TOKEN" | jq -r '.data[].id'
```

成功时应能看到当前智谱模型 API 同步后的模型集合。

### 方式二：发送聊天请求
```bash
source .env
curl -fsS "$NEW_API_PUBLIC_URL/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $NEW_API_SERVICE_TOKEN" \
  -d '{"model":"glm-5.1","messages":[{"role":"user","content":"回复OK即可"}],"max_tokens":10}'
```

成功特征：
- 返回 `choices`
- HTTP 状态码为 `200`

### 方式三：浏览器验证
1. 打开 LibreChat
2. 登录后选择 `API-zhipu` 端点
3. 在模型列表中应能看到当前智谱模型 API 同步后的模型集合
4. 选择任意模型发起对话，确认有正常回复

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
- 渠道未创建成功
- 模型名拼写错误
- 渠道组别不是 `default`

### `insufficient_user_quota`
可能原因：
- 服务用户额度、服务 token unlimited 状态或渠道余额被手工改小
- 智谱上游账号额度不足

处理：
- 重新执行 `bash scripts/bootstrap-new-api.sh`

### `429`
可能原因：
- 智谱上游限流
- `NEW-API` 模型请求限流被手工重新开启
- 管理后台登录接口限流

处理思路：
- 先看 `NEW-API` 日志
- 区分是后台登录限流还是模型请求限流

## 运营建议
- 新模型上线时，在 `ZHIPU_EXPOSED_MODEL` 追加模型名，保持 `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true`
- 只想让 LibreChat 展示部分模型时，使用 `LIBRECHAT_VISIBLE_MODELS` 而不是删除渠道模型
- 改完智谱 key 后必须重新执行 bootstrap
- 重要变更后至少执行一次模型列表验证
