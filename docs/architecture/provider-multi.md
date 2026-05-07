# 多模型供应商接入指南

## 文档目标
本文档说明如何在当前平台中接入除智谱以外的其他大模型供应商，包括 DeepSeek、阿里通义/百炼、火山豆包、OpenAI 等。平台架构已设计为可扩展，新增供应商只需在 `.env` 中添加配置并在 `NEW-API` 中创建对应渠道。

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

## NEW-API 渠道类型对照表

| 供应商 | 渠道类型 (type) | API 格式 | 说明 |
|--------|----------------|---------|------|
| 智谱 Zhipu | 26 | ZhipuV4 | 已接入 |
| DeepSeek | 1 | OpenAI 兼容 | base_url 改为 DeepSeek 地址 |
| 阿里通义/百炼 DashScope | 26 或 40 | 兼容 | 部分模型走 type=26 |
| 火山/豆包 Volcengine | 1 或 33 | OpenAI 兼容 | 火山引擎方舟平台 |
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
DEEPSEEK_CHANNEL_NAME=deepseek-primary
DEEPSEEK_CHANNEL_TYPE=1
DEEPSEEK_CHANNEL_GROUP=default
DEEPSEEK_CHANNEL_PRIORITY=10
DEEPSEEK_CHANNEL_WEIGHT=100
DEEPSEEK_EXPOSED_MODEL=deepseek-chat,deepseek-reasoner
```

### 第三步：在 NEW-API 后台手动创建渠道
1. 登录 `NEW-API` 后台（`http://localhost:13000`）
2. 进入「渠道管理」->「添加渠道」
3. 填写：
   - 名称：`deepseek-primary`
   - 类型：选择对应渠道类型
   - Base URL：供应商 API 地址
   - 密钥：API Key
   - 模型：填写要暴露的模型列表
   - 分组：`default`
4. 保存并测试

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
- 模型：`deepseek-chat,deepseek-reasoner`
- Base URL：`https://api.deepseek.com`

注意：
- DeepSeek 的 API 完全兼容 OpenAI 格式
- `deepseek-chat` 对应 DeepSeek-V3，`deepseek-reasoner` 对应 DeepSeek-R1

### 阿里通义/百炼 DashScope

```dotenv
DASHSCOPE_API_KEY=sk-xxxxx
DASHSCOPE_API_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode
```

渠道配置：
- 类型：`1`（OpenAI 兼容模式）
- 模型：`qwen-turbo,qwen-plus,qwen-max,qwen-long`
- Base URL：`https://dashscope.aliyuncs.com/compatible-mode/v1`

注意：
- 百炼提供 OpenAI 兼容模式，推荐使用
- 也可使用原生 DashScope 格式（type=26 或 40）

### 火山/豆包 Volcengine

```dotenv
VOLCENGINE_API_KEY=xxxxx
VOLCENGINE_API_BASE_URL=https://ark.cn-beijing.volces.com/api/v3
```

渠道配置：
- 类型：`1`（OpenAI 兼容）
- 模型：填写你在火山引擎方舟平台创建的推理接入点 ID
- Base URL：`https://ark.cn-beijing.volces.com/api/v3`

注意：
- 火山引擎使用推理接入点（Endpoint ID）作为模型名
- 需先在火山引擎方舟平台创建推理接入点

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

当前 bootstrap 脚本已处理智谱渠道。如果需要将新供应商也纳入自动化管理，可以：

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
