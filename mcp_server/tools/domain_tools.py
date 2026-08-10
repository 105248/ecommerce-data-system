# -*- coding: utf-8 -*-
"""其他业务域 Tools：载体/内容/终端/价格带/人群 summary + 排名"""
import database
import schemas
import config


# ---------- Carrier 载体 ----------
def get_carrier_summary(shop_name=None, start_date=None, end_date=None,
                        sale_scope=None, carrier_type=None, account_channel=None,
                        metric_key="user_pay_amount"):
    """载体/渠道汇总。仅做拆分/排名，不承担全店 TOTAL。
    '全域投放时段/标准+品牌投放' 为 special_overlap，不可与其明细同时 SUM。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_carrier_period_summary(%s, %s::date, %s::date, %s, %s, %s)",
        (shop_name, start_date, end_date, sale_scope, carrier_type, account_channel),
    )
    data = [{
        "shop_name": r.get("shop_name"),
        "sale_scope": r.get("sale_scope"),
        "carrier_type": r.get("carrier_type"),
        "account_channel": r.get("account_channel"),
        "user_pay_amount": r.get("user_pay_amount"),
        "transaction_amount": r.get("transaction_amount"),
        "settlement_amount": r.get("settlement_amount"),
        "refund_amount_pay_time": r.get("refund_amount_pay_time"),
        "refund_rate_pay_time": r.get("refund_rate_pay_time"),
        "transaction_order_count": r.get("transaction_order_count"),
        "transaction_buyer_count": r.get("transaction_buyer_count"),
        "avg_customer_amount": r.get("avg_customer_amount"),
        "ad_spend_shop_promoted": r.get("ad_spend_shop_promoted"),
        "ad_spend_rate_net_refund_shop_promoted": r.get("ad_spend_rate_net_refund_shop_promoted"),
        "unrecalculable_metrics": r.get("unrecalculable_metrics"),
    } for r in rows]
    if not data:
        return schemas.err("get_carrier_summary", "NO_DATA", "无数据")
    return schemas.ok("get_carrier_summary", data, {"count": len(data)})


def rank_carriers(shop_name=None, start_date=None, end_date=None, sale_scope="全部",
                  metric_key="user_pay_amount", sort_by="current_value", sort_direction="DESC", limit=20):
    """载体排名：使用 deal 合法 TOTAL Scope（商品卡/短视频/直播/图文/其他），
    不通过 carrier_daily 账号渠道明细重建载体 TOTAL。"""
    schemas.validate_period(start_date, end_date)
    n = schemas.parse_limit(limit)
    schemas.check_sort(sort_by)
    schemas.check_direction(sort_direction)
    if sale_scope not in config.CARRIER_SCOPES:
        raise schemas.ArgError("INVALID_ARGUMENT", "carrier 的 sale_scope 仅允许 全部/自营/合作")

    rows = database.query(
        "SELECT * FROM mart.rank_carriers(%s, %s::date, %s::date, %s, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, sale_scope, metric_key, sort_by, sort_direction, n),
    )
    data = [{
        "sale_scope": r.get("sale_scope"),
        "carrier_type": r.get("carrier_type"),
        "current_value": r.get("current_value"),
        "previous_value": r.get("previous_value"),
        "absolute_change": r.get("absolute_change"),
        "relative_change": r.get("relative_change"),
        "current_rank": r.get("current_rank"),
        "previous_rank": r.get("previous_rank"),
        "rank_change": r.get("rank_change"),
    } for r in rows]
    if not data:
        return schemas.err("rank_carriers", "NO_DATA", "无数据")
    return schemas.ok("rank_carriers", data, {"count": len(data)})


# ---------- Content 内容 ----------
def get_content_summary(shop_name=None, start_date=None, end_date=None,
                        selling_type=None, carrier_type=None, content_id=None,
                        metric_key="user_pay_amount"):
    """内容汇总。当前真实样本仅验证 carrier_type=商品卡；不伪造短视频/直播内容数据。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_content_period_summary(%s, %s::date, %s::date, %s, %s, %s)",
        (shop_name, start_date, end_date, selling_type, carrier_type, content_id),
    )
    data = [{
        "shop_name": r.get("shop_name"),
        "selling_type": r.get("selling_type"),
        "carrier_type": r.get("carrier_type"),
        "content_id": r.get("content_id"),
        "content_title": r.get("content_title"),
        "user_pay_amount": r.get("user_pay_amount"),
        "transaction_amount": r.get("transaction_amount"),
        "settlement_amount": r.get("settlement_amount"),
        "refund_amount_pay_time": r.get("refund_amount_pay_time"),
        "refund_rate_pay_time": r.get("refund_rate_pay_time"),
        "transaction_order_count": r.get("transaction_order_count"),
        "transaction_buyer_count": r.get("transaction_buyer_count"),
        "unrecalculable_metrics": r.get("unrecalculable_metrics"),
    } for r in rows]
    if not data:
        return schemas.err("get_content_summary", "NO_DATA", "无数据")
    return schemas.ok("get_content_summary", data, {"count": len(data)})


# ---------- Terminal 终端 ----------
def get_terminal_summary(shop_name=None, start_date=None, end_date=None,
                         terminal_type=None, selling_type=None, metric_key="user_pay_amount"):
    """终端汇总。terminal_type='整体' 是合法 TOTAL（总览优先取）；拆分只取具体终端，
    禁止 '整体+明细终端' 同时 SUM。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_terminal_period_summary(%s, %s::date, %s::date, %s, %s)",
        (shop_name, start_date, end_date, terminal_type, selling_type),
    )
    data = [{
        "shop_name": r.get("shop_name"),
        "terminal_type": r.get("terminal_type"),
        "selling_type": r.get("selling_type"),
        "user_pay_amount": r.get("user_pay_amount"),
        "transaction_amount": r.get("transaction_amount"),
        "settlement_amount": r.get("settlement_amount"),
        "refund_amount_pay_time": r.get("refund_amount_pay_time"),
        "refund_rate_pay_time": r.get("refund_rate_pay_time"),
        "transaction_order_count": r.get("transaction_order_count"),
        "unrecalculable_metrics": r.get("unrecalculable_metrics"),
    } for r in rows]
    if not data:
        return schemas.err("get_terminal_summary", "NO_DATA", "无数据")
    return schemas.ok("get_terminal_summary", data, {"count": len(data)})


# ---------- Price Band 价格带 ----------
def get_price_band_summary(shop_name=None, start_date=None, end_date=None,
                           price_band=None, metric_key="user_pay_amount"):
    """价格带汇总。6 个价格带已验证互斥，可安全 SUM 重建店铺总量。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_price_band_period_summary(%s, %s::date, %s::date, %s)",
        (shop_name, start_date, end_date, price_band),
    )
    data = [{
        "shop_name": r.get("shop_name"),
        "price_band": r.get("price_band"),
        "user_pay_amount": r.get("user_pay_amount"),
        "unrecalculable_metrics": r.get("unrecalculable_metrics"),
    } for r in rows]
    if not data:
        return schemas.err("get_price_band_summary", "NO_DATA", "无数据")
    return schemas.ok("get_price_band_summary", data, {"count": len(data)})


def rank_price_bands(shop_name=None, start_date=None, end_date=None, metric_key="user_pay_amount",
                     sort_by="current_value", sort_direction="DESC", limit=20):
    """价格带排名：6 个价格带互斥，可直接比较。"""
    schemas.validate_period(start_date, end_date)
    n = schemas.parse_limit(limit)
    schemas.check_sort(sort_by)
    schemas.check_direction(sort_direction)
    rows = database.query(
        "SELECT * FROM mart.rank_price_bands(%s, %s::date, %s::date, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, metric_key, sort_by, sort_direction, n),
    )
    data = [{
        "price_band": r.get("price_band"),
        "current_value": r.get("current_value"),
        "previous_value": r.get("previous_value"),
        "absolute_change": r.get("absolute_change"),
        "relative_change": r.get("relative_change"),
        "current_rank": r.get("current_rank"),
        "previous_rank": r.get("previous_rank"),
        "rank_change": r.get("rank_change"),
    } for r in rows]
    if not data:
        return schemas.err("rank_price_bands", "NO_DATA", "无数据")
    return schemas.ok("rank_price_bands", data, {"count": len(data)})


# ---------- Audience 人群 ----------
def get_audience_summary(shop_name=None, start_date=None, end_date=None,
                         audience_type=None, carrier_type="全部", metric_key="user_pay_amount"):
    """人群汇总。carrier_type='全部' 是合法 TOTAL（总览优先）；拆分只用 5 个明细载体，
    禁止 '全部+明细' 同时 SUM。"""
    schemas.validate_period(start_date, end_date)
    if carrier_type is None:
        carrier_type = "全部"
    rows = database.query(
        "SELECT * FROM mart.get_audience_period_summary(%s, %s::date, %s::date, %s, %s)",
        (shop_name, start_date, end_date, audience_type, carrier_type),
    )
    data = [{
        "shop_name": r.get("shop_name"),
        "audience_type": r.get("audience_type"),
        "carrier_type": r.get("carrier_type"),
        "user_pay_amount": r.get("user_pay_amount"),
        "transaction_buyer_count": r.get("transaction_buyer_count"),
        "transaction_order_count": r.get("transaction_order_count"),
        "avg_customer_amount": r.get("avg_customer_amount"),
        "unrecalculable_metrics": r.get("unrecalculable_metrics"),
    } for r in rows]
    if not data:
        return schemas.err("get_audience_summary", "NO_DATA", "无数据")
    return schemas.ok("get_audience_summary", data, {"count": len(data)})


def rank_audiences(shop_name=None, start_date=None, end_date=None, carrier_type="全部",
                   metric_key="user_pay_amount", sort_by="current_value", sort_direction="DESC", limit=20):
    """人群排名。默认 carrier_type='全部'（合法 TOTAL），禁止 TOTAL+明细载体混排。"""
    schemas.validate_period(start_date, end_date)
    n = schemas.parse_limit(limit)
    schemas.check_sort(sort_by)
    schemas.check_direction(sort_direction)
    if carrier_type is None:
        carrier_type = "全部"
    rows = database.query(
        "SELECT * FROM mart.rank_audiences(%s, %s::date, %s::date, %s, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, carrier_type, metric_key, sort_by, sort_direction, n),
    )
    data = [{
        "audience_type": r.get("audience_type"),
        "carrier_type": r.get("carrier_type"),
        "current_value": r.get("current_value"),
        "previous_value": r.get("previous_value"),
        "absolute_change": r.get("absolute_change"),
        "relative_change": r.get("relative_change"),
        "current_rank": r.get("current_rank"),
        "previous_rank": r.get("previous_rank"),
        "rank_change": r.get("rank_change"),
    } for r in rows]
    if not data:
        return schemas.err("rank_audiences", "NO_DATA", "无数据")
    return schemas.ok("rank_audiences", data, {"count": len(data)})
