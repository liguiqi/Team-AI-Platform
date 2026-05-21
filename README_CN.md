# Team AI Platform

**[English](./README.md)** | 中文

> AI Gateway Chat — 面向中小型团队的全模型聚合对话平台

无论对于企业团队还是个人用户，LLM 对话数据的私有化管理正变得愈发重要。基于近期对 Chatlog Data 私有化管理的实际需求，本项目完成了一个面向小型团队/公司的 AI-Agent-Chatlog 聚合平台验证，目前已基本调通并稳定部署。

虽然本质上是一个 AI Gateway Chat 项目，但更愿意称之为 **Team AI Platform**。

## 主要特性

1. **全模型 Chat 平台** — 面向中小型团队/公司，支持所有主流大模型供应商
2. **统一认证与国际化** — 支持邮箱、手机交叉验证注册/登录，多国语言国际化支持
3. **Prompt 工程与 Agent 编排** — 支持 Prompt 工程、AI Native ChatAgent 智能体编排、官方原生 Model 超参微调调用
4. **Chatlog 高度私有化** — 支持多 Agent Workflow 编排与交叉复用，Agent 智能体广场共享
5. **API Key 统一管控** — 聚合官方模型，API Key 由 Admin 后端统一管理，团队成员只需关注对话与智能体产出
6. **全渠道拓展能力** — 支持国内外任意模型厂商渠道，支持第三方中转站接口向下拓展
7. **7 大渠道 165+ 模型矩阵** — 已接入智谱、DeepSeek、阿里云百炼、Kimi、火山豆包、小米 MiMo 共 7 个 API 渠道，165+ 款模型任意调用
8. **对话操作能力** — 支持 Chat History 热修改、Chat Fork、Chat Export（Picture/Markdown）、Chat with Internet（第三方）
9. **RAG/MCP 与制品策略** — 支持 Chat Platform 制品策略、RAG/MCP，模型/智能体双列对比调用验证
10. **精细化管理与数据隔离** — Admin Panel 支持用户、用户组精细化管理，用户数据与 Chat Platform 容器化隔离，保障数据安全

目前开发已近收尾，待域名审批后上线使用，欢迎届时注册体验。

## 致谢

该项目站在巨人的肩膀上完成，感谢以下优秀开源项目：

- [LibreChat](https://github.com/danny-avila/LibreChat)
- [NEW-API](https://github.com/calciumion/new-api)
- [Casdoor](https://github.com/casdoor/casdoor)

---

## 责任边界

基于 `NEW-API + LibreChat` 的内部 AI 对话整合仓库，目标是把公司采购的上游模型能力统一收口到 `NEW-API`，再由 `LibreChat` 提供部门同学使用的对话界面。本地默认入口为 `http://localhost:3081` 与 `http://localhost:13001`。

## 责任边界
- Codex 负责完整实施、结构整理、文档交付、脚本生成、配置模板、联调路径设计、自测与问题收敛。
- 项目负责人最后只负责验收。
- 用户会提供明确可用的智谱、DeepSeek、阿里云百炼、Kimi、火山方舟豆包、小米 MiMo 或 MiniMax API Key。
- 最终验收以智谱 API 渠道为主验收渠道。
- 除填写真实密钥和执行最终验收外，用户不负责补做工程集成。

## 架构
```text
智谱 / DeepSeek / 阿里云百炼 / Kimi / 火山方舟豆包 / 小米 MiMo / MiniMax / 其他上游模型
    -> NEW-API
    -> LibreChat
    -> 部门用户
```

本仓库默认采用：
- `NEW-API` 原生 `ZhipuV4` 渠道 + 火山方舟豆包原生渠道 + DeepSeek / 阿里云百炼 / Kimi / 小米 MiMo / MiniMax OpenAI 兼容渠道
- `LibreChat` 自定义 OpenAI 兼容端点按供应商拆分为 `API-zhipu` / `API-deepseek` / `API-aliyun` / `API-kimi` / `API-doubao` / `API-mimo` / `API-minimax`，底层仍统一走 `NEW-API`
- `Docker Compose` 作为本地与单机生产的统一编排方式
- 生产默认使用 direct-ip 直连端口；`Caddy` 仅在 `COMPOSE_PROFILES=domain-proxy` 时作为域名 HTTPS 反向代理启用

## 版本矩阵
- `calciumion/new-api:v0.12.1`
- `ghcr.io/danny-avila/librechat:v0.8.5`
- `postgres:16-alpine`
- `redis:7.4.2-alpine`
- `mongo:8.0.20`
- `caddy:2.10.0-alpine`

版本选择依据：
- `NEW-API v0.12.1` 来自官方 GitHub Release / Docker Hub tag。
- `LibreChat v0.8.5` 来自官方 Git tag 与 GHCR 镜像 tag。
- 其余核心基础镜像均固定为可用的明确版本，避免 `latest` 漂移；本地 Admin Panel 当前由 `LIBRECHAT_ADMIN_PANEL_VERSION` 控制，默认值仍为上游提供的 `latest`，生产 compose 默认不启用该服务。

## 快速开始
1. 复制环境文件并填写至少一组真实上游密钥：
   ```bash
   cp .env.example .env
   ```
   必填项：`ZHIPU_API_KEY`、`DEEPSEEK_API_KEY`、`ALIYUN_API_KEY`、`KIMI_API_KEY`、`DOUBAO_API_KEY`、`MIMO_API_KEY` 或 `MINIMAX_API_KEY`
   如果当前只想接 DeepSeek、阿里云百炼、Kimi、豆包、MiMo 或 MiniMax，不再使用智谱，请同时把 `ZHIPU_ENABLED=false`。
2. 初始化本地目录并自动生成非敏感随机密钥：
   ```bash
   make init
   ```
3. 启动核心服务：
   ```bash
   make up
   ```
4. 执行智谱联调与主链路 smoke test：
   ```bash
   make smoke-zhipu
   ```
   如已启用 DeepSeek，也可执行：
   ```bash
   make smoke-deepseek
   ```
   如已启用阿里云百炼，也可执行：
   ```bash
   make smoke-aliyun
   ```
   如已启用 Kimi，也可执行：
   ```bash
   make smoke-kimi
   ```
   如已启用火山方舟豆包，也可执行：
   ```bash
   make smoke-doubao
   ```
   如已启用小米 MiMo，也可执行：
   ```bash
   make smoke-mimo
   ```
   如已启用 MiniMax，也可执行：
   ```bash
   make smoke-minimax
   ```
5. 如果你后续调整了上游模型矩阵，或配置了 LibreChat 前端白名单，执行：
   ```bash
   make sync-provider-models
   ```

说明：
- `make smoke-zhipu` / `make smoke-deepseek` / `make smoke-aliyun` / `make smoke-kimi` / `make smoke-doubao` / `make smoke-mimo` / `make smoke-minimax` 都会先调用 `scripts/bootstrap-new-api.sh`，自动完成 `NEW-API` 初始化、限流参数写入、已启用供应商渠道创建、LibreChat 服务用户与 token 生成。
- bootstrap 过程会把自动生成的 `NEW_API_SERVICE_TOKEN` 回写到本地 `.env`，无需手工复制 token。
- 本地 compose 当前默认带上 `LibreChat Admin Panel`，入口由 `LIBRECHAT_ADMIN_PANEL_PORT` 控制；main 本机部署当前使用 `http://localhost:3003`，避免与已运行分支和本机其它进程冲突。
- main 分支容器默认使用 `ai-gateway-main-*` 命名，避免和 `ai-gateway-*` 分支环境互相覆盖。
- 默认会创建管理员（邮箱和密码见 `.env` 中 `LIBRECHAT_DEFAULT_ADMIN_EMAIL` / `LIBRECHAT_DEFAULT_ADMIN_PASSWORD`），并同步到 LibreChat 本地用户库与 Casdoor `team-ai` 业务组织，可用于登录 LibreChat、统一认证入口和 Admin Panel；第一个非默认注册用户也会自动提升为 `ADMIN`。
- LibreChat 的 OIDC state / session 当前持久化到 `new-api-redis` 的 DB 1，重启后不会再因为内存 session 丢失而要求重复登录。
- Casdoor 登录页样式由脚本渲染并随浏览器 `light/dark` 主题自适应，登录/注册页默认中文。
- 生产 compose 现已支持 **无域名直连**：默认按 `LIBRECHAT_PUBLIC_URL / NEW_API_PUBLIC_URL / CASDOOR_PUBLIC_URL` 直接暴露端口；只有在 `COMPOSE_PROFILES=domain-proxy` 时才启动 Caddy 做域名 HTTPS 反向代理。
- 生产 env 模板和 compose 已按 Aliyun 2C2G、实际可用内存约 1.6GB 收敛；生产默认不启用 Admin Panel，不启动 Caddy。
- 当 `ZHIPU_ENABLED=true`、`DEEPSEEK_ENABLED=true`、`ALIYUN_ENABLED=true`、`KIMI_ENABLED=true`、`DOUBAO_ENABLED=true`、`MIMO_ENABLED=true`、`MINIMAX_ENABLED=true` 同时开启时，`make bootstrap` 会同时创建/更新 `zhipu-primary`、`deepseek-primary`、`aliyun-bailian-primary`、`kimi-primary`、`doubao-primary`、`mimo-primary` 与 `minimax-primary` 渠道；LibreChat 展示为 `API-zhipu` / `API-deepseek` / `API-aliyun` / `API-kimi` / `API-doubao` / `API-mimo` / `API-minimax` 七个入口，底层共用同一个 `NEW_API_SERVICE_TOKEN`。

## 目录结构
```text
docs/                     需求、架构、部署、验收、自测文档
deploy/                   local/prod compose 与配置模板
scripts/                  初始化、启停、健康检查、bootstrap、备份恢复
tests/smoke/              smoke test 请求模板
.github/workflows/        基础 CI 校验
runtime/                  本地与生产运行期数据目录（不入库）
```

## 核心命令
- `make init`：初始化本地目录、复制环境文件、生成随机密钥占位。
- `make up`：启动本地 compose。
- `make down`：停止本地 compose。
- `make restart`：重启本地 compose。
- `make bootstrap`：初始化 `NEW-API` 并配置已启用供应商渠道。
- `make bootstrap-librechat-admin`：创建或校正 LibreChat 默认管理员，并把第一个非默认注册用户提升为 `ADMIN`。
- `make sync-provider-models`：检测供应商模型 API、同步 `NEW-API` 渠道并重渲染 LibreChat 模型列表。
- `make sync-librechat-models`：兼容入口，默认会调用 `make sync-provider-models` 等价逻辑。
- `make health`：检查 `NEW-API` 与 `LibreChat` 应用层健康状态。
- `make smoke`：执行通用 smoke test。
- `make smoke-zhipu`：执行智谱验收通道 smoke test。
- `make smoke-deepseek`：执行 DeepSeek 验收通道 smoke test。
- `make smoke-aliyun`：执行阿里云百炼验收通道 smoke test。
- `make smoke-kimi`：执行 Kimi 验收通道 smoke test。
- `make smoke-doubao`：执行火山方舟豆包验收通道 smoke test。
- `make smoke-mimo`：执行小米 MiMo 验收通道 smoke test。
- `make smoke-minimax`：执行 MiniMax 验收通道 smoke test。
- `make doctor`：诊断依赖、端口、env、compose 配置。
- `make verify-no-secrets`：扫描已纳入 Git 的文件，检查明显密钥风险。

默认部署说明：
- `MeiliSearch` 已预留变量，但默认关闭，不纳入验收主链路。
- 如需启用搜索能力，可恢复 compose 中的 `meilisearch` 服务并把 `LIBRECHAT_SEARCH_ENABLED=true`。

## 智谱配置说明
根目录 `.env` 至少填写以下字段：
```dotenv
ZHIPU_ENABLED=true
ZHIPU_API_KEY=__FILL_BY_USER__
ZHIPU_API_BASE_URL=https://open.bigmodel.cn
ZHIPU_DEFAULT_MODEL=glm-5.1
ZHIPU_TEST_MODEL=glm-5.1
ZHIPU_EXPOSED_MODEL=glm-5.1,glm-5,glm-5-turbo,glm-4.7,glm-4.6,glm-4.5-air,glm-4.5
ZHIPU_LIBRECHAT_ENDPOINT_NAME=API-zhipu
```

当前主配置会先从智谱模型 API 检测可用模型，再把排序后的 `ZHIPU_EXPOSED_MODEL` 同步到 `NEW-API` 与 LibreChat 的 `API-zhipu` 入口，从而实现：
- 前端不直接持有官方采购密钥
- LibreChat 只在 `API-zhipu` 下展示智谱模型
- NEW-API 可继续扩展其它上游而不改前端

`NEW-API` 的 `ZhipuV4` 渠道会自动补上 `/api/paas/v4`，所以 `ZHIPU_API_BASE_URL` 必须写成 `https://open.bigmodel.cn`，不要重复带完整路径。

## DeepSeek 配置说明
根目录 `.env` 启用 DeepSeek 时至少填写以下字段：
```dotenv
DEEPSEEK_ENABLED=true
DEEPSEEK_API_KEY=__FILL_BY_USER__
DEEPSEEK_API_BASE_URL=https://api.deepseek.com
DEEPSEEK_DEFAULT_MODEL=deepseek-v4-flash
DEEPSEEK_TEST_MODEL=deepseek-v4-flash
DEEPSEEK_EXPOSED_MODEL=deepseek-v4-pro,deepseek-v4-flash
DEEPSEEK_LIBRECHAT_ENDPOINT_NAME=API-deepseek
```

说明：
- 当前仓库默认使用 `type=1` 的 OpenAI 兼容渠道接入 DeepSeek 官方 API。
- `make bootstrap` 会在 `DEEPSEEK_ENABLED=true` 时自动创建/更新 `deepseek-primary` 渠道。
- bootstrap 会把 `deepseek-primary` 与其它已启用供应商渠道的 `balance` 校正为 `NEW_API_PROVIDER_CHANNEL_BALANCE`，本项目内不再做渠道费用余额限制。
- DeepSeek 官方文档当前给出的 OpenAI 兼容 `base_url` 是 `https://api.deepseek.com`，不需要额外手工补 `/v1`。
- `make sync-provider-models` 会从 DeepSeek 模型 API 动态刷新 `DEEPSEEK_EXPOSED_MODEL`；当前真实 API 返回 `deepseek-v4-pro` / `deepseek-v4-flash`。

## 阿里云百炼配置说明
根目录 `.env` 启用百炼时至少填写以下字段：
```dotenv
ALIYUN_ENABLED=true
ALIYUN_API_KEY=__FILL_BY_USER__
ALIYUN_API_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode
ALIYUN_DEFAULT_MODEL=qwen-plus
ALIYUN_TEST_MODEL=qwen-plus
ALIYUN_EXPOSED_MODEL=qwen3.6-max-preview,qwen3-max,qwen-max-latest,qwen-max,qwen-plus-latest,qwen-plus
ALIYUN_LIBRECHAT_ENDPOINT_NAME=API-aliyun
```

说明：
- 当前仓库使用 `type=1` 的 OpenAI 兼容渠道接入阿里云百炼 DashScope。
- `make bootstrap` 会在 `ALIYUN_ENABLED=true` 时自动创建/更新 `aliyun-bailian-primary` 渠道。
- `ALIYUN_API_BASE_URL` 写到 `https://dashscope.aliyuncs.com/compatible-mode`，模型检测接口由 `ALIYUN_MODEL_LIST_URLS=https://dashscope.aliyuncs.com/compatible-mode/v1/models` 单独配置。
- `make sync-provider-models` 会从百炼模型 API 动态刷新 `ALIYUN_EXPOSED_MODEL`，并按 `ALIYUN_MODEL_ORDER` 高阶优先排序。

## Kimi 配置说明
根目录 `.env` 启用 Kimi 时至少填写以下字段：
```dotenv
KIMI_ENABLED=true
KIMI_API_KEY=__FILL_BY_USER__
KIMI_API_BASE_URL=https://api.moonshot.cn
KIMI_DEFAULT_MODEL=kimi-k2.6
KIMI_TEST_MODEL=kimi-k2.6
KIMI_EXPOSED_MODEL=kimi-k2.6,kimi-k2.5,moonshot-v1-128k,moonshot-v1-32k,moonshot-v1-8k
KIMI_LIBRECHAT_ENDPOINT_NAME=API-kimi
```

说明：
- 当前仓库使用 `type=1` 的 OpenAI 兼容渠道接入 Kimi 开放平台。
- `make bootstrap` 会在 `KIMI_ENABLED=true` 时自动创建/更新 `kimi-primary` 渠道。
- Kimi 官方 SDK Base URL 是 `https://api.moonshot.cn/v1`；NEW-API 渠道写 `https://api.moonshot.cn`，模型检测接口由 `KIMI_MODEL_LIST_URLS=https://api.moonshot.cn/v1/models` 单独配置。
- `make sync-provider-models` 会从 Kimi 模型 API 动态刷新 `KIMI_EXPOSED_MODEL`，并按 `KIMI_MODEL_ORDER` 高阶优先排序。

## 火山方舟豆包配置说明
根目录 `.env` 启用豆包时至少填写以下字段：
```dotenv
DOUBAO_ENABLED=true
DOUBAO_API_KEY=__FILL_BY_USER__
DOUBAO_API_BASE_URL=https://ark.cn-beijing.volces.com
DOUBAO_DEFAULT_MODEL=doubao-seed-1-6-250615
DOUBAO_TEST_MODEL=doubao-seed-1-6-250615
DOUBAO_EXPOSED_MODEL=doubao-seed-1-6-250615,doubao-seed-1-6-flash-250828,doubao-1-5-pro-32k-250115
DOUBAO_LIBRECHAT_ENDPOINT_NAME=API-doubao
```

说明：
- 当前仓库使用 `type=45` 的 NEW-API 火山方舟原生渠道接入豆包。
- `DOUBAO_API_BASE_URL` 写根地址 `https://ark.cn-beijing.volces.com`，NEW-API 适配器会自行拼接 `/api/v3/chat/completions`。
- 模型检测接口由 `DOUBAO_MODEL_LIST_URLS=https://ark.cn-beijing.volces.com/api/v3/models` 单独配置，并会过滤停用、embedding、图像、音视频等非普通 chat 模型。
- 火山方舟账号必须在控制台开通对应模型服务或创建可调用的推理接入点；否则 API key 可查模型列表但真实 chat 会返回“未开通该模型服务”。

## 小米 MiMo 配置说明
根目录 `.env` 启用 MiMo 时至少填写以下字段：
```dotenv
MIMO_ENABLED=true
MIMO_API_KEY=__FILL_BY_USER__
MIMO_API_BASE_URL=https://api.xiaomimimo.com
MIMO_DEFAULT_MODEL=mimo-v2.5-pro
MIMO_TEST_MODEL=mimo-v2.5-pro
MIMO_EXPOSED_MODEL=mimo-v2.5-pro,mimo-v2.5,mimo-v2-pro,mimo-v2-omni,mimo-v2-flash
MIMO_LIBRECHAT_ENDPOINT_NAME=API-mimo
```

说明：
- 当前仓库使用 `type=1` 的 OpenAI 兼容渠道接入小米 MiMo。
- MiMo 官方 SDK Base URL 是 `https://api.xiaomimimo.com/v1`；NEW-API 渠道写 `https://api.xiaomimimo.com`，模型检测接口由 `MIMO_MODEL_LIST_URLS=https://api.xiaomimimo.com/v1/models` 单独配置。
- `make sync-provider-models` 会从 MiMo 模型 API 动态刷新 `MIMO_EXPOSED_MODEL`，过滤 TTS / voiceclone / voicedesign 等非普通 chat 模型，并按 `MIMO_MODEL_ORDER` 高阶优先排序。

## MiniMax 配置说明
根目录 `.env` 启用 MiniMax 时至少填写以下字段：
```dotenv
MINIMAX_ENABLED=true
MINIMAX_API_KEY=__FILL_BY_USER__
MINIMAX_API_BASE_URL=https://api.minimaxi.com
MINIMAX_DEFAULT_MODEL=MiniMax-M2.7
MINIMAX_TEST_MODEL=MiniMax-M2.7
MINIMAX_EXPOSED_MODEL=MiniMax-M2.7,MiniMax-M2.7-highspeed,MiniMax-M2.5,MiniMax-M2.5-highspeed,MiniMax-M2.1,MiniMax-M2.1-highspeed,MiniMax-M2
MINIMAX_LIBRECHAT_ENDPOINT_NAME=API-minimax
```

说明：
- 当前仓库使用 `type=1` 的 OpenAI 兼容渠道接入 MiniMax。
- MiniMax 官方 OpenAI SDK Base URL 是 `https://api.minimaxi.com/v1`；NEW-API 渠道写 `https://api.minimaxi.com`，模型检测接口由 `MINIMAX_MODEL_LIST_URLS=https://api.minimaxi.com/v1/models` 单独配置。
- `make sync-provider-models` 会从 MiniMax 模型 API 动态刷新 `MINIMAX_EXPOSED_MODEL`，当前默认同步 `MiniMax-M2.7`、`MiniMax-M2.7-highspeed`、`MiniMax-M2.5`、`MiniMax-M2.5-highspeed`、`MiniMax-M2.1`、`MiniMax-M2.1-highspeed`、`MiniMax-M2`，并按 `MINIMAX_MODEL_ORDER` 高阶优先排序。

## 模型同步说明
当前默认策略是按供应商拆分 LibreChat 模型入口：

- `API-zhipu`：只显示智谱模型，并按 `ZHIPU_MODEL_ORDER` 高阶优先排序。
- `API-deepseek`：只显示 DeepSeek 模型，并按 `DEEPSEEK_MODEL_ORDER` 高阶优先排序。
- `API-aliyun`：只显示阿里云百炼模型，并按 `ALIYUN_MODEL_ORDER` 高阶优先排序。
- `API-kimi`：只显示 Kimi 模型，并按 `KIMI_MODEL_ORDER` 高阶优先排序。
- `API-doubao`：只显示火山方舟豆包模型，并按 `DOUBAO_MODEL_ORDER` 高阶优先排序。
- `API-mimo`：只显示小米 MiMo 模型，并按 `MIMO_MODEL_ORDER` 高阶优先排序。
- `API-minimax`：只显示 MiniMax 模型，并按 `MINIMAX_MODEL_ORDER` 高阶优先排序。
- 所有入口底层都使用同一个 `NEW_API_SERVICE_TOKEN` 请求 `NEW-API /v1/*`。

推荐默认策略：
- `NEW_API_SERVICE_TOKEN_QUOTA=1000000000000`
- `NEW_API_SERVICE_TOKEN_UNLIMITED=true`
- `NEW_API_PROVIDER_CHANNEL_BALANCE=999999999999`
- `NEW_API_RATE_LIMIT_ENABLED=false`
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true`
- `LIBRECHAT_SPLIT_PROVIDER_ENDPOINTS=true`
- `LIBRECHAT_FETCH_MODELS=true`
- `LIBRECHAT_VISIBLE_MODELS=` 留空

每日动态同步：
```bash
make install-model-sync-cron
```

默认 cron 为 `17 4 * * *`，会执行 `make sync-provider-models` 等价逻辑：检测供应商模型 API、更新 `*_EXPOSED_MODEL`、回放 bootstrap，并重启 LibreChat。

## LibreChat 默认管理员
默认部署会启用一个本地管理员账号，用于首次登录 LibreChat 与 Admin Panel：
```dotenv
LIBRECHAT_DEFAULT_ADMIN_ENABLED=true
LIBRECHAT_DEFAULT_ADMIN_EMAIL=<YOUR_ADMIN_EMAIL>
LIBRECHAT_DEFAULT_ADMIN_PASSWORD=<YOUR_ADMIN_PASSWORD>
LIBRECHAT_DEFAULT_ADMIN_CASDOOR_ENABLED=true
LIBRECHAT_FIRST_USER_ADMIN_ENABLED=true
```

说明：
- `make up` 和 `make bootstrap` 会自动执行 `scripts/bootstrap-librechat-admin.sh`。
- 默认管理员会同时写入 LibreChat MongoDB 和 Casdoor `team-ai` 业务组织，因此既可以走 LibreChat 本地登录，也可以从 Casdoor 统一认证入口登录。
- 登录 LibreChat 本体时如被自动跳转到统一认证页，可打开 `http://localhost:3081/login?redirect=false` 使用默认管理员账号（见 `.env` 配置）。
- 第一个非默认注册用户会自动设置为 `ADMIN`，之后注册的用户保持普通 `USER`，便于在 Admin Panel 中继续调试用户组和权限。

## smoke test
- 通用检查：
  ```bash
  make smoke
  ```
- 智谱主验收通道：
  ```bash
  make smoke-zhipu
  ```
- DeepSeek 主验收通道：
  ```bash
  make smoke-deepseek
  ```
- 阿里云百炼主验收通道：
  ```bash
  make smoke-aliyun
  ```
- Kimi 主验收通道：
  ```bash
  make smoke-kimi
  ```
- 火山方舟豆包主验收通道：
  ```bash
  make smoke-doubao
  ```
- 小米 MiMo 主验收通道：
  ```bash
  make smoke-mimo
  ```
- MiniMax 主验收通道：
  ```bash
  make smoke-minimax
  ```
- 应用层健康检查：
  ```bash
  make health
  ```

## 常见入口
- 需求说明：[docs/architecture/requirements.md](docs/architecture/requirements.md)
- 架构说明：[docs/architecture/architecture.md](docs/architecture/architecture.md)
- 实施计划：[docs/architecture/implementation-plan.md](docs/architecture/implementation-plan.md)
- 本地部署说明：[docs/architecture/deployment-local.md](docs/architecture/deployment-local.md)
- 云端部署说明：[docs/architecture/deployment-cloud.md](docs/architecture/deployment-cloud.md)
- 智谱接入说明：[docs/architecture/provider-zhipu.md](docs/architecture/provider-zhipu.md)
- DeepSeek 接入说明：[docs/architecture/provider-deepseek.md](docs/architecture/provider-deepseek.md)
- 阿里云百炼接入说明：[docs/architecture/provider-aliyun.md](docs/architecture/provider-aliyun.md)
- Kimi 接入说明：[docs/architecture/provider-kimi.md](docs/architecture/provider-kimi.md)
- 火山方舟豆包接入说明：[docs/architecture/provider-doubao.md](docs/architecture/provider-doubao.md)
- 小米 MiMo 接入说明：[docs/architecture/provider-mimo.md](docs/architecture/provider-mimo.md)
- MiniMax 接入说明：[docs/architecture/provider-minimax.md](docs/architecture/provider-minimax.md)
- NEW-API 管理员手册：[docs/architecture/admin-new-api.md](docs/architecture/admin-new-api.md)
- LibreChat 管理员手册：[docs/architecture/admin-librechat.md](docs/architecture/admin-librechat.md)
- Admin Panel 管理说明：[docs/architecture/admin-panel.md](docs/architecture/admin-panel.md)
- 运行手册：[docs/architecture/runbook.md](docs/architecture/runbook.md)
- 验收标准：[docs/architecture/acceptance-criteria.md](docs/architecture/acceptance-criteria.md)
- 自测报告：[docs/architecture/self-test-report.md](docs/architecture/self-test-report.md)

## 建议阅读顺序
如果你是第一次接手本项目，建议按下面顺序阅读：

1. [docs/architecture/requirements.md](docs/architecture/requirements.md)
2. [docs/architecture/architecture.md](docs/architecture/architecture.md)
3. [docs/architecture/implementation-plan.md](docs/architecture/implementation-plan.md)
4. [docs/architecture/deployment-local.md](docs/architecture/deployment-local.md) 或 [docs/architecture/deployment-cloud.md](docs/architecture/deployment-cloud.md)
5. [docs/architecture/admin-new-api.md](docs/architecture/admin-new-api.md) 与 [docs/architecture/admin-librechat.md](docs/architecture/admin-librechat.md)
6. [docs/architecture/runbook.md](docs/architecture/runbook.md)
7. [docs/architecture/acceptance-criteria.md](docs/architecture/acceptance-criteria.md)
