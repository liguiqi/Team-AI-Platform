# 运行手册

## 文档目标
本文档面向值班运维、平台管理员和接手人员，提供日常巡检、故障排查、恢复、备份和常见操作的执行手册。建议与管理员手册一起使用。

## 日常巡检

### 每次上线后必须执行
```bash
make health
make smoke-zhipu
```

### 建议每日巡检项
- 检查容器是否都在 `Up` 状态
- 检查 `NEW-API` 和 LibreChat 首页是否可访问
- 检查磁盘空间，尤其是 `runtime/` 与 `backups/`
- 检查 `NEW-API` 是否还能成功调用智谱

## 快速健康检查

### 应用层健康检查
```bash
make health
```

检查内容：
- Compose 服务状态
- `NEW-API /api/status`
- `LibreChat /health`

### 主链路联调
```bash
make smoke-zhipu
```

检查内容：
- bootstrap
- 模型可见性
- 一次真实聊天调用

## 服务状态查看

### 本地
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml ps
```

### 生产
```bash
docker compose --env-file deploy/env/prod/.env -f deploy/docker-compose.prod.yml ps
```

## 日志查看

### NEW-API
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f new-api
```

### PostgreSQL
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f new-api-postgres
```

### Redis
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f new-api-redis
```

### LibreChat
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f librechat
```

### MongoDB
```bash
docker compose --env-file .env -f deploy/docker-compose.local.yml logs -f librechat-mongodb
```

## 标准排查顺序

当用户反馈“平台不可用”时，按以下顺序处理：

1. `make doctor`
2. `make health`
3. 查看 compose 状态
4. 看 `NEW-API` 日志
5. 看 LibreChat 日志
6. 视情况执行 `make bootstrap`
7. 再执行 `make smoke-zhipu`

这个顺序的目的是先判断是：
- 环境配置错误
- 容器没起来
- NEW-API 网关故障
- LibreChat 配置故障
- 智谱上游故障

## 常见故障场景

### 场景 1：NEW-API 后台打不开
排查：
1. `docker compose ... ps`
2. `curl http://localhost:13000/api/status`
3. 查看 `new-api`、`new-api-postgres`、`new-api-redis` 日志

常见原因：
- PostgreSQL 起不来
- Redis 密码配置错误
- 端口冲突

### 场景 2：LibreChat 页面能打开但无法聊天
排查：
1. `curl http://localhost:3080/health`
2. 查看 `runtime/local/librechat/librechat.yaml` 是否已渲染
3. 确认 `.env` 中有 `NEW_API_SERVICE_TOKEN`
4. 重新执行 `make bootstrap`
5. 再看 LibreChat 日志

### 场景 3：模型列表为空
排查：
1. 手工请求 `/v1/models`
2. 检查 `.env` 中 `NEW_API_TOKEN_MODEL_LIMITS_ENABLED` 是否误设为 `true`
3. 若配置了 `LIBRECHAT_VISIBLE_MODELS`，检查目标模型是否在白名单内
4. 执行 `make sync-librechat-models`
5. 再检查 `NEW-API` 后台渠道是否启用、模型映射与组别是否正确

### 场景 4：聊天请求返回 404
重点检查：
- `ZHIPU_API_BASE_URL` 是否误写为完整路径

### 场景 5：聊天请求返回额度不足
重点检查：
- 服务用户额度
- 服务 token 配额
- 是否有人在后台手工改动

## 重启建议

### 推荐重启顺序
1. PostgreSQL / Redis / MongoDB
2. NEW-API
3. LibreChat
4. Caddy（仅生产）

### 使用仓库脚本重启
```bash
make restart
```

说明：
- `make restart` 是全量重启，不是只重启单个服务。
- 若只想重启 LibreChat，建议直接使用 `docker compose restart librechat`。

## 备份与恢复

### 创建备份
```bash
make backup
```

当前备份内容包括：
- 环境变量文件
- `deploy/`
- `runtime/local` 或 `runtime/prod`

### 恢复备份
```bash
BACKUP_FILE=backups/xxx.tar.gz make restore
```

### 注意事项
- 当前备份是目录级打包，不是数据库一致性快照。
- 若对数据一致性要求高，建议在停机后执行备份，或结合底层存储快照。

## 何时需要重新执行 bootstrap

以下场景建议执行：
- 新机器首次部署
- `NEW_API_SERVICE_TOKEN` 丢失或失效
- 智谱 key 更换
- 管理员手工修改了服务用户、渠道或 token 后需要回归标准配置
- 用户反馈 `zhipu-primary` 不可用

命令：
```bash
make bootstrap
```

## 何时只需要同步 LibreChat 模型列表

以下场景通常不需要全量 bootstrap：
- 你只是在 `NEW-API` 后台新增或下线了模型
- 你只修改了 `.env` 中的 `LIBRECHAT_VISIBLE_MODELS`
- 你确认服务 token、渠道 key、root 账号均未变化

命令：
```bash
make sync-librechat-models
```

## 敏感信息检查

### 检查已纳入 Git 的文件
```bash
make verify-no-secrets
```

### 注意
- 这个脚本只扫描已经被 Git 跟踪的文件。
- `.env`、运行数据和备份包本来就不应该被跟踪。

## 升级后的最小回归
每次升级后至少执行：

```bash
make health
make smoke-zhipu
```

如果是生产环境：
- 再额外从浏览器验证一次 LibreChat 页面
- 再从 `NEW-API` 后台验证渠道、token、日志页可访问

## 建议搭配文档
遇到具体问题时，建议按职责边界补充阅读：

1. 前台页面、模型显示、上传与用户体验问题，优先看 [admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/admin-librechat.md)
2. 渠道、token、额度、限流、上游模型映射问题，优先看 [admin-new-api.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/admin-new-api.md)
3. 若需要回看整体设计，再看 [architecture.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture.md)
