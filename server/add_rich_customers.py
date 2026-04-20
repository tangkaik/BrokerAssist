#!/usr/bin/env python3.11
"""
添加10个具有丰富家庭背景的新客户
包含多样化的子女、婚姻、父母、职业情况
"""

import asyncio
import sys
from datetime import datetime, timedelta
from uuid import uuid4
import random

sys.path.insert(0, '/Users/kaitang/Desktop/【保险助手】/BrokerAssist/server')

from app.db.session import async_session_factory
from app.models.customer import Customer
from app.models.record import Record

# 10个新客户数据
NEW_CUSTOMERS = [
    {
        "name": "刘思琪",
        "gender": "女",
        "age": 36,
        "phone": "13812345678",
        "tags": ["OPC", "离异", "女儿上小学", "保费敏感"],
        "job": "OPC（一个人公司）",
        "family": {
            "marriage": "离异3年",
            "children": "8岁女儿，随母亲生活",
            "parents": "父母健在，在老家生活",
            "living": "独自带女儿租房居住"
        },
        "records": [
            {"type": "text", "content": "下午在万达影城附近的咖啡厅见面。客户做自媒体运营，一个人公司，收入不稳定但时间自由。离异后独自带女儿，最担心的是自己出事女儿没人照顾。预算有限，希望先做基础保障。", "channel": "面谈"},
            {"type": "text", "content": "电话沟通20分钟。客户说最近有个大项目要赶，见面时间推到下周。主要是确认了一下女儿的教育金她也在考虑，但优先级不如健康保障高。", "channel": "电话"},
            {"type": "text", "content": "微信简短回复：'方案我看了，能不能把重疾险和医疗险分开做？我想先买医疗险试试。'", "channel": "微信"},
        ]
    },
    {
        "name": "马德胜",
        "gender": "男",
        "age": 52,
        "phone": "13987654321",
        "tags": ["高管", "二婚", "新生儿", "高净值"],
        "job": "外企大中华区副总裁",
        "family": {
            "marriage": "二婚，现任妻子32岁",
            "children": "新婚妻子刚生男孩（3个月），前妻有两个孩子已成年",
            "parents": "四位老人都在，身体尚可",
            "living": "别墅+保姆，妻子全职带娃"
        },
        "records": [
            {"type": "text", "content": "在王总办公室面谈，总裁楼层视野很好。客户刚得子，喜悦之余开始认真考虑财富传承。担心自己和现任妻子年龄差距大，想为幼子做长期安排。对年金和信托类产品感兴趣。", "channel": "面谈"},
            {"type": "text", "content": "公司楼下西餐厅午餐边吃边聊。客户提到前妻的孩子已经成年，不需要他操心，现在主要精力在新家庭。希望方案能兼顾税务优化。", "channel": "面谈"},
            {"type": "text", "content": "微信语音留言3分钟，主要是确认见面时间。背景有婴儿哭声，说妻子最近产后恢复，让他多参与育儿。", "channel": "微信语音"},
            {"type": "text", "content": "电话沟通15分钟。客户在国外出差，时差关系只能电话。问了一些关于海外资产配置和保险的问题。", "channel": "电话"},
        ]
    },
    {
        "name": "杨慧敏",
        "gender": "女",
        "age": 41,
        "phone": "13711112222",
        "tags": ["丧偶", "先天疾病", "独立投资人", "谨慎型"],
        "job": "独立投资人，做股票和基金",
        "family": {
            "marriage": "丧偶2年",
            "children": "独子12岁，患有先天性心脏病，做过手术",
            "parents": "公婆在老家，自己父母同城但不同住",
            "living": "自住房，母子二人"
        },
        "records": [
            {"type": "text", "content": "客户家里见面，装修简洁。气氛有些沉重，提到丈夫突然离世让她意识到保障的重要性。最担心的是儿子，先天心脏病导致很多保险买不了，想找到能承保的产品。", "channel": "面谈"},
            {"type": "text", "content": "儿童医院附近的咖啡厅。客户带儿子复查，顺便见面聊。孩子情况稳定，但需要长期关注。客户希望能在儿子18岁前做好全面的医疗和重疾安排。", "channel": "面谈"},
            {"type": "text", "content": "微信发了几张产品对比图，客户回复：'我研究了一下，这个等待期太长了，有没有短一点的？我儿子的情况等不了太久。'", "channel": "微信"},
            {"type": "text", "content": "晚上9点电话，客户刚收盘。聊了很多关于投资理念的话题，她对保险的理解很理性，希望保险是资产配置的一部分，不是投机。", "channel": "电话"},
        ]
    },
    {
        "name": "陈小龙",
        "gender": "男",
        "age": 29,
        "phone": "13633334444",
        "tags": ["媒体博主", "单身", "刚买房", "高压工作"],
        "job": "科技类自媒体博主，全网50万粉丝",
        "family": {
            "marriage": "单身，有女朋友在谈",
            "children": "无",
            "parents": "农村父母，有新农合",
            "living": "刚贷款买的小两居，每月还贷8000"
        },
        "records": [
            {"type": "text", "content": "在客户的工作室见面，桌上三台显示器，设备很专业。客户说自媒体看着光鲜但收入不稳定，主要靠广告和带货。刚买房压力山大，担心断供风险。", "channel": "面谈"},
            {"type": "text", "content": "客户家附近的奶茶店，他下楼取的，说在赶一个视频 deadline，只有20分钟。快速确认了意外险和医疗险的方案，说下周再细聊。", "channel": "面谈"},
            {"type": "text", "content": "凌晨1点微信：'刚剪完片子，看了你发的方案，有个问题：如果我不幸挂了，房贷怎么办？保险能覆盖吗？'", "channel": "微信"},
            {"type": "text", "content": "电话15分钟，客户在高速上出差途中。说最近体检发现甲状腺结节，担心影响投保，想尽快定下来。", "channel": "电话"},
            {"type": "text", "content": "微信发了一个链接，是某保险产品的测评视频，问我的看法。客户说粉丝经常问他保险问题，他自己也要先搞明白。", "channel": "微信"},
        ]
    },
    {
        "name": "吴雅琴",
        "gender": "女",
        "age": 47,
        "phone": "13555556666",
        "tags": ["三代同堂", "医疗险", "预算充足", "理赔经验"],
        "job": "国企财务总监",
        "family": {
            "marriage": "已婚，丈夫是公务员",
            "children": "双胞胎女儿，高三，准备高考",
            "parents": "公公婆婆同住，均已70+，身体一般",
            "living": "160平大房子，三代六口人"
        },
        "records": [
            {"type": "text", "content": "在客户家附近的高端茶楼见面。客户去年刚经历过母亲癌症理赔，对保险价值有深刻认识。现在主要关注全家人的医疗险升级，尤其是老人的防癌医疗。", "channel": "面谈"},
            {"type": "text", "content": "客户办公室见面，午休时间。说最近两个女儿压力大，她也在考虑高考后的教育金安排。丈夫比较传统，觉得保险是浪费钱，需要说服。", "channel": "面谈"},
            {"type": "text", "content": "电话30分钟，详细讲解了老人投保的健康告知问题。客户公公有高血压，婆婆有糖尿病，需要仔细筛选产品。", "channel": "电话"},
            {"type": "text", "content": "微信发了老人的体检报告，问哪些指标会影响投保。客户说看了很多资料，还是专业人士靠谱。", "channel": "微信"},
            {"type": "text", "content": "周末在客户家附近公园散步聊。客户状态很放松，说双胞胎下周模考，等高考结束全家一起做个全面规划。", "channel": "面谈"},
        ]
    },
    {
        "name": "周天明",
        "gender": "男",
        "age": 38,
        "phone": "13477778888",
        "tags": ["单亲爸爸", "女儿刚出生", "创业初期", "时间紧张"],
        "job": "创业公司CEO，做SaaS服务",
        "family": {
            "marriage": "离异1年，抚养权在男方",
            "children": "女儿刚出生6个月，前妻无抚养能力",
            "parents": "父母离异，母亲帮忙带孩子，父亲再婚",
            "living": "租房+母亲同住"
        },
        "records": [
            {"type": "text", "content": "客户公司附近快餐店，边吃边聊。创业初期很忙，边吃边回微信。最担心的是自己万一出事，女儿和母亲没人照顾。希望快速搞定基础保障。", "channel": "面谈"},
            {"type": "text", "content": "电话10分钟，客户在开会间隙。说公司刚拿到天使轮，现金流还是紧张，保费要控制在合理范围。", "channel": "电话"},
            {"type": "text", "content": "晚上10点微信：'女儿今天发烧了，我在医院。保险的事能不能先给我做最简单的方案，我下周签。'", "channel": "微信"},
            {"type": "text", "content": "在客户家楼下便利店门口站着聊。母亲抱着孩子在旁边，客户抽了根烟，说压力真的大，但看到女儿又觉得值得。", "channel": "面谈"},
        ]
    },
    {
        "name": "赵丽华",
        "gender": "女",
        "age": 55,
        "phone": "13399990000",
        "tags": ["丁克", "体制内", "养老规划", "保守型"],
        "job": "大学副教授",
        "family": {
            "marriage": "已婚30年，丁克",
            "children": "无",
            "parents": "母亲健在，父亲已故，母亲有退休金",
            "living": "学校分的房子，无贷款"
        },
        "records": [
            {"type": "text", "content": "学校咖啡厅见面，环境很安静。客户和丈夫都是丁克，现在55岁开始认真考虑养老问题。没有子女依靠，希望养老金能覆盖后期护理费用。", "channel": "面谈"},
            {"type": "text", "content": "客户办公室，书架很多。聊了很多关于养老社区的话题，客户说去过几次高端养老社区考察，对那种模式不排斥。", "channel": "面谈"},
            {"type": "text", "content": "微信发了几个养老年金产品的对比，客户回复：'我和老公商量了，倾向于领取确定型的，不想有浮动。'", "channel": "微信"},
            {"type": "text", "content": "电话20分钟，客户在外地参加学术会议。说丈夫最近体检发现血糖高，想给他也看看医疗险。", "channel": "电话"},
        ]
    },
    {
        "name": "黄磊",
        "gender": "男",
        "age": 44,
        "phone": "13266667777",
        "tags": ["重组家庭", "各自带娃", "房产多", "传承需求"],
        "job": "房地产开发商，区域负责人",
        "family": {
            "marriage": "二婚，各自带一个孩子",
            "children": "儿子16岁（前妻带，但常来往），继女14岁",
            "parents": "父亲已故，母亲跟着弟弟住",
            "living": "三套房产，自住一套大的"
        },
        "records": [
            {"type": "text", "content": "客户会所见面，装修豪华。重组家庭的财产安排很复杂，担心万一自己不在了，两个孩子和现任妻子的权益保障。对保险金信托很感兴趣。", "channel": "面谈"},
            {"type": "text", "content": "高尔夫球场边聊边打，客户教了我几杆。说生意上有几个项目在谈，如果顺利今年收入会很可观，到时候保额想再提高。", "channel": "面谈"},
            {"type": "text", "content": "微信发了信托相关的法律资料，客户回复：'我让我的律师也看看，这种东西还是要法律结构清楚。'", "channel": "微信"},
            {"type": "text", "content": "晚上电话，客户喝了点酒，话比较多。说前妻最近又来找他要钱，他担心儿子被教坏，想提前把一部分钱锁定给儿子。", "channel": "电话"},
            {"type": "text", "content": "在客户新开发的楼盘销售中心见面，他顺便视察工作。聊了一下房产市场的走势，客户对长期不看好，所以想多配置金融资产。", "channel": "面谈"},
        ]
    },
    {
        "name": "林小萌",
        "gender": "女",
        "age": 31,
        "phone": "13122223333",
        "tags": ["备孕", "自由职业", "异国恋", "灵活工作"],
        "job": "插画师，自由职业",
        "family": {
            "marriage": "已婚，丈夫在美国工作，异国恋",
            "children": "正在备孕，计划先生孩子再考虑团聚",
            "parents": "父母在同城，经常互相照顾",
            "living": "父母资助首付的小公寓"
        },
        "records": [
            {"type": "text", "content": "客户工作室见面，墙上都是她的作品，很有艺术气息。正在备孕，担心孕期和产后的保障问题。丈夫不在身边，很多事要靠自己。", "channel": "面谈"},
            {"type": "text", "content": "在客户家附近的咖啡馆，她带了一本孕期看的书。聊了很多关于孕妇险和新生儿保险的话题，客户说想提前做功课。", "channel": "面谈"},
            {"type": "text", "content": "微信发了几张产检单，问哪些指标会影响投保。客户说刚做完孕前检查，一切正常，想趁健康先把保险落实好。", "channel": "微信"},
            {"type": "text", "content": "凌晨微信（美国时间的晚上）：'老公视频的时候问了保险的事，他那边也有保险，我们要不要统筹考虑一下？'", "channel": "微信"},
            {"type": "text", "content": "电话30分钟，客户在画画时打的。说她其实也可以去美国，但放心不下父母，而且自己的事业刚起步，很纠结。", "channel": "电话"},
        ]
    },
    {
        "name": "谢建国",
        "gender": "男",
        "age": 60,
        "phone": "13044445555",
        "tags": ["退休", "失独", "高净值", "慈善意向"],
        "job": "退休企业家，原制造业老板",
        "family": {
            "marriage": "已婚，妻子也是退休教师",
            "children": "独子已故（意外），无孙辈",
            "parents": "双方父母均已去世",
            "living": "郊区别墅，有保姆"
        },
        "records": [
            {"type": "text", "content": "客户家里见面，很大的院子，但感觉有些冷清。客户说儿子走了5年了，钱再多也没意义。现在考虑怎么安排身后事，部分财产想做慈善。", "channel": "面谈"},
            {"type": "text", "content": "在客户的老厂房改的办公室见面，现在做创业孵化器。客户说看到年轻创业者就像看到儿子，想帮助他们。", "channel": "面谈"},
            {"type": "text", "content": "微信发了关于慈善信托的资料，客户回复：'这个方向是对的，但我还想再看看具体的操作流程。'", "channel": "微信"},
            {"type": "text", "content": "电话40分钟，聊了很多人生感悟。客户说保险对他来说不是保障，是一种责任的延续，他想确保即便自己不在了，也能持续做善事。", "channel": "电话"},
            {"type": "text", "content": "在慈善基金会见面，客户是理事。现场看了他们的运作，客户说想做冠名基金，但担心资金规模不够。", "channel": "面谈"},
        ]
    },
]


async def import_customers(session):
    """导入新客户和记录"""
    user_id = "default-user"
    now = datetime.now()
    
    for customer_data in NEW_CUSTOMERS:
        # 创建客户
        customer = Customer(
            id=str(uuid4()),
            name=customer_data["name"],
            phone=customer_data["phone"],
            gender=customer_data["gender"],
            tags=customer_data["tags"],
            user_id=user_id,
            summary_text=None,
            summary_status="stale",
            created_at=now,
            updated_at=now,
        )
        
        session.add(customer)
        await session.flush()
        
        print(f"👤 创建客户: {customer.name} ({customer_data['job']})")
        print(f"   家庭: {customer_data['family']['marriage']}, {customer_data['family']['children']}")
        
        # 创建记录（分散在过去一个月内）
        base_date = now - timedelta(days=random.randint(7, 30))
        
        for i, record_data in enumerate(customer_data["records"]):
            # 构建完整内容（包含沟通渠道）
            channel = record_data.get("channel", "面谈")
            content = f"【{channel}】{record_data['content']}"
            
            record = Record(
                id=str(uuid4()),
                customer_id=customer.id,
                content=content,
                type=record_data.get("type", "text"),
                created_at=base_date + timedelta(days=i * random.randint(2, 5)),
                updated_at=base_date + timedelta(days=i * random.randint(2, 5)),
            )
            session.add(record)
        
        print(f"   📝 添加 {len(customer_data['records'])} 条记录")
        print()
    
    await session.commit()


async def main():
    print("═══════════════════════════════")
    print("  添加10个丰富背景的新客户")
    print("═══════════════════════════════\n")
    
    async with async_session_factory() as session:
        await import_customers(session)
        
        # 统计
        from sqlalchemy import select, func
        from app.models.customer import Customer
        from app.models.record import Record
        
        result = await session.execute(select(func.count(Customer.id)))
        customer_count = result.scalar()
        
        result = await session.execute(select(func.count(Record.id)))
        record_count = result.scalar()
        
        print(f"📊 当前总数:")
        print(f"   客户: {customer_count}")
        print(f"   记录: {record_count}")


if __name__ == "__main__":
    asyncio.run(main())
