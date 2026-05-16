# BrokerAssist Web

独立桌面 Web 前端，面向电脑浏览器使用。

## 当前范围

- 客户列表与搜索排序
- 客户详情
- 沟通记录时间线
- 生成客户摘要
- 生成拜访建议
- 客户专属 AI 问答
- 全局 AI 业务问答
- 新建客户

## 运行方式

这是一个无构建依赖的静态前端，直接用任意静态服务器启动即可。

示例：

```bash
cd web
python3 dev_server.py
```

然后在浏览器打开：

```text
http://127.0.0.1:4173
```

首次进入页面后，默认会使用同源 API 地址：

```text
http://127.0.0.1:4173/api/v1
```

`dev_server.py` 会把 `/api/v1` 和 `/media` 请求转发到后端 `http://127.0.0.1:8001`，浏览器侧不需要再关心后端端口。

## 说明

- 当前版本优先验证桌面信息架构和关键工作流，没有复刻移动端的录音与转写输入。
- 记录录入仍建议继续通过现有 App 完成，桌面 Web 先承担“查看、总结、提问、跟进”的角色。

## 前端结构

Web 版仍保持无构建依赖的静态前端，使用浏览器原生 ES module。

```text
web/
  index.html
  styles.css
  app.js
  src/
    state.js   # 全局状态与 localStorage key
    dom.js     # DOM 元素集中查询
    api.js     # API URL 拼装、JSON 请求、表单请求
    auth.js    # 登录、注册、退出、登录态恢复
    customers.js # 客户列表、搜索、新建、编辑、删除
    customer_detail.js # 客户详情、沟通记录、画像/建议、客户问答
    global_ai.js # 全局 AI 助手、跨客户问答、附件、回答导出
    utils.js   # 日期、转义、标签拆分、Markdown/富文本渲染
```

后续新增功能时，优先放入 `src/` 下的独立模块，再由 `app.js` 编排，避免继续扩大单文件脚本。
