# Repository Guidelines

## 项目结构与模块组织
根目录保留总入口文件：`README.md`、`Makefile`、`.env.example`。部署编排放在 `deploy/`，其中 `docker-compose.local.yml` 和 `docker-compose.prod.yml` 分别对应本地与生产；服务配置放在 `deploy/librechat/config/`、`deploy/new-api/config/`、`deploy/proxy/config/`。脚本统一放在 `scripts/`，文档放在 `docs/`，smoke 请求模板放在 `tests/smoke/`。运行期数据仅写入 `runtime/`，不得提交。

## 构建、测试与开发命令
- `make init`：生成本地 `.env`、随机密钥和运行目录。
- `make doctor`：检查 Docker、环境变量、端口和 compose 配置。
- `make up` / `make down` / `make restart`：启动、停止、重启本地环境。
- `make bootstrap`：初始化 `NEW-API`、限流、智谱渠道和服务 token。
- `make health`：检查 `NEW-API` 与 `LibreChat` 健康状态。
- `make smoke` / `make smoke-zhipu`：执行通用或智谱联调验证。

## 编码风格与命名
统一使用空格缩进；Markdown、YAML、JSON 默认 2 空格。Shell 脚本使用 `bash`，文件名采用 `kebab-case`，环境变量使用全大写下划线风格，例如 `ZHIPU_API_KEY`。修改脚本时优先保持幂等，避免把真实密钥写入仓库或日志。

## 测试与验收要求
任何配置或脚本改动后，至少运行 `make doctor` 与 `docker compose --env-file .env -f deploy/docker-compose.local.yml config`。涉及联调链路时，再执行 `make health` 和 `make smoke-zhipu`。新增测试资源放在 `tests/`，命名应直接体现行为，例如 `chat-completions.template.json`。

## 提交与合并请求
当前历史很短，沿用简短祈使句式提交信息，如 `feat: add zhipu bootstrap`、`docs: update local deployment guide`。PR 需说明改动范围、验证命令、是否涉及真实密钥，并在 UI 或入口变更时附上截图或访问说明。

## Agent 说明
本仓库协作者与自动化代理默认必须使用中文回复，包括进度说明、评审意见和最终总结。代码、命令、路径、环境变量名保持原始技术写法；除非维护者明确要求，说明性文字不要切换为英文。
