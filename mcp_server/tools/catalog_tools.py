# -*- coding: utf-8 -*-
"""基础目录 Tools：list_shops / get_data_coverage / get_metric_catalog / get_import_history / health_check"""
import database
import schemas
from datetime import datetime


def list_shops():
    """返回可用店铺列表（shop_name 为主，不返回 shop_id 作为主字段）。"""
    rows = database.query(
        "SELECT shop_name, shop_code, platform_code, platform_shop_id, enabled "
        "FROM meta.shop ORDER BY shop_name"
    )
    data = [
        {"shop_name": r["shop_name"], "shop_code": r.get("shop_code"),
         "platform_code": r.get("platform_code"),
         "platform_shop_id": r.get("platform_shop_id"),
         "enabled": r.get("enabled")}
        for r in rows
    ]
    return schemas.ok("list_shops", data, {"count": len(data)})


def get_data_coverage(shop_name=None):
    schemas.check_shop(shop_name)
    """返回指定店铺（或全部）的数据覆盖：min/max 日期、天数、行数、覆盖状态。
    经 mart.get_data_coverage 安全函数读取（不给 core 直接 SELECT）。"""
    rows = database.query(
        "SELECT * FROM mart.get_data_coverage(%s)",
        (shop_name,),
    )
    data = []
    for r in rows:
        status = "ok"
        if r["min_date"] is None:
            status = "no_data"
        data.append({
            "shop_name": r["shop_name"],
            "min_date": schemas.serialize(r["min_date"]),
            "max_date": schemas.serialize(r["max_date"]),
            "day_count": r["day_count"],
            "row_count": r["row_count"],
            "coverage_status": status,
        })
    return schemas.ok("get_data_coverage", data, {"count": len(data)})


def get_metric_catalog(domain_key=None):
    """返回指标目录：V1.4 规则 + Stage3 白名单。metric_key 用于后续 AI 选择正确工具。"""
    rows = database.query("SELECT * FROM mart.analysis_metric_whitelist")
    data = []
    for r in rows:
        if domain_key and r.get("domain_key") != domain_key:
            continue
        data.append({
            "domain": r.get("domain_key"),
            "metric_key": r.get("metric_key"),
            "metric_name_cn": r.get("metric_name_cn"),
            "value_type": r.get("value_type"),
            "rank_allowed": r.get("rank_allowed"),
            "contribution_allowed": r.get("contribution_allowed"),
            "default_rank_direction": r.get("default_rank_direction"),
        })
    return schemas.ok("get_metric_catalog", data, {"count": len(data), "source": "analysis_metric_whitelist"})


def get_import_history(limit=20):
    """返回最近导入批次（只返回必要安全字段，不含密码/路径/sha256）。"""
    n = schemas.parse_limit(limit)
    rows = database.query(
        "SELECT b.batch_id, s.shop_name, b.source_file_name, b.import_mode, "
        "       b.import_status, b.source_row_count, b.inserted_row_count, "
        "       b.period_start, b.period_end, b.imported_at "
        "FROM audit.import_batch b LEFT JOIN meta.shop s ON s.shop_id = b.shop_id "
        "ORDER BY b.batch_id DESC LIMIT %s",
        (n,),
    )
    data = [
        {
            "batch_id": r["batch_id"],
            "shop_name": r.get("shop_name"),
            "source_file_name": r.get("source_file_name"),
            "import_mode": r.get("import_mode"),
            "import_status": r.get("import_status"),
            "source_row_count": r.get("source_row_count"),
            "inserted_row_count": r.get("inserted_row_count"),
            "period_start": schemas.serialize(r.get("period_start")),
            "period_end": schemas.serialize(r.get("period_end")),
            "imported_at": schemas.serialize(r.get("imported_at")),
        }
        for r in rows
    ]
    return schemas.ok("get_import_history", data, {"count": len(data)})


def health_check():
    """服务健康检查：数据库连通 + 只读角色可查白名单。"""
    try:
        rows = database.query("SELECT count(*) AS c FROM mart.analysis_metric_whitelist")
        return schemas.ok("health_check",
                          {"status": "ok", "db_connected": True,
                           "metric_catalog_rows": rows[0]["c"] if rows else 0})
    except Exception as e:  # noqa: BLE001
        return schemas.err("health_check", "DB_ERROR", str(e))
