# 验收标准

## 文档目标
本文档定义最终验收时应该检查什么、怎样算通过、什么情况必须判定为失败，以及需要保留哪些证据。它面向最终验收人和平台管理员。

## 验收责任边界
- Codex 已负责实施、脚本、自测与问题收敛。
- 用户Project Owner负责最终人工验收。
- 用户不会被要求补写脚本、手改容器配置或临时修库。
- 如验收失败，原则上应先回到项目侧修复，而不是由验收人手工补位。

## Must 条件
- 仓库结构完整，`docs/`、`deploy/`、`scripts/`、`tests/` 齐全。
- 本地 compose 可正常解析。
- `NEW-API` 管理后台可访问。
- Casdoor 统一认证入口可访问。
- LibreChat 页面可访问。
- `NEW-API` 能通过智谱完成真实模型调用。
- LibreChat 已接入 `NEW-API` 自定义端点。
- LibreChat 已接入 Casdoor OIDC，且本地登录入口已关闭。
- 智谱与 DeepSeek 模型能按 `API-zhipu` / `API-deepseek` 分组访问。
- 自动 bootstrap 在 `make up` 时正确执行。
- 网络搜索功能已配置（Serper + Firecrawl + Jina）。
- 所有容器配置了内存限制。
- `.env.example` 与生产模板完整。
- 健康检查脚本可执行。
- 文档已填写到可直接操作的程度。
- 真实密钥未进入 Git 跟踪文件。
- LibreChat 重启后，统一认证链路不应长期卡在 `Unable to verify authorization request state`。

## Should 条件
- 服务用户额度、服务 token unlimited 状态和供应商渠道余额符合项目内不限额策略。
- 服务 token 使用 48 字符强随机值。
- `NEW-API` 项目内请求限流默认关闭，真实限额由上游模型平台控制。
- LibreChat 模型动态同步行为符合预期。
- 本地 Admin Panel 可访问并可用于管理员角色验证。
- 备份恢复脚本可跑通。
- 管理员手册可直接指导后续接手人。
- systemd 开机自启动服务可正常安装和运行。
- 容器内存使用在限制范围内。

## 阻塞性失败
满足以下任一项，应判定为验收失败：
- `NEW-API` 无法调用智谱。
- LibreChat 无法通过 `NEW-API` 访问模型。
- `zhipu-primary` 不可用，或模型同步结果与预期明显不符。
- LibreChat 每次重启后都需要用户额外重复一次统一认证才能进入聊天页。
- 真实密钥进入 Git 跟踪范围。
- 文档与脚本明显不一致。
- 本地按文档无法复现启动。
- 手机或邮箱真实认证链路无法完成登录。

## 最终验收步骤

### 一、环境准备
1. 确认 `.env` 已存在。
2. 确认 `ZHIPU_API_KEY` 为真实可用值。
3. 确认 Casdoor SMTP 与短信变量已填写。
4. 确认 Docker 与 Docker Compose 可用。

### 二、脚本验收
按顺序执行：

```bash
make init
make up
```

当 `BOOTSTRAP_AUTOCONFIGURE=true` 时，以上两步即完成全部部署。

若未启用自动 bootstrap，额外执行：
```bash
bash scripts/bootstrap-new-api.sh
```

### 三、后台验收
1. 打开 `http://localhost:13000`
2. 使用 `.env` 中的 `NEW_API_SETUP_USERNAME` / `NEW_API_SETUP_PASSWORD` 登录
3. 检查以下内容：
   - 能看到渠道列表
   - 存在名为 `zhipu-primary` 的渠道
   - 渠道状态为启用
   - 服务用户存在
   - 服务 token 存在

### 四、前台验收
1. 打开 `http://localhost:3080`
2. 确认页面只显示 `统一认证登录`
3. 点击进入 Casdoor
4. 至少验证一次邮箱真实登录
5. 至少验证一次手机号真实登录
6. 确认端点中存在 `API-zhipu`，启用 DeepSeek 时存在 `API-deepseek`
7. 确认模型列表按供应商拆分并高阶优先排序
8. 至少选择一个可用模型发起真实对话，建议优先验证 `glm-5.1` 与 `deepseek-v4-flash`
9. 重启 LibreChat 后再次走一次统一认证，确认不会稳定复现 state 校验失败页

## 通过标准

### 脚本层
- `make health` 输出成功
- `make smoke-zhipu` 输出成功

### API 层
- `GET /v1/models` 返回当前已启用供应商同步后的模型集合
- `POST /v1/chat/completions` 返回 `HTTP 200`
- 返回体中包含 `choices`

### UI 层
- LibreChat 可访问
- Casdoor 可访问
- 用户可通过邮箱和手机号完成真实认证
- 自定义端点 `NEW-API` 已生效
- 用户可在 UI 中选择当前应暴露的模型
- 用户实际发言后能够收到模型回复

## 建议保留的验收证据
- `make health` 终端输出
- `make smoke-zhipu` 终端输出
- `NEW-API` 后台渠道页面截图
- Casdoor 登录页与 Provider 测试截图
- LibreChat 模型列表页面截图
- 一轮真实问答截图

## 上线前补充检查
- 生产 `.env` 已准备好强随机密码和 secret
- 域名解析与 HTTPS 证书条件已满足
- 已执行过至少一次真实智谱联调
- 已阅读 `docs/architecture/admin-new-api.md`
- 已阅读 `docs/architecture/admin-librechat.md`
- 已阅读 `docs/architecture/admin-auth-sso.md`
