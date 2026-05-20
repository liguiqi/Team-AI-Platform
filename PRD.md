# Codex 执行总指令：AI Gateway Chat 整合项目一次性施工说明书

你现在处于 **YOLO 执行模式**。  
请基于以下**冻结后的需求、架构、边界、交付标准和验收口径**，直接完成项目骨架、文档、脚本、配置模板、本地联调能力与验收准备工作。  
除非遇到**确实无法继续推进的外部阻塞项**（例如必须由人工提供的真实 API Key、域名、证书），否则**不要反复向我提问澄清**。  
你应当按本文定义的默认决策持续推进、实现、自测、修正并输出最终结果。

---

## 0. 执行目标

本项目是一个新的整合型项目 repo，目标是建设一个**统一、可控、可追踪、可迁移**的内部 AI 对话系统。

### 最终架构
公司官方采购 API Key  
→ **NEW-API**（统一管理 / 路由 / 分发 / 配额 / 审计）  
→ **LibreChat**（对话界面）  
→ 部门同学使用

### 最终方案结论
**已确认采用 NEW-API 方案。**

不得再引导我回到“是否换别的网关”的讨论。  
本次执行以 **NEW-API + LibreChat** 作为既定架构，不再摇摆。

---

## 1. 项目背景

公司已经采购官方 API Key，希望将大模型能力以内部统一入口的方式提供给部门同学使用。  
项目当前阶段以**本机验证开发**为主，待功能稳定、性能稳定、文档清晰后，将整体迁移到云端服务器部署。

本项目的重点不是开发一个新模型平台，而是：

1. **统一管理上游 API**
2. **统一模型出口**
3. **避免密钥直接下沉到前端或用户侧**
4. **实现可用、可管、可迁移的工程形态**
5. **建立完整根仓，便于后续维护和部署**

---

## 2. 本项目的冻结决策（不可再漂移）

以下内容视为**已确认、已冻结**：

### 2.1 已冻结的架构决策
1. 采用 **NEW-API** 作为统一 API 网关。
2. 采用 **LibreChat** 作为内部对话界面。
3. 官方采购 API Key **只进入 NEW-API**，不得直接暴露给 LibreChat 或最终用户。
4. 项目以**整合根仓 Monorepo** 形式管理。
5. 初期本地与云端均采用 **Docker Compose** 路线。
6. 首发云端部署目标为**单机服务器**，不在首期上 Kubernetes。
7. 优先采用**配置化集成**，尽量不深度修改第三方源码。
8. 固定镜像版本，**禁止使用 latest**。
9. 项目文档、脚本、配置模板、验收标准必须成套交付。
10. 本次项目最终验收使用**智谱 API 渠道**进行联调与验收。

### 2.2 已冻结的工程原则
1. **先集成，后定制**
2. **先跑通，后治理**
3. **先单机，后扩展**
4. **先可复现，后优化**
5. **真实密钥不入库**
6. **所有关键能力必须可文档化、脚本化、可验证**

---

## 3. 你（Codex）的角色与责任

你需要扮演的是：  
**项目整合工程负责人 + DevOps 初始落地者 + 文档整理者 + 自测执行者**

你负责：

1. 建立项目根目录 Git 仓库结构
2. 生成并完善文档
3. 生成本地与生产部署模板
4. 生成脚本
5. 建立 NEW-API 与 LibreChat 的联调能力
6. 预留并适配至少一个**智谱 API Key 渠道**
7. 完成本地自测与联调测试能力
8. 输出最终可交付结果与验收依据

你不应把工作留给我来“继续补齐”。  
**我本人最后只做验收。**

---

## 4. 我（用户）的角色与边界

我只负责以下事项：

1. 按你的 `.env.example` / 配置模板填写真实密钥
2. 至少填写一个明确可用的**智谱 API Key**
3. 在你完成施工后执行最终验收

### 明确声明
- 我提供的智谱 API **是明确可用的**
- 最终验收时，我将**以智谱这个 API 渠道作为验收主渠道**
- 我本人**最后只做验收**，不承担你本应完成的结构整理、脚本编写、配置设计、仓库组织、联调路径设计等工作

---

## 5. 本项目目标

### 5.1 业务目标
1. 为部门同学提供统一 AI 对话入口
2. 降低 API Key 泄漏风险
3. 实现模型统一接入与统一管理
4. 支持基础权限、配额、限流、日志、审计
5. 为后续云端部署做好工程准备

### 5.2 技术目标
1. 建立整合项目根仓并进行 Git 追踪
2. 本地可复现启动和联调
3. NEW-API 可统一接入上游模型
4. LibreChat 可通过 NEW-API 正常对话
5. 形成本地验证与云端部署的统一工程骨架
6. 输出完整文档、脚本、配置模板、验收标准

---

## 6. 范围定义

### 6.1 本期 In Scope（必须覆盖）
1. 项目根仓初始化
2. 文档体系建立
3. 本地环境可复现部署
4. NEW-API 基础接入与上游模型打通
5. LibreChat 对接 NEW-API
6. 至少适配一个**智谱 API Key 渠道**
7. 基础模型可见性、权限、配额、限流、日志能力
8. 健康检查、smoke test、备份恢复脚本
9. 云端部署模板与文档
10. 最终验收标准文档
11. 自测与交付说明

### 6.2 本期 Out of Scope（不要做胖）
1. 自研模型推理服务
2. 大规模深度二开 LibreChat
3. 企业级计费系统
4. 首发即 Kubernetes
5. 多地域高可用
6. 复杂 Agent / Workflow 平台
7. 完整知识库/RAG体系
8. 复杂企业 IAM / SSO（非必须先不做）
9. 大规模 UI 重构
10. 任何脱离当前目标的“平台化过度设计”

---

## 7. 项目实施边界

### 7.1 必须遵守
1. 不得将真实 API Key 写入 Git
2. 不得使用 `latest` 镜像标签
3. 不得只交付“文档空架子”而缺少实际脚本
4. 不得让用户必须读源码才能部署
5. 不得让 LibreChat 直接持有官方采购 API Key
6. 不得将“版本兼容问题”留给验收阶段才暴露
7. 不得把关键路径做成“只能在作者电脑跑”的状态

### 7.2 允许灵活处理的内容
以下内容允许你根据实际官方版本与兼容性进行合理选择，但必须固定下来并写入文档：

1. NEW-API 的具体稳定版本
2. LibreChat 的具体稳定版本
3. NEW-API 所需持久化依赖（选择官方支持的最小必要依赖）
4. LibreChat 所需依赖服务（按官方要求选择最小集合）
5. 本地与生产 compose 的具体服务拆分方式
6. 智谱渠道在 NEW-API 中采用**原生 provider 适配**还是**官方兼容 OpenAI 风格接入方式**  
   但无论采用哪种方法，最终必须：
   - 可配置
   - 可联调
   - 可 smoke test
   - 可用于最终验收

---

## 8. 架构要求

### 8.1 逻辑架构
上游模型渠道（至少含智谱）  
→ NEW-API（统一管理、路由、分发、额度、限流、审计）  
→ LibreChat（内部对话界面）  
→ 部门用户

### 8.2 物理部署形态
#### 本地开发/验证
- Docker Compose
- 服务容器化
- 配置通过环境变量和模板文件提供

#### 生产部署准备
- 单机云服务器
- Docker Compose
- 反向代理（Nginx 或 Caddy，选其一并写明）
- HTTPS 预留
- 数据持久化目录规划
- 备份恢复预案

---

## 9. 默认技术路线

请按以下默认路线推进：

1. 使用 **Monorepo** 管理整个整合项目
2. 使用 **Docker Compose** 管理本地/生产编排
3. 使用**官方镜像 + 配置外置 + 必要脚本**为主
4. 非必要不 fork 第三方源码
5. 若确需对第三方做小范围修改，必须：
   - 明确记录原因
   - 使用补丁/覆盖文件方式
   - 在文档中说明

---

## 10. 必须交付的项目结构

请至少生成并维护以下结构（可在不破坏可读性的前提下补充）：

TeamAIPlatform_main/
├─ README.md  
├─ .gitignore  
├─ .env.example  
├─ Makefile  
├─ docs/  
│  ├─ requirements.md  
│  ├─ implementation-plan.md  
│  ├─ acceptance-criteria.md  
│  ├─ architecture.md  
│  ├─ deployment-local.md  
│  ├─ deployment-cloud.md  
│  ├─ runbook.md  
│  ├─ provider-zhipu.md  
│  ├─ self-test-report.md  
│  └─ adr/  
│     └─ 0001-use-new-api-as-gateway.md  
├─ deploy/  
│  ├─ docker-compose.local.yml  
│  ├─ docker-compose.prod.yml  
│  ├─ env/  
│  │  ├─ local/  
│  │  │  └─ .env.example  
│  │  └─ prod/  
│  │     └─ .env.example  
│  ├─ librechat/  
│  │  └─ config/  
│  ├─ new-api/  
│  │  └─ config/  
│  └─ proxy/  
│     └─ config/  
├─ scripts/  
│  ├─ init-local.sh  
│  ├─ up.sh  
│  ├─ down.sh  
│  ├─ restart.sh  
│  ├─ healthcheck.sh  
│  ├─ smoke-test.sh  
│  ├─ smoke-test-zhipu.sh  
│  ├─ backup.sh  
│  ├─ restore.sh  
│  ├─ verify-no-secrets.sh  
│  └─ doctor.sh  
├─ tests/  
│  └─ smoke/  
└─ .github/  
   └─ workflows/  
      ├─ validate-compose.yml  
      └─ lint-docs-or-basic-check.yml  

说明：
- 如果某些文件名因上游工具实际要求需要微调，你可以调整，但必须在 README 和文档中保持一致
- 如果你选择不生成某个文件，必须给出充分理由；默认视为必须生成

---

## 11. 文档交付要求

所有文档默认使用 **中文**，内容要做到**给另一个工程师接手也能继续推进**。

### 必须完善的文档说明

#### 11.1 `docs/requirements.md`
需要明确：
- 项目背景
- 项目目标
- 角色定义
- 范围和非范围
- 功能需求
- 非功能需求
- 安全要求
- 工程边界
- 验收前提

#### 11.2 `docs/implementation-plan.md`
需要明确：
- 分阶段实施路径
- 每阶段任务
- 每阶段交付物
- 风险控制
- 依赖关系
- 里程碑
- 完成标准

#### 11.3 `docs/acceptance-criteria.md`
需要明确：
- 验收项
- Must / Should / Nice to Have
- 阻塞性问题定义
- 测试步骤
- 通过标准
- 上线前通过线

#### 11.4 `docs/architecture.md`
需要明确：
- 总体架构图
- 调用链路
- 组件职责
- 数据流向
- 安全边界
- 本地与生产拓扑关系

#### 11.5 `docs/deployment-local.md`
需要明确：
- 本地依赖
- 启动方法
- 环境变量说明
- 常见报错
- 调试方法

#### 11.6 `docs/deployment-cloud.md`
需要明确：
- 生产目录规划
- 反向代理/HTTPS 规划
- 持久化目录
- 部署步骤
- 升级与回滚
- 风险提示

#### 11.7 `docs/runbook.md`
需要明确：
- 健康检查
- 常见故障
- 排查路径
- 重启顺序
- 日志查看方法
- 备份恢复方法

#### 11.8 `docs/provider-zhipu.md`
这是重点文档，必须写清楚：
- 智谱渠道接入方式
- 采用的 provider 方案
- 所需环境变量
- 模型映射方式
- smoke test 方法
- 常见错误
- 验收使用方法

#### 11.9 `docs/self-test-report.md`
必须由你在完成实施后填写，至少包含：
- 你实际完成了哪些步骤
- 实际跑通了哪些测试
- 哪些测试依赖真实密钥
- 在检测到 `ZHIPU_API_KEY` 已填写时，你是否执行了真实联调
- 是否存在遗留问题
- 若存在，属于 P0 / P1 / P2 哪一级

---

## 12. 功能需求（必须落地）

### FR-01 项目根仓初始化
- 建立完整根仓结构
- Git 可追踪
- `.gitignore` 合理
- 禁止敏感信息入库

### FR-02 本地环境一键启动
- 提供一键初始化脚本
- 提供启动/停止/重启脚本
- 可在新机器按文档复现

### FR-03 NEW-API 基础接入
- 接入至少一个上游模型渠道
- 至少配置一个可调用模型
- 具备健康检查和基础日志

### FR-04 LibreChat 接入 NEW-API
- LibreChat 使用 NEW-API 作为统一模型出口
- 用户可以通过 LibreChat 发起正常对话
- 不直接暴露官方采购 API Key

### FR-05 智谱渠道接入（必须）
这是本次的硬要求。

#### 最低要求
1. 至少适配一个智谱 API Key 渠道
2. 预留完整环境变量位置
3. 支持在 NEW-API 中配置并被 LibreChat 使用
4. 支持 smoke test
5. 支持最终验收

#### 实施要求
- 你可以采用 NEW-API 支持的最稳妥方式接入智谱
- 如果该版本 NEW-API 原生支持智谱 provider，则优先使用原生 provider
- 如果该版本主要通过兼容 OpenAI 风格方式接入，则使用官方兼容方式
- 无论采用哪种，都必须形成：
  - 文档
  - 模板配置
  - 测试脚本
  - 可验证的模型别名/映射

#### 重要说明
最终验收我会使用**智谱 API**。  
因此，智谱渠道不是“顺手预留”，而是**必须打通的验收通道**。

### FR-06 模型可见性控制
- 至少区分管理员与普通用户
- 普通用户只看到授权模型
- 禁用模型不可正常使用

### FR-07 配额与限流
- 至少支持一种额度限制
- 至少支持一种频率限制
- 超额或超频时返回清晰错误

### FR-08 日志与审计
- 记录关键调用日志
- 记录关键错误日志
- 支持基础排障
- 若能力允许，记录关键管理变更

### FR-09 配置与密钥隔离
- local/prod 配置分离
- `.env.example` 完整
- 真实密钥不进入仓库

### FR-10 健康检查
- 检查关键服务状态
- 不只是“容器活着”，而要覆盖应用可用性
- 输出结果清晰

### FR-11 备份与恢复
- 明确持久化目录
- 提供 `backup.sh`
- 提供 `restore.sh`
- 至少支持最小可用恢复路径

### FR-12 云端部署准备
- `docker-compose.prod.yml`
- 生产环境变量模板
- 反向代理/HTTPS 方案
- 升级/回滚说明

### FR-13 文档交付
- 文档与脚本必须一致
- 不得出现文档里写 A、脚本实际叫 B 的情况

---

## 13. 非功能需求

### NFR-01 安全性
- 官方 API Key 仅保存在 NEW-API/环境变量侧
- 不出现在前端配置中
- 不出现在 Git 仓库中

### NFR-02 可维护性
- 固定镜像版本
- 配置外置
- 脚本化
- 文档化
- 目录结构清晰

### NFR-03 可复现性
- 新机器可按文档拉起
- 不依赖个人机器的隐藏状态

### NFR-04 可观测性
- 有健康检查
- 有日志
- 有基本排障路径

### NFR-05 稳定性
- 服务重启后可恢复
- 核心配置不丢失

### NFR-06 可扩展性
- 后续新增或替换上游模型时，不应重构前端

### NFR-07 可迁移性
- 本地与生产部署结构尽量一致

---

## 14. 仓库管理规则

### 14.1 必须纳入 Git
- compose 文件
- 配置模板
- 启停脚本
- 健康检查脚本
- smoke test 脚本
- 文档
- CI 校验文件
- 补丁文件（若有）

### 14.2 禁止纳入 Git
- 真实 API Key
- 生产 `.env`
- 日志文件
- 数据库数据
- 缓存
- 证书私钥
- 备份压缩包

### 14.3 分支建议
- `main`
- `dev`
- `feature/*`
- `fix/*`
- `docs/*`

### 14.4 提交要求
提交信息应可读，例如：
- `feat: add docker compose for local integration`
- `feat: add zhipu provider env template and smoke test`
- `docs: add cloud deployment guide`
- `fix: correct librechat to new-api endpoint mapping`

---

## 15. 环境变量模板要求

你必须提供完整 `.env.example`，并在本地与生产模板中保持对应关系。

### 15.1 通用要求
- 所有变量有注释说明
- 关键变量给出示例值或占位符
- 真实值由用户填写
- 如果某变量是必填，必须明确标注

### 15.2 必须预留的智谱变量（至少）
以下是必须出现的占位字段，命名可微调，但必须保留同等语义：

- `ZHIPU_ENABLED=true`
- `ZHIPU_API_KEY=__FILL_BY_USER__`
- `ZHIPU_API_BASE_URL=https://open.bigmodel.cn/api/paas/v4/`
- `ZHIPU_DEFAULT_MODEL=glm-4-flash`
- `ZHIPU_TEST_MODEL=glm-4-flash`
- `ZHIPU_CHANNEL_NAME=zhipu-primary`

如果你因 NEW-API 的实际接入方式需要补充额外字段，也必须一并加入，例如：
- provider type
- upstream alias
- model alias
- organization/project id（若某接入方式需要）
- timeout
- retry
- proxy 配置

### 15.3 智谱联调要求
- 当检测到 `ZHIPU_API_KEY` 非空时，脚本应支持真实联调
- `scripts/smoke-test-zhipu.sh` 应针对智谱渠道执行最小可用测试
- `scripts/smoke-test.sh` 应至少能覆盖：
  - NEW-API 基础可用性
  - 智谱模型调用验证（如已配置）
  - 结果输出/错误输出

---

## 16. 关于智谱渠道的明确要求

### 16.1 目标
智谱是本项目最终验收的主渠道。  
你必须确保仓库中已经把智谱路径完整预留并具备落地条件。

### 16.2 你必须做的事情
1. 预留智谱相关环境变量
2. 预留智谱接入说明文档
3. 预留 NEW-API 内部上游渠道配置模板
4. 预留至少一个对外暴露给 LibreChat 使用的模型映射
5. 准备智谱的 smoke test 脚本
6. 在 `self-test-report.md` 中说明：
   - 如果用户已填入 API Key，你是否执行了真实联调
   - 联调结果是什么

### 16.3 模型选择策略
优先选择一个普适、稳定、成本较低或较常见的模型名作为默认测试模型，例如：
- `glm-4-flash`

但必须把模型做成环境变量可配置，不要硬编码死。

### 16.4 若 provider 配置存在版本差异
由你自行研究当前稳定版本的 NEW-API 接入方式并选用最合理方案。  
**我不接受把“智谱怎么配”留给我自己再研究。**

---

## 17. 实施阶段要求

### Phase 0：建档与冻结
产出：
- requirements
- implementation-plan
- acceptance-criteria
- architecture
- ADR

### Phase 1：根仓与骨架
产出：
- Git 根仓
- `.gitignore`
- `.env.example`
- 目录结构
- README 基础版
- 脚本骨架

### Phase 2：本地编排
产出：
- `docker-compose.local.yml`
- 本地依赖服务定义
- 启停脚本
- 健康检查脚本

### Phase 3：NEW-API 接入
产出：
- NEW-API 配置模板
- 上游模型映射
- 日志/健康检查
- smoke test

### Phase 4：LibreChat 联调
产出：
- LibreChat 配置模板
- 端到端对话链路
- 模型展示与访问验证

### Phase 5：治理能力补齐
产出：
- 配额/限流配置
- 模型可见性
- 日志/排障
- 备份恢复脚本

### Phase 6：云端部署准备
产出：
- `docker-compose.prod.yml`
- 云端部署文档
- 反向代理/HTTPS 规划
- 升级回滚说明

### Phase 7：自测与交付
产出：
- `docs/self-test-report.md`
- 最终交付清单
- 未决问题列表（若有）
- 验收前检查结果

---

## 18. 脚本要求

以下脚本默认必须实现：

### `scripts/init-local.sh`
- 初始化本地目录
- 检查必要依赖
- 提示用户复制 `.env`
- 必要时初始化数据目录

### `scripts/up.sh`
- 启动本地服务
- 输出服务入口信息

### `scripts/down.sh`
- 停止服务

### `scripts/restart.sh`
- 重启服务

### `scripts/healthcheck.sh`
- 检查核心服务状态
- 应包含应用层检查，不只是容器状态

### `scripts/smoke-test.sh`
- 进行通用最小链路测试
- 若检测到某些 provider 已配置，则尝试相应测试

### `scripts/smoke-test-zhipu.sh`
- 专门用于验证智谱渠道
- 当 `ZHIPU_API_KEY` 非空时进行真实测试
- 输出成功/失败结果与错误定位建议

### `scripts/backup.sh`
- 备份关键持久化数据或配置

### `scripts/restore.sh`
- 恢复关键持久化数据或配置

### `scripts/verify-no-secrets.sh`
- 检查仓库中是否存在明显敏感信息误提交风险

### `scripts/doctor.sh`
- 帮助快速诊断环境变量、端口、依赖、服务状态问题

---

## 19. README 必须达到的标准

README 必须足够直接，至少包含：

1. 项目简介
2. 架构说明
3. 快速开始
4. 目录结构
5. 本地部署步骤
6. 核心脚本说明
7. 智谱渠道填写说明
8. smoke test 方法
9. 常见问题入口
10. 文档索引

要求：  
新接手的工程师不需要读源码，光看 README 和 docs 就能把项目拉起来。

---

## 20. 开发与配置边界（务必遵守）

### 20.1 不要做的事情
1. 不要把第三方源码整个复制进主仓当作“整合完成”
2. 不要要求我自己手动改一堆散落配置
3. 不要只输出“建议”，而没有落实成文件
4. 不要把敏感信息塞进模板
5. 不要留下一堆 `TODO` 却没有默认实现
6. 不要用过度复杂的架构
7. 不要把生产环境设计成必须依赖 K8s 才能工作

### 20.2 允许的折中
1. 若第三方服务有多个可选部署模式，选择最简且稳定的模式
2. 若个别功能受版本限制，可先实现最小可用版，但必须在文档说明差异
3. 若某项高级治理能力无法完全自动化，可先交付可操作模板和说明

---

## 21. 测试与自测要求

### 21.1 基础自测
至少验证：
1. 本地 compose 可启动
2. 关键服务可健康检查
3. NEW-API 可用
4. LibreChat 可访问
5. 日志可查看

### 21.2 功能自测
至少验证：
1. 通过 NEW-API 调用至少一个模型
2. LibreChat 通过 NEW-API 完成对话
3. 错误场景可定位
4. 智谱渠道已正确预留

### 21.3 智谱自测
当检测到以下条件成立时必须执行真实联调：
- `ZHIPU_ENABLED=true`
- `ZHIPU_API_KEY` 非空

执行内容至少包括：
1. 通过 NEW-API 调用智谱测试模型
2. 输出结果或错误
3. 记录到 `docs/self-test-report.md`

### 21.4 稳定性验证
至少做以下验证：
1. 服务重启恢复
2. 一定次数的连续请求 smoke test（轻量）
3. 无效配置场景的错误输出检查

---

## 22. 验收标准（你必须以此倒推实现）

### Must（必须通过）
1. 根仓结构完整
2. 文档齐全
3. 本地可一键启动核心服务
4. NEW-API 可正常工作
5. LibreChat 可通过 NEW-API 对话
6. 智谱 API 渠道已完整预留并具备联调能力
7. `.env.example` 完整
8. 无真实密钥入库
9. 健康检查脚本可用
10. smoke test 脚本可用
11. 具备云端部署模板
12. `self-test-report.md` 已填写

### Should（建议通过）
1. 模型可见性控制生效
2. 配额与限流可配置
3. 备份恢复可执行
4. 常见故障排查足够清晰
5. 存在基础 CI 检查

### 阻塞性失败（任何一条即不通过）
1. NEW-API 无法调用上游模型
2. LibreChat 无法完成端到端对话
3. 智谱渠道未预留或不可联调
4. 文档与脚本严重不一致
5. 真实密钥进入仓库
6. 本地无法复现
7. 没有可执行的健康检查与 smoke test
8. 用户仍需自己研究一大堆第三方配置才能完成联调

---

## 23. Definition of Done（你的完成标准）

你只有在以下条件全部满足时，才算真正完成：

1. 所有核心文件已经生成并组织到位
2. 文档与代码/脚本一致
3. 根仓可提交
4. `.env.example` 完整，真实密钥不入库
5. local compose 可运行
6. prod compose 模板存在
7. NEW-API → LibreChat 主链路已落地
8. 智谱渠道完整预留并可联调
9. 已进行自测并填写 `docs/self-test-report.md`
10. 已明确列出任何剩余风险与问题分级

---

## 24. 交付物清单（必须完整）

请最终至少交付以下内容：

### 根目录
- `README.md`
- `.gitignore`
- `.env.example`
- `Makefile`

### docs
- `docs/requirements.md`
- `docs/implementation-plan.md`
- `docs/acceptance-criteria.md`
- `docs/architecture.md`
- `docs/deployment-local.md`
- `docs/deployment-cloud.md`
- `docs/runbook.md`
- `docs/provider-zhipu.md`
- `docs/self-test-report.md`
- `docs/adr/0001-use-new-api-as-gateway.md`

### deploy
- `deploy/docker-compose.local.yml`
- `deploy/docker-compose.prod.yml`
- `deploy/env/local/.env.example`
- `deploy/env/prod/.env.example`
- `deploy/librechat/config/...`
- `deploy/new-api/config/...`
- `deploy/proxy/config/...`

### scripts
- `scripts/init-local.sh`
- `scripts/up.sh`
- `scripts/down.sh`
- `scripts/restart.sh`
- `scripts/healthcheck.sh`
- `scripts/smoke-test.sh`
- `scripts/smoke-test-zhipu.sh`
- `scripts/backup.sh`
- `scripts/restore.sh`
- `scripts/verify-no-secrets.sh`
- `scripts/doctor.sh`

### 其他
- `tests/smoke/...`
- `.github/workflows/...`

---

## 25. 关于版本选择的要求

你需要自行选择**当前稳定、互相兼容**的版本，但必须：

1. 固定版本号
2. 记录版本来源或理由
3. 在 README 或文档中说明版本矩阵
4. 不使用 `latest`

如果 NEW-API 与 LibreChat 某版本存在明显兼容性问题，你应主动规避并选择更稳妥版本。

---

## 26. 关于第三方源码的处理要求

### 默认策略
- 优先使用镜像
- 优先使用配置外置
- 优先使用脚本和环境变量接入

### 若必须修改第三方
- 仅做最小改动
- 以 patch、override、custom config 的方式维护
- 在文档中写明修改原因和影响
- 不得无说明地把大量第三方源码复制进项目仓库

---

## 27. 最终输出要求

在你执行完成后，必须给出一份**最终执行结果摘要**，至少包含：

1. 实际创建/修改了哪些文件
2. 实际采用了哪些版本
3. 本地如何启动
4. 智谱 API Key 应填在哪些位置
5. 智谱 smoke test 如何运行
6. 哪些内容已自测通过
7. 哪些内容因缺少真实密钥或外部资源而未能自动测试
8. 是否存在遗留问题
9. 若有遗留问题，按 P0/P1/P2 归类
10. 最终建议的验收顺序

---

## 28. 验收责任边界（必须写入最终文档与最终说明）

请在最终文档中明确写出以下内容，不可省略：

### 最终责任说明
1. **Codex 负责完整实施、结构整理、文档交付、脚本生成、配置模板、联调路径设计、自测与问题收敛**
2. **用户（Project Owner）最后只负责验收**
3. **用户会提供明确可用的智谱 API Key**
4. **最终验收将以智谱 API 渠道作为主验收渠道**
5. **除填写真实密钥与执行最终验收外，用户不负责代替 Codex 补做工程集成工作**

这段要求必须至少体现在：
- `README.md`
- `docs/provider-zhipu.md`
- `docs/acceptance-criteria.md`
- `docs/self-test-report.md`（可简述）

---

## 29. 你现在应当直接开始做的事情

请按以下顺序执行，不要空谈：

### 第一步
建立根仓结构与文档框架

### 第二步
生成 `.gitignore`、`.env.example`、Makefile、README

### 第三步
生成 local/prod compose、配置模板、脚本

### 第四步
落地 NEW-API 与 LibreChat 的接入路径

### 第五步
预留并适配智谱渠道

### 第六步
生成健康检查、通用 smoke test、智谱 smoke test

### 第七步
补齐 runbook、deployment、provider-zhipu、自测报告

### 第八步
完成自测并输出最终结果摘要

---

## 30. 最终强调

这不是一个“讨论型任务”，而是一个“施工型任务”。

目标不是把方案讲漂亮，  
而是要把下面这件事落下来：

**公司官方采购 API Key → NEW-API → LibreChat → 部门同学使用**

并且其中：
- **NEW-API 方案已经确认**
- **智谱渠道必须预留并可用于验收**
- **我本人最后只做验收**
- **我给的智谱 API 是明确可用的**
- **最终验收将以智谱 API 作为主渠道进行**

请直接按本文执行，并以“可交付、可自测、可验收”为唯一标准推进。

特别说明：
1、当前 `lgq` 账号拥有 sudo 权限；如需执行高阶命令，请通过本机安全渠道获取密码，禁止在文档中记录明文密码。
2、联调阶段如需使用智谱渠道，请通过本地 `.env` 中的 `ZHIPU_API_KEY` 配置，禁止在文档中记录真实 key。
3、再次声明，除非真的需要我手动执行，否则我只做验收
