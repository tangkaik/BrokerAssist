#!/usr/bin/env python3
"""
批量样本测试脚本
自动导入3组样本，执行summary/chat/advice，输出完整报告
"""

import asyncio
import json
import sys
from datetime import datetime

import httpx

BASE_URL = "http://127.0.0.1:8001/api/v1"

# 3组样本数据
SAMPLES = [
    {
        "name": "样本1-首次咨询重疾险",
        "customer": {
            "name": "张先生",
            "phone": "13800138001",
            "gender": "男",
            "tags": ["重疾险", "首次咨询"]
        },
        "records": [
            {
                "content": "客户主动来电：听说你们有新出的重疾险，想了解一下。我今年32岁，在互联网公司做产品经理，年收入大概40万。之前没买过商业保险，只有社保。最近同事查出甲状腺癌，觉得自己也该买个保障。预算的话，年缴保费控制在1万以内可以接受。",
                "type": "call"
            },
            {
                "content": "微信跟进：客户问如果买50万保额，保终身的话一年要交多少钱。另外问甲状腺结节能不能买，体检发现2级结节。",
                "type": "wechat"
            }
        ],
        "chat_questions": [
            "客户今年多大年纪？",
            "客户预算多少？",
            "客户有什么健康状况？",
            "建议推荐什么产品？"
        ]
    },
    {
        "name": "样本2-拒绝犹豫客户",
        "customer": {
            "name": "李女士",
            "phone": "13800138002",
            "gender": "女",
            "tags": ["重疾险", "价格异议", "犹豫"]
        },
        "records": [
            {
                "content": "客户咨询：想给自己和先生看重疾险，家里有两个孩子，大的5岁小的2岁。我32岁，先生35岁，都在国企上班，收入稳定但不算高。家庭年收入大概25万，有房贷每月8000。",
                "type": "call"
            },
            {
                "content": "方案讲解后：客户反馈方案整体不错，但觉得两个人加起来年缴1.5万有点贵。说房贷压力大，孩子教育支出也多，想再考虑考虑。问能不能先买一个人的，或者降低保额。",
                "type": "call"
            },
            {
                "content": "客户微信：跟先生商量了一下，还是觉得现阶段保费压力有点大。说等年底发了年终奖再看，到时候再联系。",
                "type": "wechat"
            }
        ],
        "chat_questions": [
            "客户为什么犹豫？",
            "客户家庭负担情况如何？",
            "什么时候再跟进比较好？"
        ]
    },
    {
        "name": "样本3-多轮沟通需求演进",
        "customer": {
            "name": "王女士",
            "phone": "13800138003",
            "gender": "女",
            "tags": ["家庭保障", "多轮沟通", "需求升级"]
        },
        "records": [
            {
                "content": "【首次沟通】客户咨询：想给女儿买个教育金保险，孩子刚满1岁。家里条件还可以，想提前给孩子存笔钱，以后上大学用。对教育金产品比较感兴趣。",
                "type": "call"
            },
            {
                "content": "【第二次沟通】客户主动来电：上次说的教育金我考虑了一下。另外想问问，我和先生是不是也该买点保险？我30岁，先生33岁，都是外企工作，年收入合计60万左右。目前有社保，没有商业保险。",
                "type": "call"
            },
            {
                "content": "【第三次沟通】客户带先生一起见面：仔细了解了重疾险和医疗险。先生比较担心重疾保额不够，想要高保额的。客户本人更关注医疗保障，说之前住院自费了不少钱。最后决定先生买100万重疾+高端医疗，客户自己买50万重疾+中端医疗，女儿的教育金暂缓，先配齐大人的保障。",
                "type": "offline"
            },
            {
                "content": "【第四次跟进】客户微信：先生说想再等等，觉得现在买太早，想明年再说。客户自己还是想尽快落实，担心体检出问题买不了。问能不能先给自己买，先生的明年再说。",
                "type": "wechat"
            }
        ],
        "chat_questions": [
            "客户需求有什么变化？",
            "客户和先生的分歧是什么？",
            "应该先给谁买？",
            "当前最紧迫的问题是什么？"
        ]
    }
]


async def create_customer(client: httpx.AsyncClient, customer_data: dict) -> str:
    """创建客户，返回customer_id"""
    resp = await client.post(f"{BASE_URL}/customers", json=customer_data)
    resp.raise_for_status()
    return resp.json()["data"]["customer_id"]


async def add_record(client: httpx.AsyncClient, customer_id: str, record: dict) -> None:
    """添加一条record"""
    payload = {
        "customer_id": customer_id,
        "content": record["content"],
        "type": record["type"]
    }
    resp = await client.post(f"{BASE_URL}/records", json=payload)
    resp.raise_for_status()


async def generate_summary(client: httpx.AsyncClient, customer_id: str) -> dict:
    """生成summary"""
    resp = await client.post(f"{BASE_URL}/customers/{customer_id}/summary/generate")
    resp.raise_for_status()
    return resp.json()["data"]


async def chat(client: httpx.AsyncClient, customer_id: str, question: str) -> dict:
    """发送chat问题"""
    payload = {"question": question}
    resp = await client.post(
        f"{BASE_URL}/customers/{customer_id}/chat",
        json=payload
    )
    resp.raise_for_status()
    return resp.json()["data"]


async def generate_advice(client: httpx.AsyncClient, customer_id: str) -> dict:
    """生成advice"""
    resp = await client.post(f"{BASE_URL}/customers/{customer_id}/advice/generate")
    resp.raise_for_status()
    return resp.json()["data"]


async def process_sample(client: httpx.AsyncClient, sample: dict) -> dict:
    """处理单组样本，返回完整结果"""
    print(f"\n{'='*60}")
    print(f"处理: {sample['name']}")
    print(f"{'='*60}")
    
    result = {
        "sample_name": sample["name"],
        "customer": sample["customer"],
        "records": sample["records"],
        "chat_questions": sample["chat_questions"]
    }
    
    # 1. 创建客户
    print("1. 创建客户...", end=" ")
    customer_id = await create_customer(client, sample["customer"])
    result["customer_id"] = customer_id
    print(f"✓ {customer_id}")
    
    # 2. 添加records
    print(f"2. 添加 {len(sample['records'])} 条记录...", end=" ")
    for record in sample["records"]:
        await add_record(client, customer_id, record)
    print("✓")
    
    # 3. 生成summary
    print("3. 生成summary...", end=" ")
    summary = await generate_summary(client, customer_id)
    result["summary"] = summary
    print("✓")
    
    # 4. Chat问答
    print(f"4. Chat问答 ({len(sample['chat_questions'])}个问题)...")
    chat_results = []
    for q in sample["chat_questions"]:
        chat_resp = await chat(client, customer_id, q)
        chat_results.append({
            "question": q,
            "answer": chat_resp["answer"]
        })
        print(f"   Q: {q[:30]}... ✓")
    result["chat"] = chat_results
    
    # 5. 生成advice
    print("5. 生成advice...", end=" ")
    advice = await generate_advice(client, customer_id)
    result["advice"] = advice
    print("✓")
    
    return result


async def main():
    """主流程"""
    print("="*60)
    print("BrokerAssist 批量样本测试")
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*60)
    
    async with httpx.AsyncClient(timeout=60.0) as client:
        # 检查服务健康
        try:
            resp = await client.get(f"{BASE_URL}/customers")
            resp.raise_for_status()
            print("✓ 服务连接正常\n")
        except Exception as e:
            print(f"✗ 无法连接服务: {e}")
            sys.exit(1)
        
        # 处理所有样本
        all_results = []
        for sample in SAMPLES:
            try:
                result = await process_sample(client, sample)
                all_results.append(result)
            except Exception as e:
                print(f"✗ 处理失败: {e}")
                all_results.append({
                    "sample_name": sample["name"],
                    "error": str(e)
                })
        
        # 输出完整报告
        report = {
            "test_time": datetime.now().isoformat(),
            "total_samples": len(SAMPLES),
            "results": all_results
        }
        
        # 保存到文件
        output_file = f"test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        
        print(f"\n{'='*60}")
        print(f"测试完成！报告已保存: {output_file}")
        print(f"{'='*60}")
        
        return report


if __name__ == "__main__":
    report = asyncio.run(main())
    
    # 同时打印简版报告到控制台
    print("\n" + "="*60)
    print("简版测试报告")
    print("="*60)
    
    for r in report["results"]:
        if "error" in r:
            print(f"\n【{r['sample_name']}】✗ 失败: {r['error']}")
            continue
            
        print(f"\n【{r['sample_name']}】")
        print(f"客户: {r['customer']['name']} ({r['customer_id']})")
        print(f"\n📋 Summary:")
        print(r['summary']['summary_text'][:200] + "..." if len(r['summary']['summary_text']) > 200 else r['summary']['summary_text'])
        
        print(f"\n💬 Chat问答:")
        for chat in r['chat']:
            print(f"  Q: {chat['question']}")
            print(f"  A: {chat['answer'][:100]}..." if len(chat['answer']) > 100 else f"  A: {chat['answer']}")
        
        print(f"\n📊 Advice:")
        print(r['advice']['advice_text'][:200] + "..." if len(r['advice']['advice_text']) > 200 else r['advice']['advice_text'])
