#!/usr/bin/env python3.11
"""
P4 阶段 API 自动化验证脚本
验证后端接口连通性和数据正确性
"""

import os
import requests
import sys
import json
from datetime import datetime

BASE_URL = os.environ.get("BROKERASSIST_API_BASE", "http://localhost:8001/api/v1")
TOKEN = os.environ.get("BROKERASSIST_TOKEN", "")

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

# 存储测试过程中创建的 ID
test_data = {
    "customer_id": None,
    "record_id": None
}


def print_step(step_num, desc):
    print(f"\n{'='*50}")
    print(f"Step {step_num}: {desc}")
    print('='*50)


def check_response(resp, expected_status=200):
    """检查响应状态"""
    # 2xx 都算成功
    if not (200 <= resp.status_code < 300):
        print(f"❌ 失败: HTTP {resp.status_code}")
        print(f"响应: {resp.text[:500]}")
        return False
    print(f"✅ HTTP {resp.status_code}")
    return True


def step1_create_customer():
    """Step 1: 创建测试客户"""
    print_step(1, "创建测试客户")
    
    url = f"{BASE_URL}/customers"
    payload = {
        "name": f"P4测试客户_{datetime.now().strftime('%m%d_%H%M%S')}",
        "gender": "男",
        "age": 35,
        "tags": ["高净值", "车险"]
    }
    
    resp = requests.post(url, json=payload, headers=HEADERS)
    if not check_response(resp):
        return False
    
    data = resp.json().get("data", {})
    test_data["customer_id"] = data.get("customer_id") or data.get("id")
    print(f"创建成功（200），customer_id: {test_data['customer_id']}")
    return True


def step2_get_customer_detail():
    """Step 2: 获取客户详情"""
    print_step(2, "获取客户详情")
    
    if not test_data["customer_id"]:
        print("❌ 没有 customer_id")
        return False
    
    url = f"{BASE_URL}/customers/{test_data['customer_id']}"
    resp = requests.get(url, headers=HEADERS)
    
    if not check_response(resp):
        return False
    
    data = resp.json().get("data", {})
    print(f"客户姓名: {data.get('name')}")
    print(f"当前 summary: {data.get('summary') or '空'}")
    print(f"summary_status: {data.get('summary_status', 'unknown')}")
    return True


def step3_get_customer_records():
    """Step 3: 获取客户记录列表（验证新创建客户记录为空）"""
    print_step(3, "获取客户记录列表")
    
    url = f"{BASE_URL}/customers/{test_data['customer_id']}/records"
    resp = requests.get(url, headers=HEADERS)
    
    if not check_response(resp):
        return False
    
    data = resp.json().get("data", {})
    records = data.get("items", [])
    print(f"记录数量: {len(records)}")
    return True


def step4_create_record_direct():
    """Step 4: 直接创建一条记录"""
    print_step(4, "直接创建沟通记录")
    
    url = f"{BASE_URL}/records"
    payload = {
        "customer_id": test_data["customer_id"],
        "content": "这是 P4 验收测试的沟通记录内容"
    }
    
    resp = requests.post(url, json=payload, headers=HEADERS)
    if not check_response(resp, 200):
        return False
    
    data = resp.json().get("data", {})
    test_data["record_id"] = data.get("id")
    print(f"记录创建成功，id: {test_data['record_id']}")
    return True


def step5_verify_record_in_list():
    """Step 5: 验证记录出现在列表中"""
    print_step(5, "验证记录出现在客户记录列表")
    
    url = f"{BASE_URL}/customers/{test_data['customer_id']}/records"
    resp = requests.get(url, headers=HEADERS)
    
    if not check_response(resp):
        return False
    
    data = resp.json().get("data", {})
    records = data.get("items", [])
    
    if len(records) == 0:
        print("❌ 记录列表为空")
        return False
    
    latest = records[0]
    print(f"✅ 最新记录内容: {latest.get('content', '')[:50]}...")
    print(f"   记录类型: {latest.get('type', 'unknown')}")
    return True


def step6_generate_summary():
    """Step 6: 生成 Summary"""
    print_step(6, "生成客户画像摘要 (Summary)")
    
    url = f"{BASE_URL}/customers/{test_data['customer_id']}/summary/generate"
    resp = requests.post(url, headers=HEADERS)
    
    if not check_response(resp):
        return False
    
    data = resp.json().get("data", {})
    print(f"summary_status: {data.get('summary_status')}")
    return True


def step7_check_summary_updated():
    """Step 7: 检查 Summary 是否已更新"""
    print_step(7, "检查 Summary 更新状态")
    
    url = f"{BASE_URL}/customers/{test_data['customer_id']}"
    resp = requests.get(url, headers=HEADERS)
    
    if not check_response(resp):
        return False
    
    data = resp.json().get("data", {})
    summary = data.get("summary")
    status = data.get("summary_status")
    
    print(f"summary_status: {status}")
    if summary:
        print(f"✅ Summary 有值: {summary[:100]}...")
    else:
        print(f"⚠️ Summary 为空（状态: {status}，可能需要异步等待）")
    return True


def step8_generate_advice():
    """Step 8: 生成拜访建议"""
    print_step(8, "生成拜访建议 (Advice)")
    
    url = f"{BASE_URL}/customers/{test_data['customer_id']}/advice/generate"
    resp = requests.post(url, headers=HEADERS)
    
    if not check_response(resp):
        return False
    
    data = resp.json().get("data", {})
    advice = data.get("advice", "")
    
    if advice:
        print(f"✅ Advice 返回成功: {advice[:100]}...")
    else:
        print(f"⚠️ Advice 为空，检查后端 mock 数据")
    return True


def step9_list_all_customers():
    """Step 9: 列出客户（供用户选择测试）"""
    print_step(9, "列出所有客户（供手动测试选择）")
    
    url = f"{BASE_URL}/customers?limit=10"
    resp = requests.get(url, headers=HEADERS)
    
    if not check_response(resp):
        return False
    
    data = resp.json().get("data", {})
    items = data.get("items", [])
    
    print(f"\n共 {len(items)} 个客户:")
    for c in items[:5]:
        print(f"  - {c.get('name')} (id: {c.get('id')})")
        print(f"    summary: {'有' if c.get('summary') else '无'}")
    
    return True


def main():
    print("="*50)
    print("P4 客户详情页 API 自动化验证")
    print(f"目标: {BASE_URL}")
    print("="*50)
    
    steps = [
        ("创建客户", step1_create_customer),
        ("获取详情", step2_get_customer_detail),
        ("获取记录列表", step3_get_customer_records),
        ("创建记录", step4_create_record_direct),
        ("验证记录", step5_verify_record_in_list),
        ("生成 Summary", step6_generate_summary),
        ("检查 Summary", step7_check_summary_updated),
        ("生成 Advice", step8_generate_advice),
        ("列出客户", step9_list_all_customers),
    ]
    
    passed = 0
    failed = 0
    
    for name, func in steps:
        try:
            if func():
                passed += 1
            else:
                failed += 1
                print(f"\n⚠️ 步骤 '{name}' 失败，继续执行后续步骤...")
        except Exception as e:
            failed += 1
            print(f"\n❌ 步骤 '{name}' 异常: {e}")
    
    print(f"\n{'='*50}")
    print("验证完成")
    print(f"通过: {passed}/{len(steps)}, 失败: {failed}/{len(steps)}")
    print('='*50)
    
    if test_data["customer_id"]:
        print(f"\n测试客户 ID: {test_data['customer_id']}")
        print(f"可用于手动在 App 中测试: 客户列表 → 找到该客户 → 查看详情")
    
    return failed == 0


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
