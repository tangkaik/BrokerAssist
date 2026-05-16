# JSON 文件存储 → 数据库迁移建议

**现状**: `server/data/` 下有 3 个 JSON 文件用于持久化数据，均为 MVP 阶段绕过表结构修改的临时方案。

---

## 1. 拜访建议 (`customer_advices.json`) → `customers.advice_text`

- **当前**: `CustomerAdviceStore` 读写 JSON 文件，CustomerService 需同时查数据库和 JSON 拼数据返回
- **关系**: 客户:建议 = 1:1，同表已有 `summary_text` 同等字段
- **结论**: **迁**。加一列 `Text`，改两处 service 代码，成本极低

## 2. 记录图片索引 (`record_images_index.json`) → 新建 `record_images` 表

- **当前**: JSON 索引作为 record→images 的唯一映射，与 records 表脱钩；图片文件存本地磁盘
- **问题**: 删 record 时 JSON 和磁盘操作不在同一事务，可能不一致；JSON 文件丢失则图片变孤儿
- **结论**: **元数据迁，文件留磁盘**。建表存 `id / record_id(FK) / name / file_path / url / content_type`

## 3. 图片识别结果 (`record_image_analysis.json`) → 并入 `record_images` 表

- **当前**: JSON 存 `{record_id: {image_url: {answer}}}`，与图片 1:1
- **当前数据为空**，迁移零成本
- **结论**: **并入**，在 `record_images` 表加 `vision_analysis JSONB` 列

---

## 改动量估算

| 项目 | 内容 |
|------|------|
| 数据库 | `customers` 加 1 列 + 新建 `record_images` 表（1 个 migration） |
| 数据迁移 | 一条脚本灌 `customer_advices.json` → `customers.advice_text` |
| 代码改动 | 3 个 Store 类改为 ORM 读写 + CustomerService / RecordService 调整数据组装 |
| 风险 | 低。`record_images` 和 `vision_analysis` 当前数据为空，仅 `customer_advices.json` 有 129 行需迁移 |
