#!/usr/bin/env python3.11
"""
导入测试客户数据
- 清空现有数据
- 插入新的测试客户和记录
"""

import asyncio
import argparse
import json
import sys
from datetime import datetime, timedelta
from uuid import uuid4

sys.path.insert(0, '/Users/kaitang/Desktop/【保险助手】/BrokerAssist/server')

from app.db.session import async_session_factory
from app.models.customer import Customer
from app.models.record import Record
from app.models.user import User
from sqlalchemy import delete, select

# 测试数据
TEST_DATA = {
  "customers": [
    {
      "name": "张建国",
      "gender": "男",
      "age": 52,
      "tags": ["企业主", "高净值", "家庭保障", "年金兴趣"],
      "phone": "13846271593",
      "records": [
        {
          "type": "text",
          "content": "首次上门拜访。客户经营一家建材贸易公司，近两年业务整体稳定，家庭年收入较高。客户本人已婚，有一儿一女，孩子分别在读高中和大学。客户提到自己名下已有基础社保和一份多年前购买的终身寿险，但对家庭整体保障配置缺乏系统规划。此次沟通中客户重点关心资产保全、孩子教育及未来养老金安排，希望先从自己和爱人的重疾、医疗保障开始梳理。"
        },
        {
          "type": "text",
          "content": "第二次拜访时重点讨论高端医疗和重疾险。客户表示自己平时工作应酬较多，体检发现轻度脂肪肝和血脂偏高，目前无重大既往病史。客户妻子45岁，在银行工作，比较关注女性特定疾病保障。客户希望保额充足，但不要产品结构太复杂，强调理赔和服务体验要好。客户对年缴保费接受度较高，但明确表示不愿意一次性投入过多现金。"
        },
        {
          "type": "text",
          "content": "第三次沟通时客户开始关注子女教育金和婚嫁金安排。大女儿明年准备出国读研，小儿子还在国内读高中。客户提到希望通过稳健型工具做长期储备，不追求高收益，更在意资金安全和确定性。客户认可先完善夫妻二人的健康保障，再考虑为子女做专门的教育储备规划。"
        }
      ]
    },
    {
      "name": "李晓雯",
      "gender": "女",
      "age": 34,
      "tags": ["二胎家庭", "重疾险", "保费敏感", "女性保障"],
      "phone": "13973148206",
      "records": [
        {
          "type": "text",
          "content": "客户通过朋友介绍来咨询。客户34岁，在公立小学任教，丈夫36岁在国企工作，目前有两个孩子，分别为6岁和2岁。家庭收入稳定，但有房贷和育儿支出，整体预算偏谨慎。客户此前只买过意外险，没有系统配置重疾和医疗保障。客户表示最担心自己生病后影响家庭收入，希望先给夫妻二人补齐基础保障。"
        },
        {
          "type": "text",
          "content": "面谈时客户重点询问女性重疾和医疗险，尤其关注甲状腺、乳腺相关保障责任。客户有轻微乳腺结节，近期一直在复查，担心影响投保。客户希望方案简单明了，最好能分层配置，例如先做基础保额，后续经济情况改善后再逐步加保。"
        },
        {
          "type": "text",
          "content": "第三次沟通讨论预算问题。客户明确表示夫妻两人总保费每年控制在1.2万元以内较为合适，如果超出太多会有压力。客户丈夫更倾向先给孩子买，客户本人认为应该优先保障家庭收入支柱。当前双方在保障顺序上尚未完全达成一致。"
        },
        {
          "type": "text",
          "content": "最近一次回访中，客户表示愿意接受先给夫妻二人做基础重疾和百万医疗，孩子的保障后续补充。客户希望下次见面时能够看到两个预算版本，一种偏保守，一种偏全面，便于和丈夫进一步沟通决策。"
        }
      ]
    },
    {
      "name": "王志远",
      "gender": "男",
      "age": 41,
      "tags": ["中层管理", "加保", "已有寿险", "健康告知关注"],
      "phone": "13750429618",
      "records": [
        {
          "type": "text",
          "content": "客户为互联网公司运营总监，41岁，已婚，有一个10岁的女儿。客户早年买过一份定期寿险和一份普通医疗险，但整体保额不高。最近因同事突发重疾，开始重新审视自己的保障缺口。客户担心自己长期熬夜加班、血压波动会影响承保，希望先评估能否顺利投保再谈具体方案。"
        },
        {
          "type": "text",
          "content": "本次沟通重点梳理已有保单。客户现有寿险保额50万，缴费压力不大，但认为无法覆盖家庭负债和未来教育支出。客户希望在不退保旧保单的前提下加保重疾和长期医疗，同时希望保障责任尽量全面。"
        }
      ]
    },
    {
      "name": "陈雨晴",
      "gender": "女",
      "age": 29,
      "tags": ["单身白领", "首次投保", "医疗险优先", "预算有限"],
      "phone": "13682957144",
      "records": [
        {
          "type": "text",
          "content": "客户29岁，未婚，在广告公司做品牌策划，工作节奏快，经常熬夜。客户此前没有买过任何商业保险，这次是因为自己最近住院做了一个小手术，感觉医保报销后自费部分仍然不少，才开始认真考虑商业保障。客户明确表示目前收入还在增长阶段，希望先用较低预算把基础医疗和重疾风险覆盖住。"
        },
        {
          "type": "text",
          "content": "客户对保险专业术语不熟悉，需要从最基础的重疾险、医疗险、意外险区别讲起。客户比较在意理赔是否方便，以及线上服务是否成熟。预算上客户希望年缴控制在5000元以内，如果保障层级合理，也可以稍微上浮。"
        },
        {
          "type": "text",
          "content": "最近沟通中客户表示暂时不考虑寿险，因为没有房贷和子女负担。客户希望先把自己最容易发生的住院、手术和重大疾病风险处理好。客户计划下个月发年中奖后再确定是否立即投保。"
        }
      ]
    },
    {
      "name": "赵明轩",
      "gender": "男",
      "age": 63,
      "tags": ["退休规划", "养老年金", "健康关注", "夫妻共同决策"],
      "phone": "13591826470",
      "records": [
        {
          "type": "text",
          "content": "客户63岁，已退休，退休前在事业单位工作，爱人60岁刚退休。夫妻二人有基础养老和医保，经济状况较平稳。此次咨询主要由儿子建议，希望看看是否还有适合退休阶段的医疗和养老补充方案。客户对风险型产品兴趣一般，更关注长期稳定领取和医疗服务资源。"
        },
        {
          "type": "text",
          "content": "沟通中客户提到自己有高血压，长期服药控制，爱人有轻度骨质疏松。客户担心年龄偏大后，普通健康险可选空间有限，因此更关心防癌医疗、住院补充和养老年金类工具。客户不追求高收益，希望流程简洁、条款清楚。"
        },
        {
          "type": "text",
          "content": "第三次沟通重点放在养老补充工具。客户希望如果配置年金，领取节奏要稳定，最好与现有养老金形成互补。客户儿子则更关心父母后续住院和康复阶段的费用问题。当前家庭倾向于先补医疗，再看是否追加养老储备。"
        }
      ]
    },
    {
      "name": "孙海涛",
      "gender": "男",
      "age": 38,
      "tags": ["房贷家庭", "收入支柱", "寿险优先", "风险意识强"],
      "phone": "15827463091",
      "records": [
        {
          "type": "text",
          "content": "客户38岁，在制造业企业担任销售负责人，已婚，有一名4岁孩子。家庭目前房贷每月约9000元，客户自认为是主要收入来源，因此非常重视身故和失能风险。客户此前没有配置足够的寿险，觉得一旦发生极端情况，家庭现金流会非常紧张。"
        },
        {
          "type": "text",
          "content": "面谈时客户表示自己可以接受把寿险放在优先级第一位，其次再考虑重疾和医疗。客户身体总体不错，但有轻度胃炎，平时应酬饮酒较多。客户希望方案不要太分散，最好能按照家庭责任高峰期来匹配缴费和保障期限。"
        },
        {
          "type": "text",
          "content": "最近一次跟进中，客户询问如果未来二胎计划落实，是否需要同步调整当前保额。客户还提到妻子目前仅有单位团险，没有单独购买商业保险，后续希望一并纳入规划，但当前预算会先优先保障自己。"
        },
        {
          "type": "text",
          "content": "客户希望下一次面谈时能看到一版非常直观的家庭责任缺口分析，包括房贷、孩子教育、老人赡养等因素，以便更好地和妻子沟通投保必要性。"
        }
      ]
    },
    {
      "name": "周婉婷",
      "gender": "女",
      "age": 47,
      "tags": ["中高收入", "子女教育", "重疾医疗", "理赔关注"],
      "phone": "15964081257",
      "records": [
        {
          "type": "text",
          "content": "客户47岁，在民营企业任财务总监，丈夫49岁经营小型贸易公司，女儿准备高考。客户之前曾为家人买过一些短期意外险，但没有系统配置长期健康保障。客户本人非常关注理赔体验和条款稳定性，因为身边朋友曾遇到理赔纠纷，对保险公司服务能力较为敏感。"
        },
        {
          "type": "text",
          "content": "客户目前体检有轻度甲状腺结节，正在定期复查。客户更在意住院和大病带来的现金支出，希望自己和丈夫都能有较完整的医疗与重疾组合。对于子女教育金，客户有兴趣，但表示必须在保障做完之后再考虑。"
        }
      ]
    },
    {
      "name": "郭文博",
      "gender": "男",
      "age": 27,
      "tags": ["刚工作", "单身", "意外险", "保费敏感"],
      "phone": "13458617329",
      "records": [
        {
          "type": "text",
          "content": "客户27岁，刚工作第三年，在新能源汽车行业做研发，未婚，租房居住。客户接触保险的契机是公司最近组织了体检和健康讲座，开始意识到商业保障的重要性。客户当前收入还不高，明确表示希望先用最低成本建立基础保障，重点关注意外和住院风险。"
        },
        {
          "type": "text",
          "content": "沟通中客户对保险理解较浅，担心被推销复杂产品，因此非常看重方案是否简单透明。客户可以接受每年3000元以内的保费，希望先了解最基础的搭配逻辑。客户暂时没有寿险需求，因为没有家庭负担。"
        },
        {
          "type": "text",
          "content": "回访时客户表示最近加班较多，睡眠质量一般，但无已知重大疾病史。客户计划等季度奖金到账后再做决定，希望下一次沟通时可以看到一版非常基础的入门型保障方案说明。"
        }
      ]
    },
    {
      "name": "何美玲",
      "gender": "女",
      "age": 56,
      "tags": ["家庭主妇", "夫妻保障", "防癌险", "保守型"],
      "phone": "13371940528",
      "records": [
        {
          "type": "text",
          "content": "客户56岁，家庭主妇，丈夫59岁经营小型餐饮门店。夫妻二人对子女依赖度不高，但对子女未来负担自己医疗费用这件事比较介意。客户过去对保险兴趣不大，认为社保足够，但最近身边同龄朋友陆续出现肿瘤和慢病情况，开始改变看法。"
        },
        {
          "type": "text",
          "content": "客户目前最关注防癌医疗和住院保障，对复杂的投资型产品没有兴趣。客户担心自己年龄偏大、健康告知严格，因此希望先了解是否还能买、怎么买更稳妥。客户丈夫平时吸烟较多，也有体检异常情况，夫妻共同投保意愿存在，但希望先分别评估。"
        },
        {
          "type": "text",
          "content": "最近沟通中客户表达了比较强的保守倾向，明确表示不愿一次性投入过高保费，也不希望缴费周期太长。客户更希望用可接受的预算先把高概率的大额医疗支出风险挡住。"
        }
      ]
    },
    {
      "name": "邓宇航",
      "gender": "男",
      "age": 45,
      "tags": ["高净值", "资产传承", "企业主", "家族信托兴趣"],
      "phone": "18853194762",
      "records": [
        {
          "type": "text",
          "content": "客户45岁，经营一家区域连锁餐饮品牌，家庭资产规模较大，已婚，有两个孩子分别在初中和大学阶段。客户本次沟通主要不是为了基础保障，而是关注长期资产安排和家族财富传承。客户曾接触过年金、增额终身寿和家族信托概念，但尚未形成系统认知。"
        },
        {
          "type": "text",
          "content": "客户提到自己更在意资产安全性和代际传承秩序，不追求高收益。希望通过保险类工具解决部分资产隔离、婚前婚后财产安排及子女教育支持问题。客户本人健康情况良好，但强调自己时间有限，希望后续沟通尽量高效、材料准备充分。"
        },
        {
          "type": "text",
          "content": "最近一次深度沟通中，客户提出希望下一次能重点对比保险工具与家族信托在使用门槛、灵活性和法律安排上的差异。客户对保费并不敏感，但很看重法律结构、受益人安排及未来资金用途控制。"
        },
        {
          "type": "text",
          "content": "客户还提到配偶对复杂金融安排的接受程度一般，希望方案解释既要专业，也要方便家庭成员理解。客户倾向于先做顶层规划，再决定是否分步实施。"
        },
        {
          "type": "text",
          "content": "回访时客户助理确认，下个月可安排一次家庭会议形式的沟通，希望届时能准备一版适合夫妻共同决策的简明框架材料。"
        }
      ]
    }
  ]
}


REAL_ESTATE_TEST_DATA = {
  "customers": [
    {
      "name": "林佳怡",
      "gender": "女",
      "age": 32,
      "tags": ["首套刚需", "预算敏感", "通勤优先", "二居"],
      "phone": "13671028495",
      "location": {"raw": "北京市朝阳区望京", "city": "北京市", "district": "朝阳区", "subarea": "望京"},
      "records": [
        {
          "type": "text",
          "content": "客户32岁，在望京互联网公司做产品经理，目前租住在望京西附近。首次购房，预算总价控制在450万以内，首付约180万。客户明确希望通勤时间控制在40分钟以内，优先考虑朝阳、海淀交界区域，二居即可，不强求新房。"
        },
        {
          "type": "text",
          "content": "第二次沟通重点聊贷款压力。客户担心月供超过收入的40%，希望先看总价稳定、税费清楚、物业成熟的小区。客户父母可以补充一部分首付，但不希望过度依赖家庭支持。客户对老小区能接受，但要求电梯或低楼层。"
        },
        {
          "type": "text",
          "content": "最近带看了两套望京周边二手房。客户喜欢其中一套的通勤和小区环境，但觉得客厅采光一般。客户希望下次再对比一套朝阳公园方向的房源，重点看通勤、采光和未来转手流动性。"
        }
      ]
    },
    {
      "name": "周明哲",
      "gender": "男",
      "age": 39,
      "tags": ["改善三居", "学区关注", "预算充足", "家庭决策"],
      "phone": "13810573942",
      "location": {"raw": "北京市海淀区中关村", "city": "北京市", "district": "海淀区", "subarea": "中关村"},
      "records": [
        {
          "type": "text",
          "content": "客户39岁，已婚，有一个7岁孩子，目前住在海淀两居，想改善到三居。家庭预算总价约1200万以内，核心诉求是孩子上学和老人偶尔同住，关注中关村、万柳、苏州桥一带。客户本人更关注通勤，爱人更关注学校和小区品质。"
        },
        {
          "type": "text",
          "content": "客户已经看过三套房，对楼龄、物业和停车都比较敏感。客户觉得一套万柳房源位置很好，但价格偏高，担心议价空间有限。爱人倾向一步到位，客户本人希望不要把月供压力拉太满。"
        },
        {
          "type": "text",
          "content": "回访时客户提出希望下次看房前先做一个三套候选房源对比表，包括总价、单价、学校、楼龄、停车、通勤和税费估算。客户希望周末带爱人一起复看。"
        }
      ]
    },
    {
      "name": "许晨曦",
      "gender": "女",
      "age": 28,
      "tags": ["租转买", "低首付", "地铁沿线", "小户型"],
      "phone": "13944268107",
      "location": {"raw": "上海市徐汇区漕河泾", "city": "上海市", "district": "徐汇区", "subarea": "漕河泾"},
      "records": [
        {
          "type": "text",
          "content": "客户28岁，在漕河泾上班，目前租房。想从租房转为买小户型，总价预算约300万，首付能力有限，倾向地铁沿线一居或小两居。客户最担心贷款资质和月供压力，希望先明确可买范围。"
        },
        {
          "type": "text",
          "content": "客户接受房龄稍老，但希望小区安全、通勤方便，最好离地铁不超过1公里。客户对上海不同板块不熟，需要顾问帮她把可选区域缩小到3个方向。当前她对闵行、徐汇边缘和浦东部分板块都愿意了解。"
        },
        {
          "type": "text",
          "content": "最近沟通中客户表示如果合适可以年内定下来，但不想被催促。她希望先看总价低、税费低、流动性还可以的房源，暂时不考虑需要大装修的房子。"
        }
      ]
    },
    {
      "name": "陈立峰",
      "gender": "男",
      "age": 46,
      "tags": ["投资型", "现金充足", "租金回报", "谨慎决策"],
      "phone": "13788204631",
      "location": {"raw": "上海市浦东新区陆家嘴", "city": "上海市", "district": "浦东新区", "subarea": "陆家嘴"},
      "records": [
        {
          "type": "text",
          "content": "客户46岁，企业高管，已有自住房，这次主要看投资型房产。客户现金较充足，但明确表示不追高，不接受过度包装的投资逻辑。关注浦东、前滩、徐汇滨江等板块，希望了解租金稳定性和未来转手流动性。"
        },
        {
          "type": "text",
          "content": "沟通中客户重点询问税费、持有成本、出租难度和空置风险。客户对商住和公寓兴趣不大，更倾向住宅或核心板块小面积标的。客户要求所有收益判断必须保守，不希望听到夸张涨幅预测。"
        },
        {
          "type": "text",
          "content": "最近一次电话中客户要求下次提供3套不同策略的标的：一套偏核心稳健、一套偏租金回报、一套偏总价门槛低。客户希望每套都列出风险点，而不是只讲优点。"
        }
      ]
    },
    {
      "name": "王欣然",
      "gender": "女",
      "age": 35,
      "tags": ["改善换房", "卖一买一", "时间紧", "决策人不一致"],
      "phone": "13690351728",
      "location": {"raw": "北京市丰台区丽泽", "city": "北京市", "district": "丰台区", "subarea": "丽泽"},
      "records": [
        {
          "type": "text",
          "content": "客户35岁，夫妻二人准备卖掉当前小两居，换一套三居。意向区域在丰台丽泽、菜户营、玉泉营附近，预算取决于现房出售价格。客户本人想尽快换，丈夫担心卖一买一衔接不好。"
        },
        {
          "type": "text",
          "content": "客户现在最大的顾虑是时间节奏：如果先卖后买，担心短期租房不方便；如果先买后卖，资金压力较大。客户希望顾问帮她梳理换房路径，以及不同路径下的风险和时间节点。"
        },
        {
          "type": "text",
          "content": "最近沟通中客户说现房已有中介估价，但价格预期和市场成交价可能有差距。客户希望下一步先做现房真实成交价评估，再决定目标房源预算。"
        }
      ]
    },
    {
      "name": "赵雅楠",
      "gender": "女",
      "age": 42,
      "tags": ["学区优先", "单价敏感", "二手房", "孩子转学"],
      "phone": "13566792084",
      "location": {"raw": "北京市西城区广安门", "city": "北京市", "district": "西城区", "subarea": "广安门"},
      "records": [
        {
          "type": "text",
          "content": "客户42岁，孩子准备转学，核心诉求是西城学区。预算总价约900万以内，能接受面积小一些，但不能接受明显硬伤。客户对政策变化非常敏感，要求顾问对学区相关信息表达保守，不能做确定承诺。"
        },
        {
          "type": "text",
          "content": "客户已经看过两套广安门附近老破小，一套楼层高无电梯，一套户型较差。客户觉得价格压力大，但为了孩子可以接受一定居住牺牲。丈夫更关注未来是否容易转手。"
        },
        {
          "type": "text",
          "content": "客户希望下一次集中看三套不同取舍的房源：一套学校更优，一套居住更舒服，一套总价更低。她希望顾问提前把每套房的硬伤讲清楚。"
        }
      ]
    },
    {
      "name": "刘景航",
      "gender": "男",
      "age": 31,
      "tags": ["婚房", "双方父母参与", "预算摇摆", "新房偏好"],
      "phone": "15821067439",
      "location": {"raw": "上海市闵行区七宝", "city": "上海市", "district": "闵行区", "subarea": "七宝"},
      "records": [
        {
          "type": "text",
          "content": "客户31岁，准备结婚买婚房。双方父母都会参与决策，预算从500万到650万之间摇摆。客户本人偏好新房或次新房，未婚妻更关注生活配套和离地铁距离。意向区域包括七宝、莘庄、九亭。"
        },
        {
          "type": "text",
          "content": "客户父母担心期房交付风险，更倾向成熟二手房；女方父母希望小区环境好一些。客户夹在中间，希望顾问帮他把新房、次新和成熟二手房的利弊讲清楚。"
        },
        {
          "type": "text",
          "content": "最近沟通中客户说本周末双方父母都有时间，可以安排一次集中看房。客户希望路线不要太散，最好控制在两个板块内，每套房都能说明为什么值得看。"
        }
      ]
    },
    {
      "name": "何宇辰",
      "gender": "男",
      "age": 37,
      "tags": ["改善四居", "品质小区", "停车关注", "不急成交"],
      "phone": "18801957263",
      "location": {"raw": "上海市杨浦区五角场", "city": "上海市", "district": "杨浦区", "subarea": "五角场"},
      "records": [
        {
          "type": "text",
          "content": "客户37岁，家庭已有一套两居，想改善到四居或大三居。预算约1000万到1300万，关注杨浦五角场、新江湾城、虹口部分板块。客户不急成交，要求小区品质、停车、物业和户型都比较均衡。"
        },
        {
          "type": "text",
          "content": "客户看房很理性，会逐项记录优缺点。上次带看的房源中，他认为一套户型很好但停车困难，另一套小区品质不错但离地铁稍远。客户希望顾问不要频繁推不匹配房源。"
        },
        {
          "type": "text",
          "content": "回访时客户表示可以继续看，但希望每次最多安排2到3套，并提前说明推荐理由。客户更愿意为真正稀缺和均衡的房源付溢价，不接受明显短板。"
        }
      ]
    }
  ]
}


DATASETS = {
    "insurance": TEST_DATA,
    "real_estate": REAL_ESTATE_TEST_DATA,
    "mixed": {
        "customers": TEST_DATA["customers"][:5] + REAL_ESTATE_TEST_DATA["customers"][:5],
    },
}


async def clear_data(session):
    """清空现有数据"""
    print("🗑️  清空现有客户和记录...")
    
    # 删除所有记录
    await session.execute(delete(Record))
    
    # 删除所有客户
    await session.execute(delete(Customer))
    
    await session.commit()
    print("✅ 数据已清空")


async def update_user_industry(session, user_id: str, industry: str):
    """如果目标用户存在，同步设置行业，便于导入后直接体验对应 Prompt。"""
    user = await session.get(User, user_id)
    if not user:
        print(f"ℹ️  未找到用户 {user_id}，跳过用户行业设置")
        return
    user.industry_key = industry if industry in {"generic", "insurance", "real_estate"} else "generic"
    user.industry_selected = True
    print(f"🏷️  用户行业已设置为: {user.industry_key}")


async def import_data(session, dataset: dict, user_id: str, industry: str):
    """导入测试数据"""
    now = datetime.now()

    await update_user_industry(session, user_id, industry)

    for customer_data in dataset["customers"]:
        # 年龄写入正式字段，同时保留年龄标签，方便旧查询逻辑和前端展示兼容。
        tags = customer_data.get("tags", [])
        if customer_data.get("age"):
            tags = [f"{customer_data['age']}岁"] + tags
        location = customer_data.get("location") or {}
        
        customer = Customer(
            id=str(uuid4()),
            name=customer_data["name"],
            phone=customer_data.get("phone"),
            gender=customer_data.get("gender"),
            age=customer_data.get("age"),
            location_raw=location.get("raw"),
            location_city=location.get("city"),
            location_district=location.get("district"),
            location_subarea=location.get("subarea"),
            tags=tags,
            user_id=user_id,
            summary_text=None,
            summary_status="stale",
            created_at=now,
            updated_at=now,
        )
        
        session.add(customer)
        await session.flush()  # 获取 customer.id
        
        print(f"👤 创建客户: {customer.name} ({customer.id[:8]})")
        
        # 创建记录（倒序时间，最新的在前）
        base_date = now - timedelta(days=len(customer_data["records"]) * 7)
        
        for i, record_data in enumerate(customer_data["records"]):
            record = Record(
                id=str(uuid4()),
                customer_id=customer.id,
                content=record_data["content"],
                type=record_data.get("type", "text"),
                location_raw=location.get("raw"),
                location_city=location.get("city"),
                location_district=location.get("district"),
                location_subarea=location.get("subarea"),
                created_at=base_date + timedelta(days=i * 7),
                updated_at=base_date + timedelta(days=i * 7),
            )
            session.add(record)
        
        print(f"   📝 添加 {len(customer_data['records'])} 条记录")
    
    await session.commit()
    print("\n✅ 所有数据导入完成")


def parse_args():
    parser = argparse.ArgumentParser(description="导入测试客户数据")
    parser.add_argument(
        "--industry",
        choices=sorted(DATASETS.keys()),
        default="insurance",
        help="导入哪一组样例客户",
    )
    parser.add_argument(
        "--user-id",
        default="default-user",
        help="客户归属用户 ID，默认 default-user",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="确认清空现有客户和记录并执行导入",
    )
    return parser.parse_args()


async def main():
    args = parse_args()
    dataset = DATASETS[args.industry]

    print("═══════════════════════════════")
    print("  导入测试客户数据")
    print("═══════════════════════════════\n")
    print(f"行业数据集: {args.industry}")
    print(f"用户 ID: {args.user_id}\n")

    if not args.yes:
        print("⚠️  该脚本会清空现有客户和记录。")
        print("如确认执行，请追加 --yes，例如：")
        print(f"  ./.venv/bin/python import_customers.py --industry {args.industry} --user-id {args.user_id} --yes")
        return
    
    async with async_session_factory() as session:
        # 1. 清空数据
        await clear_data(session)
        
        # 2. 导入新数据
        await import_data(
            session,
            dataset=dataset,
            user_id=args.user_id,
            industry=args.industry,
        )
        
        # 3. 验证
        result = await session.execute(select(Customer))
        customers = result.scalars().all()
        
        result = await session.execute(select(Record))
        records = result.scalars().all()
        
        print(f"\n📊 导入结果:")
        print(f"   客户数: {len(customers)}")
        print(f"   记录数: {len(records)}")


if __name__ == "__main__":
    asyncio.run(main())
