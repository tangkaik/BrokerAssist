#!/usr/bin/env python3.11
"""
地域问答回归测试

目的：
1. 固定一组“该命中谁 / 不该命中谁”的地域问题
2. 在每次调整 AI 地域判断逻辑后快速回归
3. 先关注高价值问题：城区、片区、街道
"""

from __future__ import annotations

import os
import sys
import json
from dataclasses import dataclass
from urllib import request, error


import os
BASE_URL = os.environ.get("BROKERASSIST_API_BASE", "http://127.0.0.1:8001/api/v1")
TOKEN = os.environ.get("BROKERASSIST_TOKEN", "")

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
}


@dataclass
class GeoCase:
    question: str
    must_include: list[str]
    must_exclude: list[str]
    note: str


CASES = [
    GeoCase(
        question="海淀附近有哪些客户？",
        must_include=["张建国", "李晓雯", "王志远"],
        must_exclude=["赵明轩", "何美玲", "郭文博", "孙海涛", "周天明"],
        note="理解成海淀区内客户，不应把西城/通州/昌平混进来。",
    ),
    GeoCase(
        question="西城区有哪些客户？",
        must_include=["赵明轩", "何美玲"],
        must_exclude=["张建国", "王志远", "邓宇航"],
        note="西城应主要命中达官营/广安门/金融街/复兴门。",
    ),
    GeoCase(
        question="金融街有哪些客户？",
        must_include=["何美玲"],
        must_exclude=["赵明轩", "张建国", "王志远"],
        note="片区级问题应比城区更窄。",
    ),
    GeoCase(
        question="亦庄附近有哪些客户？",
        must_include=["马德胜", "黄磊"],
        must_exclude=["邓宇航", "张建国", "赵明轩"],
        note="理解成亦庄片区客户，不应放大到任意北京客户。",
    ),
    GeoCase(
        question="西二旗有哪些客户？",
        must_include=["王志远"],
        must_exclude=["张建国", "李晓雯", "何美玲"],
        note="片区级问题应能命中明确提到西二旗的客户。",
    ),
]


def run_case(case: GeoCase) -> tuple[bool, list[str], str]:
    payload = json.dumps({"question": case.question}).encode("utf-8")
    req = request.Request(
        f"{BASE_URL}/ai/chat",
        data=payload,
        headers=HEADERS,
        method="POST",
    )
    try:
        with request.urlopen(req, timeout=120) as response:
            body = response.read().decode("utf-8")
    except error.HTTPError as exc:
        raise RuntimeError(f"HTTP {exc.code}: {exc.read().decode('utf-8', errors='ignore')}") from exc

    payload_json = json.loads(body)
    answer = payload_json.get("data", {}).get("answer", "")

    failures: list[str] = []
    for expected in case.must_include:
        if expected not in answer:
            failures.append(f"缺少应命中客户：{expected}")

    for unexpected in case.must_exclude:
        if unexpected in answer:
            failures.append(f"误命中客户：{unexpected}")

    return (not failures, failures, answer)


def main() -> int:
    print("═══════════════════════════════")
    print("  地域问答回归测试")
    print("═══════════════════════════════")
    print(f"API: {BASE_URL}\n")

    passed = 0
    failed = 0

    for index, case in enumerate(CASES, start=1):
        print(f"[{index}] {case.question}")
        print(f"    说明: {case.note}")

        try:
            ok, failures, answer = run_case(case)
        except Exception as error:
            failed += 1
            print(f"    ❌ 请求失败: {error}\n")
            continue

        if ok:
            passed += 1
            print("    ✅ 通过")
        else:
            failed += 1
            print("    ❌ 失败")
            for item in failures:
                print(f"      - {item}")

        print("    回答摘要:")
        preview = answer.replace("\n", " ")
        if len(preview) > 180:
            preview = f"{preview[:180]}..."
        print(f"      {preview}\n")

    print("═══════════════════════════════")
    print(f"通过: {passed}")
    print(f"失败: {failed}")
    print("═══════════════════════════════")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
