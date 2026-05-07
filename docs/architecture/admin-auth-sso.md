# Casdoor 统一认证管理员手册

## 文档目标
本文档面向平台管理员，说明本项目中 `Casdoor + LibreChat OIDC` 的认证链路、环境变量含义、首次启用步骤、日常运维动作与常见故障排查。

## 当前认证架构

### 认证角色分工
- `Casdoor`：统一身份入口，负责用户注册、邮箱验证码、手机号验证码、密码登录、OIDC 授权。
- `LibreChat`：只保留统一认证入口，不再使用本地邮箱密码体系。
- `NEW-API`：只负责模型网关、token、限流、渠道与日志，不负责用户身份认证。

### 当前真实链路
1. 用户访问 LibreChat。
2. 页面只显示 `统一认证登录` 按钮。
3. 用户跳转到 Casdoor。
4. Casdoor 使用邮箱 SMTP 或阿里云 `PNVS SMS` 发送验证码。
5. Casdoor 完成登录后，以 OIDC 回调方式把用户带回 LibreChat。

## 为什么短信 Provider 使用 PNVS
你提供的阿里云官方示例使用的是 `Dypnsapi / SendSmsVerifyCode`。这条接口在本项目里对应 Casdoor 的 `Alibaba Cloud PNVS SMS`，不是普通 `Aliyun SMS`。因此仓库已经按 `PNVS` 固化，避免模板参数不兼容。

补充：
- `Alibaba Cloud PNVS SMS` 需要较新的 Casdoor 镜像支持。
- 当前仓库要求 `CASDOOR_VERSION=2.396.1` 或更高版本。
- 旧的 `v2.99.0` 镜像不支持 PNVS，会直接报 `unsupported provider: Alibaba Cloud PNVS SMS`。

## 关键环境变量

### Casdoor 基础
- `CASDOOR_PUBLIC_URL`：Casdoor 对外访问地址。
- `CASDOOR_DB_NAME`：Casdoor 在 PostgreSQL 中使用的独立库名。
- `CASDOOR_APPLICATION_NAME`：Casdoor 中给 LibreChat 创建的 OIDC 应用名。
- `CASDOOR_USER_ORGANIZATION_NAME`：面向业务用户的组织名，不能写成 `built-in`。
- `CASDOOR_USER_ORGANIZATION_DISPLAY_NAME`：业务用户组织展示名。
- `CASDOOR_CLIENT_ID` / `CASDOOR_CLIENT_SECRET`：LibreChat 连接 Casdoor 的 OIDC 客户端凭据。

### Casdoor 管理员
- `CASDOOR_ADMIN_EMAIL`
- `CASDOOR_ADMIN_PASSWORD`
- `CASDOOR_ADMIN_PHONE`
- `CASDOOR_ADMIN_COUNTRY_CODE`

### 邮箱验证码
- `CASDOOR_EMAIL_SMTP_HOST`
- `CASDOOR_EMAIL_SMTP_PORT`
- `CASDOOR_EMAIL_SMTP_USERNAME`
- `CASDOOR_EMAIL_SMTP_PASSWORD`
- `CASDOOR_EMAIL_SSL_MODE`
- `CASDOOR_EMAIL_FROM_ADDRESS`
- `CASDOOR_EMAIL_FROM_NAME`

建议：
- 若使用 163 企业邮，优先使用 `465 + Enable`。
- `25 + Disable` 在 163 企业邮场景下容易出现 `gomail: ... broken pipe`。
- 若容器直连 163 SMTP 仍被重置，可在本地模式启用 `LOCAL_SMTP_RELAY_ENABLED=true`，让 Casdoor 先连接宿主机转发器。

### 手机验证码
- `CASDOOR_SMS_ACCESS_KEY_ID`
- `CASDOOR_SMS_ACCESS_KEY_SECRET`
- `CASDOOR_SMS_SIGN_NAME`
- `CASDOOR_SMS_TEMPLATE_CODE`
- `CASDOOR_SMS_REGION_ID`

### LibreChat OIDC
- `LIBRECHAT_OPENID_SESSION_SECRET`
- `LIBRECHAT_OPENID_SCOPE`
- `LIBRECHAT_OPENID_BUTTON_LABEL`
- `LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP`：仅本地 `http://localhost` 调试时设为 `true`，生产必须保持 `false`。

### 平台主题与品牌统一
- `PLATFORM_THEME_MODE`：平台统一主题，建议固定为 `dark`。
- `PLATFORM_THEME_LOCK`：是否强制 LibreChat 固定主题，建议保持 `true`。
- `PLATFORM_HIDE_THEME_SELECTOR`：是否隐藏 LibreChat 主题切换入口，建议保持 `true`。
- `PLATFORM_BRAND_NAME`：统一品牌名。
- `PLATFORM_BRAND_LOGO_PATH`：统一品牌 Logo 路径，默认 `/images/team-ai-platform-logo.svg`。
- `PLATFORM_BRAND_FAVICON_PATH`：统一品牌图标路径，默认 `/images/team-ai-platform-mark.svg`。

说明：
- Casdoor 的 `theme_data`、`logo`、`favicon`、`form_css` 现在都由仓库脚本统一下发。
- Casdoor 的 `form_css` 字段本质上是“插入登录页的 HTML 片段”，如果要写样式，必须用 `<style>...</style>` 包裹，不能直接写裸 CSS 文本。
- LibreChat 登录前和登录后主题不再依赖用户浏览器“跟随系统”，而是由平台配置锁定。
- 管理员不应再单独在 Casdoor UI 或 LibreChat 前端里手工改主题，否则下次重启会被仓库配置覆盖。

## 首次启用步骤

### 本地
```bash
cp .env.example .env
make init
make up
make health
```

### 生产
```bash
cp deploy/env/prod/.env.example deploy/env/prod/.env
MODE=prod bash scripts/up.sh
MODE=prod bash scripts/healthcheck.sh
```

### 启动后会自动完成的事情
- 渲染 `runtime/*/casdoor/app.conf`
- 渲染 `runtime/*/casdoor/init_data.json`
- 创建 Casdoor OIDC 应用
- 创建或校正业务用户组织
- 创建 SMTP Provider
- 创建阿里云 `PNVS SMS` Provider
- 将 Casdoor 应用从 `built-in` 迁移到业务用户组织
- 将邮件和短信 Provider 同步到 PostgreSQL 持久化表
- 重建或校正 `built-in/admin` 管理员账号
- 本地模式下可选启动宿主机 SMTP relay，规避容器直连企业邮箱的兼容问题

说明：
- 当前默认 `CASDOOR_INIT_DATA_NEW_ONLY=false`，表示仓库中的认证配置会在服务启动时持续回放。
- 业务用户默认进入 `CASDOOR_USER_ORGANIZATION_NAME` 对应组织，不会进入 `built-in`。
- `make up` 和 `make restart` 现在会把 `.env` 渲染后的 Provider 配置回写到 Casdoor 持久化库。
- `make up` 和 `make restart` 也会同步 Casdoor 组织和应用配置，防止应用重新挂回 `built-in`。
- 不建议只在 Casdoor UI 中手工改 Provider 或 Application 而不回写仓库环境变量，否则后续重启会再次被仓库配置覆盖。

## 管理入口

### 本地
- Casdoor：`http://localhost:18000`
- LibreChat：`http://localhost:3080`

补充：
- 当本地启用 `LIBRECHAT_OPENID_ALLOW_INSECURE_HTTP=true` 时，初始化脚本会把 `localhost` 公网地址自动替换为宿主机 IP。
- 实际应以 `make up` 输出的 URL 为准，不要手工把 Casdoor OIDC 地址再改回 `localhost`。

### 生产
- Casdoor：`https://$AUTH_PUBLIC_DOMAIN`
- LibreChat：`https://$PUBLIC_CHAT_DOMAIN`

## 用户如何使用

### 邮箱登录
1. 打开 LibreChat。
2. 点击 `统一认证登录`。
3. 在 Casdoor 中注册或登录。
4. 选择邮箱验证码或邮箱密码方式。
5. 成功后回跳 LibreChat。

### 手机登录
1. 打开 LibreChat。
2. 点击 `统一认证登录`。
3. 在 Casdoor 中选择手机号注册或验证码登录。
4. 由阿里云 `PNVS SMS` 发送验证码。
5. 成功后回跳 LibreChat。

## 常见运维动作

### 更换 SMTP 密码
1. 修改 `.env` 或 `deploy/env/prod/.env` 中的 SMTP 变量。
2. 执行 `make up`，生产环境使用 `MODE=prod bash scripts/up.sh`。
3. 打开 Casdoor 后台发送一封测试邮件验证。

### 调整统一登录视觉风格
适用场景：
- 需要统一 Casdoor 登录页与 LibreChat 登录后页面的色调
- 需要替换统一认证 Logo / favicon
- 需要锁定或放开 LibreChat 的主题切换能力

操作：
1. 修改 `.env` 或 `deploy/env/prod/.env` 中的 `PLATFORM_*` 和 `CASDOOR_THEME_*` 变量。
2. 执行：

```bash
MODE=local bash scripts/render-casdoor-config.sh
MODE=local bash scripts/sync-casdoor-auth-config.sh
docker compose -f deploy/docker-compose.local.yml --env-file deploy/env/local/.env up -d --force-recreate casdoor librechat
```

生产环境：

```bash
MODE=prod bash scripts/render-casdoor-config.sh
MODE=prod bash scripts/sync-casdoor-auth-config.sh
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/env/prod/.env up -d --force-recreate casdoor librechat
```

效果：
- Casdoor 登录页会同步新的深浅主题、主色、Logo、favicon 与表单样式。
- LibreChat 会在页面初始化阶段锁定主题，并隐藏主题切换入口。
- `LibreChat -> Casdoor` 的登录跳转保持单入口自动跳转，不再回退到旧的双页面点击流程。

### 本地启用 SMTP relay
适用场景：
- 宿主机 Python 直连 SMTP 正常
- Casdoor 容器直连 SMTP 报 `broken pipe` 或 `connection reset by peer`

配置：
- `.env` 中设置 `LOCAL_SMTP_RELAY_ENABLED=true`
- 保持外部 SMTP 仍然填写真实的 `CASDOOR_EMAIL_SMTP_HOST/PORT/USERNAME/PASSWORD`
- 执行 `make up`

效果：
- 宿主机会启动 `runtime/local/smtp-relay/relay.log` 对应的 Python relay
- Casdoor 持久化 Provider 会自动切换为 `host.docker.internal:2525`
- relay 再使用宿主机 Python 把邮件投递到真实企业邮箱 SMTP

### 更换阿里云短信凭据
1. 修改短信相关环境变量。
2. 重新执行渲染与启动。
3. 在 Casdoor 后台发送测试短信验证。

### 重置 Casdoor 管理员密码
1. 修改 `CASDOOR_ADMIN_PASSWORD`。
2. 重新执行渲染与启动。
3. 使用新的管理员密码重新登录 Casdoor。

## 故障排查

### Casdoor 页面打不开
排查：
- `docker compose ... ps`
- `docker compose ... logs -f casdoor`
- `curl $CASDOOR_PUBLIC_URL/.well-known/openid-configuration`
- 检查 Casdoor 健康检查状态：`docker inspect ai-gateway-casdoor | jq '.[0].State.Health'`

### LibreChat 点击统一认证后报错
排查：
- `CASDOOR_PUBLIC_URL` 是否正确。
- `CASDOOR_CLIENT_ID` / `CASDOOR_CLIENT_SECRET` 是否与 Casdoor 应用一致。
- `redirectUris` 是否包含 `.../oauth/openid/callback`。

### 收不到邮件验证码
排查：
- SMTP Host / Port / Username / Password 是否正确。
- `CASDOOR_EMAIL_SSL_MODE` 是否与端口匹配。
- 若使用 163 企业邮，优先确认是否为 `465 + Enable`，不要继续使用 `25 + Disable`。
- 执行一次 `make up`，确认仓库已把最新 Provider 配置同步到 Casdoor PostgreSQL。
- 若容器 curl/应用直连 SMTP 报 `connection reset by peer`，启用 `LOCAL_SMTP_RELAY_ENABLED=true`
- 先在 Casdoor 后台做测试邮件，不要直接先查 LibreChat。

### 收不到短信验证码
排查：
- 当前仓库使用的是 `Alibaba Cloud PNVS SMS`。
- `CASDOOR_SMS_SIGN_NAME`、`CASDOOR_SMS_TEMPLATE_CODE`、`CASDOOR_SMS_REGION_ID` 是否正确。
- 阿里云模板是否允许 `code` 与 `min` 参数。

## 安全建议
- 不要把 `.env` 与生产密钥放进 Git。
- 不要重新开启 LibreChat 本地邮箱登录，避免绕过统一认证。
- 你本轮提供过真实云凭据，建议在验收完成后尽快轮换一遍。

## 建议联读
1. [architecture.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/architecture.md)
2. [deployment-local.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/deployment-local.md)
3. [deployment-cloud.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/deployment-cloud.md)
4. [admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/admin-librechat.md)
