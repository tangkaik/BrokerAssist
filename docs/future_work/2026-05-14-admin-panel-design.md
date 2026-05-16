# BrokerAssist 管理后台设计文档

> 创建日期：2026-05-14
> 状态：待审批

---

## 一、目标

为 BrokerAssist 构建一个 Web 端系统管理员后台，使管理员能够在线管理用户、配置系统、扩展行业和调整 AI 提示词，无需直接操作数据库或修改配置文件。

---

## 二、管理员身份

- 在 `users` 表新增 `is_admin` 布尔字段（默认 `false`）
- 管理员直接通过数据库设置：`UPDATE users SET is_admin = true WHERE account = 'xxx'`
- 后端通过依赖注入中间件校验 `is_admin`，所有 `/api/v1/admin/*` 路由受保护

---

## 三、整体架构

```
web/admin.html                 ← 新增：管理后台入口页面
web/src/admin/
  ├── dashboard.js             ← 仪表盘
  ├── users.js                 ← 用户管理
  ├── config.js                ← 系统配置
  ├── industries.js            ← 行业管理
  └── prompts.js               ← 提示词管理

server/app/
  api/admin_routes.py          ← 新增：管理 API 路由
  services/admin_service.py    ← 新增：管理业务逻辑
  models/config.py             ← 新增：动态配置表 (configs)
  models/industry.py           ← 新增：行业配置表 (industries)
```

- 管理后台通过 `/admin.html` 独立页面访问
- API 统一前缀：`/api/v1/admin/`
- 所有管理 API 需 `is_admin` 校验
- 前端风格与现有 Web 端保持一致（原生 JS + CSS，无构建工具）

---

## 四、模块详情

### 4.1 数据仪表盘

**页面布局：**
- 上方一排 4 个数字统计卡片：总用户数、总客户数、本月 AI 调用次数、近 7 天活跃用户数
- 下方左侧：近 30 天 AI 调用趋势折线图（纯 SVG/CSS 实现，不引入图表库）
- 下方右侧：各行业用户数与客户数的横向条形图

**API：** `GET /api/v1/admin/stats`
- 返回聚合统计数据
- 折线图数据：`[{date, kimi_calls, qwen_calls, xunfei_calls}]`

---

### 4.2 用户管理

**功能：**
- 分页表格展示：账号、昵称、行业、客户数、注册时间、最近活跃时间、状态（正常/已禁用）
- 搜索：按账号或昵称模糊搜索
- 操作：
  - 重置密码（管理员直接设置新密码）
  - 禁用/启用账号（禁用后无法登录）
  - 查看该用户的客户列表
- 不提供删除用户功能，避免误删数据

**API：**

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/admin/users` | 分页列表 + 搜索 |
| PUT | `/api/v1/admin/users/{id}/password` | 重置密码 |
| PUT | `/api/v1/admin/users/{id}/status` | 启用/禁用 |
| GET | `/api/v1/admin/users/{id}/customers` | 查看用户客户列表 |

---

### 4.3 系统配置

**设计原则：** 将频繁变动的配置从 `.env` 迁移到数据库 `configs` 表，在线修改即时生效。敏感信息（API Key、Secret、数据库连接）仍保留在 `.env`。

**动态配置项：**

| 配置项 | 说明 |
|--------|------|
| AI 模型选择 | Kimi model、Qwen VL model |
| 上传限制 | 最大图片张数、单张大小上限 |
| 默认测试账号开关 | 是否允许内置测试账号登录 |
| 注册开关 | 是否开放新用户注册 |

**页面：** 配置列表，每行：标签、当前值、修改输入框、保存按钮。改完即时生效。

**API：** `GET /api/v1/admin/configs`、`PUT /api/v1/admin/configs/{key}`

**数据模型：**
```
configs: id, key (unique), value, label, description, updated_at
```

---

### 4.4 行业管理

**功能：**
- 行业列表展示：key、中文标签、角色名、状态（启用/禁用）
- 新增行业：填写 key + 中文标签 + 角色名，其余提示词字段使用默认值
- 编辑行业：修改标签/角色名
- 启用/禁用行业：禁用后用户切换行业时不可见，但不删除已有用户数据关联

**API：** `GET/POST /api/v1/admin/industries`、`GET/PUT/DELETE /api/v1/admin/industries/{key}`

**数据模型：**
```
industries: id, key (unique), label, role_name, enabled, created_at, updated_at
```

**预置数据（迁移时插入）：**
- `generic` / 通用 / 客户关系管理助手
- `insurance` / 保险经纪 / 保险经纪人助手
- `real_estate` / 房产顾问 / 房产顾问助手

**现有代码迁移：** `industry_profiles.py` 中的 `_PROFILES` 改为从数据库加载，数据库无数据时回退到硬编码默认值。

---

### 4.5 提示词管理

**功能：**
- 选择一个行业后，展示该行业下的所有提示词配置
- 可编辑字段（对应 IndustryProfile）：
  - `summary_focus`：摘要关注点（多行文本，一行一项）
  - `missing_info`：信息缺失项
  - `advice_focus`：建议方向
  - `forbidden_guidance`：禁用话术
  - `query_examples`：查询示例
- 系统提示词（不按行业）：全局 AI 助手的 system prompt 也可在线编辑
- 每个字段旁边有"恢复默认"按钮，重置为代码中的硬编码默认值

**API：** `GET/PUT /api/v1/admin/industries/{key}/prompts`

**数据模型：**
```
industry_prompts: id, industry_key (FK), prompt_field, value, created_at, updated_at
```

默认值仍保持在 `industry_profiles.py` 中作为回退。

---

## 五、数据库变更

### users 表
```sql
ALTER TABLE users ADD COLUMN is_admin BOOLEAN NOT NULL DEFAULT false;
```

### 新增 configs 表
```sql
CREATE TABLE configs (
    id UUID PRIMARY KEY,
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT NOT NULL,
    label VARCHAR(200),
    description TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 新增 industries 表
```sql
CREATE TABLE industries (
    id UUID PRIMARY KEY,
    key VARCHAR(40) UNIQUE NOT NULL,
    label VARCHAR(100) NOT NULL,
    role_name VARCHAR(100) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 新增 industry_prompts 表
```sql
CREATE TABLE industry_prompts (
    id UUID PRIMARY KEY,
    industry_key VARCHAR(40) NOT NULL REFERENCES industries(key) ON DELETE CASCADE,
    prompt_field VARCHAR(100) NOT NULL,
    value TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(industry_key, prompt_field)
);
```

---

## 六、后端路由汇总

| 方法 | 路径 | 模块 |
|------|------|------|
| GET | `/api/v1/admin/stats` | 仪表盘 |
| GET | `/api/v1/admin/users` | 用户列表 |
| PUT | `/api/v1/admin/users/{id}/password` | 重置密码 |
| PUT | `/api/v1/admin/users/{id}/status` | 启用/禁用 |
| GET | `/api/v1/admin/users/{id}/customers` | 用户客户列表 |
| GET | `/api/v1/admin/configs` | 配置列表 |
| PUT | `/api/v1/admin/configs/{key}` | 修改配置 |
| GET | `/api/v1/admin/industries` | 行业列表 |
| POST | `/api/v1/admin/industries` | 新增行业 |
| GET | `/api/v1/admin/industries/{key}` | 行业详情 |
| PUT | `/api/v1/admin/industries/{key}` | 编辑行业 |
| DELETE | `/api/v1/admin/industries/{key}` | 删除行业 |
| GET | `/api/v1/admin/industries/{key}/prompts` | 行业提示词 |
| PUT | `/api/v1/admin/industries/{key}/prompts` | 修改提示词 |

---

## 七、前端结构

管理后台独立入口 `/admin.html`，通过顶部导航进入。样式复用 `styles.css` 的设计语言，新增模块化 JS：

```
web/src/admin/
  dashboard.js   — 加载统计数据，渲染卡片和图表
  users.js        — 用户列表、搜索、操作按钮
  config.js       — 配置项表单
  industries.js   — 行业列表 CRUD
  prompts.js      — 提示词编辑器
```

页面布局：顶部横向导航 Tab（仪表盘、用户管理、系统配置、行业管理、提示词管理），下方为各模块的内容区域，Tab 切换用 JS 控制显隐或简单 SPA 路由。

---

## 八、不在本次范围内的项目

- 完整 RBAC 多角色系统
- 管理操作审计日志
- 批量导入/导出用户
- 前端图表库引入
- 管理后台独立认证（复用现有登录态 + is_admin 校验）

以上列入未来迭代。
