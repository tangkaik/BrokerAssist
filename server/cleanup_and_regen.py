"""
清理数据库脚本：
1. 删除所有带有图片的"沟通记录"(records)
2. 清理图片相关 JSON 和磁盘文件
3. 重置所有客户的"客户画像摘要"和"下一步建议"
4. 为每个客户重新生成摘要和建议
"""
import asyncio
import json
import logging
import shutil
import sys
from datetime import datetime
from pathlib import Path

# 确保可以导入 app 模块
sys.path.insert(0, str(Path(__file__).resolve().parent))

from sqlalchemy import select, delete, and_
from app.db.session import async_session_factory
from app.models.customer import Customer
from app.models.record import Record
from app.models.user import User
from app.ai.kimi_client import KimiClient
from app.core.prompts import (
    customer_summary,
    customer_summary_system,
    advice,
    advice_system,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("cleanup")

SERVER_ROOT = Path(__file__).resolve().parent
DATA_DIR = SERVER_ROOT / "data"

IMAGE_INDEX_FILE = DATA_DIR / "record_images_index.json"
IMAGE_ANALYSIS_FILE = DATA_DIR / "record_image_analysis.json"
ADVICES_FILE = DATA_DIR / "customer_advices.json"
IMAGE_DIR = DATA_DIR / "record_images"


def load_json(path: Path) -> dict:
    try:
        if path.exists():
            text = path.read_text(encoding="utf-8").strip()
            if text:
                data = json.loads(text)
                return data if isinstance(data, dict) else {}
    except Exception as e:
        logger.warning(f"Failed to read {path}: {e}")
    return {}


def save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


async def step1_delete_image_records() -> tuple[list[str], dict]:
    """Step 1: 读取图片索引，删除对应的 records"""
    image_index = load_json(IMAGE_INDEX_FILE)

    # 收集有图片的 record IDs
    record_ids_with_images = [
        rid for rid, images in image_index.items()
        if isinstance(images, list) and len(images) > 0
    ]

    if not record_ids_with_images:
        logger.info("没有找到带图片的沟通记录，跳过删除")
        return [], image_index

    logger.info(f"找到 {len(record_ids_with_images)} 条带图片的沟通记录: {record_ids_with_images}")

    async with async_session_factory() as session:
        for rid in record_ids_with_images:
            await session.execute(
                delete(Record).where(Record.id == rid)
            )
        await session.commit()

    logger.info(f"已从数据库删除 {len(record_ids_with_images)} 条沟通记录")
    return record_ids_with_images, image_index


async def step2_cleanup_image_data(record_ids_with_images: list[str]) -> None:
    """Step 2: 清理图片 JSON 文件和磁盘文件"""
    # 清空 record_images_index.json
    save_json(IMAGE_INDEX_FILE, {})
    logger.info(f"已清空 {IMAGE_INDEX_FILE}")

    # 清空 record_image_analysis.json
    save_json(IMAGE_ANALYSIS_FILE, {})
    logger.info(f"已清空 {IMAGE_ANALYSIS_FILE}")

    # 删除磁盘图片目录
    if IMAGE_DIR.exists():
        shutil.rmtree(IMAGE_DIR)
        IMAGE_DIR.mkdir(parents=True, exist_ok=True)
        logger.info(f"已删除图片目录: {IMAGE_DIR}")


async def step3_reset_customers() -> list[dict]:
    """Step 3: 重置所有客户摘要状态，清空建议文件"""
    async with async_session_factory() as session:
        result = await session.execute(
            select(Customer).where(Customer.deleted_at.is_(None))
        )
        customers = result.scalars().all()

        customer_list = []
        for c in customers:
            customer_list.append({
                "id": c.id,
                "name": c.name,
                "user_id": c.user_id,
            })
            c.summary_status = "stale"
            c.summary_text = None

        await session.commit()
        logger.info(f"已重置 {len(customer_list)} 位客户的摘要状态")

    # 清空建议文件
    save_json(ADVICES_FILE, {})
    logger.info(f"已清空 {ADVICES_FILE}")

    return customer_list


async def step4_regen_for_customer(customer: dict) -> bool:
    """Step 4: 为单个客户重新生成摘要和建议"""
    customer_id = customer["id"]
    name = customer["name"]
    user_id = customer["user_id"]
    industry_key = "generic"

    # --- 获取记录 ---
    async with async_session_factory() as session:
        user = await session.get(User, user_id)
        if user and user.industry_key:
            industry_key = user.industry_key

        result = await session.execute(
            select(Record)
            .where(Record.customer_id == customer_id)
            .order_by(Record.created_at)
        )
        records = list(result.scalars().all())

    if not records:
        logger.info(f"[{name}] 无沟通记录，跳过")
        return False

    # 过滤噪音记录
    NOISE_PHRASES = ['确认转写', '确认文本', '测试录音', '测试一下', '这是一条测试', '请点击链接']
    MIN_RECORD_LENGTH = 20
    filtered = []
    for r in records:
        content = r.content or ""
        is_short = len(content) < MIN_RECORD_LENGTH
        has_noise = any(phrase in content for phrase in NOISE_PHRASES)
        if is_short and has_noise:
            continue
        filtered.append(r)
    if len(filtered) >= 2:
        records = filtered

    records_text = "\n---\n".join([
        f"【记录 {i+1} - {r.created_at.strftime('%Y-%m-%d')}】\n{r.content}"
        for i, r in enumerate(records)
    ])

    # --- 生成摘要 ---
    logger.info(f"[{name}] 正在生成客户画像摘要 ({len(records)} 条记录, industry={industry_key})...")
    summary_prompt = customer_summary(records_text, industry_key=industry_key)

    try:
        kimi = KimiClient()
        try:
            summary_text = await kimi.chat_simple(
                prompt=summary_prompt,
                system_prompt=customer_summary_system(industry_key=industry_key),
            )
        finally:
            await kimi.close()

        if not summary_text or not summary_text.strip():
            logger.error(f"[{name}] LLM 返回空摘要")
            async with async_session_factory() as session:
                result = await session.execute(
                    select(Customer).where(Customer.id == customer_id)
                )
                c = result.scalar_one_or_none()
                if c:
                    c.summary_status = "failed"
                    await session.commit()
            return False

        summary_text = summary_text.strip()
    except Exception as e:
        logger.error(f"[{name}] 摘要生成失败: {e}")
        async with async_session_factory() as session:
            result = await session.execute(
                select(Customer).where(Customer.id == customer_id)
            )
            c = result.scalar_one_or_none()
            if c:
                c.summary_status = "failed"
                await session.commit()
        return False

    # 保存摘要
    async with async_session_factory() as session:
        result = await session.execute(
            select(Customer).where(Customer.id == customer_id)
        )
        c = result.scalar_one_or_none()
        if c:
            c.summary_text = summary_text
            c.summary_status = "ready"
            c.updated_at = datetime.now()
            await session.commit()

    logger.info(f"[{name}] 摘要生成成功 ({len(summary_text)} 字符)")

    # --- 生成建议 ---
    recent_records = records[-5:]  # 最近5条
    recent_text = "\n\n".join([
        f"[{r.created_at.strftime('%Y-%m-%d')}] {r.content}"
        for r in reversed(recent_records)
    ])

    logger.info(f"[{name}] 正在生成下一步建议...")
    advice_prompt = advice(
        customer_summary_text=summary_text,
        recent_records_text=recent_text,
        industry_key=industry_key,
    )

    try:
        kimi = KimiClient()
        try:
            advice_text = await kimi.chat_simple(
                prompt=advice_prompt,
                system_prompt=advice_system(industry_key=industry_key),
            )
        finally:
            await kimi.close()

        if not advice_text or not advice_text.strip():
            logger.error(f"[{name}] LLM 返回空建议")
            return True  # 摘要已成功，只是建议失败

        advice_text = advice_text.strip()
    except Exception as e:
        logger.error(f"[{name}] 建议生成失败: {e}")
        return True  # 摘要已成功，只是建议失败

    # 保存建议到 JSON
    advices = load_json(ADVICES_FILE)
    advices.setdefault(user_id, {})[customer_id] = {
        "customer_id": customer_id,
        "advice_text": advice_text,
        "updated_at": datetime.utcnow().isoformat(),
    }
    save_json(ADVICES_FILE, advices)

    logger.info(f"[{name}] 建议生成成功 ({len(advice_text)} 字符)")
    return True


async def main():
    logger.info("=" * 60)
    logger.info("开始清理数据库并重新生成客户画像")
    logger.info("=" * 60)

    # Step 1: 删除带图片的沟通记录
    logger.info("\n>>> Step 1: 删除带图片的沟通记录")
    record_ids_with_images, _ = await step1_delete_image_records()

    # Step 2: 清理图片数据
    logger.info("\n>>> Step 2: 清理图片数据")
    await step2_cleanup_image_data(record_ids_with_images)

    # Step 3: 重置客户摘要和建议
    logger.info("\n>>> Step 3: 重置客户摘要和建议")
    customers = await step3_reset_customers()

    # Step 4: 重新生成
    logger.info(f"\n>>> Step 4: 为 {len(customers)} 位客户重新生成摘要和建议")
    success_count = 0
    for i, customer in enumerate(customers, 1):
        logger.info(f"\n--- [{i}/{len(customers)}] {customer['name']} ---")
        try:
            ok = await step4_regen_for_customer(customer)
            if ok:
                success_count += 1
        except Exception as e:
            logger.error(f"[{customer['name']}] 处理异常: {e}")

        # 短暂延迟避免 API 限流
        await asyncio.sleep(1)

    logger.info("\n" + "=" * 60)
    logger.info("清理和重新生成完成")
    logger.info(f"删除记录数: {len(record_ids_with_images)}")
    logger.info(f"客户总数: {len(customers)}")
    logger.info(f"成功重新生成: {success_count}")
    logger.info("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
