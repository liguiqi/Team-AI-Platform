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

## 关键环境变量

### Casdoor 基础
- `CASDOOR_PUBLIC_URL`：Casdoor 对外访问地址。
- `CASDOOR_DB_NAME`：Casdoor 在 PostgreSQL 中使用的独立库名。
- `CASDOOR_APPLICATION_NAME`：Casdoor 中给 LibreChat 创建的 OIDC 应用名。
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
- `CASDOOR_EMAIL_FROM_ADDRESS`
- `CASDOOR_EMAIL_FROM_NAME`

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
- 创建 SMTP Provider
- 创建阿里云 `PNVS SMS` Provider
- 重建或校正 `built-in/admin` 管理员账号

说明：
- 当前默认 `CASDOOR_INIT_DATA_NEW_ONLY=false`，表示仓库中的认证配置会在服务启动时持续回放。
- 不建议只在 Casdoor UI 中手工改 Provider 或 Application 而不回写仓库环境变量，否则重启后会被仓库配置覆盖。

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
2. 执行 `make render-auth && make up`，生产环境使用 `MODE=prod` 对应命令。
3. 打开 Casdoor 后台发送一封测试邮件验证。

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

### LibreChat 点击统一认证后报错
排查：
- `CASDOOR_PUBLIC_URL` 是否正确。
- `CASDOOR_CLIENT_ID` / `CASDOOR_CLIENT_SECRET` 是否与 Casdoor 应用一致。
- `redirectUris` 是否包含 `.../oauth/openid/callback`。

### 收不到邮件验证码
排查：
- SMTP Host / Port / Username / Password 是否正确。
- `CASDOOR_EMAIL_SSL_MODE` 是否与端口匹配。
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
1. [architecture.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture.md)
2. [deployment-local.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/deployment-local.md)
3. [deployment-cloud.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/deployment-cloud.md)
4. [admin-librechat.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/admin-librechat.md)
