# -*- coding: utf-8 -*-
"""参数校验与统一返回结构。"""
import re
from datetime import date, datetime

import config

_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class ArgError(ValueError):
    """参数校验错误。error_type 用于返回给 AI 的统一错误码。"""

    def __init__(self, error_type: str, message: str):
        super().__init__(message)
        self.error_type = error_type


def parse_date(value, name: str) -> date:
    if value is None:
        raise ArgError("INVALID_ARGUMENT", "{} 不能为空".format(name))
    s = str(value).strip()
    if not _DATE_RE.match(s):
        raise ArgError("INVALID_ARGUMENT", "{} 必须是 YYYY-MM-DD，收到 '{}'".format(name, s))
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except ValueError as e:
        raise ArgError("INVALID_ARGUMENT", "{} 非法日期 '{}'".format(name, s)) from e


def validate_period(start_date, end_date):
    d1 = parse_date(start_date, "start_date")
    d2 = parse_date(end_date, "end_date")
    if d1 > d2:
        raise ArgError("INVALID_ARGUMENT", "start_date({}) 不能晚于 end_date({})".format(d1, d2))
    return d1, d2


def parse_limit(value, default=config.LIMIT_DEFAULT):
    if value is None:
        return default
    try:
        n = int(value)
    except (TypeError, ValueError):
        raise ArgError("INVALID_ARGUMENT", "limit 必须是整数") from None
    if n < config.LIMIT_MIN or n > config.LIMIT_MAX:
        raise ArgError("INVALID_ARGUMENT", "limit 仅允许 {}~{}，收到 {}".format(config.LIMIT_MIN, config.LIMIT_MAX, n))
    return n


def check_scope(value):
    if value not in config.SCOPES:
        raise ArgError("UNKNOWN_SCOPE", "未知经营语义 '{}'。可用：{}".format(value, "、".join(sorted(config.SCOPES))))


def check_metric(domain: str, metric_key: str, rows_catalog):
    """根据 get_metric_catalog 结果校验 domain+metric 组合。rows_catalog 元素含 domain_key/metric_key。"""
    for r in rows_catalog:
        if r.get("domain_key") == domain and r.get("metric_key") == metric_key:
            return r
    raise ArgError("UNKNOWN_METRIC", "域{}不支持指标 '{}'。请用 get_metric_catalog 查看可用指标".format(domain, metric_key))


def check_category_level(v):
    if v is None:
        return None
    try:
        n = int(v)
    except (TypeError, ValueError):
        raise ArgError("INVALID_ARGUMENT", "category_level 必须是 1/2/3/4") from None
    if n not in config.CATEGORY_LEVELS:
        raise ArgError("INVALID_ARGUMENT", "category_level 仅允许 1/2/3/4，收到 {}".format(n))
    return n


def check_sort(value, allowed=None):
    allowed = allowed or config.SORT_BY_MODES
    if value not in allowed:
        raise ArgError("INVALID_ARGUMENT", "sort_by 仅允许 {}".format("、".join(sorted(allowed))))
    return value


def check_direction(v):
    v = (v or "DESC").upper()
    if v not in config.SORT_DIRECTIONS:
        raise ArgError("INVALID_ARGUMENT", "sort_direction 仅允许 ASC/DESC")
    return v


def ok(tool: str, data, meta=None):
    return {"ok": True, "tool": tool, "data": data, "meta": meta or {}}


def err(tool: str, error_type: str, message: str):
    return {"ok": False, "tool": tool, "error_type": error_type, "message": message}


def serialize(value):
    """date/datetime → str；其余原样（保留 NULL、Decimal 由 json 层处理）。"""
    if isinstance(value, (date, datetime)):
        return value.isoformat()
    return value
