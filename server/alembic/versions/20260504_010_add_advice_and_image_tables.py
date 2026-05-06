"""add customer advice columns, record_images and record_image_analyses tables

Revision ID: 20260504_010
Revises: 20260503_009
Create Date: 2026-05-04 23:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260504_010"
down_revision: Union[str, None] = "20260503_009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. customers 表新增 advice 字段
    op.add_column("customers", sa.Column("advice_text", sa.Text(), nullable=True, comment="AI 生成的跟进建议"))
    op.add_column("customers", sa.Column("advice_updated_at", sa.DateTime(timezone=True), nullable=True, comment="建议更新时间"))

    # 2. 创建 record_images 表
    op.create_table(
        "record_images",
        sa.Column("id", sa.String(36), primary_key=True, comment="图片ID (UUID)"),
        sa.Column("record_id", sa.String(36), sa.ForeignKey("records.id", ondelete="CASCADE"), nullable=False, index=True, comment="所属记录ID"),
        sa.Column("image_name", sa.String(255), nullable=False, comment="原始文件名"),
        sa.Column("image_path", sa.String(500), nullable=False, comment="存储路径"),
        sa.Column("url", sa.String(500), nullable=False, comment="访问URL"),
        sa.Column("content_type", sa.String(100), nullable=False, server_default="'image/jpeg'", comment="MIME 类型"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now(), comment="创建时间"),
    )

    # 3. 创建 record_image_analyses 表
    op.create_table(
        "record_image_analyses",
        sa.Column("id", sa.String(36), primary_key=True, comment="分析ID (UUID)"),
        sa.Column("record_id", sa.String(36), sa.ForeignKey("records.id", ondelete="CASCADE"), nullable=False, index=True, comment="所属记录ID"),
        sa.Column("image_url", sa.String(500), nullable=False, comment="图片URL"),
        sa.Column("answer", sa.Text(), nullable=False, comment="AI 分析结果"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now(), comment="创建时间"),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now(), comment="更新时间"),
    )


def downgrade() -> None:
    op.drop_table("record_image_analyses")
    op.drop_table("record_images")
    op.drop_column("customers", "advice_updated_at")
    op.drop_column("customers", "advice_text")
