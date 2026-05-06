"""
根据拜访记录填充客户缺失的 age 和 location_raw。
1. 先从 records content 和 summary_text 中提取
2. 提取不到则用 Kimi AI 根据上下文生成
3. 完全没有上下文的也生成一个合理的
"""
import asyncio
import json
import logging
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from sqlalchemy import select, func
from app.db.session import async_session_factory
from app.models.customer import Customer
from app.models.record import Record
from app.ai.kimi_client import KimiClient

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("fill_fields")

# ---- 本地正则提取 ----

def extract_age_from_text(text: str) -> int | None:
    """从文本中提取年龄"""
    if not text:
        return None
    # 匹配 "35岁"、"年龄35"、"今年35" 等
    patterns = [
        r'(\d{1,3})\s*岁',
        r'年龄[：:]\s*(\d{1,3})',
        r'今年\s*(\d{1,3})',
        r'现年\s*(\d{1,3})',
    ]
    for pat in patterns:
        m = re.search(pat, text)
        if m:
            age = int(m.group(1))
            if 18 <= age <= 90:
                return age
    return None


def extract_location_from_text(text: str) -> str | None:
    """从文本中提取地点线索"""
    if not text:
        return None
    # 常见住址/工作地模式
    patterns = [
        r'住[在的]([一-鿿]{2,10}(?:区|县|镇|街道|路|园|城|庄|桥|营|店|苑|小区))',
        r'在([一-鿿]{2,10}(?:区|县|镇|街道|路|园|城|庄|桥|营|店|苑|小区))\s*(?:住|附近|这边|那边|上班|工作)',
        r'客户住[在的]([一-鿿]{2,15})',
        r'(?:住在|家住|地址[：:])\s*([一-鿿]{2,30})',
        r'去([一-鿿]{2,10}(?:区|县|镇|路|园|城|庄|桥|营|店|苑|小区))\s*(?:拜访|见面|聊)',
    ]
    for pat in patterns:
        m = re.search(pat, text)
        if m:
            loc = m.group(1).strip()
            # 过滤太泛的名称
            if loc not in {'这边', '那边', '附近', '那边附近', '这里', '那里'}:
                return loc
    return None


async def get_customer_records(customer_id: str) -> list[Record]:
    async with async_session_factory() as session:
        result = await session.execute(
            select(Record)
            .where(Record.customer_id == customer_id)
            .order_by(Record.created_at)
        )
        return list(result.scalars().all())


async def get_customer_context(customer: Customer) -> str:
    """拼装客户上下文给 AI"""
    parts = []
    parts.append(f"客户姓名: {customer.name}")
    if customer.gender:
        parts.append(f"性别: {customer.gender}")
    if customer.tags:
        parts.append(f"标签: {', '.join(customer.tags)}")

    records = await get_customer_records(customer.id)
    if records:
        parts.append("沟通记录:")
        for r in records[:5]:
            content = (r.content or "")[:200]
            parts.append(f"  [{r.created_at.strftime('%Y-%m-%d')}] {content}")

    if customer.summary_text:
        parts.append(f"客户摘要: {customer.summary_text[:300]}")

    return "\n".join(parts)


async def ai_fill_age_and_location(customer: Customer) -> tuple[int | None, str | None]:
    """用 Kimi 推断年龄和地点"""
    context = await get_customer_context(customer)

    prompt = (
        "请根据以下客户信息，推断或生成一个合理的年龄和常用地址。\n\n"
        f"{context}\n\n"
        "请只输出一个 JSON，格式严格如下：\n"
        '{"age": 数字或null, "location": "合理的地点字符串或null"}\n\n'
        "规则：\n"
        "- 如果记录中有明确年龄信息，使用记录中的\n"
        "- 如果没有，根据客户标签和内容合理推断（如'企业高管'通常40-55岁，'自媒体'通常25-40岁）\n"
        "- location 应当是一个具体的区域名（如'海淀五路居'、'国贸'），不要省市前缀\n"
        "- 如果记录中有明确地点，直接提取；如果没有，根据客户标签和内容合理生成\n"
        "- 如果完全无法推断，设为 null"
    )

    try:
        kimi = KimiClient()
        try:
            result_text = await kimi.chat_simple(
                prompt=prompt,
                system_prompt="你是一个客户数据分析助手，只输出 JSON。",
            )
        finally:
            await kimi.close()

        # 解析 JSON
        start = result_text.find("{")
        end = result_text.rfind("}")
        if start != -1 and end != -1:
            data = json.loads(result_text[start:end+1])
            age = data.get("age")
            if isinstance(age, (int, float)) and 18 <= age <= 90:
                age = int(age)
            else:
                age = None
            location = data.get("location")
            if isinstance(location, str) and location.strip() and location.strip().lower() != "null":
                location = location.strip()[:100]
            else:
                location = None
            return age, location
    except Exception as e:
        logger.warning(f"AI inference failed for {customer.name}: {e}")

    return None, None


async def main():
    async with async_session_factory() as session:
        result = await session.execute(
            select(Customer).where(Customer.deleted_at.is_(None))
        )
        customers = result.scalars().all()

    needs_age = [c for c in customers if c.age is None]
    needs_loc = [c for c in customers if not c.location_raw]

    logger.info(f"Need age: {len(needs_age)}, Need location: {len(needs_loc)}")

    # 先去重（同一客户可能同时缺 age 和 location）
    work_set: dict[str, Customer] = {}
    for c in customers:
        if c.age is None or not c.location_raw:
            work_set[c.id] = c

    logger.info(f"Total customers to process: {len(work_set)}")

    for i, (cid, c) in enumerate(work_set.items(), 1):
        name = c.name
        logger.info(f"\n[{i}/{len(work_set)}] {name}")

        # 获取所有文本用于本地提取
        records = await get_customer_records(c.id)
        all_text = "\n".join([
            r.content or "" for r in records
        ])
        if c.summary_text:
            all_text += "\n" + c.summary_text

        # 尝试本地提取
        local_age = extract_age_from_text(all_text)
        local_loc = extract_location_from_text(all_text)

        need_ai_age = c.age is None and local_age is None
        need_ai_loc = not c.location_raw and local_loc is None

        # 如果本地提取到了，先标记
        final_age = c.age if c.age is not None else local_age
        final_loc = c.location_raw if c.location_raw else local_loc

        if need_ai_age or need_ai_loc:
            logger.info(f"  Using AI to infer... (need_age={need_ai_age}, need_loc={need_ai_loc})")
            ai_age, ai_loc = await ai_fill_age_and_location(c)
            if need_ai_age and ai_age is not None:
                final_age = ai_age
                logger.info(f"  AI age -> {ai_age}")
            if need_ai_loc and ai_loc is not None:
                final_loc = ai_loc
                logger.info(f"  AI location -> {ai_loc}")
            await asyncio.sleep(0.5)  # 避免 API 限流

        if final_age is None and local_age is None:
            logger.info(f"  Still no age, skipping")
        if final_loc is None and local_loc is None:
            logger.info(f"  Still no location, skipping")

        # 更新数据库
        if final_age != c.age or final_loc != (c.location_raw or None):
            async with async_session_factory() as session:
                result = await session.execute(
                    select(Customer).where(Customer.id == cid)
                )
                db_c = result.scalar_one_or_none()
                if db_c:
                    if final_age is not None and db_c.age is None:
                        db_c.age = final_age
                    if final_loc is not None and not db_c.location_raw:
                        db_c.location_raw = final_loc
                    await session.commit()
            logger.info(f"  Saved: age={final_age}, location={final_loc!r}")
        else:
            logger.info(f"  No changes needed")

    # 最终统计
    async with async_session_factory() as session:
        result = await session.execute(
            select(func.count()).where(Customer.deleted_at.is_(None), Customer.age.is_(None))
        )
        still_no_age = result.scalar()
        result = await session.execute(
            select(func.count()).where(Customer.deleted_at.is_(None),
                (Customer.location_raw.is_(None)) | (Customer.location_raw == ''))
        )
        still_no_loc = result.scalar()

    logger.info(f"\nDone. Still missing age: {still_no_age}, location: {still_no_loc}")


if __name__ == "__main__":
    asyncio.run(main())
