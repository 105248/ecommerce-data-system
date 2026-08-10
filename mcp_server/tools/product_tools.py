# -*- coding: utf-8 -*-
"""商品域 Tools：get_product_summary / rank_products / get_product_contribution"""
import database
import schemas


def get_product_summary(shop_name=None, start_date=None, end_date=None,
                        product_id=None, product_name=None, carrier_type="全部", metric_key="user_pay_amount"):
    """商品汇总。默认 carrier_type='全部'，使用 product 平台独立 TOTAL，
    不通过各载体明细重建。product_id 始终按文本处理。"""
    schemas.validate_period(start_date, end_date)
    if carrier_type is None:
        carrier_type = "全部"

    rows = database.query(
        "SELECT * FROM mart.get_product_period_summary(%s, %s::date, %s::date, %s, %s, %s)",
        (shop_name, start_date, end_date, product_id, product_name, carrier_type),
    )
    data = [{
        "shop_name": r.get("shop_name"),
        "product_id": r.get("product_id"),
        "product_name": r.get("product_name"),
        "carrier_type": r.get("carrier_type"),
        "start_date": schemas.serialize(r.get("start_date")),
        "end_date": schemas.serialize(r.get("end_date")),
        "day_count": r.get("day_count"),
        "user_pay_amount": r.get("user_pay_amount"),
        "refund_amount_pay_time": r.get("refund_amount_pay_time"),
        "refund_rate_pay_time": r.get("refund_rate_pay_time"),
        "smart_coupon_amount": r.get("smart_coupon_amount"),
        "platform_subsidy_amount": r.get("platform_subsidy_amount"),
        "unrecalculable_metrics": r.get("unrecalculable_metrics"),
    } for r in rows]
    if not data:
        return schemas.err("get_product_summary", "NO_DATA", "无数据")
    return schemas.ok("get_product_summary", data, {"count": len(data)})


def rank_products(shop_name=None, start_date=None, end_date=None, metric_key="user_pay_amount",
                  sort_by="current_value", sort_direction="DESC", limit=20, product_id=None, product_name=None):
    """商品排名/增长/下降/排名变化。排名使用 product carrier=全部 平台独立 TOTAL。
    过滤商品时先全量排名再过滤，保留真实名次。"""
    schemas.validate_period(start_date, end_date)
    n = schemas.parse_limit(limit)
    schemas.check_sort(sort_by)
    schemas.check_direction(sort_direction)

    rows = database.query(
        "SELECT * FROM mart.rank_products(%s, %s::date, %s::date, %s, %s, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, metric_key, sort_by, sort_direction, n, product_id, product_name),
    )
    data = [{
        "product_id": r.get("product_id"),
        "product_name": r.get("product_name"),
        "carrier_type": r.get("carrier_type"),
        "current_value": r.get("current_value"),
        "previous_value": r.get("previous_value"),
        "absolute_change": r.get("absolute_change"),
        "relative_change": r.get("relative_change"),
        "percentage_point_change": r.get("percentage_point_change"),
        "current_rank": r.get("current_rank"),
        "previous_rank": r.get("previous_rank"),
        "rank_change": r.get("rank_change"),
        "rank_status": r.get("rank_status"),
    } for r in rows]
    if not data:
        return schemas.err("rank_products", "NO_DATA", "无数据")
    return schemas.ok("rank_products", data, {"count": len(data)})


def get_product_contribution(shop_name=None, start_date=None, end_date=None,
                             metric_key="user_pay_amount", product_id=None, product_name=None, limit=20):
    """商品贡献度。同时返回 product 域占比与全店占比（双分母，不强制相等）。"""
    schemas.validate_period(start_date, end_date)
    n = schemas.parse_limit(limit)

    rows = database.query(
        "SELECT * FROM mart.get_product_contribution(%s, %s::date, %s::date, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, metric_key, product_id, product_name, n),
    )
    data = [{
        "product_id": r.get("product_id"),
        "product_name": r.get("product_name"),
        "carrier_type": r.get("carrier_type"),
        "metric_key": r.get("metric_key"),
        "numerator_value": r.get("numerator_value"),
        "product_domain_total": r.get("product_domain_total"),
        "contribution_to_product_domain": r.get("contribution_to_product_domain"),
        "store_total": r.get("store_total"),
        "contribution_to_store": r.get("contribution_to_store"),
        "denominator_note": r.get("denominator_note"),
    } for r in rows]
    if not data:
        return schemas.err("get_product_contribution", "NO_DATA", "无数据")
    return schemas.ok("get_product_contribution", data, {"count": len(data)})
