# 多模型供应商接入指南

## 文档目标
本文档说明如何在当前平台中接入除智谱以外的其他大模型供应商，包括 DeepSeek、阿里云百炼 DashScope、Kimi、火山方舟豆包、小米 MiMo、OpenAI 等。平台架构已设计为可扩展；其中 DeepSeek、阿里云百炼、Kimi、火山方舟豆包与小米 MiMo 已经被纳入当前 bootstrap 自动化，其它供应商仍可按本文方式继续扩展。

## 架构前提

当前平台模型调用链路：
```
LibreChat -> NEW-API (统一网关) -> 各供应商渠道
```

关键设计：
- `NEW-API` 作为统一网关，所有供应商通过渠道（Channel）接入
- 每个供应商对应一个或多个渠道
- 渠道类型（type）决定了 `NEW-API` 使用哪个适配器
- LibreChat 不直接接触供应商，只通过 `NEW-API` 的 OpenAI 兼容接口访问
- 当前主线默认保持 `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true`，也就是 `.env` 仍是标准渠道矩阵的首要来源；新增多供应商时建议沿用这一套同步方式

## NEW-API 渠道类型对照表

| 供应商 | 渠道类型 (type) | API 格式 | 说明 |
|--------|----------------|---------|------|
| 智谱 Zhipu | 26 | ZhipuV4 | 已接入 |
| DeepSeek | 1 | OpenAI 兼容 | base_url 改为 DeepSeek 地址 |
| 阿里云百炼 DashScope | 1 | OpenAI 兼容 | base_url 使用 `/compatible-mode` |
| Kimi / Moonshot | 1 | OpenAI 兼容 | base_url 使用 `https://api.moonshot.cn` |
| 火山方舟豆包 Volcengine | 45 | VolcEngine | NEW-API 原生火山方舟适配器 |
| 小米 MiMo | 1 | OpenAI 兼容 | base_url 使用 `https://api.xiaomimimo.com` |
| OpenAI | 1 | 原生 | 直连 OpenAI |
| Azure OpenAI | 3 | Azure | 需额外配置 |
| Google Gemini | 24 | Gemini | Google AI Studio |
| 月之暗面 Moonshot | 1 | OpenAI 兼容 | base_url 改为 Moonshot 地址 |
| 百度文心 | 14 | 文心 | 百度千帆平台 |
| 讯飞星火 | 21 | 星火 | 讯飞开放平台 |
| Groq | 1 | OpenAI 兼容 | Groq Cloud |
| Mistral | 1 | OpenAI 兼容 | Mistral AI |
| Cohere | 1 | OpenAI 兼容 | Cohere Platform |
| 自定义代理/中转站 | 1 | OpenAI 兼容 | base_url 指向代理地址 |

## 接入步骤

### 第一步：获取供应商 API Key
在目标供应商平台注册并获取 API Key。

### 第二步：在 `.env` 中添加供应商配置
参照智谱的配置模式，添加新的环境变量组：

```dotenv
# 以 DeepSeek 为例
DEEPSEEK_ENABLED=true
DEEPSEEK_API_KEY=sk-xxxxx
DEEPSEEK_API_BASE_URL=https://api.deepseek.com
DEEPSEEK_DEFAULT_MODEL=deepseek-v4-flash
DEEPSEEK_TEST_MODEL=deepseek-v4-flash
DEEPSEEK_CHANNEL_NAME=deepseek-primary
DEEPSEEK_CHANNEL_TYPE=1
DEEPSEEK_CHANNEL_GROUP=default
DEEPSEEK_CHANNEL_PRIORITY=10
DEEPSEEK_CHANNEL_WEIGHT=100
DEEPSEEK_EXPOSED_MODEL=deepseek-v4-pro,deepseek-v4-flash
DEEPSEEK_LIBRECHAT_ENDPOINT_NAME=API-deepseek
DEEPSEEK_MODEL_ORDER=deepseek-v4-pro,deepseek-v4-flash,deepseek-reasoner,deepseek-chat
```

### 第三步：执行 bootstrap 自动创建渠道

当前主线已经把 DeepSeek 纳入 `scripts/bootstrap-new-api.sh`。配置好 `.env` 后直接执行：

```bash
make bootstrap
```

或：

```bash
bash scripts/bootstrap-new-api.sh
```

bootstrap 会自动创建或更新 `deepseek-primary` 渠道，并同步本项目统一不限额策略：
- 服务 token 保持 `NEW_API_SERVICE_TOKEN_UNLIMITED=true`
- token 模型白名单保持关闭
- 供应商渠道 `balance` 校正为 `NEW_API_PROVIDER_CHANNEL_BALANCE`
- LibreChat 按 `API-zhipu` / `API-deepseek` / `API-aliyun` / `API-kimi` / `API-doubao` / `API-mimo` 分组展示模型

每日动态同步可执行：
```bash
make install-model-sync-cron
```

如果当前只想测试 DeepSeek，不再保留智谱主链路，请把：

```dotenv
ZHIPU_ENABLED=false
```

### 第四步：验证
```bash
source .env
curl -fsS "$NEW_API_PUBLIC_URL/v1/models" \
  -H "Authorization: Bearer $NEW_API_SERVICE_TOKEN" | jq -r '.data[].id'
```

确认新模型出现在列表中，LibreChat 刷新后即可使用。

## 常见供应商配置示例

### DeepSeek

```dotenv
DEEPSEEK_API_KEY=sk-xxxxx
DEEPSEEK_API_BASE_URL=https://api.deepseek.com
```

渠道配置：
- 类型：`1`（OpenAI 兼容）
- 模型：由 DeepSeek 模型 API 动态刷新，当前真实返回 `deepseek-v4-pro,deepseek-v4-flash`
- Base URL：`https://api.deepseek.com`

注意：
- DeepSeek 的 API 完全兼容 OpenAI 格式
- 本仓库不再长期写死 DeepSeek 模型矩阵，`make sync-provider-models` 会按官方模型 API 返回值刷新

### 阿里通义/百炼 DashScope

```dotenv
ALIYUN_ENABLED=true
ALIYUN_API_KEY=sk-xxxxx
ALIYUN_API_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode
ALIYUN_DEFAULT_MODEL=qwen-plus
ALIYUN_TEST_MODEL=qwen-plus
ALIYUN_EXPOSED_MODEL=qwen3.6-max-preview,qwen3-max,qwen-max-latest,qwen-max,qwen-plus-latest,qwen-plus
ALIYUN_CHANNEL_NAME=aliyun-bailian-primary
ALIYUN_CHANNEL_TYPE=1
ALIYUN_CHANNEL_GROUP=default
ALIYUN_MODEL_MAPPING_JSON='{}'
ALIYUN_LIBRECHAT_ENDPOINT_NAME=API-aliyun
ALIYUN_MODEL_ORDER=qwen3.6-max-preview,qwen3-max-preview,qwen3-max,qwen-max-latest,qwen-max,qwen-plus-latest,qwen-plus
ALIYUN_MODEL_LIST_URLS=https://dashscope.aliyuncs.com/compatible-mode/v1/models
ALIYUN_MODEL_EXCLUDE_REGEX='(embedding|rerank|tts|asr|audio|image|video|vl|omni|mt|deep-search|deep-research|character|ocr)'
```

渠道配置：
- 类型：`1`（OpenAI 兼容模式）
- 模型：由百炼模型 API 动态刷新，常用模型包括 `qwen-plus`、`qwen-max`、`qwen3-max` 等
- Base URL：`https://dashscope.aliyuncs.com/compatible-mode`
- 模型列表 URL：`https://dashscope.aliyuncs.com/compatible-mode/v1/models`

注意：
- 百炼提供 OpenAI 兼容模式，推荐使用
- 当前仓库自动化使用 `ALIYUN_*` 前缀和 `API-aliyun` LibreChat 分组
- 不使用原生 DashScope 格式，避免与 `NEW-API` 适配器类型差异耦合

### Kimi / Moonshot

```dotenv
KIMI_ENABLED=true
KIMI_API_KEY=sk-xxxxx
KIMI_API_BASE_URL=https://api.moonshot.cn
KIMI_DEFAULT_MODEL=kimi-k2.6
KIMI_TEST_MODEL=kimi-k2.6
KIMI_EXPOSED_MODEL=kimi-k2.6,kimi-k2.5,moonshot-v1-128k,moonshot-v1-32k,moonshot-v1-8k
KIMI_CHANNEL_NAME=kimi-primary
KIMI_CHANNEL_TYPE=1
KIMI_CHANNEL_GROUP=default
KIMI_MODEL_MAPPING_JSON='{}'
KIMI_LIBRECHAT_ENDPOINT_NAME=API-kimi
KIMI_MODEL_ORDER=kimi-k2.6,kimi-k2.5,kimi-k2-thinking-turbo,kimi-k2-thinking,moonshot-v1-128k,moonshot-v1-32k,moonshot-v1-8k
KIMI_MODEL_LIST_URLS=https://api.moonshot.cn/v1/models
```

渠道配置：
- 类型：`1`（OpenAI 兼容）
- 模型：由 Kimi 模型 API 动态刷新，当前优先使用 `kimi-k2.6`
- Base URL：`https://api.moonshot.cn`
- 模型列表 URL：`https://api.moonshot.cn/v1/models`

注意：
- Kimi 官方 SDK Base URL 带 `/v1`，但 NEW-API 渠道 Base URL 不带 `/v1`
- 当前仓库自动化使用 `KIMI_*` 前缀和 `API-kimi` LibreChat 分组

### 火山方舟豆包 Volcengine

```dotenv
DOUBAO_ENABLED=true
DOUBAO_API_KEY=ark-xxxxx
DOUBAO_API_BASE_URL=https://ark.cn-beijing.volces.com
DOUBAO_DEFAULT_MODEL=doubao-seed-1-6-250615
DOUBAO_TEST_MODEL=doubao-seed-1-6-250615
DOUBAO_EXPOSED_MODEL=doubao-seed-1-6-250615,doubao-seed-1-6-flash-250828,doubao-1-5-pro-32k-250115
DOUBAO_CHANNEL_NAME=doubao-primary
DOUBAO_CHANNEL_TYPE=45
DOUBAO_CHANNEL_GROUP=default
DOUBAO_MODEL_MAPPING_JSON='{}'
DOUBAO_LIBRECHAT_ENDPOINT_NAME=API-doubao
DOUBAO_MODEL_ORDER=doubao-seed-2-0-pro-260215,doubao-seed-1-8-251228,doubao-seed-1-6-251015,doubao-seed-1-6-250615,doubao-seed-1-6-flash-250828,doubao-1-5-pro-32k-250115
DOUBAO_MODEL_LIST_URLS=https://ark.cn-beijing.volces.com/api/v3/models
```

渠道配置：
- 类型：`45`（NEW-API 火山方舟原生适配器）
- 模型：由火山方舟模型 API 动态刷新；如账号要求推理接入点，则填写控制台创建的 `ep-*` ID 或别名
- Base URL：`https://ark.cn-beijing.volces.com`
- 模型列表 URL：`https://ark.cn-beijing.volces.com/api/v3/models`

注意：
- `type=45` 会由 NEW-API 自动拼接 `/api/v3/chat/completions`，因此渠道 Base URL 不要写 `/api/v3`
- 火山方舟账号需先开通目标模型服务，或创建可调用的推理接入点

### 小米 MiMo

```dotenv
MIMO_ENABLED=true
MIMO_API_KEY=sk-xxxxx
MIMO_API_BASE_URL=https://api.xiaomimimo.com
MIMO_DEFAULT_MODEL=mimo-v2.5-pro
MIMO_TEST_MODEL=mimo-v2.5-pro
MIMO_EXPOSED_MODEL=mimo-v2.5-pro,mimo-v2.5,mimo-v2-pro,mimo-v2-omni,mimo-v2-flash
MIMO_CHANNEL_NAME=mimo-primary
MIMO_CHANNEL_TYPE=1
MIMO_CHANNEL_GROUP=default
MIMO_MODEL_MAPPING_JSON='{}'
MIMO_LIBRECHAT_ENDPOINT_NAME=API-mimo
MIMO_MODEL_ORDER=mimo-v2.5-pro,mimo-v2.5,mimo-v2-pro,mimo-v2-omni,mimo-v2-flash
MIMO_MODEL_LIST_URLS=https://api.xiaomimimo.com/v1/models
```

渠道配置：
- 类型：`1`（OpenAI 兼容）
- 模型：由 MiMo 模型 API 动态刷新，默认优先使用 `mimo-v2.5-pro`
- Base URL：`https://api.xiaomimimo.com`
- 模型列表 URL：`https://api.xiaomimimo.com/v1/models`

注意：
- MiMo 官方 SDK Base URL 带 `/v1`，但 NEW-API 渠道 Base URL 不带 `/v1`
- 当前仓库自动化使用 `MIMO_*` 前缀和 `API-mimo` LibreChat 分组
- 模型同步会过滤 TTS / voiceclone / voicedesign 等非普通 chat 模型

### OpenAI

```dotenv
OPENAI_API_KEY=sk-xxxxx
OPENAI_API_BASE_URL=https://api.openai.com
```

渠道配置：
- 类型：`1`（原生 OpenAI）
- 模型：`gpt-4o,gpt-4o-mini,o1,o3-mini`
- Base URL：`https://api.openai.com/v1`

注意：
- 如使用代理/中转站，将 Base URL 改为中转站地址
- 代理站类型仍为 `1`，只需改 Base URL

### 代理/中转站

如果你使用 API 代理或中转站（如 OpenRouter、自建中转等）：

渠道配置：
- 类型：`1`（OpenAI 兼容）
- Base URL：中转站地址
- 密钥：中转站提供的 Key
- 模型：中转站支持的模型列表

这是接入多供应商最灵活的方式，一个渠道即可覆盖多个供应商的模型。

## 自动化扩展（可选）

当前 bootstrap 脚本已处理：
- 智谱渠道
- DeepSeek 渠道
- 阿里云百炼渠道
- Kimi 渠道
- 火山方舟豆包渠道
- 小米 MiMo 渠道

如果需要将更多供应商也纳入自动化管理，可以：

### 方式一：手动后台管理（推荐）
- 在 `NEW-API` 后台手动创建和管理新供应商渠道
- 只需确保渠道分组为 `default`，模型对服务 token 可见即可
- 适合供应商较少或变更不频繁的场景

### 方式二：扩展 bootstrap 脚本
参照 `scripts/bootstrap-new-api.sh` 中智谱渠道的处理逻辑，为新供应商添加类似的渠道创建/更新逻辑：

1. 在 `.env` 中添加新供应商的环境变量
2. 在 bootstrap 脚本中添加渠道检查和创建逻辑
3. 将新模型追加到 `ZHIPU_EXPOSED_MODEL` 或创建独立模型列表变量

关键原则：
- 渠道类型必须正确
- Base URL 不要写多余路径（大多数适配器会自动补全）
- 测试模型必须是供应商真实模型名

## 供应商切换与下线

### 下线供应商
1. 在 `NEW-API` 后台将对应渠道状态设为「禁用」
2. LibreChat 刷新后该渠道模型将不可见

### 切换供应商（模型平替）
1. 创建新供应商渠道，配置相同的模型名
2. 禁用旧供应商渠道
3. LibreChat 自动切换到新渠道

### 优先级与权重
当多个渠道提供相同模型时：
- **优先级**（priority）：数值越大越优先
- **权重**（weight）：相同优先级时按权重做负载均衡

可用于实现灾备切换或灰度切换。

## 排查指南

### 新渠道创建后模型不可见
1. 确认渠道状态为「启用」
2. 确认模型列表不为空
3. 确认分组为 `default`
4. 执行 `GET /v1/models` 确认模型是否返回
5. 刷新 LibreChat 页面

### 新渠道测试失败
1. 确认 API Key 有效
2. 确认 Base URL 正确（不含多余路径）
3. 确认测试模型名是供应商真实模型名
4. 查看 `NEW-API` 日志排查具体错误

### 多渠道冲突
1. 检查是否有多个渠道配置了相同模型
2. 通过优先级和权重控制路由策略
3. 不确定时先禁用冲突渠道逐一排查

## 模型矩阵管理建议

### 推荐做法
- 每个供应商一个渠道，模型列表清晰
- 代理/中转站可作为统一入口，简化管理
- 使用优先级控制主备切换
- 定期在 `NEW-API` 后台检查渠道健康状态

### 不推荐做法
- 不要在一个渠道中混合多个供应商的 API Key
- 不要在前端直接配置供应商地址（应统一走 NEW-API）
- 不要绕过 NEW-API 直接让 LibreChat 调用供应商 API
