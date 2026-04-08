# 实施计划

## 文档目的
本文档记录项目从空仓到可验收平台的实施分解、阶段输出、依赖关系和风险控制方式。它既可作为复盘文档，也可供后续二次建设时参照。

## 总体实施策略
本项目采用“先跑通主链路，再补齐治理与文档”的策略，优先级如下：

1. 打通 `NEW-API -> 智谱` 主链路。
2. 打通 `LibreChat -> NEW-API` 用户入口链路。
3. 补齐脚本化初始化、联调、健康检查与恢复。
4. 最后补齐管理员使用、运维和验收文档。

## 阶段拆分

### Phase 0：需求冻结与技术路线确认
目标：先把“做什么、不做什么、为什么这样做”写清楚，避免后续边写边改架构。

主要产出：
- `docs/requirements.md`
- `docs/architecture.md`
- `docs/acceptance-criteria.md`
- `docs/adr/0001-use-new-api-as-gateway.md`

完成标准：
- 确认首期验收通道为智谱。
- 确认使用 `NEW-API + LibreChat`，不自研前后端。
- 确认本地与生产都采用 Docker Compose。

### Phase 1：根仓骨架搭建
目标：建立清晰的仓库结构和统一入口。

主要工作：
- 建立 `docs/`、`deploy/`、`scripts/`、`tests/`、`.github/`
- 补齐 `.gitignore`、`.env.example`、`Makefile`、`README.md`
- 约定 `runtime/` 为运行时目录，不纳入 Git

完成标准：
- 仓库结构完整。
- 常见操作可通过 `make` 入口触发。

### Phase 2：本地编排落地
目标：让核心组件能在本机稳定启动。

主要工作：
- 编写 [deploy/docker-compose.local.yml](/home/lgq/repoWorkProject/TeamAIPlatform/deploy/docker-compose.local.yml)
- 设计 `runtime/local/` 持久化目录
- 实现 `init/up/down/restart`
- 解决 PostgreSQL 与 Redis 的基础依赖

完成标准：
- `make init` 可生成本地环境并校验 compose。
- `make up` 可启动本地核心服务。

### Phase 3：NEW-API 接入智谱
目标：让平台真正具备模型调用能力。

主要工作：
- 固定 `NEW-API v0.12.1`
- 固定智谱渠道类型 `26`（`ZhipuV4`）
- 编写智谱渠道模板、服务 token 模板、限流模板
- 编写 `bootstrap-new-api.sh`

关键细节：
- 自动初始化 root 管理员。
- 自动写入模型请求限流。
- 自动创建或校正服务用户。
- 自动创建或校正智谱渠道。
- 自动创建或校正 LibreChat 服务 token。

完成标准：
- `NEW-API /v1/models` 能返回当前授权模型集合，且至少包含 `zhipu-primary`
- `NEW-API /v1/chat/completions` 可真实调用智谱成功

### Phase 4：LibreChat 联调
目标：让最终用户入口真正可用。

主要工作：
- 固定 `LibreChat v0.8.4`
- 编写自定义端点模板
- 实现运行时配置渲染脚本 `render-librechat-config.sh`
- 调整 compose，挂载渲染后的真实配置文件

关键细节：
- 不能直接把带 `${...}` 的模板文件给容器使用。
- 服务 token 变更后必须自动重渲染并重启 LibreChat。
- LibreChat 默认从 `NEW-API /v1/models` 动态拉取模型。
- 若配置前端白名单，则只展示白名单与 `NEW-API` 模型集合的交集。
- LibreChat 不暴露真实上游模型名，只暴露平台批准的模型名或别名。

完成标准：
- LibreChat 可访问。
- LibreChat 已识别 `NEW-API` 自定义端点。
- 最终用户可以在 UI 中看到 `NEW-API` 当前授权模型。
- 管理员可通过 `make sync-librechat-models` 单独同步前端模型列表。

### Phase 5：治理、运维与验收
目标：让平台从“能跑”变成“可交付、可验收、可接手”。

主要工作：
- 编写 `doctor`、`healthcheck`、`smoke-test`、`smoke-test-zhipu`
- 编写 `sync-librechat-models`
- 编写 `backup` 与 `restore`
- 编写 `verify-no-secrets`
- 记录真实自测报告
- 补齐管理员使用和运维文档

完成标准：
- 主链路联调可脚本化执行。
- 基本故障可按文档排查。
- 验收人只需按步骤执行，不需要补工程细节。

## 实施中的关键问题与处理

### 问题 1：PostgreSQL 数据目录版本不兼容
表现：
- 容器反复重启。
- 日志提示 PostgreSQL 15 无法使用由 16 初始化的数据目录。

处理：
- 将本地运行版本统一回 `postgres:16-alpine`
- 保证镜像版本与数据目录初始化版本一致

### 问题 2：智谱渠道返回 404
表现：
- `chat/completions` 返回 `404 Not Found`

根因：
- `NEW-API` 的 `ZhipuV4` 渠道会自动补 `/api/paas/v4`
- 若 `base_url` 也手工写完整路径，会造成重复拼接

处理：
- 将 `ZHIPU_API_BASE_URL` 修正为 `https://open.bigmodel.cn`

### 问题 3：服务用户额度不足
表现：
- `insufficient_user_quota`

处理：
- bootstrap 自动校正服务用户总额度
- 同时保证服务 token 配额与用户额度一致

### 问题 4：bootstrap 二次登录受限
表现：
- `NEW-API /api/user/login` 触发限流

处理：
- bootstrap 只做一次 root 登录
- 服务 token 改为通过 PostgreSQL 直连维护，避免第二次登录

## 依赖关系
- `.env` 与真实 `ZHIPU_API_KEY` 先于真实 smoke test。
- Compose 启动先于 bootstrap。
- bootstrap 先于 LibreChat 最终可用。
- LibreChat 配置渲染先于 `docker compose up`。
- 生产证书签发依赖 DNS 与公网连通性。

## 风险控制
- 固定镜像版本，避免上游 `latest` 漂移。
- 使用脚本代替人工后台点击，降低重复错误。
- 关键配置回写 `.env`，减少多份配置分叉。
- 用自测报告固化真实联调结果。

## 当前里程碑状态
- M1：文档和骨架完成。
- M2：本地 Compose 启动完成。
- M3：智谱主链路打通完成。
- M4：LibreChat 接入与动态模型同步完成。
- M5：自测与验收资料完成。
