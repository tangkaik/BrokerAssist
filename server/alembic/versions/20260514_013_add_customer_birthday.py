"""add customer birthday

Revision ID: 20260514_013
Revises: 20260506_012
Create Date: 2026-05-14 02:40:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260514_013"
down_revision: Union[str, None] = "20260506_012"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "customers",
        sa.Column("birthday", sa.Date(), nullable=True, comment="客户生日"),
    )


def downgrade() -> None:
    op.drop_column("customers", "birthday")
