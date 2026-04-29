"""
上传文件校验

统一处理图片上传的数量、类型与体积限制，避免路由层散落重复逻辑。
"""
from __future__ import annotations

from pathlib import Path

from fastapi import UploadFile

from app.core.config import settings


class UploadValidationError(ValueError):
    """上传文件校验失败。"""


def _effective_allowed_image_types() -> set[str]:
    return settings.allowed_image_types | settings.supported_image_types


def _is_allowed_image_type(file: UploadFile) -> bool:
    allowed_types = _effective_allowed_image_types()
    content_type = (file.content_type or "").lower().strip()
    if content_type in allowed_types:
        return True

    extension = Path(file.filename or "").suffix.lower()
    extension_map = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
        ".heic": "image/heic",
        ".heif": "image/heif",
    }
    inferred_type = extension_map.get(extension)
    if inferred_type and inferred_type in allowed_types:
        return True

    if content_type in {"image/jpg", "image/pjpeg"} and "image/jpeg" in allowed_types:
        return True

    return False


def _infer_image_type_from_bytes(raw_bytes: bytes) -> str | None:
    if raw_bytes.startswith(b"\xff\xd8\xff"):
      return "image/jpeg"
    if raw_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
      return "image/png"
    if raw_bytes.startswith(b"RIFF") and raw_bytes[8:12] == b"WEBP":
      return "image/webp"
    if len(raw_bytes) > 12 and raw_bytes[4:8] == b"ftyp":
      brand = raw_bytes[8:12]
      if brand in {b"heic", b"heix", b"hevc", b"hevx"}:
        return "image/heic"
      if brand in {b"mif1", b"msf1", b"heif"}:
        return "image/heif"
    return None


async def read_validated_images(files: list[UploadFile]) -> list[tuple[str, bytes, str | None]]:
    """读取并校验图片列表。"""
    if len(files) > settings.max_upload_image_count:
        raise UploadValidationError(
            f"最多只能上传 {settings.max_upload_image_count} 张图片"
        )

    payloads: list[tuple[str, bytes, str | None]] = []
    allowed_types = _effective_allowed_image_types()
    for image in files:
        raw_bytes = await image.read()
        if not raw_bytes:
            raise UploadValidationError(f"{image.filename or '文件'} 为空文件")
        if len(raw_bytes) > settings.max_upload_image_bytes:
            max_mb = settings.max_upload_image_bytes / 1024 / 1024
            raise UploadValidationError(
                f"{image.filename or '文件'} 超过大小限制（{max_mb:.0f}MB）"
            )

        normalized_content_type = (image.content_type or "").lower().strip() or None
        if not _is_allowed_image_type(image):
            inferred_type = _infer_image_type_from_bytes(raw_bytes)
            if inferred_type and inferred_type in allowed_types:
                normalized_content_type = inferred_type
            else:
                raise UploadValidationError(
                    f"{image.filename or '文件'} 不是支持的图片格式"
                )

        payloads.append(
            (
                image.filename or "image.jpg",
                raw_bytes,
                normalized_content_type or "image/jpeg",
            )
        )
    return payloads
