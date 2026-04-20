# BrokerAssist 改进计划

## 一、提取 Prompt 到独立配置（用户要求）

**目标**：将所有 AI 提示词从代码中分离到 `prompts.yaml`，便于集中管理和调整。

**涉及文件**：

| Prompt ID | 用途 | 当前位于 |
|-----------|------|----------|
| `prompt.customer_summary` | 生成客户摘要 | `customer_service.py:357` |
| `prompt.customer_summary_system` | 摘要 system prompt | `customer_service.py:417` |
| `prompt.customer_chat` | 客户对话 | `customer_service.py:515` |
| `prompt.customer_chat_system` | 对话 system prompt | `customer_service.py:540` |
| `prompt.advice` | 拜访建议生成 | `customer_service.py:621` |
| `prompt.advice_system` | 建议 system prompt | `customer_service.py:666` |
| `prompt.area_classify` | 地点目标分类 | `ai_service.py:383` |
| `prompt.area_classify_system` | 分类 system prompt | `ai_service.py:396` |
| `prompt.location_extract` | 提取地点短语 | `ai_service.py:423` |
| `prompt.location_extract_system` | 提取 system prompt | `ai_service.py:440` |
| `prompt.location_classify` | 地点归属判断 | `ai_service.py:475` |
| `prompt.location_classify_system` | 判断 system prompt | `ai_service.py:492` |
| `prompt.global_qa` | 全局 AI 问答 | `ai_service.py:702` |
| `prompt.global_qa_system` | 问答 system prompt | `ai_service.py:739` |
| `prompt.image_analysis` | 图片分析 | `record_image_analysis_service.py:36` |
| `prompt.image_analysis_fallback` | 图片分析默认模式 | `record_image_analysis_service.py:62` |

**实施步骤**：
1. 新建 `server/app/prompts.yaml`
2. 创建 `server/app/core/prompts.py` 加载并提供类型安全的访问接口
3. 重构 `customer_service.py`、`ai_service.py`、`record_image_analysis_service.py` 改为从 `prompts.py` 读取
4. **测试**：验证所有 AI 功能（摘要生成、对话、建议、地点问答、图片识别）输出与修改前一致

---

## 二、性能优化（中优先级）

### 2.1 修复 N+1 查询（`ai_service.py:610-659`）
- **问题**：循环内对每个客户单独查询其 records
- **修复**：使用 SQLAlchemy joinedload 预加载，或一次性查询后按客户分组

### 2.2 客户查询添加分页
- **问题**：`get_customer_list` 无分页，大数据量时内存爆炸
- **修复**：添加 `limit`/`offset` 参数，默认分页 20 条

### 2.3 AI 服务无分页加载
- **问题**：`ask_global_question` 加载全部客户及记录到内存
- **修复**：分批处理或限制加载数量

**测试**：使用 Python 验证脚本或 Postman 发送请求，检查响应内容不变

---

## 三、CORS 配置（低优先级）

- **问题**：`config.py` 默认 `cors_allow_origins: str = "*"`
- **修复**：从环境变量读取，默认值改为空字符串（严格模式）

**测试**：先用 `*` 验证功能正常，再改为明确的域名列表测试拒绝非授权跨域请求

---

## 四、代码组织优化

### 4.1 拆分 `home_page.dart`（约 870 行）
拆分为独立组件：
- `AudioRecordingSection` - 录音区
- `TranscriptionSection` - 转写区
- `BottomActionsSection` - 底部操作区

### 4.2 提取重复的客户所有权检查逻辑
**问题**：客户存在性校验在多处重复（`customer_service.py` 至少 8 处）

**修复**：抽取为私有方法 `_get_customer_if_owned(user_id, customer_id)`

**测试**：现有客户管理 API（CRUD）全部回归通过

---

## 五、安全强化（持续）

### 5.1 Token 加密存储
- **问题**：JWT 明文存储在 SharedPreferences
- **条件**：需要 Android KeyStore / iOS Keychain 的 Flutter 插件配合（需评估可行性）

---

## 测试策略

每项修改后必须验证：

| 修改项 | 验证方式 |
|--------|----------|
| Prompt 提取 | 所有 AI 功能（摘要/对话/建议/问答/图片）输出内容一致 |
| N+1 查询修复 | 用 20+ 客户数据验证响应时间改善或不变 |
| 分页 | `?limit=5` 返回 5 条，`?offset=10` 正确跳过 |
| CORS | 浏览器 DevTools Network 确认预检请求被正确处理 |
| home_page 拆分 | 各组件交互行为不变 |
| 客户校验抽取 | CRUD 操作正常 |
