"""add customer avatar

Revision ID: 20260514_014
Revises: 20260514_013
Create Date: 2026-05-14 05:25:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260514_014"
down_revision: Union[str, None] = "20260514_013"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "customers",
        sa.Column("avatar", sa.String(length=255), nullable=True, comment="客户头像 URL"),
    )


def downgrade() -> None:
    op.drop_column("customers", "avatar")
