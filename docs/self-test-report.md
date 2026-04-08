# 自测报告

## 文档目标
本文档记录项目在真实本地环境上的已完成验证结果、执行过的命令、修复过的问题和剩余注意事项。它不是模板，而是本次交付的真实自测记录。

## 自测责任说明
- Codex 已完成本项目实施、联调、自测与问题收敛。
- 用户Project Owner最后只负责执行人工验收。
- 文档更新时间可晚于真实联调时间，但命令结果均来自实际执行。

## 自测环境
- 操作系统：Linux 开发环境
- 部署模式：`MODE=local`
- 运行组件：
  - `calciumion/new-api:v0.12.1`
  - `ghcr.io/danny-avila/librechat:v0.8.4`
  - `postgres:16-alpine`
  - `redis:7.4.2-alpine`
  - `mongo:8.0.20`

## 已完成实施范围
- 根仓骨架与目录结构
- `README`、`docs`、`compose`、环境变量模板
- 本地与生产编排文件
- 智谱 `ZhipuV4` 渠道接入
- 服务用户与服务 token 自动化
- LibreChat 运行时配置渲染
- LibreChat 动态模型同步与前端白名单筛选
- 健康检查、smoke test、诊断、备份恢复、敏感信息扫描脚本

## 实际执行过的验证命令
- `bash scripts/doctor.sh`
- `docker compose --env-file .env -f deploy/docker-compose.local.yml config`
- `docker compose --env-file deploy/env/prod/.env.example -f deploy/docker-compose.prod.yml config`
- `bash scripts/healthcheck.sh`
- `bash scripts/smoke-test-zhipu.sh`
- `bash scripts/smoke-test.sh`
- `bash scripts/sync-librechat-models.sh`

## 自测结果

### 1. doctor
结果：通过

说明：
- compose 配置可被正确解析
- 若端口已被已启动服务占用，会给出警告而不是误判失败

### 2. local compose config
结果：通过

说明：
- `.env` 与 [deploy/docker-compose.local.yml](/home/lgq/repoWorkProject/TeamAIPlatform/deploy/docker-compose.local.yml) 一致
- 本地编排文件没有语法错误

### 3. prod compose config
结果：通过

说明：
- 生产模板变量齐全
- [deploy/docker-compose.prod.yml](/home/lgq/repoWorkProject/TeamAIPlatform/deploy/docker-compose.prod.yml) 可被正确解析

### 4. healthcheck
结果：通过

实际含义：
- `NEW-API /api/status` 可访问
- LibreChat `/health` 返回 `OK`
- 核心容器都已正常启动

### 5. 智谱 smoke
结果：通过

实际含义：
- bootstrap 可成功执行
- `NEW-API /v1/models` 返回当前授权模型集合，包含 `zhipu-primary`
- `NEW-API /v1/chat/completions` 真实调用智谱成功
- `zhipu-primary -> glm-4-flash` 映射生效

### 6. 通用 smoke
结果：通过

实际含义：
- 健康检查和主链路 smoke 形成闭环

### 7. LibreChat 模型同步
结果：通过

实际含义：
- `make sync-librechat-models` 可成功执行
- LibreChat 会按当前配置重渲染运行时模型列表
- 当前默认模式下，前端模型源为 `NEW-API /v1/models`
- 当配置 `LIBRECHAT_VISIBLE_MODELS` 时，可切换为前端白名单筛选模式
- 实测中把 `LIBRECHAT_VISIBLE_MODELS` 临时设置为 `glm-4-flash,glm-5,not-exist`
- 渲染结果只保留 `glm-4-flash` 与 `glm-5`，并自动跳过不存在的 `not-exist`

## 关键联调证据
- `GET /v1/models` 返回多模型集合，包含 `zhipu-primary`
- `POST /v1/chat/completions` 返回 `HTTP 200`
- 返回体中包含 `choices`
- 实际返回的 `model` 为 `glm-4-flash`
- 返回内容示例包含：
  - `OK`
  - “当前请求已通过 NEW-API 转发。”
- LibreChat `/health` 返回 `OK`
- LibreChat `/api/endpoints` 返回自定义端点 `NEW-API`

## 本轮关键修复

### 修复 1：PostgreSQL 主版本不兼容
问题：
- 运行中出现 PostgreSQL 15 镜像读取 PostgreSQL 16 数据目录
- 导致数据库反复重启

修复：
- 统一回到 `postgres:16-alpine`

### 修复 2：智谱 base_url 错误
问题：
- `ZHIPU_API_BASE_URL` 写成完整 `/api/paas/v4`
- 实际请求被重复拼接，返回 `404`

修复：
- 改为 `https://open.bigmodel.cn`

### 修复 3：服务用户额度不足
问题：
- `NEW-API` 返回 `insufficient_user_quota`

修复：
- bootstrap 自动校正服务用户额度

### 修复 4：bootstrap 第二次登录限流
问题：
- `NEW-API /api/user/login` 对连续登录有限流

修复：
- bootstrap 改为仅 root 登录一次
- 服务 token 改为通过 PostgreSQL 直连维护

### 修复 5：LibreChat 配置未渲染
问题：
- 直接挂载模板文件时，容器内部拿到的是 `${...}` 占位符

修复：
- 新增 `scripts/render-librechat-config.sh`
- 运行时渲染真实 `librechat.yaml`

### 修复 6：LibreChat 只能看到单模型
问题：
- 前端模型列表过于依赖静态配置
- `bootstrap` 会把服务 token 与渠道模型范围收窄回单模型

修复：
- 默认开启 `NEW-API /v1/models` 动态同步
- 默认关闭 token 单模型白名单
- 默认保留后台现有模型矩阵
- 新增 `scripts/sync-librechat-models.sh`
- 支持 `LIBRECHAT_VISIBLE_MODELS` 前端白名单筛选

## 当前已知结论
- 平台主链路已打通。
- 验收人不需要手工去后台补渠道或 token。
- 前端模型展示已经与 `NEW-API` 模型矩阵解耦为“动态同步 + 可选白名单”模式。
- 只要 `ZHIPU_API_KEY` 有效，按文档即可完成最终验收。

## 剩余说明
- LibreChat 的最终人工发言测试仍保留为验收步骤。
- `.env` 中实际使用过真实智谱 key 做联调，但未纳入 Git 跟踪。
- 文档更新可能晚于最初联调日期，但不影响已验证结论。
