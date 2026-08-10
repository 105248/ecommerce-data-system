# -*- coding: utf-8 -*-
"""V1.1 Stage2 异常检测 Tools：get_anomalies / get_anomaly_summary（只读查询，异常来自 mart）"""
import database
import schemas


def get_anomalies(platform_code="douyin", start_date=None, end_date=None,
                  domain_key=None, entity_name=None, severity=None, status="OPEN"):
    """异常检测结果：哪里异常/多严重/是否持续/影响多大。
    domain=platform/shop/scope/master_product/shop_product/product_line/carrier/account/category。
    只返回异常事实，不做根因结论、不给机会/优先级建议。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_anomalies(%s, %s::date, %s::date, %s, %s, %s, %s)",
        (platform_code, start_date, end_date, domain_key, entity_name, severity, status))
    if not rows:
        return schemas.ok("get_anomalies", [], {"note": "该区间/条件无异常事件"})
    data = [dict(r) for r in rows]
    return schemas.ok("get_anomalies", data)


def get_entity_anomalies(platform_code="douyin", domain_key=None, entity_name=None,
                         start_date=None, end_date=None):
    """单实体异常明细（域+实体名过滤）。"""
    if not domain_key or not entity_name:
        raise schemas.ArgError("INVALID_ARGUMENT", "需提供 domain_key 与 entity_name")
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_entity_anomalies(%s, %s, %s, %s::date, %s::date)",
        (platform_code, domain_key, entity_name, start_date, end_date))
    if not rows:
        return schemas.ok("get_entity_anomalies", [], {"note": "该实体无异常"})
    return schemas.ok("get_entity_anomalies", [dict(r) for r in rows])


def get_anomaly_summary(platform_code="douyin", start_date=None, end_date=None, status="OPEN"):
    """异常汇总：按域×类型统计事件数/严重度/影响额。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_anomaly_summary(%s, %s::date, %s::date, %s)",
        (platform_code, start_date, end_date, status))
    if not rows:
        return schemas.ok("get_anomaly_summary", [], {"note": "该区间无异常汇总"})
    return schemas.ok("get_anomaly_summary", [dict(r) for r in rows])
