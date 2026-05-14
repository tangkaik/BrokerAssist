"""add user disabled column

Revision ID: 20260514_016
Revises: 20260514_015
Create Date: 2026-05-14 10:30:00.000000
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "20260514_016"
down_revision: Union[str, None] = "20260514_015"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("disabled", sa.Boolean(), nullable=False, server_default="false", comment="是否已禁用"),
    )

def downgrade() -> None:
    op.drop_column("users", "disabled")
