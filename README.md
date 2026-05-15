# AI Gateway Chat

基于 `NEW-API + LibreChat` 的内部 AI 对话整合仓库，目标是把公司采购的上游模型能力统一收口到 `NEW-API`，再由 `LibreChat` 提供部门同学使用的对话界面。本地默认入口为 `http://localhost:3080` 与 `http://localhost:13000`。

## 责任边界
- Codex 负责完整实施、结构整理、文档交付、脚本生成、配置模板、联调路径设计、自测与问题收敛。
- 用户Project Owner最后只负责验收。
- 用户会提供明确可用的智谱、DeepSeek 或阿里云百炼 API Key。
- 最终验收以智谱 API 渠道为主验收渠道。
- 除填写真实密钥和执行最终验收外，用户不负责补做工程集成。

## 架构
```text
智谱 / DeepSeek / 阿里云百炼 / 其他上游模型
    -> NEW-API
    -> LibreChat
    -> 部门用户
```

本仓库默认采用：
- `NEW-API` 原生 `ZhipuV4` 渠道 + DeepSeek / 阿里云百炼 OpenAI 兼容渠道
- `LibreChat` 自定义 OpenAI 兼容端点按供应商拆分为 `API-zhipu` / `API-deepseek` / `API-aliyun`，底层仍统一走 `NEW-API`
- `Docker Compose` 作为本地与单机生产的统一编排方式
- `Caddy` 作为生产反向代理

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
- 其余基础镜像均固定为可用的明确版本，避免 `latest` 漂移。

## 快速开始
1. 复制环境文件并填写至少一组真实上游密钥：
   ```bash
   cp .env.example .env
   ```
   必填项：`ZHIPU_API_KEY`、`DEEPSEEK_API_KEY` 或 `ALIYUN_API_KEY`
   如果当前只想接 DeepSeek 或阿里云百炼，不再使用智谱，请同时把 `ZHIPU_ENABLED=false`。
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
5. 如果你后续调整了上游模型矩阵，或配置了 LibreChat 前端白名单，执行：
   ```bash
   make sync-provider-models
   ```

说明：
- `make smoke-zhipu` / `make smoke-deepseek` / `make smoke-aliyun` 都会先调用 `scripts/bootstrap-new-api.sh`，自动完成 `NEW-API` 初始化、限流参数写入、已启用供应商渠道创建、LibreChat 服务用户与 token 生成。
- bootstrap 过程会把自动生成的 `NEW_API_SERVICE_TOKEN` 回写到本地 `.env`，无需手工复制 token。
- 本地 compose 当前默认带上 `LibreChat Admin Panel`，入口为 `http://localhost:3001`。
- LibreChat 的 OIDC state / session 当前持久化到 `new-api-redis` 的 DB 1，重启后不会再因为内存 session 丢失而要求重复登录。
- Casdoor 登录页样式由脚本渲染并随浏览器 `light/dark` 主题自适应。
- 当 `ZHIPU_ENABLED=true`、`DEEPSEEK_ENABLED=true`、`ALIYUN_ENABLED=true` 同时开启时，`make bootstrap` 会同时创建/更新 `zhipu-primary`、`deepseek-primary` 与 `aliyun-bailian-primary` 渠道；LibreChat 展示为 `API-zhipu` / `API-deepseek` / `API-aliyun` 三个入口，底层共用同一个 `NEW_API_SERVICE_TOKEN`。

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
- `make sync-provider-models`：检测供应商模型 API、同步 `NEW-API` 渠道并重渲染 LibreChat 模型列表。
- `make sync-librechat-models`：兼容入口，默认会调用 `make sync-provider-models` 等价逻辑。
- `make health`：检查 `NEW-API` 与 `LibreChat` 应用层健康状态。
- `make smoke`：执行通用 smoke test。
- `make smoke-zhipu`：执行智谱验收通道 smoke test。
- `make smoke-deepseek`：执行 DeepSeek 验收通道 smoke test。
- `make smoke-aliyun`：执行阿里云百炼验收通道 smoke test。
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

## 模型同步说明
当前默认策略是按供应商拆分 LibreChat 模型入口：

- `API-zhipu`：只显示智谱模型，并按 `ZHIPU_MODEL_ORDER` 高阶优先排序。
- `API-deepseek`：只显示 DeepSeek 模型，并按 `DEEPSEEK_MODEL_ORDER` 高阶优先排序。
- `API-aliyun`：只显示阿里云百炼模型，并按 `ALIYUN_MODEL_ORDER` 高阶优先排序。
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
- 应用层健康检查：
  ```bash
  make health
  ```

## 常见入口
- 需求说明：[docs/architecture/requirements.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/requirements.md)
- 架构说明：[docs/architecture/architecture.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/architecture.md)
- 实施计划：[docs/architecture/implementation-plan.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/implementation-plan.md)
- 本地部署说明：[docs/architecture/deployment-local.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/deployment-local.md)
- 云端部署说明：[docs/architecture/deployment-cloud.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/deployment-cloud.md)
- 智谱接入说明：[docs/architecture/provider-zhipu.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/provider-zhipu.md)
- DeepSeek 接入说明：[docs/architecture/provider-deepseek.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/provider-deepseek.md)
- 阿里云百炼接入说明：[docs/architecture/provider-aliyun.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/provider-aliyun.md)
- NEW-API 管理员手册：[docs/architecture/admin-new-api.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-new-api.md)
- LibreChat 管理员手册：[docs/architecture/admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-librechat.md)
- Admin Panel 管理说明：[docs/architecture/admin-panel.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-panel.md)
- 运行手册：[docs/architecture/runbook.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/runbook.md)
- 验收标准：[docs/architecture/acceptance-criteria.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/acceptance-criteria.md)
- 自测报告：[docs/architecture/self-test-report.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/self-test-report.md)

## 建议阅读顺序
如果你是第一次接手本项目，建议按下面顺序阅读：

1. [docs/architecture/requirements.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/requirements.md)
2. [docs/architecture/architecture.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/architecture.md)
3. [docs/architecture/implementation-plan.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/implementation-plan.md)
4. [docs/architecture/deployment-local.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/deployment-local.md) 或 [docs/architecture/deployment-cloud.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/deployment-cloud.md)
5. [docs/architecture/admin-new-api.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-new-api.md) 与 [docs/architecture/admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-librechat.md)
6. [docs/architecture/runbook.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/runbook.md)
7. [docs/architecture/acceptance-criteria.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/acceptance-criteria.md)
