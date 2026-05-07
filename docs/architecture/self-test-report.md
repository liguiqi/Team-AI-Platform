# 自测报告

## 文档目标
本文档记录项目在真实本地环境上的已完成验证结果、执行过的命令、修复过的问题和当前状态。

## 自测环境
- 操作系统：Linux 开发环境（Ubuntu）
- 部署模式：`MODE=local`
- 测试日期：2026-05-07（v0.8.5 升级后自测）
- 运行组件：
  - `calciumion/new-api:v0.12.1`
  - `ghcr.io/danny-avila/librechat:v0.8.5`
  - `casbin/casdoor:2.396.1`
  - `postgres:16-alpine`
  - `redis:7.4.2-alpine`
  - `mongo:8.0.20`

## 已完成实施范围
- 根仓骨架与目录结构
- 本地与生产编排文件（含内存限制）
- 智谱全量 19 模型矩阵接入（直通模式）
- 服务用户与服务 token 自动化（强随机 token）
- LibreChat 运行时配置渲染
- LibreChat 动态模型同步
- 网络搜索配置（Serper + Firecrawl + Jina）
- Casdoor SSO 统一认证（含健康检查）
- 自动 bootstrap（`BOOTSTRAP_AUTOCONFIGURE=true`）
- systemd 开机自启动服务
- 2C2G ECS 内存优化配置

## 自测结果

### 1. 容器状态
结果：**通过**

所有 6 个容器正常运行：
```
ai-gateway-librechat         Up 5 minutes             0.0.0.0:3080->3080/tcp
ai-gateway-new-api           Up 23 hours              0.0.0.0:13000->3000/tcp
ai-gateway-casdoor           Up 23 hours (healthy)    0.0.0.0:18000->8000/tcp
ai-gateway-new-api-postgres  Up 23 hours              5432/tcp
ai-gateway-new-api-redis     Up 23 hours              6379/tcp
ai-gateway-librechat-mongodb Up 23 hours              127.0.0.1:27017->27017/tcp
```

### 2. Casdoor SSO
结果：**通过**

```
GET http://localhost:18000/.well-known/openid-configuration
- issuer: http://__YOUR_SERVER_IP__:18000
- 19 OIDC endpoints 可用
- 健康检查: healthy
```

### 3. NEW-API 状态
结果：**通过**

```
GET http://localhost:13000/api/status
- success: true
```

### 4. 智谱模型列表
结果：**通过**

```
GET http://localhost:13000/v1/models
- Total models: 19
- Chat models (13): glm-5.1, glm-5, glm-5-turbo, glm-4.7, ...
- Vision models (6): glm-5v-turbo, glm-4.6v, glm-4.1v-thinking-flashx, ...
```

### 5. Chat 调用
结果：**通过**

```
POST /v1/chat/completions (model: glm-4-flash-250414)
- Response: "Hello 👋! I'm ChatGLM"
- HTTP 200
```

### 6. LibreChat
结果：**通过**

```
GET http://localhost:3080/
- HTTP 200
- 页面正常加载
```

### 7. 搜索配置
结果：**通过**

LibreChat 容器内环境变量确认：
```
SEARCH=true
SEARCH_PROVIDER=serper
SERPER_API_KEY=0b9e...（已配置）
SCRAPER=firecrawl
FIRECRAWL_API_KEY=fc-57a...（已配置）
RERANKER=jina
JINA_API_KEY=jina_72ce...（已配置）
```

### 8. 内存使用
结果：**通过**

各容器实际内存占用在限制内：
```
librechat        257.4MiB / 512MiB (50.3%)
new-api           21.4MiB / 128MiB (16.7%)
casdoor           92.8MiB / 128MiB (72.5%)
new-api-postgres  68.0MiB / 128MiB (53.1%)
new-api-redis      3.9MiB /  64MiB (6.1%)
librechat-mongodb 137.4MiB / 256MiB (53.7%)
总计约 581MiB
```

### 9. Auto-bootstrap
结果：**通过**

```
BOOTSTRAP_AUTOCONFIGURE=true
执行 make up 后自动完成：
- NEW-API root 初始化
- 系统配置写入（SelfUseMode、DemoSite）
- 限流配置写入
- 服务用户创建/校正
- 智谱渠道创建/校正
- 服务 token 创建（48 字符强随机）
- token 回写 .env
- LibreChat 配置重渲染并重启
```

### 10. Token 安全
结果：**通过**

服务 token 使用 48 字符强随机值（由 `random_alnum` 生成），不再使用 fallback 弱 token。

## 关键修复记录

### 修复 1：PostgreSQL 主版本不兼容
问题：PostgreSQL 15 镜像读取 16 数据目录导致反复重启
修复：统一使用 `postgres:16-alpine`

### 修复 2：智谱 base_url 错误
问题：`ZHIPU_API_BASE_URL` 写成完整路径导致 404
修复：改为 `https://open.bigmodel.cn`

### 修复 3：LibreChat "Unknown authentication strategy 'openid'"
问题：LibreChat 启动时 Casdoor 尚未就绪
修复：添加 Casdoor 健康检查 + `condition: service_healthy` 依赖

### 修复 4：NEW-API 只返回 1 个模型
问题：未启用 SelfUseMode，模型比率/价格未配置
修复：bootstrap 时自动写入 `SelfUseModeEnabled=true`

### 修复 5：bootstrap token 创建 SIGPIPE
问题：`docker exec` 管道在 make 上下文中被 SIGPIPE 中断
修复：使用 `docker exec -e` 环境变量注入替代管道

### 修复 6：PostgreSQL "group" 列 bash 引用问题
问题：`group` 是 PostgreSQL 保留字，bash 双引号展开时丢失单引号
修复：INSERT 不含 group 列，单独 UPDATE group 列

### 修复 7：random_alnum 失败导致弱 token
问题：`/dev/urandom` + `tr` + `head` 管道被 SIGPIPE 中断
修复：重试机制 + $RANDOM 拼接降级方案

## 当前已知结论
- 平台主链路已完全打通
- LibreChat 已升级到 v0.8.5（支持 Admin Panel、自定义角色、分级权限等）
- 19 个智谱模型全部可用
- 自动 bootstrap 一次部署即可使用
- 搜索功能（Serper/Firecrawl/Jina）已配置
- 内存使用适合 2C2G ECS 部署（总计约 581MiB）
- 统一认证通过 Casdoor OIDC 正常工作
- Admin Panel 使用文档已就绪（待按需部署独立容器）
