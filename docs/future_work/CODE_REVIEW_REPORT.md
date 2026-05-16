# BrokerAssist 代码审查报告

**审查日期**: 2026-05-07
**审查范围**: server（Python/FastAPI）、mobile（Flutter）、web（Vanilla JS）

---

## 严重问题

### 1. 硬编码 JWT Token 提交到 Git

**文件**: `mobile/lib/config/config.dart:15`

```dart
static const String defaultToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiZGVmYXVsdC11c2VyIn0.FRHB6-A51jwFCjJ3Y5FAyKXe8iQhZqA3-KjeymG6dZw';
```

完整的 JWT token 编译进 App 二进制，任何人反编译即可获取。payload 为 `{"user_id":"default-user"}`，直接可用于认证。**该文件被 git 跟踪，永久存在于历史记录中。**

### 2. Argon2 密码哈希参数过弱

**文件**: `server/app/core/security.py:17-19`

```python
ARGON2_TIME_COST = 2       # OWASP 建议 >= 3
ARGON2_MEMORY_COST = 19456 # ≈19MB，偏低
```

`time_cost=2` 低于 OWASP 最低推荐值。建议至少 `time_cost=3`, `memory_cost=65536`。代码注释称"为低配云主机优化"，但这是以安全性为代价。

### 3. 登录接口接受 3 位密码

**文件**: `server/app/schemas/auth.py:34`

```python
password: str = Field(..., min_length=3, max_length=128)
```

注释承认是为了兼容 `t1`/`t2` 等弱密码测试账号。这意味着已存在的弱密码账号可被暴力破解。注册需要 8 位但登录只需 3 位，两者不一致。

---

## 高危问题

### 4. 弱 JWT 签名密钥默认值

**文件**: `server/app/core/config.py:64`

```python
auth_secret_key: str = "brokerassist-dev-secret-change-me"
```

虽然有 `validate()` 在生产环境检查，但如果部署时未覆盖环境变量或未调用 `validate()`，JWT 可被任何人伪造。

### 5. 测试账号硬编码

**文件**: `server/app/core/config.py:61-63` + `server/app/db/init_db.py:79`

```python
default_test_account: str = "t1"
default_test_password: str = "123"
```

启动时自动创建 `t1/123` 账号到数据库。攻击者只需知道这个账号即可登录。已提交到 git。

### 6. 无登录速率限制

**文件**: `server/app/api/auth_routes.py:19-40`

`POST /auth/login` 和 `POST /auth/register` 没有任何速率限制。结合 3 位密码下限，可被暴力破解。建议使用 slowapi 或 Redis 实现。

### 7. 音频上传接受 500MB

**文件**: `server/app/services/transcription_service.py:55`

```python
MAX_FILE_SIZE = 500 * 1024 * 1024  # 500MB
```

单个上传可传输 500MB，加上 60 次 × 5 秒 = 5 分钟的轮询，每次转写任务占用连接 5 分钟，存在 DoS 风险。建议限制为 50MB。

### 8. 内部异常消息泄露给客户端

**文件**: `server/app/services/customer_service.py` 多处

```python
detail=f"摘要生成失败: {str(e)}"   # 第 459 行
detail=f"对话生成失败: {str(e)}"   # 第 571 行
detail=f"建议生成失败: {str(e)}"   # 第 665 行
```

内部异常信息（可能包含 API key、文件路径等）直接返回给客户端。应记录日志并返回通用错误消息。

---

## 中危问题

### 9. 公网 IP 硬编码

**文件**: `mobile/lib/config/config.dart:11`

```dart
defaultValue: 'http://39.106.169.40/api/v1',
```

服务器公网 IP 直接暴露在源码中，提交到 git。

### 10. Token 存储在 localStorage（Web 端）

**文件**: `web/app.js:3-4`

```javascript
const AUTH_TOKEN_KEY = "brokerassist:web:auth-token";
state.authToken = localStorage.getItem(AUTH_TOKEN_KEY) || "";
```

JWT 存储在 `localStorage`，任何 XSS 漏洞都可以窃取 token。建议改用 `httpOnly` cookie。

### 11. AI 提示词注入风险

**文件**: `server/app/services/customer_service.py:422-424`

```python
records_text = "\n---\n".join([
    f"【记录 {i+1} - {r.created_at.strftime('%Y-%m-%d')}】\n{r.content}"
    for i, r in enumerate(records)
])
```

客户记录内容直接拼接到 LLM prompt 中，无任何过滤。如果记录内容包含 `忽略之前的指令` 等提示词注入内容，可能影响 LLM 输出。

### 12. 转写详情访问绕过所有权检查

**文件**: `server/app/services/transcription_service.py:449-454`

```python
# 如果没有 customer_id，允许访问（首页草稿流程）
# 注意：这里假设知道 transcription_id 就有权限，因为 id 是随机的
```

对于没有关联 customer_id 的转写任务，任何知道 UUID 的人都可以通过轮询接口获取转写结果。

### 13. KimiClient 全局单例有并发问题

**文件**: `server/app/ai/kimi_client.py:240-248`

```python
def get_kimi_client() -> KimiClient:
    global _kimi_client
    if _kimi_client is None:  # TOCTOU 竞态条件
        _kimi_client = KimiClient()
    return _kimi_client
```

存在竞态条件。且 `CustomerService` 中每次调用都创建新的 `KimiClient()` 实例，全局单例实际上未被使用。

---

## 低危 / 建议改进

### 14. CORS 默认通配符

**文件**: `server/app/core/config.py:74`

`cors_allow_origins: str = "*"` — 生产环境有校验，但开发环境保持通配符。

### 15. KimiClient.__del__ 的异步清理不可靠

**文件**: `server/app/ai/kimi_client.py:224-236`

在析构函数中做异步操作（`asyncio.create_task` / `run_until_complete`）不可靠，析构时事件循环可能已关闭。

### 16. Web 端无 CSP 头

**文件**: `web/index.html`

没有设置 `Content-Security-Policy` 头，无法防御 XSS 攻击。

### 17. Flutter Token 存储在未加密的 SharedPreferences

**文件**: `mobile/lib/services/auth_session.dart`

在 root 设备上可被读取。建议生产环境使用 `flutter_secure_storage`。

---

## 正面发现

| 项目 | 状态 |
|------|------|
| `.env` 被 gitignore 正确排除 | 通过 |
| SQL 查询使用参数化，无 SQL 注入 | 通过 |
| 客户数据隔离（所有查询带 `user_id`） | 良好 |
| 软删除实现（`deleted_at` 字段） | 良好 |
| 文件名校验有白名单（音频格式、图片幻数） | 良好 |
| 生产环境配置校验（`validate()`） | 有但不强制执行 |
| Web 端 HTML 转义（`escapeHtml`）防 XSS | 良好 |
| 密码哈希使用 Argon2（非 MD5/SHA） | 良好 |
| 讯飞 API HMAC-SHA1 签名 | 良好 |

---

## 优先修复建议

1. **立即轮换所有 API Key**（DeepSeek、DashScope、讯飞）—— `.env` 和 git 历史中均有暴露
2. **立即从 git 历史中清除 `config.dart` 的 JWT token**（用 `git filter-branch` 或 BFG）
3. **增加登录速率限制**（用 slowapi 或 Redis 实现）
4. **提高 Argon2 参数**：`time_cost >= 3`, `memory_cost >= 65536`
5. **统一密码策略**：登录和注册都用最少 8 位，迁移 t1/t2 测试账号密码
6. **生产环境强制覆盖所有默认密钥**（在 `validate()` 中阻止启动而非仅警告）
7. **限制音频上传大小**为 50MB
8. **隐藏内部错误详情**，客户端只返回通用错误码
