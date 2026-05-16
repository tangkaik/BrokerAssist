import unittest

from app.core.admin import ADMIN_ACCOUNT, is_administrator_account
from app.core.industry_profiles import (
    AppDisplayConfig,
    IndustryProfile,
    ReminderRuleConfig as CoreReminderRuleConfig,
)
from app.core.prompts import advice, customer_summary_system
from app.schemas.admin import (
    IndustryAssistantSuggestionGroup,
    IndustryPromptConfig,
    IndustryUpsertRequest,
    ReminderRuleConfig,
)
from app.schemas.auth import RegisterRequest
from app.services.auth_service import AuthService


class _FakeSession:
    async def scalar(self, *_args, **_kwargs):
        return None


class AdminMvpTests(unittest.IsolatedAsyncioTestCase):
    async def test_register_blocks_reserved_administrator_account_case_insensitive(self):
        service = AuthService(_FakeSession())
        data = RegisterRequest(
            account="Administrator",
            password="password123",
            name="Bad Admin",
        )

        with self.assertRaisesRegex(ValueError, "保留账号"):
            await service.register(data)

    def test_administrator_account_check_is_centralized_and_case_insensitive(self):
        self.assertEqual(ADMIN_ACCOUNT, "administrator")
        self.assertTrue(is_administrator_account("Administrator"))
        self.assertFalse(is_administrator_account("admin"))

    def test_industry_prompt_config_cleans_empty_lines(self):
        config = IndustryPromptConfig(
            summary_focus=[" 客户需求 ", "", " 预算 "],
            missing_info=["决策人", " "],
            advice_focus="  关注下一步沟通  ",
            forbidden_guidance=["不要编造", ""],
            query_examples=["高意向", "  "],
            assistant_suggestions=[
                IndustryAssistantSuggestionGroup(
                    key=" query ",
                    title=" 查客户 ",
                    icon=" manage_search ",
                    variants=[[" 高意向客户 ", ""], []],
                )
            ],
            reminder_rules=ReminderRuleConfig(
                key_date_keywords=[" 保单 ", "", " 缴费 "],
                key_date_title_template="  {customer}关键日期提醒  ",
            ),
        )

        self.assertEqual(config.summary_focus, ["客户需求", "预算"])
        self.assertEqual(config.missing_info, ["决策人"])
        self.assertEqual(config.advice_focus, "关注下一步沟通")
        self.assertEqual(config.forbidden_guidance, ["不要编造"])
        self.assertEqual(config.query_examples, ["高意向"])
        self.assertEqual(config.assistant_suggestions[0].key, "query")
        self.assertEqual(config.assistant_suggestions[0].variants, [["高意向客户"]])
        self.assertEqual(config.reminder_rules.key_date_keywords, ["保单", "缴费"])
        self.assertEqual(config.reminder_rules.key_date_title_template, "{customer}关键日期提醒")

    def test_industry_key_is_normalized_for_upsert(self):
        data = IndustryUpsertRequest(
            key="  Car_Sales  ",
            label="汽车销售",
            role_name="汽车销售顾问助手",
            prompt_config=IndustryPromptConfig(),
        )

        self.assertEqual(data.key, "car_sales")

    def test_prompt_uses_runtime_industry_profile(self):
        profile = IndustryProfile(
            key="car_sales",
            label="汽车销售",
            role_name="汽车销售顾问助手",
            summary_focus=("购车预算",),
            missing_info=("车型偏好",),
            advice_focus="围绕试驾、预算和成交节奏给出建议。",
            forbidden_guidance=("不要承诺车价",),
            query_examples=("试驾客户",),
            assistant_suggestions=(),
            app_display=AppDisplayConfig(
                workspace_label="汽车销售",
                icon_key="car",
                quick_tip="记录试驾和预算信息",
            ),
            reminder_rules=CoreReminderRuleConfig(),
        )

        system_prompt = customer_summary_system(industry_profile=profile)
        advice_prompt = advice(
            customer_summary_text="客户关注新能源车。",
            recent_records_text="客户想试驾。",
            industry_profile=profile,
        )

        self.assertIn("汽车销售顾问助手", system_prompt)
        self.assertIn("围绕试驾、预算和成交节奏给出建议。", advice_prompt)
        self.assertIn("不要承诺车价", advice_prompt)


if __name__ == "__main__":
    unittest.main()
