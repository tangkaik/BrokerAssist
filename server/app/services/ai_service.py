"""
AI 服务

封装全局业务问答、地域问答、图片问答等逻辑，
让路由层只负责接参与返回响应。
"""
import calendar
import logging
import re
from datetime import date, datetime

from sqlalchemy import func, select

from app.ai.kimi_client import KimiClient
from app.core.prompts import (
    app_help_qa as _app_help_qa_prompt,
    app_help_qa_system as _app_help_qa_system,
    assistant_intent_plan as _assistant_intent_plan_prompt,
    assistant_intent_plan_system as _assistant_intent_plan_system,
    business_assist as _business_assist_prompt,
    business_assist_plan as _business_assist_plan_prompt,
    business_assist_plan_system as _business_assist_plan_system,
    business_assist_system as _business_assist_system,
    customer_query_plan as _customer_query_plan_prompt,
    customer_query_plan_system as _customer_query_plan_system,
)
from app.db.session import async_session_factory
from app.models.customer import Customer
from app.models.record import Record
from app.models.user import User
from app.services.vision_service import analyze_image_with_qwen

STALE_CONTACT_MONTHS = 2
CUSTOMER_QUERY_LIMIT = 50
GLOBAL_RECENT_MESSAGE_LIMIT = 16
BUSINESS_CONTEXT_CUSTOMER_LIMIT = 12
SUPPORTED_QUERY_ACTIONS = {"list", "count", "none"}
SUPPORTED_ASSISTANT_ACTIONS = {"customer_query", "app_help", "business_assist", "none"}
SUPPORTED_BUSINESS_TASK_TYPES = {
    "wechat_message",
    "visit_brief",
    "last_visit_summary",
    "next_step_advice",
    "question_checklist",
    "general",
}
SUPPORTED_SORTS = {"last_contact_desc", "last_contact_asc", None}
SUPPORTED_LOCATION_SCOPES = {"customer_address", "record_location", "any"}
logger = logging.getLogger(__name__)


def looks_like_customer_query(question: str) -> bool:
    normalized = question.strip()
    if not normalized:
        return False

    normalized_no_space = re.sub(r"\s+", "", normalized)
    casual_phrases = {
        "你好", "您好", "早上好", "下午好", "晚上好",
        "谢谢", "多谢", "辛苦了", "你是谁",
    }
    if normalized_no_space in casual_phrases:
        return False

    query_cues = [
        "客户", "名单", "列表", "列出", "哪些", "有哪些", "有多少", "多少",
        "几个", "几位", "住在", "居住", "地址", "附近", "女", "男", "岁",
        "未联系", "没联系", "跟进", "优先", "高净值", "预算", "保险", "医疗险",
        "重疾险", "年金险",
    ]
    if any(cue in normalized for cue in query_cues):
        return True

    return bool(re.search(r"[\u4e00-\u9fff].*(区|县|市|镇|街道|小区|大厦|园|路)", normalized))


def normalize_gender(value: object) -> str | None:
    text = str(value or "").strip().lower()
    if text in {"female", "女", "女性", "女士", "女客户"}:
        return "female"
    if text in {"male", "男", "男性", "男士", "男客户"}:
        return "male"
    return None


def gender_matches(customer_gender: object, planned_gender: str | None) -> bool:
    if not planned_gender:
        return True
    return normalize_gender(customer_gender) == planned_gender


def clean_string(value: object, max_len: int = 80) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    return text[:max_len]


def clean_string_list(value: object, max_items: int = 10, max_len: int = 40) -> list[str]:
    if not isinstance(value, list):
        return []
    cleaned = []
    for item in value[:max_items]:
        text = clean_string(item, max_len=max_len)
        if text:
            cleaned.append(text)
    return cleaned


def clean_int(value: object, minimum: int | None = None, maximum: int | None = None) -> int | None:
    if value in {None, ""}:
        return None
    try:
        number = int(value)
    except (TypeError, ValueError):
        return None
    if minimum is not None and number < minimum:
        return None
    if maximum is not None and number > maximum:
        return None
    return number


def normalize_location_scope(value: object) -> str:
    text = str(value or "").strip()
    if text in SUPPORTED_LOCATION_SCOPES:
        return text
    return "customer_address"


def validate_customer_query_plan(raw_plan: dict | None) -> dict | None:
    if not isinstance(raw_plan, dict):
        return None

    action = raw_plan.get("action")
    if action not in SUPPORTED_QUERY_ACTIONS:
        return None
    if action == "none":
        return {"action": "none"}
    if raw_plan.get("entity") not in {None, "customers"}:
        return None

    raw_filters = raw_plan.get("filters")
    filters = raw_filters if isinstance(raw_filters, dict) else {}

    raw_location = filters.get("location")
    location = raw_location if isinstance(raw_location, dict) else {}

    raw_age = filters.get("age")
    age = raw_age if isinstance(raw_age, dict) else {}
    age_min = clean_int(age.get("min"), minimum=0, maximum=120)
    age_max = clean_int(age.get("max"), minimum=0, maximum=120)
    if age_min is not None and age_max is not None and age_min > age_max:
        age_min, age_max = age_max, age_min

    sort = raw_plan.get("sort")
    if sort not in SUPPORTED_SORTS:
        sort = None

    return {
        "action": action,
        "entity": "customers",
        "filters": {
            "gender": normalize_gender(filters.get("gender")),
            "location": {
                "raw": clean_string(location.get("raw")),
                "city": clean_string(location.get("city"), max_len=40),
                "district": clean_string(location.get("district"), max_len=40),
                "subarea": clean_string(location.get("subarea"), max_len=60),
            },
            "location_scope": normalize_location_scope(filters.get("location_scope")),
            "age": {"min": age_min, "max": age_max},
            "tags": clean_string_list(filters.get("tags")),
            "keywords": clean_string_list(filters.get("keywords")),
            "stale_contact_months": clean_int(
                filters.get("stale_contact_months"),
                minimum=1,
                maximum=36,
            ),
        },
        "sort": sort,
        "limit": clean_int(raw_plan.get("limit"), minimum=1, maximum=100) or CUSTOMER_QUERY_LIMIT,
    }


def validate_assistant_intent_plan(raw_plan: dict | None) -> dict | None:
    if not isinstance(raw_plan, dict):
        return None

    action = raw_plan.get("action")
    if action not in SUPPORTED_ASSISTANT_ACTIONS:
        return None

    raw_needs_context = raw_plan.get("needs_customer_context")
    needs_context = raw_needs_context is True
    if isinstance(raw_needs_context, str):
        needs_context = raw_needs_context.strip().lower() == "true"

    return {
        "action": action,
        "task": clean_string(raw_plan.get("task"), max_len=160) or "",
        "needs_customer_context": needs_context,
    }


def validate_business_assist_plan(raw_plan: dict | None) -> dict | None:
    if not isinstance(raw_plan, dict):
        return None

    task_type = str(raw_plan.get("task_type") or "").strip()
    if task_type not in SUPPORTED_BUSINESS_TASK_TYPES:
        task_type = "general"

    return {
        "customer_name": clean_string(raw_plan.get("customer_name"), max_len=40) or "",
        "task_type": task_type,
        "task": clean_string(raw_plan.get("task"), max_len=160) or "",
    }


def extract_age_from_customer(customer: dict) -> int | None:
    formal_age = clean_int(customer.get("age"), minimum=0, maximum=120)
    if formal_age is not None:
        return formal_age

    text_parts = []
    text_parts.extend(customer.get("tags") or [])
    text_parts.append(customer.get("summary", ""))
    text_parts.append(customer.get("recent_records", ""))
    combined = " ".join(str(part) for part in text_parts if part)
    match = re.search(r"(?<!\d)(\d{1,3})\s*岁", combined)
    if not match:
        return None
    age = int(match.group(1))
    if age < 0 or age > 120:
        return None
    return age


def age_matches(customer: dict, age_filter: dict) -> bool:
    age_min = age_filter.get("min")
    age_max = age_filter.get("max")
    if age_min is None and age_max is None:
        return True
    age = extract_age_from_customer(customer)
    if age is None:
        return False
    if age_min is not None and age < age_min:
        return False
    if age_max is not None and age > age_max:
        return False
    return True


def text_matches(customer: dict, values: list[str]) -> bool:
    if not values:
        return True
    combined = " ".join(
        [
            customer.get("name", ""),
            customer.get("phone", ""),
            customer.get("location_raw") or "",
            customer.get("location_city") or "",
            customer.get("location_district") or "",
            customer.get("location_subarea") or "",
            " ".join(customer.get("tags") or []),
            customer.get("summary", ""),
            customer.get("recent_records", ""),
        ]
    )
    return all(value in combined for value in values)


def tags_match(customer: dict, tags: list[str]) -> bool:
    if not tags:
        return True
    customer_tags = customer.get("tags") or []
    combined = " ".join(customer_tags + [customer.get("summary", ""), customer.get("recent_records", "")])
    return all(any(tag == item or tag in item for item in customer_tags) or tag in combined for tag in tags)


def location_matches(customer: dict, location_filter: dict, location_scope: str = "customer_address") -> bool:
    raw_values = [
        location_filter.get("city"),
        location_filter.get("district"),
        location_filter.get("subarea"),
        location_filter.get("raw"),
    ]
    if not any(raw_values):
        return True

    target = {
        "city": location_filter.get("city") or "",
        "district": location_filter.get("district") or "",
        "subarea": location_filter.get("subarea") or "",
    }
    scope = normalize_location_scope(location_scope)

    if target["city"] or target["district"] or target["subarea"]:
        customer_location = {
            "city": customer.get("location_city") or "",
            "district": customer.get("location_district") or "",
            "subarea": customer.get("location_subarea") or "",
        }
        if scope in {"customer_address", "any"} and is_location_match(target, customer_location):
            return True
        if scope in {"record_location", "any"}:
            for location in customer.get("structured_locations", []):
                if is_location_match(target, location):
                    return True

    raw = normalize_place_name(location_filter.get("raw") or "")
    if not raw:
        return False

    searchable_values = []
    if scope in {"customer_address", "any"}:
        searchable_values.extend([
            customer.get("location_raw") or "",
            customer.get("location_city") or "",
            customer.get("location_district") or "",
            customer.get("location_subarea") or "",
        ])
    if scope in {"record_location", "any"}:
        for location in customer.get("structured_locations", []):
            searchable_values.extend([
                location.get("raw") or "",
                location.get("city") or "",
                location.get("district") or "",
                location.get("subarea") or "",
            ])
    return any(raw and raw in normalize_place_name(value) for value in searchable_values)


def stale_contact_matches(customer: dict, months: int | None) -> bool:
    if not months:
        return True
    last_contact = customer.get("last_contact")
    if not last_contact or last_contact == "从未联系":
        return True
    try:
        last_contact_date = datetime.strptime(last_contact, "%Y-%m-%d").date()
    except ValueError:
        return False
    return last_contact_date <= subtract_months(datetime.now().date(), months)


def describe_customer_query(filters: dict) -> str:
    parts = []
    location = filters.get("location") or {}
    location_text = location.get("raw") or location.get("subarea") or location.get("district") or location.get("city")
    location_scope = filters.get("location_scope")
    gender = filters.get("gender")
    if gender == "female":
        parts.append("女性")
    elif gender == "male":
        parts.append("男性")
    age_filter = filters.get("age") or {}
    age_min = age_filter.get("min")
    age_max = age_filter.get("max")
    if age_min is not None and age_max is not None:
        parts.append(f"{age_min}-{age_max}岁")
    elif age_min is not None:
        parts.append(f"{age_min}岁以上")
    elif age_max is not None:
        parts.append(f"{age_max}岁以下")
    parts.extend(filters.get("tags") or [])
    months = filters.get("stale_contact_months")
    if months:
        parts.append(f"{months}个月未联系")

    condition_text = "".join(parts)
    if location_text and location_scope == "record_location":
        prefix = f"曾在{location_text}拜访/记录过的"
    elif location_text and location_scope == "any":
        prefix = f"与{location_text}有关的"
    elif location_text:
        prefix = str(location_text)
    else:
        prefix = ""

    label = f"{prefix}{condition_text}客户"
    return label if label != "客户" else "符合条件的客户"


def normalize_customer_links_and_tail(answer: str) -> str:
    """清理 AI 输出里的客户链接和无效不足信息尾句。"""
    if not answer:
        return answer

    normalized = re.sub(
        r"(?<!\[)([\u4e00-\u9fffA-Za-z][\u4e00-\u9fffA-Za-z·]{1,20})\|([0-9a-fA-F-]{36})",
        r"[\1|\2]",
        answer.strip(),
    )

    has_customer_link = bool(re.search(r"\[[^\]\n|]{1,24}\|[0-9a-fA-F-]{36}\]", normalized))
    if not has_customer_link:
        return normalized

    lines = normalized.splitlines()
    while lines and not lines[-1].strip():
        lines.pop()
    if not lines:
        return normalized

    last_blank_index = -1
    for index in range(len(lines) - 1, -1, -1):
        if not lines[index].strip():
            last_blank_index = index
            break

    paragraph_start = last_blank_index + 1
    last_paragraph = "\n".join(lines[paragraph_start:]).strip()
    if last_paragraph.startswith("当前记录中") and ("没有" in last_paragraph or "不足" in last_paragraph):
        return "\n".join(lines[:paragraph_start]).rstrip()

    return normalized


def normalize_recent_messages(messages: list[dict] | None) -> list[dict]:
    if not messages:
        return []

    normalized = []
    for item in messages[-GLOBAL_RECENT_MESSAGE_LIMIT:]:
        if not isinstance(item, dict):
            continue
        role = str(item.get("role") or "").strip()
        content = str(item.get("content") or "").strip()
        if role not in {"user", "assistant"} or not content:
            continue
        normalized.append({"role": role, "content": content[:2000]})
    return normalized


def format_conversation_context(messages: list[dict]) -> str:
    if not messages:
        return "无"
    labels = {"user": "用户", "assistant": "AI"}
    return "\n".join(
        f"{labels.get(message['role'], message['role'])}: {message['content']}"
        for message in messages
    )


def subtract_months(value: date, months: int) -> date:
    """按自然月回退日期，避免把"两个月"近似成 60 天。"""
    year = value.year
    month = value.month - months
    while month <= 0:
        month += 12
        year -= 1

    last_day = calendar.monthrange(year, month)[1]
    day = min(value.day, last_day)
    return date(year, month, day)


def normalize_place_name(value: str) -> str:
    text = str(value or "").strip().lower()
    for suffix in ["特别行政区", "自治区", "省", "市", "区", "县", "街道", "地区"]:
        if text.endswith(suffix.lower()):
            text = text[: -len(suffix)]
    return text.strip()


def infer_target_level(target: dict) -> str:
    if target.get("subarea"):
        return "subarea"
    if target.get("district"):
        return "district"
    if target.get("city"):
        return "city"
    return "unknown"


def is_location_match(target: dict, classified: dict) -> bool:
    target_city = normalize_place_name(target.get("city", ""))
    target_district = normalize_place_name(target.get("district", ""))
    target_subarea = normalize_place_name(target.get("subarea", ""))

    city = normalize_place_name(classified.get("city", ""))
    district = normalize_place_name(classified.get("district", ""))
    subarea = normalize_place_name(classified.get("subarea", ""))

    target_level = infer_target_level(target)

    if target_level == "city":
        return bool(target_city and city == target_city)
    if target_level == "district":
        if target_city and city and city != target_city:
            return False
        return bool(target_district and district == target_district)
    if target_level == "subarea":
        if target_city and city and city != target_city:
            return False
        if target_district and district and district != target_district:
            return False
        return bool(target_subarea and subarea == target_subarea)
    return False


def parse_json_object(text: str) -> dict | None:
    if not text:
        return None
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return None
    try:
        import json as _json
        return _json.loads(text[start : end + 1])
    except Exception:
        return None


def chunk_items(items: list, size: int) -> list[list]:
    return [items[index : index + size] for index in range(0, len(items), size)]


class AIService:
    """AI 相关业务服务。"""

    async def _get_user_industry_key(self, user_id: str) -> str:
        async with async_session_factory() as session:
            user = await session.get(User, user_id)
            return getattr(user, "industry_key", None) or "generic"

    async def ask_image_question(
        self,
        question: str,
        image,
        validated_file: tuple[str, bytes, str | None] | None = None,
    ) -> dict:
        if validated_file is not None:
            _, raw_bytes, content_type = validated_file
        else:
            if image.content_type and not image.content_type.startswith("image/"):
                raise ValueError(f"{image.filename or '文件'} 不是支持的图片格式")

            raw_bytes = await image.read()
            if not raw_bytes:
                raise ValueError("图片内容为空")
            content_type = image.content_type or "image/jpeg"

        answer = await analyze_image_with_qwen(
            question=(
                f"用户问题：{question.strip()}\n\n"
                "请只基于这张图片和这次问题回答。"
                "优先帮助用户完成：识别材料类型、提取关键信息、总结重点、整理成可行动输出。"
            ),
            raw_bytes=raw_bytes,
            content_type=content_type,
        )
        if not answer.strip():
            answer = "我收到了这张图片，但这次没能稳定读出内容。可以换一张更清晰的图片，或者直接问我想提取什么信息。"

        return {
            "answer": answer.strip(),
            "image_name": image.filename or "图片",
        }

    async def _build_customer_contexts(self, user_id: str) -> list[dict]:
        async with async_session_factory() as session:
            query = select(Customer).where(
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None)
            )
            result = await session.execute(query)
            customers = result.scalars().all()

            customer_contexts = []
            for customer in customers:
                records_result = await session.execute(
                    select(Record).where(Record.customer_id == customer.id)
                    .order_by(Record.created_at.desc())
                    .limit(8)
                )
                recent_records = records_result.scalars().all()

                count_query = select(func.count()).where(Record.customer_id == customer.id)
                count_result = await session.execute(count_query)
                records_count = count_result.scalar() or 0

                records_summary = " | ".join([
                    r.content[:80] + "..." if len(r.content) > 80 else r.content
                    for r in recent_records
                ]) if recent_records else "无近期记录"
                customer_contexts.append({
                    "id": customer.id,
                    "name": customer.name,
                    "phone": customer.phone or "未设置",
                    "gender": customer.gender,
                    "age": customer.age,
                    "location_raw": customer.location_raw,
                    "location_city": customer.location_city,
                    "location_district": customer.location_district,
                    "location_subarea": customer.location_subarea,
                    "summary": customer.summary_text or "暂无摘要",
                    "summary_status": customer.summary_status,
                    "last_contact": recent_records[0].created_at.strftime("%Y-%m-%d") if recent_records else "从未联系",
                    "records_count": records_count,
                    "tags": customer.tags or [],
                    "recent_records": records_summary,
                    "recent_records_full": "\n".join([record.content for record in recent_records]) if recent_records else "",
                    "structured_locations": [
                        {
                            "raw": record.location_raw,
                            "city": record.location_city,
                            "district": record.location_district,
                            "subarea": record.location_subarea,
                        }
                        for record in recent_records
                        if record.location_raw or record.location_city or record.location_district or record.location_subarea
                    ],
                })

            return customer_contexts

    async def _build_single_customer_context(self, user_id: str, customer_id: str) -> dict | None:
        async with async_session_factory() as session:
            customer = await session.get(Customer, customer_id)
            if not customer or customer.user_id != user_id or customer.deleted_at is not None:
                return None

            records_result = await session.execute(
                select(Record).where(Record.customer_id == customer.id)
                .order_by(Record.created_at.desc())
                .limit(6)
            )
            recent_records = records_result.scalars().all()

            count_result = await session.execute(
                select(func.count()).where(Record.customer_id == customer.id)
            )
            records_count = count_result.scalar() or 0

            return {
                "id": customer.id,
                "name": customer.name,
                "phone": customer.phone or "未设置",
                "gender": customer.gender or "未知",
                "age": customer.age,
                "location_raw": customer.location_raw or "未知",
                "tags": customer.tags or [],
                "summary": customer.summary_text or "暂无客户画像",
                "summary_status": customer.summary_status,
                "advice": customer.advice_text or "暂无下一步建议",
                "advice_updated_at": customer.advice_updated_at.strftime("%Y-%m-%d %H:%M") if customer.advice_updated_at else "未知",
                "records_count": records_count,
                "recent_records": [
                    {
                        "created_at": record.created_at.strftime("%Y-%m-%d %H:%M"),
                        "content": record.content,
                        "location_raw": record.location_raw or "",
                    }
                    for record in recent_records
                ],
            }

    async def _find_business_customer_matches(self, user_id: str, customer_name: str) -> list[dict]:
        target = (customer_name or "").strip()
        if not target:
            return []

        async with async_session_factory() as session:
            result = await session.execute(
                select(Customer).where(
                    Customer.user_id == user_id,
                    Customer.deleted_at.is_(None),
                )
            )
            customers = result.scalars().all()

        exact_matches = [customer for customer in customers if customer.name == target]
        if exact_matches:
            matched = exact_matches
        else:
            matched = [
                customer
                for customer in customers
                if target in customer.name or customer.name in target
            ]

        return [
            {
                "id": customer.id,
                "name": customer.name,
                "phone": customer.phone or "未设置",
                "tags": customer.tags or [],
            }
            for customer in matched[:8]
        ]

    def _format_single_customer_context(self, customer: dict) -> str:
        tags = "、".join(customer.get("tags") or []) or "无"
        age = customer.get("age") if customer.get("age") is not None else "未知"
        lines = [
            f"客户链接: [{customer['name']}|{customer['id']}]",
            f"姓名: {customer['name']}",
            f"电话: {customer.get('phone') or '未设置'}",
            f"性别: {customer.get('gender') or '未知'}",
            f"年龄: {age}",
            f"地址: {customer.get('location_raw') or '未知'}",
            f"标签: {tags}",
            f"记录数量: {customer.get('records_count', 0)}",
            f"客户画像状态: {customer.get('summary_status') or '未知'}",
            "",
            "【客户画像】",
            customer.get("summary") or "暂无客户画像",
            "",
            "【下一步建议】",
            customer.get("advice") or "暂无下一步建议",
            "",
            "【最近沟通记录】",
        ]
        records = customer.get("recent_records") or []
        if not records:
            lines.append("暂无沟通记录")
        else:
            for index, record in enumerate(records, start=1):
                location = f"；地点：{record['location_raw']}" if record.get("location_raw") else ""
                lines.append(f"{index}. {record['created_at']}{location}\n{record['content'][:700]}")
        return "\n".join(lines)

    async def _plan_assistant_intent(
        self,
        question: str,
        industry_key: str,
        recent_messages: list[dict] | None = None,
    ) -> dict | None:
        conversation_context = format_conversation_context(
            normalize_recent_messages(recent_messages),
        )
        try:
            kimi = KimiClient()
            try:
                raw_answer = await kimi.chat_simple(
                    prompt=_assistant_intent_plan_prompt(
                        question=question,
                        conversation_context=conversation_context,
                        industry_key=industry_key,
                    ),
                    system_prompt=_assistant_intent_plan_system(industry_key=industry_key),
                )
            finally:
                await kimi.close()
        except Exception:
            logger.exception("[AI] Assistant intent planner failed")
            return None

        plan = validate_assistant_intent_plan(parse_json_object(raw_answer))
        if not plan or plan.get("action") == "none":
            return None
        return plan

    async def _plan_customer_query(
        self,
        question: str,
        industry_key: str,
        force: bool = False,
    ) -> dict | None:
        if not force and not looks_like_customer_query(question):
            return None

        try:
            kimi = KimiClient()
            try:
                raw_answer = await kimi.chat_simple(
                    prompt=_customer_query_plan_prompt(
                        question=question,
                        industry_key=industry_key,
                    ),
                    system_prompt=_customer_query_plan_system(industry_key=industry_key),
                )
            finally:
                await kimi.close()
        except Exception:
            logger.exception("[AI] Customer query planner failed")
            return None

        plan = validate_customer_query_plan(parse_json_object(raw_answer))
        if not plan or plan.get("action") == "none":
            return None

        location = plan["filters"]["location"]
        if location.get("raw") and not (
            location.get("city") or location.get("district") or location.get("subarea")
        ):
            try:
                from app.services.location_normalizer import LocationNormalizer

                normalized = await LocationNormalizer().normalize(location["raw"])
                location["city"] = location.get("city") or normalized.get("location_city")
                location["district"] = location.get("district") or normalized.get("location_district")
                location["subarea"] = location.get("subarea") or normalized.get("location_subarea")
            except Exception:
                logger.exception("[AI] Location normalization failed for query plan")

        return plan

    async def _answer_app_help(
        self,
        question: str,
        industry_key: str,
        recent_messages: list[dict] | None = None,
    ) -> str:
        conversation_context = format_conversation_context(
            normalize_recent_messages(recent_messages),
        )
        try:
            kimi = KimiClient()
            try:
                answer = await kimi.chat_simple(
                    prompt=_app_help_qa_prompt(
                        question=question,
                        conversation_context=conversation_context,
                        industry_key=industry_key,
                    ),
                    system_prompt=_app_help_qa_system(industry_key=industry_key),
                )
            finally:
                await kimi.close()
        except Exception:
            logger.exception("[AI] App help answer failed")
            return "服务暂时不可用，请稍后再试。"

        if not answer or not answer.strip():
            return "我暂时没有找到合适的产品用法说明。"
        return answer.strip()

    def _format_business_customer_contexts(self, customer_contexts: list[dict]) -> str:
        if not customer_contexts:
            return "无"

        lines = []
        for index, customer in enumerate(customer_contexts[:BUSINESS_CONTEXT_CUSTOMER_LIMIT], start=1):
            tags = "、".join(customer.get("tags") or []) or "无"
            summary = (customer.get("summary") or "暂无摘要").replace("\n", " ")[:160]
            recent_records = (customer.get("recent_records") or "暂无最近记录").replace("\n", " ")[:220]
            lines.append(
                f"{index}. [{customer['name']}|{customer['id']}]\n"
                f"- 标签: {tags}\n"
                f"- 年龄: {customer.get('age') if customer.get('age') is not None else '未知'}\n"
                f"- 地址: {customer.get('location_raw') or '未知'}\n"
                f"- 最后联系: {customer.get('last_contact')}\n"
                f"- 摘要: {summary}\n"
                f"- 最近记录: {recent_records}"
            )
        if len(customer_contexts) > BUSINESS_CONTEXT_CUSTOMER_LIMIT:
            lines.append(
                f"另有 {len(customer_contexts) - BUSINESS_CONTEXT_CUSTOMER_LIMIT} 位客户未放入本次写作上下文。"
            )
        return "\n\n".join(lines)

    async def _plan_business_assist_task(
        self,
        question: str,
        industry_key: str,
        recent_messages: list[dict] | None = None,
    ) -> dict | None:
        conversation_context = format_conversation_context(
            normalize_recent_messages(recent_messages),
        )
        try:
            kimi = KimiClient()
            try:
                raw_answer = await kimi.chat_simple(
                    prompt=_business_assist_plan_prompt(
                        question=question,
                        conversation_context=conversation_context,
                        industry_key=industry_key,
                    ),
                    system_prompt=_business_assist_plan_system(industry_key=industry_key),
                )
            finally:
                await kimi.close()
        except Exception:
            logger.exception("[AI] Business assist planner failed")
            return None

        return validate_business_assist_plan(parse_json_object(raw_answer))

    def _business_task_instructions(self, task_type: str) -> str:
        if task_type == "wechat_message":
            return (
                "输出一段可直接发送给客户的微信文本。微信内容必须优先基于【客户画像】和【下一步建议】。"
                "不要加入客户画像、下一步建议或用户本次问题中没有依据的具体事实。"
                "最近沟通记录只能用来理解上下文，不能据此发挥新的承诺、需求判断或产品建议。"
                "语气自然、克制、真诚，长度控制在 80-160 字。"
                "不要使用过度营销、夸张承诺或客户资料中没有的事实。"
            )
        if task_type == "visit_brief":
            return (
                "输出会谈前简报，包含：客户现状、最近沟通重点、本次建议目标、"
                "建议沟通顺序、需要确认的问题。控制在 5-8 个要点。"
            )
        if task_type == "last_visit_summary":
            return (
                "优先总结最近一次实质沟通或拜访，包含：沟通背景、客户表达、"
                "顾虑/机会、待跟进事项。不要把久远记录混成一次拜访。"
            )
        if task_type == "next_step_advice":
            return (
                "输出 2-3 条下一步动作，每条说明动作、目的和沟通切入点。"
                "如果信息不足，优先建议补充关键信息。"
            )
        if task_type == "question_checklist":
            return (
                "输出 3-5 个下次沟通应确认的问题。问题要具体、自然，"
                "并简短说明每个问题为什么要问。"
            )
        return (
            "围绕当前客户完成用户任务。输出结构清晰、简洁可用；"
            "如果用户同时要总结和建议，可以分成“已知情况”和“建议下一步”。"
        )

    def _format_business_match_options(self, matches: list[dict]) -> str:
        lines = ["我找到了多个可能的客户，请补充一下你指的是哪一位："]
        for index, customer in enumerate(matches, start=1):
            tags = "、".join(customer.get("tags") or []) or "无标签"
            lines.append(f"{index}. [{customer['name']}|{customer['id']}]，电话：{customer['phone']}，标签：{tags}")
        return "\n".join(lines)

    def _has_generated_summary_and_advice(self, customer: dict) -> bool:
        summary = str(customer.get("summary") or "").strip()
        advice = str(customer.get("advice") or "").strip()
        if not summary or summary == "暂无客户画像":
            return False
        if not advice or advice == "暂无下一步建议":
            return False
        return True

    async def _answer_business_assist(
        self,
        user_id: str,
        question: str,
        industry_key: str,
        recent_messages: list[dict] | None = None,
        needs_customer_context: bool = False,
    ) -> str:
        conversation_context = format_conversation_context(
            normalize_recent_messages(recent_messages),
        )
        _ = needs_customer_context
        business_plan = await self._plan_business_assist_task(
            question=question,
            industry_key=industry_key,
            recent_messages=recent_messages,
        )
        if not business_plan or not business_plan.get("customer_name"):
            return (
                "你想针对哪位客户处理这件事？可以这样问："
                "“给蔡凤霞写一段跟进微信”、"
                "“总结张建国上次拜访，并给出这次建议”、"
                "“明天见王女士，帮我准备会谈简报”。"
            )

        matches = await self._find_business_customer_matches(
            user_id=user_id,
            customer_name=business_plan["customer_name"],
        )
        if not matches:
            return (
                f"我没有找到“{business_plan['customer_name']}”这位客户。"
                "可以检查客户姓名，或先新建客户并保存一条沟通记录。"
            )
        if len(matches) > 1:
            return self._format_business_match_options(matches)

        customer_context = await self._build_single_customer_context(
            user_id=user_id,
            customer_id=matches[0]["id"],
        )
        if not customer_context:
            return "我没能读取到这位客户的资料，请稍后再试。"

        customer_context_text = self._format_single_customer_context(customer_context)
        task_type = business_plan.get("task_type") or "general"
        if task_type == "wechat_message" and not self._has_generated_summary_and_advice(customer_context):
            return (
                f"我还不能直接给 [{customer_context['name']}|{customer_context['id']}] 写微信，"
                "因为这位客户还没有完整的客户画像和下一步建议。"
                "请先在客户详情页生成或刷新画像和建议，或者先补充一条真实沟通记录。"
            )

        try:
            kimi = KimiClient()
            try:
                answer = await kimi.chat_simple(
                    prompt=_business_assist_prompt(
                        question=question,
                        customer_context_text=customer_context_text,
                        conversation_context=conversation_context,
                        task_type=task_type,
                        task_instructions=self._business_task_instructions(task_type),
                        industry_key=industry_key,
                    ),
                    system_prompt=_business_assist_system(industry_key=industry_key),
                )
            finally:
                await kimi.close()
        except Exception:
            logger.exception("[AI] Business assist answer failed")
            return "服务暂时不可用，请稍后再试。"

        if not answer or not answer.strip():
            return "我暂时没能生成合适的内容。"
        return normalize_customer_links_and_tail(answer.strip())

    async def _execute_customer_query_plan(self, user_id: str, plan: dict) -> str:
        customer_contexts = await self._build_customer_contexts(user_id)
        filters = plan.get("filters") or {}

        matches = []
        for customer in customer_contexts:
            if not gender_matches(customer.get("gender"), filters.get("gender")):
                continue
            if not age_matches(customer, filters.get("age") or {}):
                continue
            if not location_matches(
                customer,
                filters.get("location") or {},
                filters.get("location_scope") or "customer_address",
            ):
                continue
            if not tags_match(customer, filters.get("tags") or []):
                continue
            if not text_matches(customer, filters.get("keywords") or []):
                continue
            if not stale_contact_matches(customer, filters.get("stale_contact_months")):
                continue
            matches.append(customer)

        sort = plan.get("sort")
        if sort == "last_contact_asc":
            matches.sort(key=lambda item: item["last_contact"] if item["last_contact"] != "从未联系" else "0000-00-00")
        else:
            matches.sort(
                key=lambda item: item["last_contact"] if item["last_contact"] != "从未联系" else "0000-00-00",
                reverse=True,
            )

        label = describe_customer_query(filters)
        if plan.get("action") == "count":
            lines = [f"{label}共有 {len(matches)} 位。"]
            if matches:
                lines.append("")
                for index, customer in enumerate(matches[: plan.get("limit", CUSTOMER_QUERY_LIMIT)], start=1):
                    lines.append(self._format_customer_query_item(index, customer))
            return "\n".join(lines)

        if not matches:
            return f"当前没有找到{label}。"

        lines = [f"以下是{label}：", ""]
        for index, customer in enumerate(matches[: plan.get("limit", CUSTOMER_QUERY_LIMIT)], start=1):
            lines.append(self._format_customer_query_item(index, customer))
        if len(matches) > plan.get("limit", CUSTOMER_QUERY_LIMIT):
            lines.append(f"其余 {len(matches) - plan.get('limit', CUSTOMER_QUERY_LIMIT)} 位已省略。")
        return "\n".join(lines)

    def _format_customer_query_item(self, index: int, customer: dict) -> str:
        details = []
        age = extract_age_from_customer(customer)
        if age is not None:
            details.append(f"{age}岁")
        gender = normalize_gender(customer.get("gender"))
        if gender == "female":
            details.append("女")
        elif gender == "male":
            details.append("男")
        location = "/".join(
            value
            for value in [
                customer.get("location_city"),
                customer.get("location_district"),
                customer.get("location_subarea"),
            ]
            if value
        )
        if location:
            details.append(location)
        tags = [tag for tag in (customer.get("tags") or []) if not re.fullmatch(r"\d{1,3}岁", str(tag))]
        if tags:
            details.append("、".join(tags[:3]))

        detail_text = f"：{'，'.join(details)}" if details else ""
        return f"{index}. [{customer['name']}|{customer['id']}]{detail_text}"

    async def ask_global_question(
        self,
        user_id: str,
        question: str,
        recent_messages: list[dict] | None = None,
    ) -> str:
        industry_key = await self._get_user_industry_key(user_id)
        intent_plan = await self._plan_assistant_intent(
            question=question,
            industry_key=industry_key,
            recent_messages=recent_messages,
        )
        if not intent_plan:
            return (
                "我可以帮你做三类事：查客户数据、回答产品用法、处理业务写作/总结。"
                "你可以直接说“列出两个月没联系的客户”“客户画像怎么生成”"
                "或“帮我写一段约客户沟通的微信”。"
            )

        action = intent_plan.get("action")
        if action == "customer_query":
            planned_query = await self._plan_customer_query(question, industry_key, force=True)
            if planned_query:
                return await self._execute_customer_query_plan(user_id, planned_query)
            return "我理解你想查客户数据，但这次没有形成可执行的查询条件。可以换成更明确的条件再问一次。"

        if action == "app_help":
            return await self._answer_app_help(
                question=question,
                industry_key=industry_key,
                recent_messages=recent_messages,
            )

        if action == "business_assist":
            return await self._answer_business_assist(
                user_id=user_id,
                question=question,
                industry_key=industry_key,
                recent_messages=recent_messages,
                needs_customer_context=bool(intent_plan.get("needs_customer_context")),
            )

        return "我还不太确定你想做什么。你可以让我查客户、问产品用法，或帮你写微信/简报/总结。"
