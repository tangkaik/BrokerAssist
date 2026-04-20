#!/usr/bin/env python3.11
"""
添加包含地点和联系方式的拜访记录
用于测试 AI Summary 提取能力
"""

import asyncio
import sys
from datetime import datetime, timedelta
from uuid import uuid4

sys.path.insert(0, '/Users/kaitang/Desktop/【保险助手】/BrokerAssist/server')

from app.db.session import async_session_factory
from app.models.customer import Customer
from app.models.record import Record
from sqlalchemy import select

# 新的拜访记录数据（包含地点和联系方式）
NEW_RECORDS = [
    # 地点类记录
    {
        "customer_keywords": ["张建国"],
        "content": "今天在国贸一楼的咖啡厅与客户见面。环境安静，适合谈事。客户提到对年金险的领取方式还有些疑问，希望下周能带详细方案再来。",
    },
    {
        "customer_keywords": ["李晓雯"],
        "content": "下午在元通大厦的星巴克约了客户，点了杯拿铁聊了一个小时。客户带了她丈夫一起来，两人对保费预算还是有些分歧，需要再协调。",
    },
    {
        "customer_keywords": ["王志远"],
        "content": "去王总的办公室拜访，地址在CBD核心区的高档写字楼。王总刚开完会，时间比较紧，只聊了20分钟。他让我把方案发他邮箱，他会仔细看看。",
    },
    {
        "customer_keywords": ["陈雨晴"],
        "content": "在客户公司楼下的咖啡厅碰面，她午休时间只有半小时。简单沟通了一下基础保障方案，客户表示需要回去再考虑，下周给回复。",
    },
    {
        "customer_keywords": ["赵明轩"],
        "content": "在客户家附近的茶楼见面，环境比较安静。老两口一起来的，主要问了关于养老年金的领取方式和医疗险的报销流程。",
    },
    {
        "customer_keywords": ["孙海涛"],
        "content": "约在公司附近的会议室见面，客户特意提前准备了家庭收支表。详细讨论了寿险保额和缴费期限，客户对30年缴费方案比较感兴趣。",
    },
    {
        "customer_keywords": ["周婉婷"],
        "content": "下午在万象城的一家咖啡馆见面，客户逛街顺便约的。聊了一个多小时，她对重疾险的多次赔付责任比较关注。",
    },
    {
        "customer_keywords": ["邓宇航"],
        "content": "在客户公司楼下的会客厅见面，装修很豪华。客户助理倒了茶，聊了大概40分钟。客户希望方案能突出资产隔离功能。",
    },
    
    # 联系方式类记录
    {
        "customer_keywords": ["李晓雯"],
        "content": "加了客户的微信，她的微信名称是'Stella E'，头像是一家四口的照片。客户说平时上班不方便接电话，微信联系更方便。",
    },
    {
        "customer_keywords": ["王志远"],
        "content": "客户给了他的微信，名称是'上善若水'，备注写着'IT老兵'。他说工作日比较忙，周末可以详细聊方案。",
    },
    {
        "customer_keywords": ["陈雨晴"],
        "content": "客户的QQ号是287654321，她说平时用QQ比较多，微信主要是工作用。让我把资料发她QQ邮箱。",
    },
    {
        "customer_keywords": ["孙海涛"],
        "content": "客户的微信名称是'海涛'，头像是一座山的照片。他说妻子也有微信，可以拉个群一起沟通。",
    },
    {
        "customer_keywords": ["周婉婷"],
        "content": "加了客户微信，名称是'Wendy'，朋友圈很多旅游照片。她说丈夫也有意向，可以一起拉个家庭群。",
    },
    {
        "customer_keywords": ["郭文博"],
        "content": "客户的微信名称是'新能源小王子'，很有个性。他说刚工作不久，预算有限，让我推荐性价比高的产品。",
    },
    {
        "customer_keywords": ["何美玲"],
        "content": "客户的微信名称是'平安是福'，头像是一朵莲花。她说自己不太懂保险，主要是儿子让了解了解。",
    },
    {
        "customer_keywords": ["邓宇航"],
        "content": "客户的微信名称是'David Deng'，头像是西装照。他说助理也会跟进这事，可以把我推荐给助理对接。",
    },
    {
        "customer_keywords": ["赵明轩"],
        "content": "客户的QQ号是561239874，他说和老伴都不太会用微信，QQ用了很多年习惯了。让我把方案发邮箱。",
    },
    {
        "customer_keywords": ["张建国"],
        "content": "客户的微信名称是'张总'，头像是一座别墅。他说平时忙，让助理小王和我对接具体方案细节。",
    },
]


async def get_customers(session):
    """获取所有客户"""
    result = await session.execute(select(Customer))
    return result.scalars().all()


async def add_records(session, customers):
    """添加新记录"""
    now = datetime.now()
    
    # 建立客户名称到客户的映射
    customer_map = {}
    for c in customers:
        customer_map[c.name] = c
    
    added_count = 0
    
    for record_data in NEW_RECORDS:
        # 找到匹配的客户
        target_customer = None
        for keyword in record_data["customer_keywords"]:
            if keyword in customer_map:
                target_customer = customer_map[keyword]
                break
        
        if target_customer is None:
            print(f"⚠️ 未找到客户: {record_data['customer_keywords']}")
            continue
        
        # 创建记录（时间分散在最近2周内）
        days_ago = (added_count % 14) + 1  # 1-14天前
        record = Record(
            id=str(uuid4()),
            customer_id=target_customer.id,
            content=record_data["content"],
            type="text",
            created_at=now - timedelta(days=days_ago),
            updated_at=now - timedelta(days=days_ago),
        )
        session.add(record)
        added_count += 1
        
        print(f"📝 添加记录到 {target_customer.name}: {record_data['content'][:30]}...")
    
    await session.commit()
    print(f"\n✅ 共添加 {added_count} 条记录")
    
    # 更新客户的 updated_at 时间（触发 summary 更新）
    for customer in customers:
        customer.updated_at = now
        customer.summary_status = "stale"  # 标记需要重新生成 summary
    
    await session.commit()
    print("✅ 已标记所有客户 summary 需要更新")


async def main():
    print("═══════════════════════════════")
    print("  添加地点和联系方式记录")
    print("═══════════════════════════════\n")
    
    async with async_session_factory() as session:
        # 1. 获取所有客户
        customers = await get_customers(session)
        print(f"📊 找到 {len(customers)} 个客户\n")
        
        # 2. 添加记录
        await add_records(session, customers)
        
        # 3. 统计
        result = await session.execute(select(Record))
        all_records = result.scalars().all()
        print(f"\n📊 当前总记录数: {len(all_records)}")


if __name__ == "__main__":
    asyncio.run(main())
