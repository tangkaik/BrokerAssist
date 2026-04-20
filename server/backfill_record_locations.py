#!/usr/bin/env python3
"""
历史记录地点线索回填脚本

用途：
1. 从历史沟通记录正文里提取地点线索
2. 用现有 LocationNormalizer 做归一化
3. 将结果写回 records.location_* 字段

默认是 dry-run；传 --commit 才会真正写库。
"""

from __future__ import annotations

import argparse
import asyncio
import json
from dataclasses import dataclass

from sqlalchemy import select

from app.db.session import async_session_factory
from app.models.customer import Customer
from app.models.record import Record
from app.services.location_normalizer import LocationNormalizer


KNOWN_CLUES = [
    "国贸三期",
    "望京SOHO",
    "海淀五路居",
    "西山一号院",
    "丰台科技园",
    "丽泽商务区",
    "石景山万达",
    "亦庄核心区",
    "亦庄金茂府",
    "通州北苑",
    "朝阳公园",
    "三元桥",
    "东直门",
    "三里屯",
    "亚运村",
    "后沙峪",
    "元通大厦",
    "万象城",
    "新荟城",
    "金融街",
    "复兴门",
    "广安门",
    "达官营",
    "中关村",
    "西二旗",
    "回龙观",
    "天通苑",
    "立水桥",
    "石景山",
    "门头沟",
    "西山墅",
    "国贸",
    "海淀",
    "朝阳",
    "望京",
    "万柳",
    "五路居",
    "上地",
    "梨园",
    "北苑",
    "长阳",
    "良乡",
    "黄村",
    "亦庄",
    "鸟巢",
    "枫丹壹号",
]

@dataclass
class BackfillHit:
    record_id: str
    customer_name: str
    clue: str
    city: str | None
    district: str | None
    subarea: str | None


def dedupe(items: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for item in items:
        if item in seen:
            continue
        seen.add(item)
        result.append(item)
    return result


def extract_candidates(text: str) -> list[str]:
    candidates: list[str] = []

    for clue in sorted(KNOWN_CLUES, key=len, reverse=True):
        if clue in text:
            candidates.append(clue)

    return dedupe(candidates)


async def main() -> None:
    parser = argparse.ArgumentParser(description="回填历史记录中的地点线索")
    parser.add_argument("--commit", action="store_true", help="真正写入数据库")
    parser.add_argument("--overwrite", action="store_true", help="覆盖已有地点字段")
    args = parser.parse_args()

    normalizer = LocationNormalizer()
    updated: list[BackfillHit] = []
    skipped = 0

    async with async_session_factory() as session:
        query = (
            select(Record, Customer.name)
            .join(Customer, Customer.id == Record.customer_id)
            .where(Customer.deleted_at.is_(None))
            .order_by(Record.created_at.desc())
        )
        result = await session.execute(query)
        rows = result.all()

        for record, customer_name in rows:
            has_existing = any(
                [
                    record.location_raw,
                    record.location_city,
                    record.location_district,
                    record.location_subarea,
                ]
            )
            if has_existing and not args.overwrite:
                skipped += 1
                continue

            candidates = extract_candidates(record.content or "")
            if not candidates:
                continue

            best = None
            for clue in candidates:
                normalized = await normalizer.normalize(clue)
                if normalized["location_city"] or normalized["location_district"] or normalized["location_subarea"]:
                    best = (clue, normalized)
                    break

            if not best:
                continue

            clue, normalized = best
            record.location_raw = clue
            record.location_city = normalized["location_city"]
            record.location_district = normalized["location_district"]
            record.location_subarea = normalized["location_subarea"]

            updated.append(
                BackfillHit(
                    record_id=record.id,
                    customer_name=customer_name,
                    clue=clue,
                    city=record.location_city,
                    district=record.location_district,
                    subarea=record.location_subarea,
                )
            )

        if args.commit:
            await session.commit()
        else:
            await session.rollback()

    payload = {
        "mode": "commit" if args.commit else "dry-run",
        "updated_count": len(updated),
        "skipped_existing_count": skipped,
        "items": [
            {
                "record_id": item.record_id,
                "customer_name": item.customer_name,
                "clue": item.clue,
                "city": item.city,
                "district": item.district,
                "subarea": item.subarea,
            }
            for item in updated
        ],
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
