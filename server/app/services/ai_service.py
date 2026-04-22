"""
AI 服务

封装全局业务问答、地域问答、图片问答等逻辑，
让路由层只负责接参与返回响应。
"""
import calendar
from datetime import date, datetime

from sqlalchemy import and_, func, or_, select

from app.ai.kimi_client import KimiClient
from app.core.prompts import (
    global_qa as _global_qa_prompt,
    global_qa_system as _global_qa_system,
)
from app.db.session import async_session_factory
from app.models.customer import Customer
from app.models.record import Record
from app.services.vision_service import analyze_image_with_qwen

STALE_CONTACT_MONTHS = 2
FOLLOW_UP_LOOKBACK_MONTHS = 1
PRIORITY_CUSTOMER_LIMIT = 3


def is_list_all_customers_question(question: str) -> bool:
    normalized = question.strip()
    keywords = [
        "列出当前所有客户",
        "列出所有客户",
        "所有客户",
        "全部客户",
        "客户清单",
        "客户列表",
    ]
    return any(keyword in normalized for keyword in keywords)


def is_stale_contact_question(question: str) -> bool:
    normalized = question.strip()
    return (
        "客户" in normalized and
        ("未联系" in normalized or "没联系" in normalized) and
        ("两个月" in normalized or "2个月" in normalized or "最近两个月" in normalized)
    )


def is_priority_customer_question(question: str) -> bool:
    normalized = question.strip()
    keywords = [
        "优先级最高",
        "最该跟进",
        "优先跟进",
        "重点跟进",
        "最值得跟进",
    ]
    return any(keyword in normalized for keyword in keywords)


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


def build_stale_contact_answer(customer_contexts: list[dict]) -> str:
    """对"两个月未联系"类问题走确定性回答，避免模型误判日期。"""
    today = datetime.now().date()
    threshold = subtract_months(today, STALE_CONTACT_MONTHS)
    stale_customers = []

    for customer in customer_contexts:
        last_contact = customer.get("last_contact")
        if not last_contact or last_contact == "从未联系":
            stale_customers.append(
                {
                    "name": customer["name"],
                    "id": customer["id"],
                    "last_contact": "从未联系",
                }
            )
            continue

        try:
            last_contact_date = datetime.strptime(last_contact, "%Y-%m-%d").date()
        except ValueError:
            continue

        if last_contact_date <= threshold:
            stale_customers.append(
                {
                    "name": customer["name"],
                    "id": customer["id"],
                    "last_contact": last_contact_date.isoformat(),
                }
            )

    if not stale_customers:
        return (
            f"截至 {today.isoformat()}，按\"最近两个月未联系\"的口径"
            f"（最后联系时间早于或等于 {threshold.isoformat()}），当前没有符合条件的客户。"
        )

    lines = [
        f"截至 {today.isoformat()}，按\"最近两个月未联系\"的口径"
        f"（最后联系时间早于或等于 {threshold.isoformat()}），以下客户需要优先关注：",
        "",
    ]
    for index, customer in enumerate(stale_customers, start=1):
        lines.append(
            f"{index}. [{customer['name']}|{customer['id']}]：最后联系时间 {customer['last_contact']}。"
        )
    return "\n".join(lines)


def build_list_all_customers_answer(customer_contexts: list[dict]) -> str:
    """列出全部客户，输出格式稳定可点击。"""
    if not customer_contexts:
        return "当前还没有客户。"

    lines = [f"当前共有 {len(customer_contexts)} 位客户：", ""]
    for index, customer in enumerate(customer_contexts, start=1):
        tags = "、".join(customer.get("tags") or [])
        tag_text = f"；标签：{tags}" if tags else ""
        lines.append(
            f"{index}. [{customer['name']}|{customer['id']}]：最后联系时间 {customer['last_contact']}；记录数 {customer['records_count']}{tag_text}。"
        )
    return "\n".join(lines)


BUSINESS_VALUE_TAGS = {
    "高净值": ("高净值经营潜力较高", 3),
    "预算充足": ("预算相对充足，更适合推进方案", 2),
    "企业主": ("企业主客群通常有较高综合保障需求", 2),
    "养老规划": ("养老规划需求较明确", 2),
    "医疗险": ("医疗保障需求明确", 1),
    "重疾险": ("重疾保障需求明确", 1),
    "寿险优先": ("寿险配置意向明确", 2),
    "资产传承": ("已进入资产传承类话题", 3),
    "家族信托兴趣": ("对高阶传承工具有兴趣", 3),
    "二胎家庭": ("家庭责任较重，保障议题更明确", 1),
    "新生儿": ("家庭保障窗口期明显", 1),
}

FOLLOW_UP_KEYWORDS = {
    "考虑": ("客户仍在考虑阶段，值得继续推进", 2),
    "方案": ("已经进入方案沟通阶段", 2),
    "预算": ("预算已被明确讨论", 1),
    "保费": ("保费接受度已进入讨论", 1),
    "加保": ("有继续加保空间", 2),
    "养老": ("养老相关需求已被明确提及", 1),
    "医疗": ("医疗相关保障需求已被明确提及", 1),
    "重疾": ("重疾相关保障需求已被明确提及", 1),
    "传承": ("传承需求已被明确提及", 2),
    "理赔": ("有理赔经历或关注，转化动机可能更强", 1),
}


def priority_score(customer: dict) -> tuple[int, list[str]]:
    """为"优先级最高客户"提供确定性排序。"""
    score = 0
    reasons = []
    last_contact = customer.get("last_contact")
    today = datetime.now().date()
    follow_up_threshold = subtract_months(today, FOLLOW_UP_LOOKBACK_MONTHS)
    cooling_threshold = subtract_months(today, STALE_CONTACT_MONTHS)

    if last_contact == "从未联系":
        score += 4
        reasons.append("尚未建立首轮跟进")
    else:
        try:
            last_contact_date = datetime.strptime(last_contact, "%Y-%m-%d").date()
            if last_contact_date <= cooling_threshold:
                score += 4
                reasons.append(f"距离上次联系已超过两个月（{last_contact_date.isoformat()}）")
            elif last_contact_date <= follow_up_threshold:
                score += 2
                reasons.append(f"最近联系时间为 {last_contact_date.isoformat()}")
            else:
                score += 1
                reasons.append("近期有互动，可趁热继续推进")
        except ValueError:
            pass

    summary_status = customer.get("summary_status")
    if summary_status in {"stale", "failed"}:
        score += 1
        reasons.append("客户画像待更新")

    tags = customer.get("tags") or []
    for tag in tags:
        tag_rule = BUSINESS_VALUE_TAGS.get(tag)
        if not tag_rule:
            continue
        reason, bonus = tag_rule
        score += bonus
        reasons.append(reason)

    records_count = customer.get("records_count", 0)
    if records_count >= 8:
        score += 2
        reasons.append("历史互动较深，已具备持续推进基础")
    elif records_count >= 4:
        score += 1
        reasons.append("已有多次互动基础")

    combined_text = " ".join(
        [
            customer.get("summary", ""),
            customer.get("recent_records", ""),
            " ".join(tags),
        ]
    )
    for keyword, (reason, bonus) in FOLLOW_UP_KEYWORDS.items():
        if keyword in combined_text:
            score += bonus
            reasons.append(reason)

    deduped_reasons = []
    seen = set()
    for reason in reasons:
        if reason in seen:
            continue
        seen.add(reason)
        deduped_reasons.append(reason)

    if summary_status == "ready" and any(keyword in combined_text for keyword in ["方案", "预算", "保费"]):
        score += 1
        deduped_reasons.append("已有摘要且进入具体决策话题")

    return score, deduped_reasons


def build_priority_customers_answer(customer_contexts: list[dict]) -> str:
    """输出优先跟进客户，使用简单稳定的启发式评分。"""
    if not customer_contexts:
        return "当前还没有客户，暂时无法推荐优先级。"

    ranked = []
    for customer in customer_contexts:
        score, reasons = priority_score(customer)
        ranked.append((score, customer, reasons))

    ranked.sort(
        key=lambda item: (
            -item[0],
            item[1]["last_contact"] if item[1]["last_contact"] != "从未联系" else "0000-00-00",
            -item[1]["records_count"],
        )
    )

    top_items = ranked[:PRIORITY_CUSTOMER_LIMIT]
    lines = [f"当前建议优先跟进的 {PRIORITY_CUSTOMER_LIMIT} 位客户：", ""]
    for index, (score, customer, reasons) in enumerate(top_items, start=1):
        reason_text = "；".join(reasons[:3]) if reasons else "近期值得继续观察"
        lines.append(
            f"{index}. [{customer['name']}|{customer['id']}]：优先级分数 {score}；最后联系时间 {customer['last_contact']}；建议原因：{reason_text}。"
        )
    lines.append("")
    lines.append("这是一套用于桌面版快速验证的启发式排序，后续可以再按你的业务口径继续细化。")
    return "\n".join(lines)


def looks_like_area_question(question: str) -> bool:
    """判断是否为地区相关问题（客户+地理关键词）。"""
    normalized = question.strip()
    if "客户" not in normalized:
        return False
    geo_keywords = [
        "区", "附近", "街道", "路", "园", "城", "大厦",
        "附近", "城区", "商圈", "片区", "地址",
        "海淀", "西城", "朝阳", "东城", "丰台", "石景山",
        "顺义", "大兴", "通州", "昌平", "房山", "门头沟",
    ]
    return any(kw in normalized for kw in geo_keywords)


def extract_target_area(question: str) -> str:
    """从问句中提取地名（去掉问句后缀）。"""
    normalized = question.strip()
    suffixes = [
        "附近有哪些客户", "有哪些客户", "有什么客户", "哪些客户",
        "附近的客户", "附近", "的客户",
        "有多少客户", "有多少个客户", "有几个客户", "有几位客户",
        "有多少位客户", "有几个", "有几位",
    ]
    for suffix in suffixes:
        if suffix in normalized:
            candidate = normalized.split(suffix, 1)[0].strip("：:，,。?？ ")
            if candidate:
                return candidate
    return normalized


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


def collect_structured_location_matches(target: dict, customer_contexts: list[dict]) -> list[dict]:
    """用结构化地址字段做精准匹配。"""
    matches = []
    for customer in customer_contexts:
        for location in customer.get("structured_locations", []):
            if not is_location_match(target, location):
                continue
            matches.append({
                "customer_id": customer["id"],
                "customer_name": customer["name"],
                "city": location.get("city"),
                "district": location.get("district"),
                "subarea": location.get("subarea"),
                "evidence": location.get("raw") or location.get("subarea") or location.get("district"),
                "last_contact": customer["last_contact"],
                "confidence": "structured",
            })
            break
    return matches


def build_area_customer_answer_from_matches(target_area: str, target_classification: dict, matches: list[dict]) -> str:
    """基于匹配结果生成回答。"""
    target_city = target_classification.get("city") or "未知城市"
    target_district = target_classification.get("district") or "未确定城区"
    target_subarea = target_classification.get("subarea") or "未限定片区"

    if not matches:
        return f"根据当前记录，没有找到与 {target_area} 相关的客户。"

    lines = [
        f"根据当前记录，以下客户与 {target_area} 有关：",
        f"（目标归属：{target_city} / {target_district} / {target_subarea}）",
    ]
    for index, item in enumerate(matches, start=1):
        city = item.get("city") or "未知城市"
        district = item.get("district") or "未确定区"
        subarea = item.get("subarea") or "未确定片区"
        evidence = item.get("evidence") or "未提供明确地点线索"
        lines.append(
            f"{index}. [{item['customer_name']}|{item['customer_id']}]："
            f"{city} / {district} / {subarea}；证据：{evidence}。"
        )
    return "\n".join(lines)


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


async def classify_target_area(target_area: str) -> dict:
    """将地名归一化为城市/区/片区，用本地规则库优先。"""
    from app.services.location_normalizer import LocationNormalizer
    local_normalizer = LocationNormalizer()
    local_hit = await local_normalizer.normalize(target_area)
    if local_hit.get("location_city") or local_hit.get("location_district") or local_hit.get("location_subarea"):
        return {
            "city": local_hit.get("location_city") or "",
            "district": local_hit.get("location_district") or "",
            "subarea": local_hit.get("location_subarea") or "",
            "confidence": "high",
        }
    return {"city": "", "district": "", "subarea": "", "confidence": "low"}


async def build_area_customer_answer_with_llm(question: str, customer_contexts: list[dict]) -> str:
    """地区客户查询：先用结构化字段精准匹配，匹配不到再用 LLM 提取。"""
    target_area = extract_target_area(question)
    target_classification = await classify_target_area(target_area)

    usable_matches = collect_structured_location_matches(target_classification, customer_contexts)
    if usable_matches:
        usable_matches.sort(
            key=lambda item: item["last_contact"] if item["last_contact"] != "从未联系" else "0000-00-00",
            reverse=True,
        )
        return build_area_customer_answer_from_matches(target_area, target_classification, usable_matches)

    return f"根据当前记录，没有找到与 {target_area} 相关的客户。"


class AIService:
    """AI 相关业务服务。"""

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

    async def ask_global_question(self, user_id: str, question: str) -> str:
        customer_contexts = await self._build_customer_contexts(user_id)

        if is_list_all_customers_question(question):
            return build_list_all_customers_answer(customer_contexts)

        if is_stale_contact_question(question):
            return build_stale_contact_answer(customer_contexts)

        if is_priority_customer_question(question):
            return build_priority_customers_answer(customer_contexts)

        # 地区查询：直接 SQL 精准匹配，不过 LLM 猜
        if looks_like_area_question(question):
            try:
                return await self._answer_area_question(question, user_id)
            except Exception as e:
                logger.exception(f"[AI] 地区查询异常: {e}")
                return "服务暂时不可用，请稍后再试。"

        context_text = "\n\n".join([
            f"客户{i+1}: {c['name']} [ID:{c['id']}] (电话: {c['phone']})\n"
            f"- 标签: {', '.join(c['tags']) if c['tags'] else '无'}\n"
            f"- 摘要: {c['summary'][:100]}...\n"
            f"- 最近记录: {c['recent_records'][:150]}...\n"
            f"- 最后联系: {c['last_contact']}\n"
            f"- 记录数: {c['records_count']}\n"
            f"- 地址信息: {self._format_locations(c['structured_locations'])}"
            for i, c in enumerate(customer_contexts)
        ])

        today = datetime.now().date()
        stale_date = subtract_months(today, STALE_CONTACT_MONTHS)
        prompt = _global_qa_prompt(
            customer_context_text=context_text,
            question=question,
            today_date=today.isoformat(),
            stale_date=stale_date.isoformat(),
            customer_count=len(customer_contexts),
        )

        try:
            kimi = KimiClient()
            try:
                answer = await kimi.chat_simple(
                    prompt=prompt,
                    system_prompt=_global_qa_system(),
                )
            finally:
                await kimi.close()

            if not answer or not answer.strip():
                answer = "抱歉，暂时无法回答这个问题。"

        except Exception:
            answer = "服务暂时不可用，请稍后再试。"

        return answer.strip()

    async def _answer_area_question(self, question: str, user_id: str) -> str:
        """根据客户地址字段做地区精准查询。"""
        from app.services.location_normalizer import LocationNormalizer

        # 1. 从问句提取地名并归一化
        target_area = extract_target_area(question)
        normalized = await LocationNormalizer().normalize(target_area)
        target_district = normalized.get("location_district") or ""
        target_subarea = normalized.get("location_subarea") or ""

        if not (target_district or target_subarea):
            return f"无法识别「{target_area}」所属区域，请提供更明确的地址。"

        # 2. SQL 查询匹配的客户
        from sqlalchemy import or_
        query = select(Customer).where(
            and_(
                Customer.user_id == user_id,
                Customer.deleted_at.is_(None),
            )
        )

        if target_subarea:
            query = query.where(
                or_(
                    Customer.location_subarea == target_subarea,
                    Customer.location_district == target_subarea,
                    Customer.location_raw.like(f"%{target_subarea}%"),
                )
            )
        elif target_district:
            query = query.where(
                or_(
                    Customer.location_district == target_district,
                    Customer.location_raw.like(f"%{target_district}%"),
                )
            )

        async with async_session_factory() as session:
            result = await session.execute(query)
            customers = result.scalars().all()

        if not customers:
            return f"当前没有找到与「{target_area}」相关的客户。"

        lines = [f"根据客户地址信息，以下客户与「{target_area}」有关："]
        for i, c in enumerate(customers, 1):
            location = "/".join(filter(None, [c.location_city, c.location_district, c.location_subarea]))
            evidence = f"（地址：{c.location_raw}）" if c.location_raw else ""
            lines.append(f"{i}. [{c.name}|{c.id}]{evidence} — {location}")

        return "\n".join(lines)

    def _format_locations(self, structured_locations: list[dict]) -> str:
        if not structured_locations:
            return "无"
        return " | ".join([
            f"{loc['city'] or ''}{loc['district'] or ''}{loc['subarea'] or ''}({loc['raw'] or ''})"
            for loc in structured_locations
        ])
