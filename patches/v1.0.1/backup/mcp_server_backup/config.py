# -*- coding: utf-8 -*-
"""MCP Server 配置：从 .env 读取，密码仅存于此文件。"""
import os
from pathlib import Path

# .env 固定位于 mcp_server/.env
_ENV_PATH = Path(__file__).resolve().parent / ".env"


def _load_env(path: Path):
    """极简 .env 解析（避免额外依赖 dotenv 也行，但已装则用标准解析）。"""
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        os.environ.setdefault(key.strip(), val.strip())


_load_env(_ENV_PATH)

DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "ecommerce_db")
DB_USER = os.getenv("DB_USER", "agent_readonly")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

# 数据库查询超时（毫秒），角色级 statement_timeout 已设 10s，客户端再兜底
STATEMENT_TIMEOUT_MS = int(os.getenv("MCP_STATEMENT_TIMEOUT_MS", "10000"))

# 允许的 scope_key（与 mart.period_scope_rule / stage3_expected_scope_map 一致）
SCOPES = frozenset([
    "全店", "自营", "合作", "商品卡", "短视频", "直播", "图文", "其他",
    "自营商品卡", "合作商品卡", "自营短视频", "合作短视频",
    "自营直播", "合作直播", "自营图文", "合作图文", "自营其他", "合作其他",
])

# 允许的 category_level
CATEGORY_LEVELS = frozenset([1, 2, 3, 4])

# limit 范围
LIMIT_MIN = 1
LIMIT_MAX = 100
LIMIT_DEFAULT = 20

# 排序方向
SORT_DIRECTIONS = frozenset(["ASC", "DESC"])

# 排序模式（Stage3 assert_rank_args 白名单）
SORT_BY_MODES = frozenset(["current_value", "absolute_change", "relative_change", "rank_change"])

# 账号 sale_scope 限制
ACCOUNT_SCOPES = frozenset(["自营", "合作"])

# 载体 sale_scope 限制
CARRIER_SCOPES = frozenset(["全部", "自营", "合作"])

# 日志目录
LOG_DIR = Path(os.getenv("MCP_LOG_DIR", r"D:\ecommerce-data-system\logs\mcp"))
