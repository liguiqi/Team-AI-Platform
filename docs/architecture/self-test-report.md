# 自测报告

## 文档目标
本文档记录项目在真实本地环境上的已完成验证结果、执行过的命令、修复过的问题和当前状态。

## 自测环境
- 操作系统：Linux 开发环境（Ubuntu）
- 部署模式：`MODE=local`
- 测试日期：2026-05-15（登录页样式、OIDC 重启恢复、DeepSeek、阿里云百炼、Kimi 与火山方舟豆包接入后复测）
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
- 智谱模型矩阵接入（直通模式）
- DeepSeek 官方模型矩阵接入（OpenAI 兼容模式）
- 阿里云百炼 DashScope 模型矩阵接入（OpenAI 兼容模式）
- Kimi 开放平台模型矩阵接入（OpenAI 兼容模式）
- 火山方舟豆包模型矩阵接入（NEW-API VolcEngine 原生适配器）
- 服务用户与服务 token 自动化（强随机 token）
- LibreChat 运行时配置渲染
- LibreChat 动态模型同步
- 网络搜索配置（Serper + Firecrawl + Jina）
- Casdoor SSO 统一认证（含健康检查）
- LibreChat OIDC state / session 持久化到 Redis DB 1
- Casdoor 登录页 light / dark 自适应与语言选择器样式统一
- 本地 Admin Panel 集成
- 自动 bootstrap（`BOOTSTRAP_AUTOCONFIGURE=true`）
- systemd 开机自启动服务
- 2C2G ECS 内存优化配置

## 自测结果

### 1. 容器状态
结果：**通过**

所有 7 个容器正常运行：
```
ai-gateway-librechat         Up                      0.0.0.0:3080->3080/tcp
ai-gateway-librechat-admin   Up                      0.0.0.0:3001->3000/tcp
ai-gateway-new-api           Up                      0.0.0.0:13000->3000/tcp
ai-gateway-casdoor           Up (healthy)            0.0.0.0:18000->8000/tcp
ai-gateway-new-api-postgres  Up                      5432/tcp
ai-gateway-new-api-redis     Up                      6379/tcp
ai-gateway-librechat-mongodb Up                      127.0.0.1:27017->27017/tcp
```

### 2. Casdoor SSO
结果：**通过**

```
GET http://localhost:18000/.well-known/openid-configuration
- issuer: http://__YOUR_SERVER_IP__:18000
- 19 OIDC endpoints 可用
- 健康检查: healthy
- 登录页支持浏览器 light / dark 自适应
- 登录方式仅保留 Password / Verification code
```

### 2.1 OIDC 重启恢复
结果：**通过**

```
- LibreChat 使用 RedisStore 保存 OIDC state / session
- Redis DB 1 中存在 librechat 前缀 session key
- LibreChat recreate 后旧 session key 仍可见
- 浏览器命中旧 callback 时会自动 302 回 /oauth/openid
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
POST /v1/chat/completions (model: glm-5.1 / deepseek-v4-flash / qwen-plus / kimi-k2.6)
- Response: 包含 choices
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
librechat         223.5MiB / 512MiB (43.65%)
librechat-admin    79.86MiB / 256MiB (31.20%)
new-api            43.95MiB / 128MiB (34.34%)
casdoor            70.31MiB / 128MiB (54.93%)
new-api-postgres  116.7MiB / 128MiB (91.20%)
new-api-redis       8.91MiB /  64MiB (13.93%)
librechat-mongodb 106.9MiB / 256MiB (41.77%)
总计约 650MiB
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

### 11. 阿里云百炼接入
结果：**通过**

```
make sync-provider-models
- 阿里云百炼模型 API 检测完成
- ALIYUN_EXPOSED_MODEL 已按 chat 模型规则过滤并按高阶优先排序

make smoke-aliyun
- 创建/更新 aliyun-bailian-primary 渠道
- 渠道 balance 校正为 999999999999
- model_mapping 校正为 {}
- 使用 qwen-plus 完成真实 chat/completions 调用

runtime/local/librechat/librechat.yaml
- 已渲染 API-zhipu
- 已渲染 API-deepseek
- 已渲染 API-aliyun
```

### 12. Kimi 接入
结果：**通过**

```
make sync-provider-models
- Kimi 模型 API 检测完成
- KIMI_EXPOSED_MODEL 已按 chat 模型规则过滤并按高阶优先排序

make smoke-kimi
- 创建/更新 kimi-primary 渠道
- 渠道 balance 校正为 999999999999
- model_mapping 校正为 {}
- 使用 kimi-k2.6 完成真实 chat/completions 调用

runtime/local/librechat/librechat.yaml
- 已渲染 API-kimi
```

### 13. 火山方舟豆包接入
结果：**渠道与模型同步通过；真实 chat 受上游模型开通状态阻塞**

```
make sync-provider-models
- 火山方舟豆包模型 API 检测完成
- DOUBAO_EXPOSED_MODEL 已按 chat 模型规则过滤并按高阶优先排序

make smoke-doubao
- 创建/更新 doubao-primary 渠道
- 渠道 type=45，base_url=https://ark.cn-beijing.volces.com
- 渠道 balance 校正为 999999999999
- model_mapping 校正为 {}
- NEW-API /v1/models 已返回豆包模型
- runtime/local/librechat/librechat.yaml 已渲染 API-doubao
- chat/completions 已到达火山方舟上游，但当前 API key 账号未开通测试模型，返回 ModelNotOpen
```

补充结论：
- 当前项目侧转发链路和 LibreChat 分组已完成
- 火山方舟账号侧需开通目标模型服务，或将 `DOUBAO_TEST_MODEL` / `DOUBAO_EXPOSED_MODEL` 配置为控制台可调用的 `ep-*` 推理接入点

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
- 智谱、DeepSeek、阿里云百炼、Kimi 与火山方舟豆包模型按供应商分组可见；豆包真实 chat 需先在火山方舟账号侧开通模型服务或配置推理接入点
- 自动 bootstrap 一次部署即可使用
- 搜索功能（Serper/Firecrawl/Jina）已配置
- 内存使用适合 2C2G ECS 部署（总计约 650MiB）
- 统一认证通过 Casdoor OIDC 正常工作
- Admin Panel 已在本地 compose 中集成，生产仍按需扩展
- LibreChat 重启后，OIDC state 不再因内存 session 丢失而强制用户二次登录
