# -*- coding: utf-8 -*-
"""类目域 Tools：get_category_summary / rank_categories / get_category_contribution"""
import database
import schemas


def get_category_summary(shop_name=None, start_date=None, end_date=None, category_level=3,
                         category_l1=None, category_l2=None, category_l3=None, metric_key="user_pay_amount"):
    """类目汇总。必须明确 category_level（1/2/3/4），禁止跨层级混合。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_category_level(category_level)

    rows = database.query(
        "SELECT * FROM mart.get_category_period_summary(%s, %s::date, %s::date, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, category_level, category_l1, category_l2, category_l3),
    )
    data = [{
        "shop_name": r.get("shop_name"),
        "category_level": r.get("category_level"),
        "is_total_row": r.get("is_total_row"),
        "category_l1": r.get("category_l1"),
        "category_l2": r.get("category_l2"),
        "category_l3": r.get("category_l3"),
        "category_l4": r.get("category_l4"),
        "user_pay_amount": r.get("user_pay_amount"),
        "refund_amount_pay_time": r.get("refund_amount_pay_time"),
        "refund_rate_pay_time": r.get("refund_rate_pay_time"),
        "unrecalculable_metrics": r.get("unrecalculable_metrics"),
    } for r in rows]
    if not data:
        return schemas.err("get_category_summary", "NO_DATA", "无数据")
    return schemas.ok("get_category_summary", data, {"count": len(data)})


def rank_categories(shop_name=None, start_date=None, end_date=None, category_level=3,
                    category_l1=None, category_l2=None, metric_key="user_pay_amount",
                    sort_by="current_value", sort_direction="DESC", limit=20):
    """类目排名。强制同一 category_level 内比较，L1/L2/L3 父子层级绝不混排。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_category_level(category_level)
    n = schemas.parse_limit(limit)
    schemas.check_sort(sort_by)
    schemas.check_direction(sort_direction)

    rows = database.query(
        "SELECT * FROM mart.rank_categories(%s, %s::date, %s::date, %s, %s, %s, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, category_level, category_l1, category_l2,
         metric_key, sort_by, sort_direction, n),
    )
    data = [{
        "category_level": r.get("category_level"),
        "category_l1": r.get("category_l1"),
        "category_l2": r.get("category_l2"),
        "category_l3": r.get("category_l3"),
        "category_l4": r.get("category_l4"),
        "current_value": r.get("current_value"),
        "previous_value": r.get("previous_value"),
        "absolute_change": r.get("absolute_change"),
        "relative_change": r.get("relative_change"),
        "current_rank": r.get("current_rank"),
        "previous_rank": r.get("previous_rank"),
        "rank_change": r.get("rank_change"),
    } for r in rows]
    if not data:
        return schemas.err("rank_categories", "NO_DATA", "无数据")
    return schemas.ok("rank_categories", data, {"count": len(data)})


def get_category_contribution(shop_name=None, start_date=None, end_date=None, category_level=3,
                              category_l1=None, category_l2=None, metric_key="user_pay_amount", limit=20):
    """类目贡献度。同时返回类目域占比与全店占比（双分母，允许平台口径差异）。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_category_level(category_level)
    n = schemas.parse_limit(limit)

    rows = database.query(
        "SELECT * FROM mart.get_category_contribution(%s, %s::date, %s::date, %s, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, category_level, category_l1, category_l2, metric_key, n),
    )
    data = [{
        "category_level": r.get("category_level"),
        "category_l1": r.get("category_l1"),
        "category_l2": r.get("category_l2"),
        "category_l3": r.get("category_l3"),
        "category_l4": r.get("category_l4"),
        "numerator_value": r.get("numerator_value"),
        "category_level_total": r.get("category_level_total"),
        "contribution_to_category_level": r.get("contribution_to_category_level"),
        "store_total": r.get("store_total"),
        "contribution_to_store": r.get("contribution_to_store"),
        "denominator_note": r.get("denominator_note"),
    } for r in rows]
    if not data:
        return schemas.err("get_category_contribution", "NO_DATA", "无数据")
    return schemas.ok("get_category_contribution", data, {"count": len(data)})
