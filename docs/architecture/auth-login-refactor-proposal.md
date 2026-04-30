# 认证登录模块轻量化重构建议

## 1. 文档目的

本文档用于指导后续在本地开发环境中对认证登录模块进行重构落地。重构目标不是推翻当前 `Casdoor + LibreChat OIDC + NEW-API` 的基本架构，而是在保持现有功能可用的前提下，降低配置复杂度、收紧必要安全边界、统一跨平台登录体验，并为后续多平台接入和版本升级预留参数流转的数据裕度。

本次文档主要供后续 Codex 执行具体开发任务时参考。

## 2. 重构分支要求

本次重构必须在独立分支中完成，不直接在 `main` 分支开发。

建议分支名：

```bash
git checkout -b refactor/auth-login-lightweight
```

如果需要遵循当前自动化协作约定，也可以使用：

```bash
git checkout -b genspark_ai_developer
```

要求：

1. 所有认证登录相关修改均在重构分支完成。
2. 每个阶段性改动应有清晰提交记录。
3. 合并前必须完成本地验证，包括配置渲染、Compose 配置校验、健康检查和认证链路检查。
4. 不得把真实密钥、真实短信凭据、SMTP 密码、生产 `.env` 或运行时数据提交到仓库。

## 3. 当前认证架构简述

当前认证链路为：

```text
用户浏览器
  -> LibreChat 登录页
  -> OpenID 统一认证入口
  -> Casdoor
  -> 邮箱验证码 / 手机验证码 / 密码登录
  -> OIDC 回调 LibreChat /oauth/openid/callback
  -> LibreChat 建立自身会话
  -> 用户进入聊天界面
```

当前核心组件职责：

| 组件 | 当前职责 |
| --- | --- |
| LibreChat | 聊天界面、用户会话、OIDC 登录承接 |
| Casdoor | 统一身份认证、邮箱验证码、手机号验证码、OIDC Provider |
| NEW-API | 模型网关、服务 token、模型映射、限流、日志 |
| PostgreSQL | NEW-API 与 Casdoor 的持久化存储，当前为同一实例不同库 |
| MongoDB | LibreChat 用户、会话、消息数据 |
| Caddy | 生产环境 HTTPS 与反向代理 |

当前设计方向是合理的：认证、聊天界面和模型治理职责分层，浏览器端不直接持有上游模型密钥，也不直接持有短信和邮箱服务端密钥。

## 4. 重构总体原则

### 4.1 保持基本功能

重构必须保持以下能力不退化：

1. 用户仍然可以通过 LibreChat 入口登录。
2. Casdoor 仍然作为统一身份入口。
3. 邮箱验证码和手机号验证码能力继续可用。
4. LibreChat 仍然通过 OIDC 承接登录结果。
5. NEW-API 的模型访问治理链路不受影响。
6. 本地和生产 Docker Compose 启动方式保持可用。

### 4.2 轻量化优先

本次重构不建议引入重型企业 SSO、复杂 IAM、多租户组织模型或深度二开 LibreChat/Casdoor 源码。

优先采用以下方式：

1. 通过 `.env` 参数控制认证行为。
2. 通过脚本渲染 Casdoor 和 LibreChat 配置。
3. 通过 smoke test 校验链路。
4. 通过文档约束运维动作。
5. 尽量复用现有 Docker Compose、脚本和配置目录结构。

### 4.3 适当考虑安全因素

本次重构不追求一次性做到企业级零信任体系，但必须补齐基础安全边界：

1. 生产环境必须使用 HTTPS。
2. 生产环境不得启用不安全 HTTP OIDC 调试开关。
3. OIDC grant type 应尽量收敛。
4. 认证配置不应被生产环境反复无提示覆盖。
5. 管理后台应具备后续接入 IP 白名单、VPN 或堡垒机的配置空间。
6. 所有密钥、token、SMTP 密码、短信 AccessKey 不得进入 Git。

### 4.4 复用现有配置信息

当前项目中已经存在阿里云短信和邮箱相关配置，重构时应继续复用，不要求用户重新设计或重新录入一套参数。

可继续复用的变量包括：

```dotenv
CASDOOR_EMAIL_PROVIDER_NAME=
CASDOOR_EMAIL_SMTP_HOST=
CASDOOR_EMAIL_SMTP_PORT=
CASDOOR_EMAIL_SMTP_USERNAME=
CASDOOR_EMAIL_SMTP_PASSWORD=
CASDOOR_EMAIL_SSL_MODE=
CASDOOR_EMAIL_FROM_ADDRESS=
CASDOOR_EMAIL_FROM_NAME=
CASDOOR_EMAIL_SUBJECT=

CASDOOR_SMS_PROVIDER_NAME=
CASDOOR_SMS_ACCESS_KEY_ID=
CASDOOR_SMS_ACCESS_KEY_SECRET=
CASDOOR_SMS_SIGN_NAME=
CASDOOR_SMS_TEMPLATE_CODE=
CASDOOR_SMS_REGION_ID=
```

重构时可以整理变量校验和渲染逻辑，但不应强制用户替换当前短信与邮箱供应商配置。

### 4.5 为跨平台升级预留参数流转数据裕度

后续系统可能不仅有 LibreChat 一个前端，也可能接入移动端、管理端、企业门户、第三方内部系统或新的 AI 应用。因此认证模块参数设计必须避免只服务当前单一页面。

重构时应预留：

1. 多客户端 `client_id` / `client_secret` 的配置空间。
2. 多回调地址 `redirectUris` 的配置空间。
3. 多登出回跳地址 `postLogoutRedirectUris` 的配置空间。
4. 多平台展示名称、按钮文案、Logo、主题色的配置空间。
5. 多平台用户字段映射能力，例如 `email`、`phone`、`name`、`displayName`、`avatar`、`groups`。
6. 参数向后兼容策略，避免后续新增变量导致旧环境无法启动。

## 5. 推荐重构范围

### 5.1 脚本结构轻量拆分

当前认证相关逻辑主要集中在：

```text
scripts/render-casdoor-config.sh
scripts/render-librechat-config.sh
scripts/_common.sh
```

建议适度拆分，但不要过度工程化。推荐结构：

```text
scripts/auth/
  render-casdoor-app-conf.sh
  render-casdoor-init-data.sh
  validate-auth-env.sh
  smoke-auth.sh
```

也可以保留原有入口脚本，让原命令继续可用：

```bash
bash scripts/render-casdoor-config.sh
```

内部再调用新的 `scripts/auth/*` 脚本，保证向后兼容。

### 5.2 认证环境变量分层

建议把认证变量分为四类。

#### 5.2.1 Casdoor 基础变量

```dotenv
CASDOOR_PUBLIC_URL=
CASDOOR_DB_NAME=
CASDOOR_APPLICATION_NAME=
CASDOOR_APPLICATION_DISPLAY_NAME=
CASDOOR_CLIENT_ID=
CASDOOR_CLIENT_SECRET=
```

#### 5.2.2 登录方式控制变量

建议新增或显式化：

```dotenv
CASDOOR_ENABLE_SIGNUP=true
CASDOOR_ENABLE_PASSWORD_LOGIN=true
CASDOOR_ENABLE_VERIFICATION_CODE_LOGIN=true
CASDOOR_ENABLE_PASSWORD_GRANT=false
CASDOOR_OIDC_GRANT_TYPES=authorization_code,refresh_token
CASDOOR_OIDC_TOKEN_FORMAT=JWT
CASDOOR_OIDC_EXPIRE_IN_HOURS=8
CASDOOR_OIDC_COOKIE_EXPIRE_IN_HOURS=24
```

说明：

1. 本地环境可以保留密码登录，方便调试。
2. 生产环境建议优先验证码登录。
3. `password` grant 默认应关闭。
4. token 和 cookie 过期时间不应硬编码在脚本中。

#### 5.2.3 邮箱与短信变量

继续复用现有变量，不做破坏性调整。

邮箱：

```dotenv
CASDOOR_EMAIL_PROVIDER_NAME=
CASDOOR_EMAIL_SMTP_HOST=
CASDOOR_EMAIL_SMTP_PORT=
CASDOOR_EMAIL_SMTP_USERNAME=
CASDOOR_EMAIL_SMTP_PASSWORD=
CASDOOR_EMAIL_SSL_MODE=
CASDOOR_EMAIL_FROM_ADDRESS=
CASDOOR_EMAIL_FROM_NAME=
CASDOOR_EMAIL_SUBJECT=
```

短信：

```dotenv
CASDOOR_SMS_PROVIDER_NAME=
CASDOOR_SMS_ACCESS_KEY_ID=
CASDOOR_SMS_ACCESS_KEY_SECRET=
CASDOOR_SMS_SIGN_NAME=
CASDOOR_SMS_TEMPLATE_CODE=
CASDOOR_SMS_REGION_ID=
```

#### 5.2.4 跨平台客户端变量

建议预留多平台配置，例如：

```dotenv
AUTH_CLIENTS_JSON=
```

示例：

```json
[
  {
    "name": "librechat-web",
    "displayName": "Team AI Platform",
    "clientId": "team-ai-librechat",
    "redirectUris": ["https://chat.example.com/oauth/openid/callback"],
    "postLogoutRedirectUris": ["https://chat.example.com/login"],
    "platform": "web"
  },
  {
    "name": "admin-console",
    "displayName": "Team AI Admin",
    "clientId": "team-ai-admin",
    "redirectUris": ["https://admin.example.com/oauth/callback"],
    "postLogoutRedirectUris": ["https://admin.example.com/login"],
    "platform": "admin"
  }
]
```

短期可以不完全实现多客户端，但渲染脚本和文档应避免把所有逻辑写死在单一 `LibreChat` 回调地址上。

## 6. 参数流转设计建议

### 6.1 当前参数流转

```text
.env / deploy/env/prod/.env
  -> scripts/render-casdoor-config.sh
  -> runtime/*/casdoor/app.conf
  -> runtime/*/casdoor/init_data.json
  -> Casdoor

.env / deploy/env/prod/.env
  -> scripts/render-librechat-config.sh
  -> runtime/*/librechat/librechat.yaml
  -> LibreChat
```

### 6.2 重构后的参数流转目标

建议形成更清晰的分层：

```text
环境变量
  -> 认证参数校验 validate-auth-env.sh
  -> 认证配置模型 auth config model
  -> Casdoor app.conf
  -> Casdoor init_data.json
  -> LibreChat OIDC env/config
  -> smoke-auth.sh 验证
```

这里的“认证配置模型”可以先不做复杂代码实现，只要在脚本层面形成统一变量读取和校验即可。

### 6.3 数据裕度要求

所谓“数据裕度”，是指当前字段设计不要只满足当下最小值，而要允许未来扩展。建议包括：

1. `redirectUris` 使用数组思维，不要只拼一个字符串。
2. `grantTypes` 使用变量控制，不要硬编码多个固定值。
3. `scope` 保持可扩展，但必须包含 `openid`。
4. 用户 claim 映射不要只绑定 `name` 和 `email`，应预留 `phone`、`avatar`、`groups`。
5. 前端展示参数应预留 `logo`、`themeColor`、`buttonLabel`。
6. 多平台客户端配置可以先通过 JSON 字符串承载，后续再演进为 YAML 或独立配置文件。

## 7. 跨平台界面统一性要求

用户特别关注不同平台之间的界面统一性。后续不应出现每个平台都跳到不同风格页面、登录按钮和认证流程完全不一致的情况。

### 7.1 统一入口体验

建议统一以下元素：

1. 登录按钮文案，例如统一为 `统一认证登录` 或公司内部标准名称。
2. 登录页 Logo。
3. 主题色。
4. 表单标题。
5. 验证码邮件模板。
6. 短信验证码签名与文案。
7. 登录成功后的回跳体验。
8. 登出后的回跳体验。

### 7.2 不同平台不要各自实现完全不同登录页

建议以 Casdoor 作为统一认证页面来源，各平台只负责发起 OIDC 登录，不各自复制一套认证 UI。

推荐模式：

```text
Web / 管理端 / 移动端 / 未来应用
  -> 统一 OIDC 发起入口
  -> 同一 Casdoor 认证品牌页
  -> 平台专属 callback
  -> 平台本地会话
```

这样可以保证：

1. 认证策略统一。
2. 用户看到的品牌一致。
3. 邮箱/短信验证码能力复用。
4. 后续接入新平台时不重复开发登录页面。

### 7.3 尽量减少不必要的跨平台跳转割裂

OIDC 本身需要跳转到认证页，但应避免以下问题：

1. A 平台跳到一种风格登录页，B 平台跳到另一种风格登录页。
2. 登录后回跳路径不稳定。
3. 登出后停留在 Casdoor 默认页，无法回到原平台。
4. 移动端、Web 端、管理端按钮文案不一致。
5. 邮件模板、短信签名与页面品牌不一致。

建议将品牌展示参数集中为：

```dotenv
AUTH_BRAND_NAME=Team AI Platform
AUTH_BRAND_LOGO_URL=
AUTH_BRAND_PRIMARY_COLOR=
AUTH_LOGIN_BUTTON_LABEL=统一认证登录
AUTH_EMAIL_SUBJECT=Team AI Platform 验证码
AUTH_EMAIL_FROM_NAME=Team AI Platform
```

短期可以映射到现有变量：

```dotenv
LIBRECHAT_OPENID_BUTTON_LABEL=${AUTH_LOGIN_BUTTON_LABEL}
CASDOOR_EMAIL_FROM_NAME=${AUTH_BRAND_NAME}
CASDOOR_EMAIL_SUBJECT=${AUTH_EMAIL_SUBJECT}
```

## 8. 安全收敛建议

### 8.1 OIDC grant type 收敛

当前配置中存在 `password` grant。建议改为默认关闭：

```dotenv
CASDOOR_ENABLE_PASSWORD_GRANT=false
CASDOOR_OIDC_GRANT_TYPES=authorization_code,refresh_token
```

除非后续有明确的可信后端服务需要，否则不要开启 `password` grant。

### 8.2 生产环境禁止 HTTP OIDC 调试模式

生产环境必须满足：

```dotenv
LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP=false
```

并且：

```dotenv
LIBRECHAT_PUBLIC_URL=https://...
CASDOOR_PUBLIC_URL=https://...
NEW_API_PUBLIC_URL=https://...
```

### 8.3 生产环境避免持续覆盖 Casdoor UI 配置

当前默认 `CASDOOR_INIT_DATA_NEW_ONLY=false`，适合本地，但生产建议改为：

```dotenv
CASDOOR_INIT_DATA_NEW_ONLY=true
```

推荐策略：

| 环境 | 建议值 | 原因 |
| --- | --- | --- |
| local | false | 方便反复渲染和调试 |
| prod | true | 避免重启覆盖线上手工校正配置 |

### 8.4 生产 Compose 不建议加载本地 HTTP patch

当前 `openid-insecure-http.js` 用于本地 HTTP OIDC 调试。生产环境建议不挂载该 patch，或通过环境变量显式控制：

```dotenv
LIBRECHAT_OPENID_PATCH_INSECURE_HTTP=false
```

本地可以开启，生产必须关闭。

### 8.5 管理入口保护

生产环境至少应在文档和 Caddy 配置中预留以下能力：

1. Casdoor 管理后台 IP 白名单。
2. NEW-API 管理后台 IP 白名单。
3. 只允许 VPN 或堡垒机访问管理域名。
4. 增加基础安全响应头。

## 9. 建议新增验证命令

### 9.1 `make smoke-auth`

建议新增：

```makefile
smoke-auth:
	bash scripts/auth/smoke-auth.sh
```

检查内容：

1. Casdoor discovery 可访问。
2. discovery 中 `issuer` 与 `CASDOOR_PUBLIC_URL` 一致。
3. `authorization_endpoint` 存在。
4. `token_endpoint` 存在。
5. `jwks_uri` 存在。
6. LibreChat 登录页可访问。
7. LibreChat 登录页或配置中存在 openid 登录入口。
8. `redirectUris` 包含 `${LIBRECHAT_PUBLIC_URL}/oauth/openid/callback`。
9. 生产环境下所有 public URL 必须是 HTTPS。
10. 生产环境下 `LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP` 必须为 `false`。

### 9.2 增强 `make doctor`

认证相关建议新增校验：

| 校验项 | 规则 |
| --- | --- |
| `LIBRECHAT_OPENID_SCOPE` | 必须包含 `openid` |
| `CASDOOR_CLIENT_SECRET` | 长度建议 >= 32 |
| `LIBRECHAT_OPENID_SESSION_SECRET` | 长度建议 >= 32 |
| `LIBRECHAT_JWT_SECRET` | 应为 64 位 hex |
| `LIBRECHAT_JWT_REFRESH_SECRET` | 应为 64 位 hex |
| `LIBRECHAT_CREDS_KEY` | 应为 64 位 hex |
| `LIBRECHAT_CREDS_IV` | 应为 32 位 hex |
| `CASDOOR_PUBLIC_URL` | 生产必须 HTTPS |
| `LIBRECHAT_PUBLIC_URL` | 生产必须 HTTPS |
| `CASDOOR_INIT_DATA_NEW_ONLY` | 生产建议 true |
| `LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP` | 生产必须 false |

## 10. 推荐落地步骤

### 阶段一：建立重构分支与文档基线

1. 创建重构分支。
2. 提交本文档。
3. 明确后续 Codex 任务范围。

### 阶段二：轻量配置收敛

1. 增加认证相关环境变量。
2. 保持旧变量兼容。
3. 修改 `render-casdoor-config.sh`，让 grant type、登录方式、过期时间可配置。
4. 生产模板中收紧默认值。

### 阶段三：认证校验脚本

1. 新增 `scripts/auth/validate-auth-env.sh`。
2. 新增 `scripts/auth/smoke-auth.sh`。
3. 在 `Makefile` 增加 `smoke-auth`。
4. 将认证校验接入 `doctor`。

### 阶段四：跨平台参数预留

1. 支持多 redirect URI 的配置方式。
2. 预留 `AUTH_CLIENTS_JSON`。
3. 统一品牌参数。
4. 将 LibreChat 当前 OIDC 文案映射到统一品牌变量。

### 阶段五：生产安全收敛

1. 生产关闭 HTTP OIDC patch。
2. 生产强制 HTTPS 校验。
3. Caddy 增加基础安全响应头。
4. 文档补充管理入口保护建议。

## 11. 验收标准

重构完成后，至少满足以下标准：

1. `make init` 可正常执行。
2. `make up` 可正常启动核心服务。
3. `make doctor` 可完成基础检查，并能提示认证配置风险。
4. `make health` 可通过。
5. `make smoke-auth` 可验证 Casdoor OIDC 基础链路。
6. 邮箱验证码配置仍复用现有 SMTP 变量。
7. 手机验证码配置仍复用现有阿里云 PNVS SMS 变量。
8. LibreChat 仍只展示统一认证入口。
9. 生产环境模板默认不启用不安全 HTTP OIDC。
10. 生产环境不会无提示反复覆盖 Casdoor UI 配置。
11. 新增变量具有向后兼容策略，旧 `.env` 通过 `prepare_env_file` 可补齐缺失项。
12. 文档说明跨平台参数如何扩展。
13. 不同平台的登录入口、品牌文案、验证码模板具备统一配置来源。

## 12. 不建议本轮处理的事项

为了保持本次重构轻量，不建议本轮处理：

1. 深度二开 LibreChat 前端源码。
2. 深度二开 Casdoor 源码。
3. 引入 Kubernetes。
4. 引入复杂企业 LDAP/AD 同步。
5. 一次性建设完整组织权限体系。
6. 自研认证中心。
7. 重写 NEW-API 权限体系。

这些可以作为后续阶段规划，但不应阻塞本轮认证登录模块轻量化重构。

## 13. 总结

本次认证登录模块重构建议坚持四个方向：

1. **保持功能可用**：继续沿用 `Casdoor + LibreChat OIDC`，不推翻当前架构。
2. **轻量化落地**：优先通过环境变量、脚本和 smoke test 增强能力。
3. **适度安全收敛**：重点处理 HTTPS、OIDC grant、生产覆盖策略和密钥校验。
4. **面向跨平台演进**：预留多客户端、多回调、统一品牌和用户字段映射能力。

后续 Codex 在本地端开发环境落地时，应优先从配置参数化、认证校验脚本和生产默认值收紧开始，避免一开始就进入重型架构改造。
