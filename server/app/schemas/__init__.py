# Schemas module

# 客户模块 Schema
from app.schemas.customer import (
    CustomerCreate,
    CustomerIdResponse,
    CustomerListItem,
    CustomerDetail,
    CustomerListResponse,
)

# 沟通记录模块 Schema
from app.schemas.record import (
    RecordCreate,
    RecordIdResponse,
    RecordItem,
    RecordListResponse,
)

# 音频转写模块 Schema
from app.schemas.transcription import (
    TranscriptionConfirm,
    TranscriptionIdResponse,
    TranscriptionUploadResponse,
    TranscriptionItem,
    TranscriptionDetail,
    TranscriptionListResponse,
    TranscriptionConfirmResponse,
)
