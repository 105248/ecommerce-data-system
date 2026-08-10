# -*- coding: utf-8 -*-
"""数据转换：日期解析、百分比归一化、ID 文本化、空值处理。"""
import re
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional

# 百分比字段关键字（源字段名含以下词视为百分比）
PERCENT_KEYWORDS = ["率", "占比", "费比", "转化率", "退款率"]

# ID 类字段（按文本处理，防止精度丢失）
ID_PATTERNS = [
    re.compile(r"id$", re.I),
    re.compile(r"_id$", re.I),
    re.compile(r"编号|ID", re.I),
]


def parse_date(value: Any) -> Optional[date]:
    """兼容 Excel 原生日期 / 20260601 / 2026-06-01 / 2026/06/01。
    无法解析返回 None（调用方需记录异常）。"""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, (int, float)):
        # 可能是 Excel 序列号
        if 20000 < value < 60000:
            try:
                return (datetime(1899, 12, 30) + timedelta(days=value)).date()
            except Exception:
                return None
        # 20260601
        s = str(int(value))
        if len(s) == 8 and s.isdigit():
            try:
                return datetime.strptime(s, "%Y%m%d").date()
            except ValueError:
                return None
        return None
    s = str(value).strip()
    if not s:
        return None
    # 20260601
    m = re.fullmatch(r"(\d{4})(\d{2})(\d{2})", s)
    if m:
        try:
            return datetime.strptime(s, "%Y%m%d").date()
        except ValueError:
            return None
    # 2026-06-01 / 2026/06/01 / 2026.06.01
    for fmt in ("%Y-%m-%d", "%Y/%m/%d", "%Y.%m.%d"):
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    return None


def is_percent_field(source_name: str, field_category: str = "") -> bool:
    """判断字段是否百分比指标。"""
    if field_category == "比例指标":
        return True
    return any(k in source_name for k in PERCENT_KEYWORDS)


def normalize_percent(value: Any) -> Optional[float]:
    """比例/率字段归一化规则（V1.1 修正版）：
    - Excel 数值类型：原值保存（比率值），允许 >1，例如 0.1972=19.72%、9.625=962.50%
    - 字符串带 % 符号：视为百分比展示值，÷100，例如 "3.78%" -> 0.0378
    - 字符串裸数：转 float 原值保存（比率值），例如 "9.625" -> 9.625
    不再根据 value > 1 判定口径异常。
    """
    if value is None or value == "":
        return None
    if isinstance(value, (int, float)):
        # 数值类型原值保存（比率值），保留 8 位小数精度
        return round(float(value), 8)
    if isinstance(value, str):
        s = value.strip()
        if not s:
            return None
        if "%" in s or "％" in s:
            # 带 % 符号：百分比展示值 → 比率值
            try:
                num = float(s.replace("%", "").replace("％", "").strip())
            except ValueError:
                return None
            return round(num / 100.0, 8)
        # 裸数字符串：原值（比率值）
        try:
            return round(float(s.replace(",", "")), 8)
        except ValueError:
            return None
    return None


def to_text_id(value: Any) -> Optional[str]:
    """ID 类字段转文本，防止科学计数法和精度丢失。"""
    if value is None:
        return None
    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        return f"{value:.0f}" if abs(value) > 1e10 else str(value)
    if isinstance(value, (int,)):
        return str(value)
    s = str(value).strip()
    return s if s else None


def to_numeric(value: Any) -> Optional[float]:
    """普通数值：空白 -> NULL，其他尽力转 float。"""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    s = str(value).strip().replace(",", "")
    if not s or s.lower() in ("-", "--", "null", "none"):
        return None
    try:
        return float(s)
    except ValueError:
        return None


def to_bigint(value: Any) -> Optional[int]:
    """整数值转换。"""
    if value is None:
        return None
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float)):
        return int(value)
    s = str(value).strip().replace(",", "")
    if not s or s.lower() in ("-", "--", "null", "none"):
        return None
    try:
        return int(float(s))
    except ValueError:
        return None
