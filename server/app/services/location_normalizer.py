"""
地点线索归一化服务

优先用高德 API，失败后用本地规则库（SIMPLE_RULES + UNRESOLVED_LOCATIONS）。
规则库按城区分类，可随业务增长不断补充。
"""

from __future__ import annotations

import logging
import re

import httpx

from app.core.config import settings


logger = logging.getLogger(__name__)


class LocationNormalizer:
    """把原始地点线索归一化成 城市 / 城区 / 片区。"""

    MUNICIPALITIES = {"北京市", "上海市", "天津市", "重庆市"}

    # 精确匹配的建筑物/小区/地标 → (城市, 城区, 片区)
    SIMPLE_RULES = {
        # ---- 大厦/园区 ----
        "朗琴园":     ("北京市", "西城区", "广安门外街道"),
        "凯晨大厦":   ("北京市", "西城区", "金融街街道"),
        "钻石大厦":   ("北京市", "海淀区", "西二旗"),
        "腾讯大厦":   ("北京市", "海淀区", "马连洼街道"),
        "国贸三期":   ("北京市", "朝阳区", "国贸"),
        "望京SOHO":   ("北京市", "朝阳区", "望京"),
        "鸟巢":       ("北京市", "朝阳区", "亚运村"),
        "万象城":     ("北京市", "朝阳区", None),
        "新荟城":     ("北京市", "朝阳区", "望京"),
        "元通大厦":   ("北京市", "海淀区", "万柳"),
        "丰台科技园": ("北京市", "丰台区", "丰台科技园"),
        "丽泽商务区": ("北京市", "丰台区", "丽泽"),
        "石景山万达": ("北京市", "石景山区", "石景山万达"),
        "金茂府":     ("北京市", "大兴区", "亦庄"),
        "高尔夫俱乐部": ("北京市", "大兴区", "黄村"),
        # ---- 片区/街道 ----
        "后沙峪":     ("北京市", "顺义区", "后沙峪"),
        "长阳":       ("北京市", "房山区", "长阳"),
        "良乡":       ("北京市", "房山区", "良乡"),
        "门头沟":     ("北京市", "门头沟区", None),
        "西山墅":     ("北京市", "门头沟区", "西山墅"),
        "黄村":       ("北京市", "大兴区", "黄村"),
        "枫丹壹号":   ("北京市", "大兴区", "亦庄"),
        # ---- 城区简称/全称 ----
        "海淀":       ("北京市", "海淀区", None),
        "海淀区":     ("北京市", "海淀区", None),
        "西城":       ("北京市", "西城区", None),
        "西城区":     ("北京市", "西城区", None),
        "朝阳":       ("北京市", "朝阳区", None),
        "朝阳区":     ("北京市", "朝阳区", None),
        "东城":       ("北京市", "东城区", None),
        "东城区":     ("北京市", "东城区", None),
        "丰台":       ("北京市", "丰台区", None),
        "丰台区":     ("北京市", "丰台区", None),
        "石景山":     ("北京市", "石景山区", None),
        "石景山区":   ("北京市", "石景山区", None),
        "通州":       ("北京市", "通州区", None),
        "通州区":     ("北京市", "通州区", None),
        "昌平":       ("北京市", "昌平区", None),
        "昌平区":     ("北京市", "昌平区", None),
        "大兴":       ("北京市", "大兴区", None),
        "大兴区":     ("北京市", "大兴区", None),
        "顺义":       ("北京市", "顺义区", None),
        "顺义区":     ("北京市", "顺义区", None),
        "房山":       ("北京市", "房山区", None),
        "房山区":     ("北京市", "房山区", None),
        "门头沟区":   ("北京市", "门头沟区", None),
        "密云":       ("北京市", "密云区", None),
        "怀柔":       ("北京市", "怀柔区", None),
        "延庆":       ("北京市", "延庆区", None),
        "平谷":       ("北京市", "平谷区", None),
        "亦庄":       ("北京市", "大兴区", "亦庄"),
        # ---- 具体地点 ----
        "达官营":     ("北京市", "西城区", "达官营"),
        "广安门":     ("北京市", "西城区", "广安门"),
        "西二旗":     ("北京市", "海淀区", "西二旗"),
        "上地":       ("北京市", "海淀区", "上地"),
        "中关村":     ("北京市", "海淀区", "中关村"),
        "万柳":       ("北京市", "海淀区", "万柳"),
        "五路居":     ("北京市", "海淀区", "五路居"),
        "海淀五路居": ("北京市", "海淀区", "五路居"),
        "西山一号院": ("北京市", "海淀区", "西山"),
        "金融街":     ("北京市", "西城区", "金融街"),
        "复兴门":     ("北京市", "西城区", "复兴门"),
        "国贸":       ("北京市", "朝阳区", "国贸"),
        "朝阳公园":   ("北京市", "朝阳区", "朝阳公园"),
        "三里屯":     ("北京市", "朝阳区", "三里屯"),
        "望京":       ("北京市", "朝阳区", "望京"),
        "亚运村":     ("北京市", "朝阳区", "亚运村"),
        "东直门":     ("北京市", "朝阳区", "东直门"),
        "三元桥":     ("北京市", "朝阳区", "三元桥"),
        "回龙观":     ("北京市", "昌平区", "回龙观"),
        "天通苑":     ("北京市", "昌平区", "天通苑"),
        "立水桥":     ("北京市", "朝阳区", "立水桥"),
        "北苑":       ("北京市", "朝阳区", "北苑"),
        "通州北苑":   ("北京市", "通州区", "北苑"),
        "梨园":       ("北京市", "通州区", "梨园"),
    }

    # 无法通过高德识别时的人工维护规则
    # 随业务增长，在下方按城区分类添加新条目即可
    UNRESOLVED_LOCATIONS = {
        # ---- 海淀区 ----
        "骚子营":     ("北京市", "海淀区", None),
        "清河":       ("北京市", "海淀区", "清河"),
        "四季青":     ("北京市", "海淀区", "四季青"),
        "中关村软件园": ("北京市", "海淀区", "中关村"),
        "学院路":     ("北京市", "海淀区", "学院路"),
        "魏公村":     ("北京市", "海淀区", "魏公村"),
        # ---- 朝阳区 ----
        "团结湖":     ("北京市", "朝阳区", "团结湖"),
        "劲松":       ("北京市", "朝阳区", "劲松"),
        "双井":       ("北京市", "朝阳区", "双井"),
        "建外":       ("北京市", "朝阳区", "建外"),
        "朝外":       ("北京市", "朝阳区", "朝外"),
        "呼家楼":     ("北京市", "朝阳区", "呼家楼"),
        "潘家园":     ("北京市", "朝阳区", "潘家园"),
        "垡头":       ("北京市", "朝阳区", "垡头"),
        "东坝":       ("北京市", "朝阳区", "东坝"),
        "南磨房":     ("北京市", "朝阳区", "南磨房"),
        "小红门":     ("北京市", "朝阳区", "小红门"),
        "十八里店":   ("北京市", "朝阳区", "十八里店"),
        "豆各庄":     ("北京市", "朝阳区", "豆各庄"),
        # ---- 西城区 ----
        "白纸坊":     ("北京市", "西城区", "白纸坊"),
        "椿树":       ("北京市", "西城区", "椿树"),
        "大栅栏":     ("北京市", "西城区", "大栅栏"),
        "天桥":       ("北京市", "西城区", "天桥"),
        "展览路":     ("北京市", "西城区", "展览路"),
        "月坛":       ("北京市", "西城区", "月坛"),
        "广内":       ("北京市", "西城区", "广安门内"),
        "广外":       ("北京市", "西城区", "广安门外"),
        # ---- 东城区 ----
        "东四":       ("北京市", "东城区", "东四"),
        "朝阳门":     ("北京市", "东城区", "朝阳门"),
        "建国门":     ("北京市", "东城区", "建国门"),
        "安定门":     ("北京市", "东城区", "安定门"),
        "和平里":     ("北京市", "东城区", "和平里"),
        # ---- 丰台区 ----
        "右安门":     ("北京市", "丰台区", "右安门"),
        "太平桥":     ("北京市", "丰台区", "太平桥"),
        "西罗园":     ("北京市", "丰台区", "西罗园"),
        "大红门":     ("北京市", "丰台区", "大红门"),
        "南苑":       ("北京市", "丰台区", "南苑"),
        "东高地":     ("北京市", "丰台区", "东高地"),
        "东铁营":     ("北京市", "丰台区", "东铁营"),
        "方庄":       ("北京市", "丰台区", "方庄"),
        # ---- 石景山区 ----
        "八角":       ("北京市", "石景山区", "八角"),
        "古城":       ("北京市", "石景山区", "古城"),
        "老山":       ("北京市", "石景山区", "老山"),
        "八宝山":     ("北京市", "石景山区", "八宝山"),
        "鲁谷":       ("北京市", "石景山区", "鲁谷"),
        # ---- 通州区 ----
        "新华":       ("北京市", "通州区", "新华"),
        "中仓":       ("北京市", "通州区", "中仓"),
        "玉桥":       ("北京市", "通州区", "玉桥"),
        "宋庄":       ("北京市", "通州区", "宋庄"),
        "张家湾":     ("北京市", "通州区", "张家湾"),
        "潞城":       ("北京市", "通州区", "潞城"),
        # ---- 昌平区 ----
        "南邵":       ("北京市", "昌平区", "南邵"),
        "崔村":       ("北京市", "昌平区", "崔村"),
        "百善":       ("北京市", "昌平区", "百善"),
        "小汤山":     ("北京市", "昌平区", "小汤山"),
        "北七家":     ("北京市", "昌平区", "北七家"),
        "阳坊":       ("北京市", "昌平区", "阳坊"),
        "流村":       ("北京市", "昌平区", "流村"),
        # ---- 大兴区 ----
        "瀛海":       ("北京市", "大兴区", "瀛海"),
        "青云店":     ("北京市", "大兴区", "青云店"),
        "长子营":     ("北京市", "大兴区", "长子营"),
        "采育":       ("北京市", "大兴区", "采育"),
        "安定":       ("北京市", "大兴区", "安定"),
        "礼贤":       ("北京市", "大兴区", "礼贤"),
        "榆垡":       ("北京市", "大兴区", "榆垡"),
        # ---- 顺义区 ----
        "仁和":       ("北京市", "顺义区", "仁和"),
        "马坡":       ("北京市", "顺义区", "马坡"),
        "牛栏山":     ("北京市", "顺义区", "牛栏山"),
        "高丽营":     ("北京市", "顺义区", "高丽营"),
        "李桥":       ("北京市", "顺义区", "李桥"),
        "李遂":       ("北京市", "顺义区", "李遂"),
        "南法信":     ("北京市", "顺义区", "南法信"),
        # ---- 房山区 ----
        "窦店":       ("北京市", "房山区", "窦店"),
        "琉璃河":     ("北京市", "房山区", "琉璃河"),
        "周口店":     ("北京市", "房山区", "周口店"),
        "长沟":       ("北京市", "房山区", "长沟"),
        "大石窝":     ("北京市", "房山区", "大石窝"),
        "张坊":       ("北京市", "房山区", "张坊"),
        "十渡":       ("北京市", "房山区", "十渡"),
        # ---- 门头沟区 ----
        "潭柘寺":     ("北京市", "门头沟区", "潭柘寺"),
        "永定":       ("北京市", "门头沟区", "永定"),
        "龙泉":       ("北京市", "门头沟区", "龙泉"),
        "军庄":       ("北京市", "门头沟区", "军庄"),
        "斋堂":       ("北京市", "门头沟区", "斋堂"),
        "清水":       ("北京市", "门头沟区", "清水"),
    }

    async def normalize(self, location_raw: str | None) -> dict[str, str | None]:
        """优先高德，失败后用本地规则库。"""
        text = (location_raw or "").strip()
        if not text:
            return self._empty_result()

        # 1. 先查本地规则库（SIMPLE_RULES → UNRESOLVED_LOCATIONS）
        result = self._normalize_with_local_rules(text)
        if result["location_city"]:
            return result

        # 2. 高德 API
        gaode_result = await self._normalize_with_gaode(text)
        if gaode_result:
            return gaode_result

        # 3. 高德也失败，返回保守结果
        return self._empty_result()

    def _normalize_with_local_rules(self, text: str) -> dict[str, str | None]:
        """先查 SIMPLE_RULES（精确匹配优先），再查 UNRESOLVED_LOCATIONS。"""
        # 优先：精确 key 命中
        if text in self.SIMPLE_RULES:
            city, district, subarea = self.SIMPLE_RULES[text]
            return {"location_raw": text, "location_city": city, "location_district": district, "location_subarea": subarea}

        # 其次：substring 匹配（短词优先）
        # 按 key 长度从短到长排，避免"西二旗"优先于"二旗"匹配
        all_rules = {**self.UNRESOLVED_LOCATIONS}
        for keyword in sorted(all_rules.keys(), key=len):
            if keyword in text:
                city, district, subarea = all_rules[keyword]
                return {"location_raw": text, "location_city": city, "location_district": district, "location_subarea": subarea}

        return self._empty_result()

    async def _normalize_with_gaode(self, text: str) -> dict[str, str | None] | None:
        """调用高德地理编码接口。"""
        if not settings.gaode_api_key:
            return None

        primary = await self._fetch_gaode_geocode(text)
        if not primary:
            return None

        result = self._to_normalized_result(text, primary)
        if not result:
            return None

        if self._should_retry_with_beijing(text, result):
            beijing_geo = await self._fetch_gaode_geocode(text, city="北京市")
            beijing_result = self._to_normalized_result(text, beijing_geo) if beijing_geo else None
            if beijing_result and beijing_result["location_city"] == "北京市":
                return beijing_result

        return result

    async def _fetch_gaode_geocode(self, text: str, *, city: str | None = None) -> dict[str, object] | None:
        """请求高德 geocode，并返回第一条 geocode。"""
        params = {"key": settings.gaode_api_key, "address": text}
        if city:
            params["city"] = city

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(settings.gaode_geocode_base_url, params=params)
                response.raise_for_status()
                data = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            logger.warning("高德地点归一化失败: %s", exc)
            return None

        if data.get("status") != "1":
            return None

        geocodes = data.get("geocodes") or []
        if not geocodes:
            return None
        return geocodes[0]

    def _to_normalized_result(self, text: str, geo: dict[str, object]) -> dict[str, str | None] | None:
        """把高德 geocode 转成项目内部结构。"""
        city = self._clean_field(geo.get("city")) or self._clean_field(geo.get("province"))
        district = self._clean_field(geo.get("district"))
        subarea = self._clean_field(geo.get("township"))

        if not any([city, district, subarea]):
            return None

        return {
            "location_raw": text,
            "location_city": city,
            "location_district": district,
            "location_subarea": subarea,
        }

    def _should_retry_with_beijing(self, text: str, result: dict[str, str | None]) -> bool:
        """对模糊 POI 做一次北京优先纠偏。"""
        if self._contains_explicit_city(text):
            return False
        if result.get("location_city") == "北京市":
            return False
        return any(kw in text for kw in ("大厦", "广场", "中心", "园", "苑", "城", "馆", "厦"))

    @classmethod
    def _contains_explicit_city(cls, text: str) -> bool:
        if any(city in text for city in cls.MUNICIPALITIES):
            return True
        return bool(re.search(r"[\u4e00-\u9fff]{2,8}(市|区|县)", text))

    @staticmethod
    def _clean_field(value: object) -> str | None:
        if value is None:
            return None
        if isinstance(value, list):
            value = next((item for item in value if item), None)
        text = str(value).strip()
        if not text or text in {"[]", "None", "null"}:
            return None
        return text

    @staticmethod
    def _empty_result() -> dict[str, str | None]:
        return {
            "location_raw": None,
            "location_city": None,
            "location_district": None,
            "location_subarea": None,
        }
