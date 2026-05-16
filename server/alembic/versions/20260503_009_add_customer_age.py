"""add customer age

Revision ID: 20260503_009
Revises: 20260416_008
Create Date: 2026-05-03 21:30:00.000000
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260503_009"
down_revision: Union[str, None] = "20260416_008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("customers", sa.Column("age", sa.Integer(), nullable=True, comment="客户年龄"))


def downgrade() -> None:
    op.drop_column("customers", "age")
