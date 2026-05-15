# NEW-API 管理员使用与运维手册

## 文档目标
本文档面向 `NEW-API` 平台管理员，说明如何登录后台、理解本项目中的关键对象、执行日常管理动作、进行安全变更和处理常见故障。

## 适用读者
- 平台管理员
- 运维值班人员
- 接手本项目的后续维护人

## 平台定位
在本项目中，`NEW-API` 不是普通 API 转发器，而是整个平台的治理中心。凡是与以下事项相关，优先在 `NEW-API` 视角理解：

- 上游渠道
- 模型映射
- 服务 token
- 用户额度
- 限流
- 日志与请求审计

补充边界：
- 用户手机号、邮箱、验证码、OIDC 登录不在 `NEW-API` 内处理。
- 当前真实认证统一由 Casdoor 承担。
- 如果问题表现为“用户登不上 LibreChat”，先查 Casdoor，再查 `NEW-API`。

## 入口与账号

### 本地后台入口
- 地址：`http://localhost:13000`

### 生产后台入口
- 地址：`https://$NEW_API_ADMIN_DOMAIN`

### 登录账号来源
管理员账号由 `.env` 中以下变量决定：
- `NEW_API_SETUP_USERNAME`
- `NEW_API_SETUP_PASSWORD`

### 重要提醒
如果你在 `NEW-API` 后台手工修改了 root 密码，必须同步修改 `.env` 中的 `NEW_API_SETUP_PASSWORD`。否则后续执行 `make bootstrap` 会因为登录失败而中断。

## 本项目中的关键对象

### 1. Root 管理员
作用：
- 登录后台
- 管理渠道、用户、token、系统配置
- 执行 bootstrap 所依赖的后台初始化和配置更新

注意：
- 本仓库脚本默认使用 root 进行自动化配置。
- root 账号是平台最高权限，不建议给普通使用者。

### 2. 服务用户
默认变量：
- `NEW_API_SERVICE_USER`
- `NEW_API_SERVICE_PASSWORD`

作用：
- 代表 LibreChat 访问 `NEW-API`
- 持有服务 token
- 持有项目内高额度基准，避免本项目先于上游平台阻断调用

重要结论：
- `NEW-API` 用户表没有单独的 unlimited 开关，因此部署脚本会把 `NEW_API_SERVICE_TOKEN_QUOTA` 固定为大额基准。
- 成本与费用上限统一交由智谱、DeepSeek、阿里云百炼、Kimi、火山方舟豆包等上游模型平台控制。

### 3. 服务 token
默认名称：
- `NEW_API_SERVICE_TOKEN_NAME`

作用：
- 由 LibreChat 持有
- 请求 `NEW-API /v1/*`
- 决定分组、配额以及最终可见模型范围

当前推荐策略：
- `NEW_API_SERVICE_TOKEN_UNLIMITED=true`
- `NEW_API_TOKEN_ALLOWED_MODELS=` 留空
- `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
- `NEW_API_RATE_LIMIT_ENABLED=false`
- 让 `NEW-API /v1/models` 返回当前服务 token 可访问的真实模型集合
- LibreChat 侧按 `API-zhipu` / `API-deepseek` / `API-aliyun` / `API-kimi` / `API-doubao` 分组渲染对应供应商模型
- 如果前端只想显示部分模型，再由 LibreChat 侧用 `LIBRECHAT_VISIBLE_MODELS` 做展示过滤

### 4. 智谱渠道
默认名称：
- `zhipu-primary`

关键字段：
- `type=26`
- `group` 由后台现状决定，可按你的实际分组维护
- `models` 由 `scripts/sync-provider-models.sh` 从智谱模型 API 动态刷新
- `test_model` 会在同步时校正为当前模型列表中的可用模型
- `model_mapping={}`（直通模式）
- `balance=NEW_API_PROVIDER_CHANNEL_BALANCE`（项目内不限额显示/校正值）

### 5. DeepSeek 渠道（可选）
默认名称：
- `deepseek-primary`

关键字段：
- `type=1`
- `base_url=https://api.deepseek.com`
- `models` 由 `scripts/sync-provider-models.sh` 从 DeepSeek 模型 API 动态刷新，当前真实返回为 `deepseek-v4-pro,deepseek-v4-flash`
- `test_model=deepseek-v4-flash`
- `model_mapping={}`（保持直通模型名）
- `balance=NEW_API_PROVIDER_CHANNEL_BALANCE`（项目内不限额显示/校正值）

### 6. 阿里云百炼渠道（可选）
默认名称：
- `aliyun-bailian-primary`

关键字段：
- `type=1`
- `base_url=https://dashscope.aliyuncs.com/compatible-mode`
- `models` 由 `scripts/sync-provider-models.sh` 从百炼模型 API 动态刷新
- `test_model=qwen-plus`
- `model_mapping={}`（保持直通模型名）
- `balance=NEW_API_PROVIDER_CHANNEL_BALANCE`（项目内不限额显示/校正值）

### 7. Kimi 渠道（可选）
默认名称：
- `kimi-primary`

关键字段：
- `type=1`
- `base_url=https://api.moonshot.cn`
- `models` 由 `scripts/sync-provider-models.sh` 从 Kimi 模型 API 动态刷新
- `test_model=kimi-k2.6`
- `model_mapping={}`（保持直通模型名）
- `balance=NEW_API_PROVIDER_CHANNEL_BALANCE`（项目内不限额显示/校正值）

### 8. 火山方舟豆包渠道（可选）
默认名称：
- `doubao-primary`

关键字段：
- `type=45`
- `base_url=https://ark.cn-beijing.volces.com`
- `models` 由 `scripts/sync-provider-models.sh` 从火山方舟模型 API 动态刷新
- `test_model=doubao-seed-1-6-250615`
- `model_mapping={}`（保持直通模型名或推理接入点 ID）
- `balance=NEW_API_PROVIDER_CHANNEL_BALANCE`（项目内不限额显示/校正值）
- 火山方舟账号需在控制台开通对应模型服务或创建可调用的推理接入点，否则真实 chat 会被上游拒绝

## 后台主要管理区域

### 渠道管理
重点用于：
- 查看上游渠道状态
- 启用/禁用渠道
- 修改 API Key、模型映射、分组、优先级和权重

本项目管理员最常操作的页面就是渠道管理。

### 用户管理
重点用于：
- 查看 root、服务用户和普通用户
- 调整服务用户额度
- 排查用户是否被禁用

### Token 管理
重点用于：
- 检查 LibreChat 服务 token 是否存在
- 查看 token 是否被禁用、过期或额度不足
- 检查 token 是否错误地启用了过窄的模型白名单

推荐状态：
- `model_limits_enabled=false`
- 这样 LibreChat 才能从 `NEW-API /v1/models` 看到你当前在后台维护的模型矩阵

### 日志 / 用量 / 统计
重点用于：
- 排查失败请求
- 判断是上游错误、权限错误还是额度错误
- 查看是否出现 `404`、`401`、`429`、`insufficient_user_quota`

### 设置 / 选项
重点用于：
- 模型请求限流
- 系统行为控制

本项目 bootstrap 会自动写入模型请求限流配置，当前默认 `NEW_API_RATE_LIMIT_ENABLED=false`，成本和调用频率限制交由上游模型平台控制。

## 本项目推荐的后台使用姿势

### 优先级原则
1. 高频标准动作优先用脚本。
2. 临时排障和可视化确认优先用后台。
3. 涉及服务 token 与标准渠道回归时，优先重新执行 `make bootstrap`。

### 为什么不建议大量手工点击
因为本项目已经把“标准状态”定义进脚本中。手工改动虽然能临时解决问题，但如果没有同步到 `.env` 或文档，下次 bootstrap 可能覆盖或失配。

补充说明：
- 当前主配置 `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=true`，bootstrap 会把 `.env` 中已同步的供应商模型矩阵写入渠道配置。
- 当前主配置会把服务 token 设为 unlimited，并把供应商渠道余额校正为 `NEW_API_PROVIDER_CHANNEL_BALANCE`。
- 若你希望长期以 `NEW-API` 后台为主维护入口，可显式把 `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV` 改回 `false`。

## 管理员常见操作

### 场景 1：查看智谱渠道是否正常
在后台检查：
- 渠道名称是否为 `zhipu-primary`
- 类型是否为 `26`
- 分组是否符合你的实际授权策略
- 模型矩阵是否包含你当前希望在 LibreChat 暴露的模型
- 测试模型是否属于当前 `ZHIPU_EXPOSED_MODEL`
- `model_mapping` 是否正确
- 状态是否启用

补充检查：
- `GET /v1/models` 是否返回你刚在后台维护的模型
- 若前端没同步到最新列表，执行 `make sync-provider-models`

### 场景 2：更换智谱 API Key
推荐步骤：
1. 修改 `.env` 中 `ZHIPU_API_KEY`
2. 执行：
   ```bash
   make bootstrap
   make smoke-zhipu
   ```
3. 再到后台确认渠道已更新

不推荐：
- 只在后台改 key，不同步 `.env`

原因：
- 下次 bootstrap 会按 `.env` 回写

### 场景 3：服务 token 失效或丢失
推荐处理：
```bash
make bootstrap
```

原因：
- bootstrap 会自动查找或重建服务 token
- 自动回写 `.env`
- 自动重渲染 LibreChat 配置
- 自动重启 LibreChat

补充检查：
- 确认 `.env` 中 `NEW_API_TOKEN_MODEL_LIMITS_ENABLED=false`
- 确认 `.env` 中 `NEW_API_SERVICE_TOKEN_UNLIMITED=true`
- 否则前端可能仍只能看到受限后的少量模型

### 场景 4：模型请求返回额度不足
后台排查顺序：
1. 看服务用户额度是否低于项目内不限额基准
2. 看服务 token 是否保持 `unlimited_quota=true`
3. 看供应商渠道 `balance` 是否被后台手工改小
4. 看服务 token 是否被禁用
5. 若本项目状态正常，则到智谱、DeepSeek、阿里云百炼、Kimi 或火山方舟豆包官方平台检查上游账号额度与限流

推荐修复：
```bash
make bootstrap
```

### 场景 5：聊天返回 404
后台检查：
- 渠道 base_url 是否为 `https://open.bigmodel.cn`

如果你在后台看到它带了 `/api/paas/v4`，说明配置被写错了。此时应回到 `.env` 修正后重新 bootstrap。

### 场景 6：后台已新增模型，但前端还没看到
优先检查：
1. `GET /v1/models` 是否已经返回新模型
2. `.env` 中 `NEW_API_TOKEN_MODEL_LIMITS_ENABLED` 是否仍为 `false`
3. 若配置了 `LIBRECHAT_VISIBLE_MODELS`，确认新模型在白名单中

推荐处理：
```bash
make sync-provider-models
```

## 运维侧建议

### 变更前
- 先确认 `.env` 与当前后台状态一致
- 先做备份

### 变更后
- 立即执行：
  ```bash
  make health
  make smoke-zhipu
  ```

### 风险最大的变更
- root 密码修改
- 服务用户额度修改
- 服务 token 手工删除
- 智谱渠道 base_url 修改
- 模型映射改错

## 何时必须修改 `.env`
以下变更如果只改后台、不改 `.env`，后续会产生配置漂移：
- root 管理员账号密码
- 服务用户名称、密码
- 智谱 key
- 智谱 base_url
- 是否允许 token 模型白名单生效
- 服务 token unlimited 策略
- 供应商渠道余额基准

以下内容在**当前主配置**下会由 `.env` / bootstrap 驱动，若只改后台而不改 `.env`，后续可能再次被同步覆盖：
- 已存在渠道上的模型矩阵
- `test_model`
- `model_mapping`

如果你希望这些内容长期主要在后台维护，再显式把：
- `.env` 中 `NEW_API_SYNC_CHANNEL_MODELS_FROM_ENV=false`

## 推荐操作闭环
标准闭环如下：

1. 先改 `.env`
2. 再执行 `make bootstrap`
3. 再执行 `make smoke-zhipu`
4. 最后到后台确认结果

这比“直接在后台点改”更稳定，也更可追溯。

## 常见故障对照表

### 后台能进，但模型不可用
优先检查：
- 渠道状态
- 模型映射
- 服务 token
- 服务用户额度
- `GET /v1/models` 的返回是否符合预期

### 后台不能登录
优先检查：
- `.env` 中 root 用户名密码是否正确
- 是否手工改过 root 密码却没同步 `.env`

### bootstrap 报登录失败
优先检查：
- `NEW_API_SETUP_USERNAME`
- `NEW_API_SETUP_PASSWORD`
- `NEW-API /api/status`

### 日志里出现 429
要区分：
- 管理后台登录限流
- 模型请求限流
- 智谱上游限流

## 建议阅读顺序
1. [architecture.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/architecture.md)
2. [provider-zhipu.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/provider-zhipu.md)
3. [runbook.md](/home/lgq/repoWorkProject/TeamAIPlatform/docs/architecture/runbook.md)
4. 本文档
