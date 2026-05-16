"""add user industry preference

Revision ID: 20260506_011
Revises: 20260504_010
Create Date: 2026-05-06 12:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260506_011"
down_revision: Union[str, None] = "20260504_010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "industry_key",
            sa.String(40),
            nullable=False,
            server_default="generic",
            comment="当前行业设置",
        ),
    )


def downgrade() -> None:
    op.drop_column("users", "industry_key")
