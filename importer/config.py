# -*- coding: utf-8 -*-
"""配置加载：从 .env 读取数据库凭据，禁止硬编码密码。"""
import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

# 数据库连接（专用账号，最小权限）
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "ecommerce_db")
DB_USER = os.getenv("DB_USER", "ecommerce_importer")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

# 日志与报告目录
LOG_DIR = BASE_DIR.parent / "logs" / "imports"
LOG_DIR.mkdir(parents=True, exist_ok=True)

# 默认店铺（可被命令行覆盖）
DEFAULT_SHOP_ID = 1
