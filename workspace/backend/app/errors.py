# -*- coding: utf-8 -*-
"""F0.5 Backend 错误码与统一返回"""
from fastapi.responses import JSONResponse

ERROR_CODES = {
    "INVALID_ARGUMENT": "参数无效",
    "UNAUTHORIZED": "未认证",
    "FORBIDDEN": "无权限",
    "UNKNOWN_SHOP": "未知店铺",
    "UNKNOWN_SCOPE": "未知经营口径",
    "UNKNOWN_ENTITY": "未知实体",
    "NO_DATA": "当前日期范围暂无可用数据",
    "COVERAGE_INCOMPLETE": "数据覆盖不完整",
    "MAPPING_INCOMPLETE": "主数据映射不完整",
    "DATA_SOURCE_NOT_AVAILABLE": "数据源不可用",
    "DATABASE_UNAVAILABLE": "数据库不可用",
    "DATABASE_QUERY_ERROR": "数据库查询错误",
    "INTERNAL_ERROR": "内部错误",
}


class ApiError(Exception):
    def __init__(self, code: str, message: str = None, status_code: int = 400):
        self.code = code
        self.message = message or ERROR_CODES.get(code, code)
        self.status_code = status_code
        super().__init__(self.message)


def ok(data, meta=None):
    return {"success": True, "data": data, "meta": meta or {}}


def fail(code, message=None, status_code=400):
    return {"success": False, "error": {"code": code, "message": message or ERROR_CODES.get(code, code)},
            "meta": {}}


def api_error_handler(request, exc):
    return JSONResponse(status_code=exc.status_code, content=fail(exc.code, exc.message))
