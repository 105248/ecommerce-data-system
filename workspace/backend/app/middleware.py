# -*- coding: utf-8 -*-
"""F0.5 Backend 请求日志中间件（request_id/耗时/脱敏）"""
import time
import uuid
import logging
from pathlib import Path

from fastapi import Request

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(message)s",
    handlers=[logging.FileHandler(Path(__file__).resolve().parent.parent / "logs" / "api.log", encoding="utf-8"),
              logging.StreamHandler()],
)
logger = logging.getLogger("f0.5.api")


class AccessLogMiddleware:
    """记录 request_id/endpoint/method/参数/耗时/错误码；禁止记录密码/Token/完整 Authorization。"""

    SENSITIVE_KEYS = {"password", "token", "secret", "cookie", "authorization", "feishu_app_secret"}

    def __init__(self, app):
        self.app = app

    def _clean_params(self, params: dict):
        out = {}
        for k, v in (params or {}).items():
            if any(s in k.lower() for s in self.SENSITIVE_KEYS):
                out[k] = "[REDACTED]"
            else:
                out[k] = v
        return out

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        request = Request(scope, receive)
        rid = str(uuid.uuid4())[:12]
        t0 = time.time()
        status = 200
        error_code = ""
        try:
            await self.app(scope, receive, send)
        finally:
            status = getattr(request.state, "status_code", 200)
            error_code = getattr(request.state, "error_code", "")
            dur = (time.time() - t0) * 1000
            logger.info("req=%s | %s %s | status=%s | db_ms=%s | total_ms=%.1f | err=%s | params=%s",
                        rid, request.method, request.url.path, status,
                        getattr(request.state, "db_ms", "-"), dur, error_code,
                        self._clean_params(dict(request.query_params)))
