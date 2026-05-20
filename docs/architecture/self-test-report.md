# 自测报告

## 文档目标
本文档记录项目在真实本地环境上的已完成验证结果、执行过的命令、修复过的问题和当前状态。

## 自测环境
- 操作系统：Linux 开发环境（Ubuntu）
- 部署模式：`MODE=local`
- 测试日期：2026-05-20（main 本机隔离部署、API key 本地注入、脱敏提交准备、2C2G 配置复核后复测）
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
- 小米 MiMo 模型矩阵接入（OpenAI 兼容模式）
- MiniMax 模型矩阵接入（OpenAI 兼容模式）
- 服务用户与服务 token 自动化（强随机 token）
- LibreChat 运行时配置渲染
- LibreChat 动态模型同步
- 网络搜索配置（Serper + Firecrawl + Jina）
- Casdoor SSO 统一认证（含健康检查）
- LibreChat OIDC state / session 持久化到 Redis DB 1
- Casdoor 登录页 light / dark 自适应与语言选择器样式统一
- 手机号注册用户在 LibreChat 用户菜单中显示手机号而非内部 synthetic email
- 本地 Admin Panel 集成
- LibreChat 默认 ADMIN 用户初始化
- 第一个非默认注册用户自动 ADMIN 提权
- 自动 bootstrap（`BOOTSTRAP_AUTOCONFIGURE=true`）
- systemd 开机自启动服务
- 2C2G ECS 内存优化配置

## 自测结果

### 1. 容器状态
结果：**通过**

main 本机隔离环境所有 7 个核心容器正常运行，容器名统一为 `ai-gateway-main-*`：
```
ai-gateway-main-librechat           Up                      0.0.0.0:3081->3080/tcp
ai-gateway-main-librechat-admin     Up (healthy)            0.0.0.0:3003->3000/tcp
ai-gateway-main-new-api             Up                      0.0.0.0:13001->3000/tcp
ai-gateway-main-casdoor             Up (healthy)            0.0.0.0:18001->8000/tcp
ai-gateway-main-new-api-postgres    Up (healthy)            5432/tcp
ai-gateway-main-new-api-redis       Up (healthy)            6379/tcp
ai-gateway-main-librechat-mongodb   Up (healthy)            127.0.0.1:27018->27017/tcp
```

### 2. Casdoor SSO
结果：**通过**

```
GET http://localhost:18001/.well-known/openid-configuration
- issuer: http://__YOUR_SERVER_IP__:18001
- 19 OIDC endpoints 可用
- 健康检查: healthy
- 登录页支持浏览器 light / dark 自适应
- 登录页与注册页默认语言: zh
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
GET http://localhost:13001/api/status
- success: true
```

### 4. 智谱模型列表
结果：**通过**

```
GET http://localhost:13001/v1/models
- Total models: 19
- Chat models (13): glm-5.1, glm-5, glm-5-turbo, glm-4.7, ...
- Vision models (6): glm-5v-turbo, glm-4.6v, glm-4.1v-thinking-flashx, ...
```

### 5. Chat 调用
结果：**通过**

```
POST /v1/chat/completions (model: glm-5.1 / deepseek-v4-flash / qwen-plus / kimi-k2.6 / MiniMax-M2.7)
- Response: 包含 choices
- HTTP 200
```

### 6. LibreChat
结果：**通过**

```
GET http://localhost:3081/
- HTTP 200
- 页面正常加载
```

### 7. 搜索配置
结果：**通过**

LibreChat 容器内环境变量确认：
```
SEARCH=true
SEARCH_PROVIDER=serper
SERPER_API_KEY=已配置（不在文档记录明文）
SCRAPER=firecrawl
FIRECRAWL_API_KEY=已配置（不在文档记录明文）
RERANKER=jina
JINA_API_KEY=已配置（不在文档记录明文）
```

### 8. 内存使用
结果：**通过**

各容器实际内存占用在限制内：
```
ai-gateway-main-librechat           280.8MiB / 352MiB (79.78%)
ai-gateway-main-librechat-admin     114.2MiB / 192MiB (59.49%)
ai-gateway-main-casdoor              27.2MiB /  96MiB (28.30%)
ai-gateway-main-new-api              21.8MiB /  96MiB (22.66%)
ai-gateway-main-new-api-postgres     40.6MiB /  80MiB (50.69%)
ai-gateway-main-new-api-redis         6.1MiB /  40MiB (15.35%)
ai-gateway-main-librechat-mongodb    61.5MiB / 320MiB (19.20%)
本地含 Admin Panel 总计约 553MiB；生产 compose 默认不启用 Admin Panel，按同类负载估算核心服务约 439MiB。
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

### 14. 小米 MiMo 接入
结果：**通过**

```
make sync-provider-models
- 小米 MiMo 模型 API 检测完成
- MIMO_EXPOSED_MODEL 已过滤 TTS / voiceclone / voicedesign 等非普通 chat 模型，并按高阶优先排序

make smoke-mimo
- 创建/更新 mimo-primary 渠道
- 渠道 type=1，base_url=https://api.xiaomimimo.com
- 渠道 balance 校正为 999999999999
- model_mapping 校正为 {}
- 使用 mimo-v2.5-pro 完成真实 chat/completions 调用

runtime/local/librechat/librechat.yaml
- 已渲染 API-mimo
```

### 15. MiniMax 接入
结果：**通过**

```
make sync-provider-models
- MiniMax 模型 API 检测完成
- MINIMAX_EXPOSED_MODEL 已按高阶优先顺序同步为 MiniMax-M2.7, MiniMax-M2.7-highspeed, MiniMax-M2.5, MiniMax-M2.5-highspeed, MiniMax-M2.1, MiniMax-M2.1-highspeed, MiniMax-M2

make smoke-minimax
- 创建/更新 minimax-primary 渠道
- 渠道 type=1，base_url=https://api.minimaxi.com
- 渠道 balance 校正为 999999999999
- model_mapping 校正为 {}
- 使用 MiniMax-M2.7 完成真实 chat/completions 调用

runtime/local/librechat/librechat.yaml
- 已渲染 API-minimax
```

### 16. LibreChat 默认管理员与 Admin Panel 登录
结果：**通过**

```
make bootstrap-librechat-admin
- 创建或校正默认 ADMIN 用户 __PLACEHOLDER_EMAIL__
- 创建或校正 Casdoor team-ai 业务组织默认管理员 team-ai-admin
- 当前尚无非默认注册用户，后续首个非默认注册用户会自动提升为 ADMIN
- ADMIN 角色 access:admin system grant 存在

纯净重部署验证
- 执行 `make down` + 清空 `runtime/local/new-api`、`runtime/local/casdoor`、`runtime/local/librechat` 后，再执行 `make init && make up`
- 首次启动会先等待 `new-api-postgres` / `new-api-redis` / `librechat-mongodb` 健康，再继续拉起 Casdoor / LibreChat
- 默认管理员在 `make up` 阶段即写入 LibreChat MongoDB
- Casdoor 默认业务管理员 `team-ai/team-ai-admin` 在 `make up` 阶段即写入 Casdoor `user` 表
- 使用 `POST /api/auth/login` 与 Casdoor `/api/login` 验证默认管理员可立即登录
- 额外创建首个非默认测试用户 `first-user@team-ai.local`，创建时即自动赋予 `role=ADMIN`；验证后已删除测试用户，当前本地环境恢复为仅保留默认管理员

GET /api/config
- emailLoginEnabled=true
- registrationEnabled=false
- openidLoginEnabled=true
- openidAutoRedirect=true

POST /api/auth/login
- 默认管理员可登录 LibreChat
- 返回 role=ADMIN

POST /api/admin/login/local
- 默认管理员可登录 Admin API
- 返回 role=ADMIN

Casdoor OIDC code 登录
- Casdoor /api/login 返回授权 code
- LibreChat /oauth/openid/callback 返回 302 到 http://__YOUR_SERVER_IP__:3081
- 默认管理员在 LibreChat 中完成 OpenID 关联，role=ADMIN

GET http://localhost:3003
- Admin Panel Web 入口返回 200
```

### 17. Casdoor 手机注册与 LibreChat Logout
结果：**通过**

```
Casdoor 默认语言
- runtime/local/casdoor/app.conf 已写入 forceLanguage=zh / defaultLanguage=zh
- 登录页 Set-Cookie jsonWebConfig 返回 forceLanguage=zh / defaultLanguage=zh

手机/无邮箱 OIDC 用户
- 临时 Casdoor 用户仅配置 phone，email 为空
- Casdoor /api/login 返回授权 code
- LibreChat /oauth/openid/callback 返回 302 到 http://__YOUR_SERVER_IP__:3081
- LibreChat 自动生成 synthetic email: oidc-<openidId>@casdoor.team-ai.local
- 未再出现 User validation failed: email: is invalid
- `/api/user` 对前端返回手机号作为 `email` 展示值，并保留 `teamAiInternalEmail`
- 默认管理员等邮箱账号的 `/api/user` 仍返回真实邮箱，不增加 `teamAiInternalEmail`

Logout stale token fallback
- 有 session id_token 时仍返回 Casdoor /api/logout end-session redirect
- 仅存在 stale openid_id_token cookie 且无当前 session id_token 时，返回 http://__YOUR_SERVER_IP__:3081/login?redirect=false
- 避免浏览器直达 Casdoor JSON 错误：未查询到对应token, accessToken无效
```

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

### 修复 8：手机号注册用户缺少合法 email
问题：Casdoor 手机号注册后 OIDC userinfo 可能没有合法 email，LibreChat 创建用户时报 `email: is invalid`
修复：LibreChat OpenID patch 在创建/更新 OpenID 用户时为无邮箱账号生成 `oidc-<openidId>@casdoor.team-ai.local`

### 修复 9：Logout stale id_token_hint 导致 Casdoor JSON 错误
问题：LibreChat logout 在缺少当前 OpenID session id_token 时退回 stale cookie，Casdoor `/api/logout` 返回 `accessToken无效`
修复：无当前 session id_token 时抑制 Casdoor end-session redirect，回退到 LibreChat 登录页

### 修复 10：手机号注册用户菜单显示内部 synthetic email
问题：手机号注册账号内部使用 `oidc-<openidId>@casdoor.team-ai.local` 满足 LibreChat 邮箱校验，导致左下角用户菜单显示过长
修复：`/api/user` 响应层按当前 OpenID token claims 将 synthetic email 展示为手机号；邮箱注册账号仍显示真实邮箱

## 当前已知结论
- 平台主链路已完全打通
- LibreChat 已升级到 v0.8.5（支持 Admin Panel、自定义角色、分级权限等）
- 纯净部署后默认管理员 `__PLACEHOLDER_EMAIL__` 会在首次 `make up` 即可通过 LibreChat 本地登录和 Casdoor 统一认证登录，并可进入 Admin Panel；首个非默认注册用户会自动成为 `ADMIN`
- 智谱、DeepSeek、阿里云百炼、Kimi、火山方舟豆包、小米 MiMo 与 MiniMax 模型按供应商分组可见；豆包真实 chat 需先在火山方舟账号侧开通模型服务或配置推理接入点
- 自动 bootstrap 一次部署即可使用
- 搜索功能（Serper/Firecrawl/Jina）已配置
- 内存使用适合 2C2G ECS 部署（本地含 Admin Panel 实测约 553MiB；生产默认不启用 Admin Panel）
- 统一认证通过 Casdoor OIDC 正常工作
- Admin Panel 已在本地 compose 中集成，生产仍按需扩展
- LibreChat 重启后，OIDC state 不再因内存 session 丢失而强制用户二次登录
- Casdoor 登录/注册页默认中文；手机号注册账号可完成 OIDC 回调并进入 LibreChat
- LibreChat logout 不再把 stale OpenID token 错误暴露为 Casdoor JSON 页面
- 手机号注册用户在 LibreChat 左下角用户菜单中显示手机号；邮箱登录用户继续显示邮箱
