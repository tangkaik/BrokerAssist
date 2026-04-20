#!/usr/bin/env python3.11
"""
添加包含地址信息的拜访记录
"""

import asyncio
import sys
import random
from datetime import datetime, timedelta
from uuid import uuid4

sys.path.insert(0, '/Users/kaitang/Desktop/【保险助手】/BrokerAssist/server')

from app.db.session import async_session_factory
from app.models.customer import Customer
from app.models.record import Record
from sqlalchemy import select

# 地址记录数据
ADDRESS_RECORDS = [
    # 海淀地址
    {
        "customer_keyword": "张建国",
        "addresses": ["西山一号院", "海淀五路居附近"],
        "records": [
            "今天去客户家里拜访，地址是西山一号院，高档小区，环境很好。客户家在三楼，装修很有品味。聊了两个多小时，主要讨论了家庭保障方案。",
            "在客户公司附近的海淀五路居地铁站见面，客户公司就在旁边的高新园区。午休时间有限，快速确认了方案细节。"
        ]
    },
    {
        "customer_keyword": "李晓雯",
        "addresses": ["中关村", "万柳"],
        "records": [
            "客户约在中关村的公司附近见面，她在附近的小学工作。下班后人很多，我们找了一家安静的咖啡厅聊。",
            "周末去客户家里，住在万柳那边，小区很成熟，孩子上学方便。客户丈夫也在，一起聊了家庭保障规划。"
        ]
    },
    {
        "customer_keyword": "王志远",
        "addresses": ["西二旗", "上地"],
        "records": [
            "客户公司在西二旗，互联网公司聚集地。晚上7点多下班后才见面，在公司楼下的餐厅聊的。",
            "客户住在上地附近，离公司不远。周末去家里拜访，详细聊了重疾和医疗保障方案。"
        ]
    },
    # 西城地址
    {
        "customer_keyword": "赵明轩",
        "addresses": ["达官营", "广安门"],
        "records": [
            "客户住在达官营附近，老小区但生活便利。和老两口聊了很久，主要是养老和医疗补充保险。",
            "今天是在广安门附近的茶楼见面的，客户说是老习惯，喜欢喝茶聊天。"
        ]
    },
    {
        "customer_keyword": "何美玲",
        "addresses": ["金融街", "复兴门"],
        "records": [
            "客户丈夫在金融街附近开餐馆，我中午去的时候顺便在那里吃了个饭，然后一起去了他们家，在复兴门附近。",
            "约在客户家附近见面，在金融街商圈，交通很方便。聊了防癌医疗和住院保障。"
        ]
    },
    # 亦庄/大兴
    {
        "customer_keyword": "马德胜",
        "addresses": ["亦庄枫丹壹号别墅", "亦庄核心区"],
        "records": [
            "今天去客户家里拜访，住在亦庄枫丹壹号别墅，独栋，环境非常好。聊了很久，主要是财富传承和资产配置。",
            "客户公司在亦庄核心区，亦庄线直达。下午在公司会客厅见面的，聊了一个多小时。"
        ]
    },
    {
        "customer_keyword": "黄磊",
        "addresses": ["亦庄金茂府", "大兴黄村"],
        "records": [
            "客户住在亦庄金茂府，高档住宅。今天去家里聊，谈了很多关于重组家庭的财产安排问题。",
            "在大兴黄村的一个高尔夫俱乐部见面，客户在这里有会员卡，边打球边聊。"
        ]
    },
    # 朝阳
    {
        "customer_keyword": "邓宇航",
        "addresses": ["国贸", "朝阳公园", "三里屯"],
        "records": [
            "客户在国贸的写字楼上班，公司很大。今天的会是在国贸三期楼下的咖啡厅开的，聊了一个半小时。",
            "晚上约在朝阳公园附近的一家私人会所，环境很安静，适合谈事情。聊的是家族信托和资产隔离。",
            "客户住在三里屯附近，很有生活气息的地方。周末去家里拜访，客户妻子也在，一起聊了家庭财务规划。"
        ]
    },
    {
        "customer_keyword": "周婉婷",
        "addresses": ["望京", "亚运村"],
        "records": [
            "客户公司在望京SOHO附近，很有设计感的建筑。中午在附近的新荟城吃饭，边吃边聊。",
            "客户住在亚运村，鸟巢附近，环境很好。周末去家里，详细聊了重疾险的配置方案。"
        ]
    },
    # 丰台
    {
        "customer_keyword": "陈雨晴",
        "addresses": ["丽泽商务区", "丰台科技园"],
        "records": [
            "客户在丽泽商务区工作，这边发展很快。午休时间在附近的咖啡厅见面，快速沟通了基础保障方案。",
            "客户住在丰台科技园附近，晚上下班后过去拜访，聊了一个多小时，主要是医疗险的选择。"
        ]
    },
    # 通州
    {
        "customer_keyword": "郭文博",
        "addresses": ["通州北苑", "梨园"],
        "records": [
            "客户住在通州北苑，六号线直达。周末去家里拜访，聊了基础的意外险和医疗险配置。",
            "约在通州梨园附近见面，客户说这边租金便宜，生活压力小一些。"
        ]
    },
    # 石景山
    {
        "customer_keyword": "杨慧敏",
        "addresses": ["石景山万达", "古城"],
        "records": [
            "客户住在石景山万达附近，商圈很成熟。今天去家里拜访，聊了儿子先天心脏病的保险问题。",
            "在古城附近的一家茶馆见面，客户说喜欢这里的安静，适合思考问题。"
        ]
    },
    # 昌平
    {
        "customer_keyword": "孙海涛",
        "addresses": ["回龙观", "天通苑"],
        "records": [
            "客户住在回龙观，典型的程序员聚集地。周末去家里，详细聊了寿险和重疾的配置。",
            "在天通苑附近见面，客户说这边生活成本低，但通勤比较辛苦。"
        ]
    },
    {
        "customer_keyword": "周天明",
        "addresses": ["立水桥", "北苑"],
        "records": [
            "客户住在立水桥附近，是租房。带着几个月大的女儿一起见的面，聊了单亲爸爸的保障规划。",
            "在北苑附近的一家快餐店见面，时间比较紧，但沟通很高效。"
        ]
    },
    # 顺义
    {
        "customer_keyword": "赵丽华",
        "addresses": ["顺义后沙峪", "中央别墅区"],
        "records": [
            "客户住在顺义后沙峪，中央别墅区，环境很好。今天去家里聊了丁克家庭的养老规划。",
            "客户在附近的国际学校有教职，约在学校附近的咖啡厅见面。"
        ]
    },
    # 房山
    {
        "customer_keyword": "刘思琪",
        "addresses": ["房山良乡", "长阳"],
        "records": [
            "客户住在房山良乡，有点远但房价便宜。周末专程过去拜访，聊了OPC和自由职业的保障问题。",
            "在长阳附近的万达广场见面，客户说这边现在发展也不错。"
        ]
    },
    # 门头沟
    {
        "customer_keyword": "谢建国",
        "addresses": ["门头沟", "西山墅"],
        "records": [
            "客户住在门头沟的西山墅，养老的好地方，环境清静。聊了失独家庭的慈善安排和身后事。",
            "在门头沟城区的一家茶馆见面，客户说喜欢这边的山水，很适合养老。"
        ]
    },
    # 其他地址补充
    {
        "customer_keyword": "林小萌",
        "addresses": ["东直门", "三元桥"],
        "records": [
            "客户住在东直门附近，离使馆区很近，很有国际氛围。聊了异国恋和备孕期的保障规划。",
            "在三元桥附近的工作室见面，客户是插画师，工作室很有艺术气息。"
        ]
    },
]


async def add_records(session):
    """添加地址记录"""
    now = datetime.now()
    added_count = 0
    
    for data in ADDRESS_RECORDS:
        # 查找客户
        result = await session.execute(
            select(Customer).where(Customer.name == data["customer_keyword"])
        )
        customer = result.scalar_one_or_none()
        
        if not customer:
            print(f"⚠️ 未找到客户: {data['customer_keyword']}")
            continue
        
        print(f"👤 {customer.name} - 添加 {len(data['records'])} 条地址记录")
        print(f"   地址: {', '.join(data['addresses'])}")
        
        # 添加记录（分散在过去2周内）
        base_date = now - timedelta(days=random.randint(1, 14))
        
        for i, content in enumerate(data["records"]):
            record = Record(
                id=str(uuid4()),
                customer_id=customer.id,
                content=content,
                type="text",
                created_at=base_date + timedelta(days=i * 2),
                updated_at=base_date + timedelta(days=i * 2),
            )
            session.add(record)
            added_count += 1
        
        # 把地址加入客户标签
        current_tags = customer.tags or []
        for addr in data["addresses"]:
            if addr not in current_tags:
                current_tags.append(addr)
        customer.tags = current_tags
        customer.updated_at = now
        customer.summary_status = "stale"  # 标记需要重新生成
        
        print()
    
    await session.commit()
    print(f"✅ 共添加 {added_count} 条地址记录")


async def main():
    print("═══════════════════════════════")
    print("  添加北京地址拜访记录")
    print("═══════════════════════════════\n")
    
    async with async_session_factory() as session:
        await add_records(session)
        
        # 统计
        result = await session.execute(select(Customer))
        customers = result.scalars().all()
        
        print(f"📊 客户总数: {len(customers)}")
        
        result = await session.execute(select(Record))
        records = result.scalars().all()
        print(f"📊 记录总数: {len(records)}")


if __name__ == "__main__":
    asyncio.run(main())
