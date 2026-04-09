"""
统一 API 响应格式

所有 API 返回必须遵循以下结构：

成功响应：
{
    "success": true,
    "data": {},
    "error": null
}

失败响应：
{
    "success": false,
    "data": null,
    "error": {
        "code": "ERROR_CODE",
        "message": "错误说明"
    }
}
"""
from typing import Any, Optional

from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
from pydantic import BaseModel


class ErrorDetail(BaseModel):
    """错误详情结构"""
    code: str
    message: str


class ApiResponse(BaseModel):
    """统一 API 响应结构"""
    success: bool
    data: Optional[Any] = None
    error: Optional[ErrorDetail] = None


def success_response(
    data: Any = None,
    status_code: int = 200,
) -> JSONResponse:
    """
    构建成功响应
    
    Args:
        data: 响应数据，可以是任意类型
        status_code: HTTP 状态码，默认 200
        
    Returns:
        JSONResponse 对象
        
    Examples:
        >>> return success_response({"id": "123", "name": "张三"})
        >>> return success_response([{"id": "1"}, {"id": "2"}])
        >>> return success_response({"message": "操作成功"}, status_code=201)
    """
    response = ApiResponse(
        success=True,
        data=data,
        error=None,
    )
    # 使用 jsonable_encoder 处理 datetime、UUID 等不可序列化类型
    content = jsonable_encoder(response.model_dump(exclude_none=True))
    return JSONResponse(
        status_code=status_code,
        content=content,
    )


def error_response(
    code: str,
    message: str,
    status_code: int = 400,
) -> JSONResponse:
    """
    构建失败响应
    
    Args:
        code: 错误代码，用于程序识别（如 "CUSTOMER_NOT_FOUND"）
        message: 错误信息，用于展示给用户
        status_code: HTTP 状态码，默认 400
        
    Returns:
        JSONResponse 对象
        
    Examples:
        >>> return error_response(
        ...     code="CUSTOMER_NOT_FOUND",
        ...     message="客户不存在",
        ...     status_code=404,
        ... )
        >>> return error_response(
        ...     code="VALIDATION_ERROR",
        ...     message="参数校验失败",
        ...     status_code=422,
        ... )
    """
    response = ApiResponse(
        success=False,
        data=None,
        error=ErrorDetail(
            code=code,
            message=message,
        ),
    )
    # 使用 jsonable_encoder 处理 datetime、UUID 等不可序列化类型
    content = jsonable_encoder(response.model_dump(exclude_none=True))
    return JSONResponse(
        status_code=status_code,
        content=content,
    )


# 常用错误响应快捷方法

def not_found_error(resource: str, resource_id: Optional[str] = None) -> JSONResponse:
    """资源不存在错误"""
    msg = f"{resource} 不存在"
    if resource_id:
        msg = f"{resource} [{resource_id}] 不存在"
    return error_response(
        code=f"{resource.upper()}_NOT_FOUND",
        message=msg,
        status_code=404,
    )


def validation_error(message: str = "参数校验失败") -> JSONResponse:
    """参数校验错误"""
    return error_response(
        code="VALIDATION_ERROR",
        message=message,
        status_code=422,
    )


def unauthorized_error(message: str = "未授权访问") -> JSONResponse:
    """未授权错误"""
    return error_response(
        code="UNAUTHORIZED",
        message=message,
        status_code=401,
    )


def internal_error(message: str = "服务器内部错误") -> JSONResponse:
    """服务器内部错误"""
    return error_response(
        code="INTERNAL_ERROR",
        message=message,
        status_code=500,
    )
