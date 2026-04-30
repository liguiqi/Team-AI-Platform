# AI Gateway Chat

基于 `NEW-API + LibreChat` 的内部 AI 对话整合仓库，目标是把公司采购的上游模型能力统一收口到 `NEW-API`，再由 `LibreChat` 提供部门同学使用的对话界面。本地默认入口为 `http://localhost:3080` 与 `http://localhost:13000`。

## 责任边界
- Codex 负责完整实施、结构整理、文档交付、脚本生成、配置模板、联调路径设计、自测与问题收敛。
- 用户Project Owner最后只负责验收。
- 用户会提供明确可用的智谱 API Key。
- 最终验收以智谱 API 渠道为主验收渠道。
- 除填写真实密钥和执行最终验收外，用户不负责补做工程集成。

## 架构
```text
智谱 / 其他上游模型
    -> NEW-API
    -> LibreChat
    -> 部门用户
```

本仓库默认采用：
- `NEW-API` 原生 `ZhipuV4` 渠道
- `LibreChat` 自定义 OpenAI 兼容端点接入 `NEW-API`
- `Docker Compose` 作为本地与单机生产的统一编排方式
- `Caddy` 作为生产反向代理

## 版本矩阵
- `calciumion/new-api:v0.12.1`
- `ghcr.io/danny-avila/librechat:v0.8.4`
- `postgres:16-alpine`
- `redis:7.4.2-alpine`
- `mongo:8.0.20`
- `caddy:2.10.0-alpine`

版本选择依据：
- `NEW-API v0.12.1` 来自官方 GitHub Release / Docker Hub tag。
- `LibreChat v0.8.4` 来自官方 Git tag 与 GHCR 镜像 tag。
- 其余基础镜像均固定为可用的明确版本，避免 `latest` 漂移。

## 快速开始
1. 复制环境文件并只填写真实智谱密钥：
   ```bash
   cp .env.example .env
   ```
   必填项：`ZHIPU_API_KEY`
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
5. 如果你后续在 `NEW-API` 后台调整了模型矩阵，或配置了 LibreChat 前端白名单，执行：
   ```bash
   make sync-librechat-models
   ```

说明：
- `make smoke-zhipu` 会调用 `scripts/bootstrap-new-api.sh`，自动完成 `NEW-API` 初始化、限流参数写入、智谱渠道创建、LibreChat 服务用户与 token 生成。
- bootstrap 过程会把自动生成的 `NEW_API_SERVICE_TOKEN` 回写到本地 `.env`，无需手工复制 token。

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
- `make bootstrap`：初始化 `NEW-API` 并配置智谱渠道。
- `make sync-librechat-models`：按当前 `NEW-API` 模型矩阵与前端白名单重渲染 LibreChat 模型列表。
- `make health`：检查 `NEW-API` 与 `LibreChat` 应用层健康状态。
- `make smoke`：执行通用 smoke test。
- `make smoke-zhipu`：执行智谱验收通道 smoke test。
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
ZHIPU_DEFAULT_MODEL=glm-4-flash
ZHIPU_TEST_MODEL=glm-4-flash
ZHIPU_EXPOSED_MODEL=zhipu-primary
```

本仓库默认把 `zhipu-primary -> glm-4-flash` 做成 `NEW-API` 模型映射，并让 LibreChat 通过 `NEW-API /v1/models` 动态获取当前可见模型，从而实现：
- 前端不直接持有官方采购密钥
- LibreChat 只看见 `NEW-API` 当前授权给服务 token 的模型
- NEW-API 可继续扩展其它上游而不改前端

`NEW-API` 的 `ZhipuV4` 渠道会自动补上 `/api/paas/v4`，所以 `ZHIPU_API_BASE_URL` 必须写成 `https://open.bigmodel.cn`，不要重复带完整路径。

## 模型同步说明
当前 LibreChat 支持两种模型展示方式：

- 全量动态同步：保持 `LIBRECHAT_FETCH_MODELS=true` 且 `LIBRECHAT_VISIBLE_MODELS=` 为空，前端将直接显示 `NEW-API /v1/models` 当前返回的模型集合。
- 前端白名单筛选：设置 `LIBRECHAT_VISIBLE_MODELS=glm-4-flash,glm-4-plus,glm-5` 这类逗号分隔列表后，前端只显示白名单与 `NEW-API` 实际模型集合的交集。

推荐默认策略：
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
- `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=false`
- `LIBRECHAT_FETCH_MODELS=true`
- `LIBRECHAT_VISIBLE_MODELS=` 留空

这样可以把 `NEW-API` 后台作为模型矩阵的主维护入口，而把 LibreChat 作为展示层。

## smoke test
- 通用检查：
  ```bash
  make smoke
  ```
- 智谱主验收通道：
  ```bash
  make smoke-zhipu
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
- NEW-API 管理员手册：[docs/architecture/admin-new-api.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-new-api.md)
- LibreChat 管理员手册：[docs/architecture/admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-librechat.md)
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
