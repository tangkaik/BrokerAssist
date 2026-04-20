#!/usr/bin/env python3.11
"""
P6 全链路自动化验证
覆盖所有API端点和核心功能
"""

import requests
import sys
import json
from datetime import datetime

import os
BASE_URL = os.environ.get("BROKERASSIST_API_BASE", "http://localhost:8001/api/v1")
TOKEN = os.environ.get("BROKERASSIST_TOKEN", "")

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

# 测试结果
results = {
    "passed": [],
    "failed": [],
    "manual": []
}

def check(desc, condition, error_msg=""):
    """记录测试结果"""
    if condition:
        results["passed"].append(desc)
        print(f"  ✅ {desc}")
        return True
    else:
        results["failed"].append(f"{desc}: {error_msg}")
        print(f"  ❌ {desc}: {error_msg}")
        return False

def test_health():
    """测试1: 后端健康检查"""
    print("\n【测试1】后端健康检查")
    try:
        resp = requests.get(f"{BASE_URL}/health", timeout=5)
        check("Health API 返回 200", resp.status_code == 200)
        data = resp.json()
        check("数据库状态健康", data.get("data", {}).get("components", {}).get("database", {}).get("status") == "healthy")
    except Exception as e:
        check("Health API 可访问", False, str(e))

def test_customer_list():
    """测试2: 客户列表API"""
    print("\n【测试2】客户列表API")
    try:
        # 基础列表
        resp = requests.get(f"{BASE_URL}/customers", headers=HEADERS, timeout=10)
        check("客户列表 API 返回 200", resp.status_code == 200)
        
        data = resp.json()
        customers = data.get("data", {}).get("items", [])
        check(f"客户数量 >= 20", len(customers) >= 20, f"实际: {len(customers)}")
        
        # 关键客户存在
        names = [c["name"] for c in customers]
        check("张建国在列表中", "张建国" in names)
        check("马德胜在列表中", "马德胜" in names)
        check("杨慧敏在列表中", "杨慧敏" in names)
        
        # 搜索功能
        resp = requests.get(f"{BASE_URL}/customers?keyword=企业主", headers=HEADERS, timeout=10)
        check("搜索 API 返回 200", resp.status_code == 200)
        
        # 排序功能
        resp = requests.get(f"{BASE_URL}/customers?sort_by=name&sort_order=asc", headers=HEADERS, timeout=10)
        check("排序 API 返回 200", resp.status_code == 200)
        
    except Exception as e:
        check("客户列表 API", False, str(e))

def test_customer_detail():
    """测试3: 客户详情和记录"""
    print("\n【测试3】客户详情和记录")
    try:
        # 获取一个客户ID
        resp = requests.get(f"{BASE_URL}/customers?keyword=张建国", headers=HEADERS, timeout=10)
        customers = resp.json().get("data", {}).get("items", [])
        
        if not customers:
            check("找到张建国", False, "客户不存在")
            return
            
        customer_id = customers[0]["id"]
        
        # 详情API
        resp = requests.get(f"{BASE_URL}/customers/{customer_id}", headers=HEADERS, timeout=10)
        check("客户详情 API 返回 200", resp.status_code == 200)
        
        data = resp.json().get("data", {})
        check("详情包含 summary_status", "summary_status" in data)
        check("详情包含 tags", "tags" in data)
        
        # 记录列表API
        resp = requests.get(f"{BASE_URL}/customers/{customer_id}/records", headers=HEADERS, timeout=10)
        check("客户记录 API 返回 200", resp.status_code == 200)
        
        records = resp.json().get("data", {}).get("items", [])
        check(f"张建国记录数 >= 3", len(records) >= 3, f"实际: {len(records)}")
        
    except Exception as e:
        check("客户详情 API", False, str(e))

def test_summary_generation():
    """测试4: Summary生成（仅验证API连通，不验证内容质量）"""
    print("\n【测试4】Summary生成API")
    try:
        # 获取李晓雯（有微信名称和地点记录）
        resp = requests.get(f"{BASE_URL}/customers?keyword=李晓雯", headers=HEADERS, timeout=10)
        customers = resp.json().get("data", {}).get("items", [])
        
        if not customers:
            check("找到李晓雯", False, "客户不存在")
            return
            
        customer_id = customers[0]["id"]
        
        # 先生成
        resp = requests.post(f"{BASE_URL}/customers/{customer_id}/summary/generate", headers=HEADERS, timeout=30)
        check("Summary生成 API 返回 200", resp.status_code == 200)
        
        data = resp.json().get("data", {})
        check("返回 summary_status", "summary_status" in data)
        check("返回 summary_text", "summary_text" in data)
        
        # 再查询详情验证已保存
        resp = requests.get(f"{BASE_URL}/customers/{customer_id}", headers=HEADERS, timeout=10)
        data = resp.json().get("data", {})
        check("详情中 summary_status 为 ready", data.get("summary_status") == "ready")
        
        # 检查是否包含微信名称（关键提取点）
        summary = data.get("summary_text", "")
        if "Stella" in summary or "微信" in summary:
            check("Summary包含联系方式提取", True)
        else:
            results["manual"].append("Summary是否包含'Stella E'需要人工确认")
            print(f"  ⚠️  Summary包含联系方式需要人工确认")
        
    except Exception as e:
        check("Summary生成 API", False, str(e))

def test_advice_generation():
    """测试5: Advice生成"""
    print("\n【测试5】Advice生成API")
    try:
        # 获取马德胜（有新生儿、二婚等复杂情况）
        resp = requests.get(f"{BASE_URL}/customers?keyword=马德胜", headers=HEADERS, timeout=10)
        customers = resp.json().get("data", {}).get("items", [])
        
        if not customers:
            check("找到马德胜", False, "客户不存在")
            return
            
        customer_id = customers[0]["id"]
        
        # 确保有summary
        requests.post(f"{BASE_URL}/customers/{customer_id}/summary/generate", headers=HEADERS, timeout=30)
        
        # 生成advice
        resp = requests.post(f"{BASE_URL}/customers/{customer_id}/advice/generate", headers=HEADERS, timeout=30)
        check("Advice生成 API 返回 200", resp.status_code == 200)
        
        data = resp.json().get("data", {})
        check("返回 advice_text", "advice_text" in data)
        check("advice_text 非空", len(data.get("advice_text", "")) > 50)
        
    except Exception as e:
        check("Advice生成 API", False, str(e))

def test_ai_chat():
    """测试6: AI全局问答"""
    print("\n【测试6】AI全局问答API")
    try:
        # 测试基础问答
        resp = requests.post(f"{BASE_URL}/ai/chat", headers=HEADERS, json={"question": "请列出当前所有客户"}, timeout=30)
        check("AI Chat API 返回 200", resp.status_code == 200)
        
        data = resp.json().get("data", {})
        check("返回 answer", "answer" in data)
        answer = data.get("answer", "")
        check("answer 非空", len(answer) > 20)
        
        # 检查是否包含客户名称（基于真实数据）
        if "张建国" in answer or "马德胜" in answer or "共" in answer:
            check("AI回答包含客户信息", True)
        else:
            results["manual"].append("AI回答是否基于真实客户数据需要人工确认")
            print(f"  ⚠️  AI回答基于真实数据需要人工确认")
        
        # 测试复杂问题
        resp = requests.post(f"{BASE_URL}/ai/chat", headers=HEADERS, json={"question": "哪些客户有先天疾病的子女"}, timeout=30)
        check("复杂问题 API 返回 200", resp.status_code == 200)
        
        answer = resp.json().get("data", {}).get("answer", "")
        if "杨慧敏" in answer or "先天" in answer:
            check("复杂问题回答准确", True)
        else:
            results["manual"].append("AI是否能准确回答'先天疾病'问题需要人工确认")
            print(f"  ⚠️  复杂问题准确性需要人工确认")
        
    except Exception as e:
        check("AI Chat API", False, str(e))

def test_data_integrity():
    """测试7: 数据完整性"""
    print("\n【测试7】数据完整性检查")
    try:
        resp = requests.get(f"{BASE_URL}/customers?limit=100", headers=HEADERS, timeout=10)
        customers = resp.json().get("data", {}).get("items", [])
        
        # 检查关键客户
        names = {c["name"]: c for c in customers}
        
        check("共20个客户", len(customers) == 20, f"实际: {len(customers)}")
        
        # 检查各类标签客户存在
        check("包含高净值客户", any("高净值" in c.get("tags", []) for c in customers))
        check("包含离异客户", any("离异" in c.get("tags", []) for c in customers))
        check("包含丧偶客户", any("丧偶" in c.get("tags", []) for c in customers))
        check("包含丁克客户", any("丁克" in c.get("tags", []) for c in customers))
        check("包含单亲客户", any("单亲" in str(c.get("tags", [])) for c in customers))
        
        # 检查记录分布
        total_records = 0
        for c in customers:
            resp = requests.get(f"{BASE_URL}/customers/{c['id']}/records", headers=HEADERS, timeout=10)
            records = resp.json().get("data", {}).get("items", [])
            total_records += len(records)
        
        check(f"总记录数 >= 90", total_records >= 90, f"实际: {total_records}")
        
    except Exception as e:
        check("数据完整性", False, str(e))

def test_upload_api():
    """测试8: 上传API（仅验证端点存在）"""
    print("\n【测试8】上传API端点")
    try:
        # 不实际传文件，仅检查OPTIONS或错误响应
        resp = requests.post(f"{BASE_URL}/transcriptions/upload", headers=HEADERS, timeout=5)
        # 400表示API存在但参数错误，这是预期的
        check("上传API端点存在", resp.status_code in [200, 400, 422], f"状态码: {resp.status_code}")
    except Exception as e:
        check("上传API", False, str(e))

def main():
    print("=" * 50)
    print("P6 全链路自动化验证")
    print(f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    
    test_health()
    test_customer_list()
    test_customer_detail()
    test_summary_generation()
    test_advice_generation()
    test_ai_chat()
    test_data_integrity()
    test_upload_api()
    
    # 输出结果汇总
    print("\n" + "=" * 50)
    print("测试结果汇总")
    print("=" * 50)
    print(f"✅ 通过: {len(results['passed'])} 项")
    print(f"❌ 失败: {len(results['failed'])} 项")
    print(f"⚠️  需人工确认: {len(results['manual'])} 项")
    
    if results['failed']:
        print("\n【失败项详情】")
        for item in results['failed']:
            print(f"  ❌ {item}")
    
    if results['manual']:
        print("\n【需人工确认项】")
        for item in results['manual']:
            print(f"  ⚠️  {item}")
    
    # 判断可试用标准
    print("\n" + "=" * 50)
    if len(results['failed']) == 0 and len(results['passed']) >= 20:
        print("🎉 自动化测试通过！建议进入人工验收阶段")
    elif len(results['failed']) <= 2:
        print("⚠️  基本可用，但建议修复失败项后再验收")
    else:
        print("❌ 存在较多失败项，请先修复再验收")
    print("=" * 50)
    
    return len(results['failed']) == 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
