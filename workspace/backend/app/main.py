# -*- coding: utf-8 -*-
"""F0.5 Backend 入口：FastAPI + 统一返回 + 日志 + 错误处理 + 静态 Web + 飞书身份映射（配置层）"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, FileResponse

import api
import api_f1
import db
from errors import ApiError, fail
from middleware import AccessLogMiddleware, logger

app = FastAPI(title="Growth Workspace Backend (F1.0)", version="F1.0")
app.add_middleware(AccessLogMiddleware)
app.include_router(api.router)
app.include_router(api_f1.router)

STATIC = Path(__file__).resolve().parent.parent / "static"

# ===== 飞书身份映射（F0.5 配置层，不扩张数据库） =====
# 飞书 open_id → (角色, 可见店铺)。F0.5 演示为内置配置；F1.0 可迁移至 meta.app_user*。
FEISHU_USERS = {
    # 示例：open_id: {"role": "ADMIN", "shops": ["DY_DANDONG_OFFICIAL", "DY_GERENHULI_OFFICIAL"]}
}
FEISHU_APP = {"app_id": "[FEISHU_APP_ID]", "app_secret_env": "FEISHU_APP_SECRET"}


@app.get("/feishu/auth")
def feishu_auth(open_id: str = ""):
    """飞书网页应用入口：识别用户 → 角色 → 店铺权限（F0.5 最小：白名单配置）。"""
    user = FEISHU_USERS.get(open_id)
    if not user:
        return fail("UNAUTHORIZED", "飞书用户未映射", 401)
    return {"success": True, "data": {"open_id": open_id, "role": user["role"], "shops": user["shops"]}}


# ===== 静态 Web（同源，零 CORS）；no-cache 保证前端迭代后刷新即最新 =====
def _fresh(resp):
    resp.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    resp.headers["Pragma"] = "no-cache"
    return resp

@app.get("/")
def index():
    return _fresh(FileResponse(STATIC / "index.html"))


@app.get("/app.js")
def app_js():
    return _fresh(FileResponse(STATIC / "app.js"))


@app.get("/system-status")
def system_status():
    return _fresh(FileResponse(STATIC / "system-status.html"))


@app.get("/data-status")
def data_status_page():
    return _fresh(FileResponse(STATIC / "data-status.html"))


@app.exception_handler(ApiError)
async def _api_error(request: Request, exc: ApiError):
    request.state.status_code = exc.status_code
    request.state.error_code = exc.code
    return JSONResponse(status_code=exc.status_code, content=fail(exc.code, exc.message))


@app.exception_handler(Exception)
async def _unhandled(request: Request, exc: Exception):
    logger.exception("unhandled: %s", exc)
    request.state.status_code = 500
    request.state.error_code = "INTERNAL_ERROR"
    return JSONResponse(status_code=500, content=fail("INTERNAL_ERROR", "内部错误"))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=False)
