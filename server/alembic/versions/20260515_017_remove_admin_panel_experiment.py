"""remove admin panel experiment

Revision ID: 20260515_017
Revises: 20260514_016
Create Date: 2026-05-15 14:30:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260515_017"
down_revision: Union[str, None] = "20260514_016"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.drop_table("industry_prompts")
    op.drop_table("industries")
    op.drop_table("configs")
    op.drop_column("users", "disabled")
    op.drop_column("users", "is_admin")


def downgrade() -> None:
    op.add_column(
        "users",
        sa.Column("is_admin", sa.Boolean(), nullable=False, server_default="false", comment="是否管理员"),
    )
    op.add_column(
        "users",
        sa.Column("disabled", sa.Boolean(), nullable=False, server_default="false", comment="是否已禁用"),
    )

    op.create_table(
        "configs",
        sa.Column("id", sa.String(36), primary_key=True, comment="主键 UUID"),
        sa.Column("key", sa.String(100), unique=True, nullable=False, comment="配置键"),
        sa.Column("value", sa.Text(), nullable=False, comment="配置值"),
        sa.Column("label", sa.String(200), nullable=True, comment="配置标签"),
        sa.Column("description", sa.Text(), nullable=True, comment="配置说明"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False, comment="创建时间"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False, comment="更新时间"),
    )

    op.create_table(
        "industries",
        sa.Column("id", sa.String(36), primary_key=True, comment="主键 UUID"),
        sa.Column("key", sa.String(40), unique=True, nullable=False, comment="行业标识"),
        sa.Column("label", sa.String(100), nullable=False, comment="中文标签"),
        sa.Column("role_name", sa.String(100), nullable=False, comment="角色名称"),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default="true", comment="是否启用"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False, comment="创建时间"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False, comment="更新时间"),
    )

    op.create_table(
        "industry_prompts",
        sa.Column("id", sa.String(36), primary_key=True, comment="主键 UUID"),
        sa.Column("industry_key", sa.String(40), nullable=False, comment="行业标识"),
        sa.Column("prompt_field", sa.String(100), nullable=False, comment="提示词字段名"),
        sa.Column("value", sa.Text(), nullable=False, comment="提示词内容"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False, comment="创建时间"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False, comment="更新时间"),
    )
    op.create_unique_constraint("uq_industry_prompts_key_field", "industry_prompts", ["industry_key", "prompt_field"])
    op.create_foreign_key("fk_industry_prompts_industry", "industry_prompts", "industries", ["industry_key"], ["key"], ondelete="CASCADE")
