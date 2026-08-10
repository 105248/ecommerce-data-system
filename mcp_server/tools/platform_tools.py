# -*- coding: utf-8 -*-
"""V1.3 平台经营 Tools：get_platform_business_summary / compare_platform_business / get_shop_contribution / decompose_platform_change_by_shop"""
import database
import schemas


def _check_platform(code):
    rows = database.query("SELECT 1 FROM meta.platform WHERE platform_code = %s AND enabled", (code,))
    if not rows:
        raise schemas.ArgError("UNKNOWN_PLATFORM", "未知/未启用平台 '{}'。可用：douyin".format(code))


def get_platform_business_summary(platform_code="douyin", start_date=None, end_date=None, scope_key="全店"):
    """抖音平台整体经营汇总：两店合计 + coverage（启用/覆盖/缺失店铺数）。比例=分子/分母重算，效率=加权。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_scope(scope_key)
    _check_platform(platform_code)

    rows = database.query(
        "SELECT * FROM mart.get_platform_business_period_summary(%s, %s::date, %s::date, %s)",
        (platform_code, start_date, end_date, scope_key))
    if not rows:
        return schemas.err("get_platform_business_summary", "NO_DATA", "该区间无数据")
    r = rows[0]
    data = {
        "platform_code": r.get("platform_code"),
        "platform_name": r.get("platform_name"),
        "scope_key": r.get("scope_key"),
        "start_date": schemas.serialize(r.get("start_date")),
        "end_date": schemas.serialize(r.get("end_date")),
        "enabled_shop_count": r.get("enabled_shop_count"),
        "covered_shop_count": r.get("covered_shop_count"),
        "missing_shop_count": r.get("missing_shop_count"),
        "missing_shops": r.get("missing_shops"),
        "coverage_complete": r.get("coverage_complete"),
        "coverage_days": r.get("coverage_days"),
        "expected_days": r.get("expected_days"),
        "user_pay_amount": r.get("user_pay_amount"),
        "transaction_amount": r.get("transaction_amount"),
        "settlement_amount": r.get("settlement_amount"),
        "refund_amount_pay_time": r.get("refund_amount_pay_time"),
        "refund_rate_pay_time": r.get("refund_rate_pay_time"),
        "transaction_order_count": r.get("transaction_order_count"),
        "transaction_buyer_count": r.get("transaction_buyer_count"),
        "transaction_item_count": r.get("transaction_item_count"),
        "avg_customer_amount": r.get("avg_customer_amount"),
        "avg_item_amount": r.get("avg_item_amount"),
        "ad_spend_shop_promoted": r.get("ad_spend_shop_promoted"),
        "ad_spend_shop_bound": r.get("ad_spend_shop_bound"),
        "ad_attributed_transaction_amount": r.get("ad_attributed_transaction_amount"),
        "ad_attributed_transaction_share": r.get("ad_attributed_transaction_share"),
        "ad_spend_rate_net_refund_shop_bound": r.get("ad_spend_rate_net_refund_shop_bound"),
        "total_expense_rate_net_refund_shop_bound": r.get("total_expense_rate_net_refund_shop_bound"),
        "ad_efficiency_shop_promoted": r.get("ad_efficiency_shop_promoted"),
        "ad_efficiency_shop_bound": r.get("ad_efficiency_shop_bound"),
        "store_efficiency_shop_promoted": r.get("store_efficiency_shop_promoted"),
        "store_efficiency_shop_bound": r.get("store_efficiency_shop_bound"),
        "notes": "成交人数=各店之和（跨店不去重）；平台整体仅 mart 语义，无 shop_id=0",
    }
    return schemas.ok("get_platform_business_summary", data)


def compare_platform_business(platform_code="douyin", start_date=None, end_date=None,
                              scope_key="全店", metric_key="user_pay_amount"):
    """抖音平台环比：本期 vs 等长上期。比例返回百分点+相对变化。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_scope(scope_key)
    _check_platform(platform_code)

    rows = database.query(
        "SELECT * FROM mart.compare_platform_business(%s, %s::date, %s::date, %s, %s)",
        (platform_code, start_date, end_date, scope_key, metric_key))
    if not rows:
        return schemas.err("compare_platform_business", "NO_DATA", "本期或上期无数据")
    r = rows[0]
    data = {
        "platform_code": r.get("platform_code"),
        "platform_name": r.get("platform_name"),
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
        "enabled_shop_count": r.get("enabled_shop_count"),
        "covered_shop_count": r.get("covered_shop_count"),
        "current_coverage_complete": r.get("current_coverage_complete"),
        "previous_coverage_complete": r.get("previous_coverage_complete"),
        "comparison_status": r.get("comparison_status"),
    }
    return schemas.ok("compare_platform_business", data)


def get_shop_contribution(platform_code="douyin", start_date=None, end_date=None,
                          scope_key="全店", metric_key="user_pay_amount"):
    """抖音店铺贡献度：单店值/平台总额/占比（本期+上期+变化）。贡献度和=100%（数据完整且指标可加时）。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_scope(scope_key)
    _check_platform(platform_code)

    rows = database.query(
        "SELECT * FROM mart.get_shop_contribution(%s, %s::date, %s::date, %s, %s)",
        (platform_code, start_date, end_date, scope_key, metric_key))
    if not rows:
        return schemas.err("get_shop_contribution", "NO_DATA", "该区间无数据")
    data = [{
        "shop_name": r.get("shop_name"),
        "current_value": r.get("current_value"),
        "platform_total": r.get("platform_total"),
        "contribution": r.get("contribution"),
        "previous_value": r.get("previous_value"),
        "previous_contribution": r.get("previous_contribution"),
        "contribution_change": r.get("contribution_change"),
        "coverage_complete": r.get("coverage_complete"),
    } for r in rows]
    return schemas.ok("get_shop_contribution", data)


def decompose_platform_change_by_shop(platform_code="douyin", start_date=None, end_date=None,
                                      scope_key="全店", metric_key="user_pay_amount"):
    """抖音平台变化按店铺拆解：net_change/gross_negative/gross_positive/negative_impact_share（单店负向/全部负向）。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_scope(scope_key)
    _check_platform(platform_code)

    rows = database.query(
        "SELECT * FROM mart.decompose_platform_change_by_shop(%s, %s::date, %s::date, %s, %s)",
        (platform_code, start_date, end_date, scope_key, metric_key))
    if not rows:
        return schemas.err("decompose_platform_change_by_shop", "NO_DATA", "该区间无数据")
    data = [{
        "shop_name": r.get("shop_name"),
        "current_value": r.get("current_value"),
        "previous_value": r.get("previous_value"),
        "absolute_change": r.get("absolute_change"),
        "relative_change": r.get("relative_change"),
        "net_change": r.get("net_change"),
        "gross_negative_impact": r.get("gross_negative_impact"),
        "gross_positive_offset": r.get("gross_positive_offset"),
        "negative_impact_share": r.get("negative_impact_share"),
    } for r in rows]
    return schemas.ok("decompose_platform_change_by_shop", data)
