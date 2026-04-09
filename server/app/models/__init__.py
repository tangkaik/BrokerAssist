# Models module

# 模型导入
from app.models.customer import Customer
from app.models.record import Record
from app.models.transcription import Transcription

# 建立关系（避免循环导入）
from sqlalchemy.orm import relationship

# Customer 关系
Customer.records = relationship("Record", back_populates="customer", cascade="all, delete-orphan")
Customer.transcriptions = relationship("Transcription", back_populates="customer", cascade="all, delete-orphan")
