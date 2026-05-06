"""add user industry selected lock

Revision ID: 20260506_012
Revises: 20260506_011
Create Date: 2026-05-06 14:00:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260506_012"
down_revision: Union[str, None] = "20260506_011"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "industry_selected",
            sa.Boolean(),
            nullable=False,
            server_default=sa.text("false"),
            comment="是否已完成首次行业选择",
        ),
    )
    op.execute("UPDATE users SET industry_selected = true WHERE industry_key <> 'generic'")


def downgrade() -> None:
    op.drop_column("users", "industry_selected")
