# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 重要约束

- **本目录 `/home/lgq/repoWorkProject/TeamAIPlatform_main` 只允许在 `main` 分支上工作和提交**，不得切换到或提交 `hetbot-deploy` 等其他分支。
- 本机存在 `hetbot-deploy` 环境（容器名 `ai-gateway-*`）；本项目只能操作 `ai-gateway-main-*` 容器，禁止停止、删除、重建或改名 `ai-gateway-*` 容器。
- 本地环境端口采用相对 hetbot-deploy 的 `+1` 策略（LibreChat 3081、NEW-API 13001、Casdoor 18001）。
- 真实 `.env`、`deploy/env/local/.env`、`deploy/env/prod/.env` 必须保持 Git 忽略，不得提交。
- 协作者与自动化代理默认必须使用中文回复；代码、命令、路径、环境变量名保持原始技术写法。

## 项目概述

内部 AI 对话整合平台，架构：**上游模型 → NEW-API（网关） → LibreChat（UI） → 部门用户**。统一收口多个 AI 供应商 API（智谱、DeepSeek、阿里云百炼、Kimi、豆包、MiMo、MiniMax），通过 Casdoor OIDC 统一认证。

核心组件：NEW-API v0.12.1（API 网关）、LibreChat v0.8.5（聊天界面）、Casdoor v2.396.1（认证）、PostgreSQL 16、Redis 7.4.2、MongoDB 8.0.20、Caddy 2.10.0（可选 HTTPS 反代）。

## 目录结构

```
deploy/                   docker-compose.local.yml / prod.yml + 各服务配置
  librechat/config/       LibreChat 配置
  new-api/config/         NEW-API 配置
  proxy/config/           Caddy 反代配置
  env/                    环境变量模板（local/prod）
scripts/                  初始化、启停、bootstrap、健康检查、smoke test、备份恢复
tests/smoke/              smoke test 请求模板
docs/architecture/        需求、架构、部署、供应商接入、管理员手册等文档
runtime/                  运行期数据（不入库）
```

## 常用命令

```bash
make init                   # 初始化本地目录、复制 .env、生成随机密钥
make up / make down         # 启动/停止本地 compose
make restart                # 重启本地 compose
make bootstrap              # 初始化 NEW-API、限流、已启用供应商渠道、服务 token
make health                 # 检查 NEW-API 与 LibreChat 应用层健康
make smoke-zhipu            # 智谱主验收 smoke test（先跑 bootstrap）
make smoke-deepseek         # DeepSeek smoke test
make smoke-aliyun           # 阿里云百炼 smoke test
make smoke-kimi             # Kimi smoke test
make smoke-doubao           # 豆包 smoke test
make smoke-mimo             # MiMo smoke test
make smoke-minimax          # MiniMax smoke test
make sync-provider-models   # 检测供应商模型 API → 同步 NEW-API 渠道 → 重渲染 LibreChat 模型列表
make doctor                 # 诊断依赖、端口、env、compose 配置
make verify-no-secrets      # 扫描已入库文件检查密钥泄露
make backup / make restore  # 备份/恢复数据
```

改动配置或脚本后，至少运行 `make doctor` + `docker compose --env-file .env -f deploy/docker-compose.local.yml config`；涉及联调链路时加跑 `make health` 和对应供应商 `make smoke-*`。

## 架构要点

- **数据流**：用户 → Casdoor（OIDC 认证） → LibreChat（UI） → NEW-API（网关） → 供应商 API
- **渠道类型**：智谱用 NEW-API 原生 ZhipuV4 渠道（type=3），豆包用火山方舟原生渠道（type=45），其余供应商均用 OpenAI 兼容渠道（type=1）
- **LibreChat 端点**：按供应商拆分为 API-zhipu / API-deepseek / API-aliyun / API-kimi / API-doubao / API-mimo / API-minimax，底层共用同一个 NEW_API_SERVICE_TOKEN
- **模型同步**：`make sync-provider-models` 从供应商模型 API 动态刷新 `*_EXPOSED_MODEL`，按 `*_MODEL_ORDER` 高阶优先排序
- **每日 cron**：`make install-model-sync-cron` 安装每日模型同步定时任务（默认 04:17）
- **生产部署**：默认 direct-ip 直连端口模式；`COMPOSE_PROFILES=domain-proxy` 时启用 Caddy HTTPS 反代
- **资源约束**：生产 compose 按 Aliyun 2C2G（可用 ~1.6GB）收玫

## 编码规范

- 空格缩进；Markdown / YAML / JSON 默认 2 空格
- Shell 脚本使用 bash，文件名 kebab-case，环境变量全大写下划线风格（如 `ZHIPU_API_KEY`）
- 脚本必须保持幂等，不得把真实密钥写入仓库或日志
- 提交信息格式：`feat: ...`、`fix: ...`、`docs: ...`、`chore: ...`
- 容器镜像版本固定，不使用 `latest`

## CI

GitHub Actions 两个 workflow：
- `validate-compose.yml`：校验 compose 文件语法
- `lint-docs-or-basic-check.yml`：文档 lint 和基础检查
