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
- `docs/architecture/requirements.md`
- `docs/architecture/architecture.md`
- `docs/architecture/acceptance-criteria.md`
- `docs/architecture/adr/0001-use-new-api-as-gateway.md`

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
- 自动写入项目内请求限流配置，默认关闭。
- 自动创建或校正服务用户。
- 自动创建或校正智谱渠道。
- 自动创建或校正 LibreChat 服务 token。

完成标准：
- `NEW-API /v1/models` 能返回当前授权模型集合，且至少包含 `zhipu-primary`
- `NEW-API /v1/chat/completions` 可真实调用智谱成功

### Phase 4：LibreChat 联调
目标：让最终用户入口真正可用。

主要工作：
- 固定 `LibreChat v0.8.5`
- 编写自定义端点模板
- 实现运行时配置渲染脚本 `render-librechat-config.sh`
- 调整 compose，挂载渲染后的真实配置文件

关键细节：
- 不能直接把带 `${...}` 的模板文件给容器使用。
- 服务 token 变更后必须自动重渲染并重启 LibreChat。
- LibreChat 默认按供应商拆分为 `API-zhipu` / `API-deepseek` / `API-aliyun` / `API-kimi` / `API-doubao` / `API-mimo` 端点。
- 若配置前端白名单，则只展示白名单与 `NEW-API` 模型集合的交集。
- LibreChat 不暴露真实上游模型名，只暴露平台批准的模型名或别名。

完成标准：
- LibreChat 可访问。
- LibreChat 已识别 `API-zhipu` / `API-deepseek` / `API-aliyun` / `API-kimi` / `API-doubao` / `API-mimo` 自定义端点。
- 最终用户可以在 UI 中按供应商看到当前授权模型。
- 管理员可通过 `make sync-provider-models` 同步供应商模型列表与前端模型列表。

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
- bootstrap 自动校正服务用户总额度为项目内不限额基准
- 同时保证服务 token 为 unlimited

### 问题 4：LibreChat "Unknown authentication strategy 'openid'"
表现：
- LibreChat 启动后日志报错，无法加载 OIDC 策略

根因：
- LibreChat 启动时 Casdoor 尚未就绪，OIDC 配置未加载

处理：
- 添加 Casdoor 健康检查（`/.well-known/openid-configuration`）
- LibreChat 依赖 Casdoor `condition: service_healthy`
- 增加 start_period 到 60s，首次启动给 Casdoor 足够时间初始化

### 问题 5：NEW-API 只返回 1 个模型
表现：
- `/v1/models` 只返回 `glm-4-long` 等单个模型

根因：
- 未启用 SelfUseMode，模型比率/价格未配置

处理：
- bootstrap 自动写入 `SelfUseModeEnabled=true`

### 问题 6：bootstrap token 创建 SIGPIPE
表现：
- `docker exec` 管道在 make 上下文中被 SIGPIPE 中断（exit 141）

处理：
- 使用 `docker exec -e` 环境变量注入替代管道
- INSERT 不含 group 列，单独 UPDATE group 列（避免 bash 引号问题）
- `random_alnum` 添加重试和降级机制

### 问题 7：Casdoor 首次启动 panic
表现：
- Casdoor panic: "Fail to delete application"

根因：
- 已有数据库数据与 init_data.json 冲突

处理：
- 清空 Casdoor 数据库后重新启动
- `DROP SCHEMA public CASCADE; CREATE SCHEMA public;`
表现：
- `NEW-API /api/user/login` 触发限流

处理：
- bootstrap 只做一次 root 登录
- 服务 token 改为通过 PostgreSQL 直连维护，避免第二次登录

### 问题 8：Casdoor 登录页主题与浏览器主题不一致
表现：
- 浏览器 dark / light 主题切换后，Casdoor 登录页背景、Logo 或语言选择器配色不协调

处理：
- 将 Casdoor 登录页样式统一收口到 `scripts/render-casdoor-config.sh`
- 通过 `formCss` 生成 light / dark 自适应样式
- 同时移除 `WebAuthn` / `Face ID` 登录方式，保持登录面板简洁

### 问题 9：LibreChat 重启后 OIDC 需要重复登录
表现：
- Casdoor 认证成功后先落到错误页，再做一次统一认证才能进入聊天页

处理：
- 为 LibreChat 启用 RedisStore，持久化 OIDC state / session
- 在运行时 patch 中增加 stale callback 自动重试逻辑
- 让 local / prod compose 都统一接入 `new-api-redis` 的 DB 1

### 问题 10：多供应商模型入口混杂
表现：
- LibreChat 模型选择中不同上游模型混在单一 `NEW-API` 入口下

处理：
- 使用 `provider_prefixes()` 管理 `ZHIPU`、`DEEPSEEK`、`ALIYUN`、`KIMI`、`DOUBAO`、`MIMO`
- LibreChat 渲染为 `API-zhipu`、`API-deepseek`、`API-aliyun`、`API-kimi`、`API-doubao`、`API-mimo`
- `scripts/sync-provider-models.sh` 每日检测供应商模型 API 并按 `*_MODEL_ORDER` 高阶优先排序

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
- M6：网络搜索配置完成（Serper + Firecrawl + Jina）。
- M7：智谱全量 19 模型矩阵接入完成。
- M8：自动 bootstrap 完成（一键部署）。
- M9：systemd 开机自启动完成。
- M10：2C2G ECS 内存优化完成。
- M11：多供应商可扩展文档完成。
- M12：Casdoor 登录页 light / dark 自适应与登录方式收敛完成。
- M13：LibreChat OIDC Redis session 持久化与 stale callback 自动恢复完成。
- M14：Admin Panel 本地集成与文档刷新完成。
