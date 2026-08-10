# -*- coding: utf-8 -*-
"""F1.0 扩展 API：趋势/店铺贡献/诊断详情/拆解/漏斗/实体详情
全部包装白名单函数（不新增数据库对象）；Backend 只做参数校验与格式。"""
import datetime

from fastapi import APIRouter, Query

import db
from errors import ApiError, ok

router = APIRouter(prefix="/api/v1", tags=["f1.0"])

VALID_SCOPES = {"全店", "自营", "合作", "商品卡", "短视频", "直播", "图文", "其他"}


def _check_period(start_date, end_date):
    try:
        s = datetime.date.fromisoformat(start_date)
        e = datetime.date.fromisoformat(end_date)
    except ValueError:
        raise ApiError("INVALID_ARGUMENT", "日期格式须为 YYYY-MM-DD")
    if s > e:
        raise ApiError("INVALID_ARGUMENT", "start_date 不能晚于 end_date")
    return s, e


def _shop_name(shop_code):
    if not shop_code:
        return None
    rows, _ = db.query("SELECT shop_name, enabled FROM meta.shop WHERE shop_code = %s", (shop_code,))
    if not rows:
        rows, _ = db.query("SELECT shop_name, enabled FROM meta.shop WHERE shop_name = %s", (shop_code,))
    if not rows:
        raise ApiError("UNKNOWN_SHOP", "未知店铺: {}".format(shop_code))
    return rows[0]["shop_name"]


# ===== 趋势（DAILY_FACT 日序列；Backend 包装逐日查询，不新增 DB 对象） =====
@router.get("/business/trend")
def business_trend(shop_code: str = Query(None), start_date: str = Query(...), end_date: str = Query(...),
                   scope_key: str = Query("全店"), metric_key: str = Query("user_pay_amount")):
    s, e = _check_period(start_date, end_date)
    if scope_key not in VALID_SCOPES:
        raise ApiError("UNKNOWN_SCOPE", "未知经营口径: {}".format(scope_key))
    shop_name = _shop_name(shop_code)
    points = []
    day = s
    while day <= e:
        ds = day.isoformat()
        if shop_name:
            rows, _ = db.query(
                "SELECT user_pay_amount, refund_rate_pay_time, ad_spend_shop_bound, settlement_amount "
                "FROM mart.get_business_period_summary(%s, %s::date, %s::date, %s)",
                (shop_name, ds, ds, scope_key))
        else:
            rows, _ = db.query(
                "SELECT user_pay_amount, refund_rate_pay_time, ad_spend_shop_bound, settlement_amount "
                "FROM mart.get_platform_business_period_summary(%s, %s::date, %s::date, %s)",
                ("douyin", ds, ds, scope_key))
        r = rows[0] if rows else {}
        points.append({"date": ds, "user_pay_amount": r.get("user_pay_amount"),
                       "refund_rate_pay_time": r.get("refund_rate_pay_time"),
                       "ad_spend_shop_bound": r.get("ad_spend_shop_bound"),
                       "settlement_amount": r.get("settlement_amount")})
        day += datetime.timedelta(days=1)
    return ok(points, {"metric_key": metric_key, "data_time_type": "DAILY_FACT", "grain": "day"})


# ===== 店铺贡献（平台模式：两店贡献 + 净变化拆解） =====
@router.get("/business/shop-contribution")
def shop_contribution(start_date: str = Query(...), end_date: str = Query(...), scope_key: str = Query("全店"),
                      metric_key: str = Query("user_pay_amount")):
    _check_period(start_date, end_date)
    # get_shop_contribution(p_platform_code, p_sd, p_ed, p_scope, p_metric)
    shops_rows, _ = db.query("SELECT * FROM mart.get_shop_contribution(%s, %s::date, %s::date, %s, %s)",
                             ("douyin", start_date, end_date, scope_key, metric_key))
    # decompose_platform_change_by_shop(p_platform_code, p_sd, p_ed, p_scope, p_metric)
    dec_rows, _ = db.query("SELECT * FROM mart.decompose_platform_change_by_shop(%s, %s::date, %s::date, %s, %s)",
                           ("douyin", start_date, end_date, scope_key, metric_key))
    return ok({"shops": shops_rows or [], "decomposition": dec_rows[0] if dec_rows else None})


# ===== 诊断结果（详情/路径/漏斗/拆解） =====
@router.get("/diagnostics/results")
def diagnostic_results(shop_code: str = Query(None), start_date: str = Query(...), end_date: str = Query(...),
                       domain_key: str = Query("shop")):
    _check_period(start_date, end_date)
    # get_diagnostic_result(p_platform_code, p_sd, p_ed, p_domain, p_status)
    rows, _ = db.query("SELECT * FROM mart.get_diagnostic_result(%s, %s::date, %s::date, %s, %s)",
                       ("douyin", start_date, end_date, domain_key, None))
    return ok(rows)


@router.get("/diagnostics/funnel")
def diagnostic_funnel(shop_code: str = Query(...), domain_key: str = Query("shop"),
                      entity_name: str = Query(...), start_date: str = Query(...), end_date: str = Query(...)):
    _check_period(start_date, end_date)
    shop_name = _shop_name(shop_code)
    rows, _ = db.query("SELECT * FROM mart.get_funnel_diagnosis(%s, %s, %s::date, %s::date, %s, %s)",
                       (domain_key, entity_name, start_date, end_date, shop_name, "全店"))
    return ok(rows)


@router.get("/diagnostics/decomposition")
def decomposition(start_date: str = Query(...), end_date: str = Query(...), scope_key: str = Query("全店")):
    _check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.decompose_platform_change_by_shop(%s, %s::date, %s::date, %s, %s)",
                       ("douyin", start_date, end_date, scope_key, "user_pay_amount"))
    if not rows:
        raise ApiError("NO_DATA")
    return ok(rows[0])


# ===== 风险详情（实体异常） / 机会详情（实体机会） =====
@router.get("/risks/detail")
def risk_detail(domain_key: str = Query(...), entity_name: str = Query(...),
                start_date: str = Query(...), end_date: str = Query(...)):
    _check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_entity_anomalies(%s, %s, %s, %s::date, %s::date)",
                       ("douyin", domain_key, entity_name, start_date, end_date))
    return ok(rows)


@router.get("/opportunities/detail")
def opportunity_detail(domain_key: str = Query(...), entity_name: str = Query(...),
                       start_date: str = Query(...), end_date: str = Query(...)):
    _check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_entity_opportunity(%s, %s, %s, %s::date, %s::date)",
                       ("douyin", domain_key, entity_name, start_date, end_date))
    return ok(rows)


# ===== 品线 / MP 明细（白名单内组合） =====
@router.get("/master-data/product-line-members")
def product_line_members(product_line_code: str = Query(...)):
    # meta.product_line → master_product 关联（白名单视图，不新增对象）
    rows, _ = db.query(
        "SELECT mp.master_product_code, mp.master_product_name, mp.enabled "
        "FROM meta.master_product mp JOIN meta.product_line pl ON pl.product_line_id = mp.product_line_id "
        "WHERE pl.product_line_code = %s ORDER BY mp.master_product_id", (product_line_code,))
    return ok(rows)
