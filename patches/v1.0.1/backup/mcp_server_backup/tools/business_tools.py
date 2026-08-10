# -*- coding: utf-8 -*-
"""经营总览 Tools：get_business_summary / compare_business"""
import database
import schemas
import config


def get_business_summary(shop_name=None, start_date=None, end_date=None, scope_key="全店", metric_key="user_pay_amount"):
    """高频经营总览：按 Scope 返回区间汇总。
    比例/均值已由数据库按 V1.4 跨期重算，客户端不要再次 AVG。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_scope(scope_key)

    rows = database.query(
        "SELECT * FROM mart.get_business_period_summary(%s, %s::date, %s::date, %s)",
        (shop_name, start_date, end_date, scope_key),
    )
    if not rows:
        return schemas.err("get_business_summary", "NO_DATA", "本期无数据")

    r = rows[0]
    # 按白名单确认指标存在（业务域 business）
    cat = database.query("SELECT * FROM mart.analysis_metric_whitelist WHERE domain_key='business'")
    schemas.check_metric("business", metric_key, cat)

    metric_map = {
        "user_pay_amount": "user_pay_amount",
        "transaction_amount": "transaction_amount",
        "refund_amount_pay_time": "refund_amount_pay_time",
        "settlement_amount": "settlement_amount",
        "transaction_order_count": "transaction_order_count",
        "transaction_buyer_count": "transaction_buyer_count",
        "transaction_item_count": "transaction_item_count",
        "avg_customer_amount": "avg_customer_amount",
        "avg_item_amount": "avg_item_amount",
        "refund_rate_pay_time": "refund_rate_pay_time",
        "exposure_to_click_rate_users": "exposure_to_click_rate_users",
        "click_to_transaction_rate_users": "click_to_transaction_rate_users",
        "exposure_to_transaction_rate_users": "exposure_to_transaction_rate_users",
        "exposure_to_click_rate_events": "exposure_to_click_rate_events",
        "click_to_transaction_rate_events": "click_to_transaction_rate_events",
        "exposure_to_transaction_rate_events": "exposure_to_transaction_rate_events",
        "user_pay_amount_per_1000_exposures": "user_pay_amount_per_1000_exposures",
    }
    col = metric_map.get(metric_key)
    if col is None:
        return schemas.err("get_business_summary", "UNKNOWN_METRIC", "business 域不支持指标 {}".format(metric_key))

    data = {
        "shop_name": r.get("shop_name"),
        "scope_key": r.get("scope_key"),
        "start_date": schemas.serialize(r.get("start_date")),
        "end_date": schemas.serialize(r.get("end_date")),
        "expected_days": r.get("expected_days"),
        "coverage_days": r.get("coverage_days"),
        "coverage_complete": r.get("coverage_complete"),
        "metric_key": metric_key,
        "metric_value": r.get(col),
        "unrecalculable_metrics": r.get("unrecalculable_metrics"),
    }
    return schemas.ok("get_business_summary", [data])


def compare_business(shop_name=None, start_date=None, end_date=None, scope_key="全店", metric_key="user_pay_amount"):
    """环比：本期 N 天 vs 紧邻前 N 天。比例同时返回相对变化率与百分点变化。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_scope(scope_key)

    rows = database.query(
        "SELECT * FROM mart.compare_business_period(%s, %s::date, %s::date, %s, %s)",
        (shop_name, start_date, end_date, scope_key, metric_key),
    )
    if not rows:
        return schemas.err("compare_business", "NO_DATA", "本期无数据")
    r = rows[0]
    data = {
        "shop_name": r.get("shop_name"),
        "scope_key": r.get("scope_key"),
        "metric_key": r.get("metric_key"),
        "metric_name_cn": r.get("metric_name_cn"),
        "value_type": r.get("value_type"),
        "current_start_date": schemas.serialize(r.get("current_start_date")),
        "current_end_date": schemas.serialize(r.get("current_end_date")),
        "previous_start_date": schemas.serialize(r.get("previous_start_date")),
        "previous_end_date": schemas.serialize(r.get("previous_end_date")),
        "current_value": r.get("current_value"),
        "previous_value": r.get("previous_value"),
        "absolute_change": r.get("absolute_change"),
        "relative_change": r.get("relative_change"),
        "percentage_point_change": r.get("percentage_point_change"),
        "current_coverage_complete": r.get("current_coverage_complete"),
        "previous_coverage_complete": r.get("previous_coverage_complete"),
        "comparison_status": r.get("comparison_status"),
    }
    return schemas.ok("compare_business", [data])
