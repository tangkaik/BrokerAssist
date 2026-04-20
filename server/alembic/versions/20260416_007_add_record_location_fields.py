"""
为 records 表新增地点线索字段
"""

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "20260416_007"
down_revision = "7e03908c876c"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("records", sa.Column("location_raw", sa.Text(), nullable=True, comment="原始地点线索"))
    op.add_column("records", sa.Column("location_city", sa.String(length=50), nullable=True, comment="归一化城市"))
    op.add_column("records", sa.Column("location_district", sa.String(length=50), nullable=True, comment="归一化城区"))
    op.add_column("records", sa.Column("location_subarea", sa.String(length=100), nullable=True, comment="归一化街道/片区"))


def downgrade() -> None:
    op.drop_column("records", "location_subarea")
    op.drop_column("records", "location_district")
    op.drop_column("records", "location_city")
    op.drop_column("records", "location_raw")
