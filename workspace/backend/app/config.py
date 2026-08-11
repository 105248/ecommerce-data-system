# -*- coding: utf-8 -*-
"""F0.5 Backend 配置：从 .env 读取（禁止硬编码）"""
import os
from pathlib import Path

_ENV = Path(__file__).resolve().parent.parent / ".env"

def _load(path):
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and "=" in line and not line.startswith("#"):
            k, _, v = line.partition("=")
            os.environ.setdefault(k.strip(), v.strip())

_load(_ENV)

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "ecommerce_db")
DB_USER = os.getenv("DB_USER", "growth_workspace_reader")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
# F1.1：目标管理写库专用最小权限角色（仅 meta.business_target 增改查）
TARGET_WRITER_USER = "growth_workspace_target_writer"
TARGET_WRITER_PASSWORD = os.getenv("TARGET_WRITER_PASSWORD", "")
STATEMENT_TIMEOUT_MS = int(os.getenv("STATEMENT_TIMEOUT_MS", "10000"))
SESSION_SECRET = os.getenv("SESSION_SECRET", "")

# 店铺展示层映射（Backend 配置，不扩张数据库）
SHOP_NAMES = {
    "1": "抖音弹动官方旗舰店",
    "2": "抖音弹动个人护理旗舰店",
}
