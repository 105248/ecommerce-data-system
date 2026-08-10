# -*- coding: utf-8 -*-
"""F0.5 Backend API 路由：系统健康/数据状态/店铺/经营/主数据/优先级"""
from fastapi import APIRouter, Query, Request

import db
from errors import ApiError, ok
from services import VALID_SCOPES, TREND_METRICS, check_period, resolve_shop_name

router = APIRouter(prefix="/api/v1", tags=["f0.5"])

# check_period 统一来自 services（F1.0.4-R2：删除本地重复定义，避免与 services 行为分叉）


# ===== health / ready =====
@router.get("/health")
def health():
    return ok({"status": "OK", "service": "growth-workspace-backend"})


@router.get("/ready")
def ready(request: Request):
    r = db.health_check_db()
    if r["database"] == "OK":
        return ok({k: v for k, v in r.items() if k != "detail"})
    # P2-04：错误细节只写服务日志，不暴露给客户端
    request.state.status_code = 503
    raise ApiError("DATABASE_UNAVAILABLE", "数据库不可用", status_code=503)


# ===== data-status =====
@router.get("/data-status")
def data_status(platform_code: str = Query("douyin"), shop_code: str = Query(None)):
    # P1-04 修复：get_data_coverage 参数是 shop_name（NULL=平台），shop_code 必须先转换
    # F1.0.2 4.6：platform_code 显式校验（当前仅支持 douyin，假参数一律拒绝）
    if platform_code != "douyin":
        raise ApiError("UNSUPPORTED_PLATFORM", "当前仅支持平台: douyin")
    shop_name = resolve_shop_name(shop_code) if shop_code else None
    rows, _ = db.query("SELECT * FROM mart.get_data_coverage(%s)", (shop_name,))
    if not rows:
        raise ApiError("NO_DATA")
    return ok(rows)


# ===== shops =====
@router.get("/shops")
def shops(platform_code: str = Query("douyin")):
    rows, _ = db.query(
        "SELECT platform_code, shop_code, shop_name, enabled FROM meta.shop WHERE platform_code=%s ORDER BY shop_id",
        (platform_code,))
    return ok(rows)


# ===== business summary =====
@router.get("/business/summary")
def business_summary(platform_code: str = Query("douyin"), shop_code: str = Query(None),
                     start_date: str = Query(...), end_date: str = Query(...),
                     scope_key: str = Query("全店")):
    check_period(start_date, end_date)
    if scope_key not in VALID_SCOPES:
        raise ApiError("UNKNOWN_SCOPE", "未知经营口径: {}".format(scope_key))
    shop_name = resolve_shop_name(shop_code)
    request_db_ms = {}
    if shop_name:
        rows, ms = db.query(
            "SELECT * FROM mart.get_business_period_summary(%s, %s::date, %s::date, %s)",
            (shop_name, start_date, end_date, scope_key))
    else:
        rows, ms = db.query(
            "SELECT * FROM mart.get_platform_business_period_summary(%s, %s::date, %s::date, %s)",
            (platform_code, start_date, end_date, scope_key))
    if not rows:
        raise ApiError("NO_DATA")
    r = rows[0]
    data = {
        "platform_code": platform_code,
        "shop_code": shop_code,
        "shop_name": shop_name,
        "scope_key": scope_key,
        "start_date": start_date, "end_date": end_date,
        "transaction_amount": r.get("transaction_amount"),
        "user_pay_amount": r.get("user_pay_amount"),
        "refund_amount_pay_time": r.get("refund_amount_pay_time"),
        "transaction_refund_amount_pay_time": r.get("transaction_refund_amount_pay_time"),
        "settlement_amount": r.get("settlement_amount"),
        "refund_rate": r.get("refund_rate_pay_time"),
        "ad_spend_shop_bound": r.get("ad_spend_shop_bound"),
        "ad_spend_rate_net_refund_shop_bound": r.get("ad_spend_rate_net_refund_shop_bound"),
    }
    meta = {
        "current_period": {"start_date": start_date, "end_date": end_date},
        "coverage_complete": r.get("coverage_complete"),
        "expected_days": r.get("expected_days"),
        "coverage_days": r.get("coverage_days"),
        "enabled_shop_count": r.get("enabled_shop_count"),
        "covered_shop_count": r.get("covered_shop_count"),
        "data_max_date": r.get("data_max_date"),
        "source_function": "mart.get_business_period_summary" if shop_name else "mart.get_platform_business_period_summary",
    }
    return ok(data, meta)


# ===== F1.0.4-R3 周期进度（日报/周报/月报同结构）：3 店铺表 × 6 经营类型 × 6 指标 =====
@router.get("/business/cycle-report")
def business_cycle_report(start_date: str = Query(...), end_date: str = Query(...)):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_cycle_report(%s::date, %s::date)",
                       (start_date, end_date))
    if not rows:
        raise ApiError("NO_DATA", "该区间无经营数据")
    return ok({"start_date": start_date, "end_date": end_date, "rows": rows})


# ===== business compare =====
@router.get("/business/compare")
def business_compare(platform_code: str = Query("douyin"), shop_code: str = Query(None),
                     start_date: str = Query(...), end_date: str = Query(...),
                     scope_key: str = Query("全店"), metric_key: str = Query("user_pay_amount")):
    check_period(start_date, end_date)
    shop_name = resolve_shop_name(shop_code)
    if shop_name:
        rows, _ = db.query(
            "SELECT * FROM mart.compare_business_period(%s, %s::date, %s::date, %s, %s)",
            (shop_name, start_date, end_date, scope_key, metric_key))
    else:
        rows, _ = db.query(
            "SELECT * FROM mart.compare_platform_business(%s, %s::date, %s::date, %s, %s)",
            (platform_code, start_date, end_date, scope_key, metric_key))
    if not rows:
        raise ApiError("NO_DATA")
    return ok(rows[0])


# ===== products top =====
@router.get("/business/products/top")
def products_top(shop_code: str = Query(...), start_date: str = Query(...), end_date: str = Query(...),
                 metric_key: str = Query("user_pay_amount"), limit: int = Query(10, ge=1, le=100)):
    check_period(start_date, end_date)
    shop_name = resolve_shop_name(shop_code)  # rank 按店铺，必须指定
    # rank_products(p_shop_name, p_sd, p_ed, p_metric, p_sort_by, p_sort_direction, p_limit, p_product_id, p_product_name)
    rows, _ = db.query(
        "SELECT * FROM mart.rank_products(%s, %s::date, %s::date, %s, %s, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, metric_key, "current_value", "DESC", limit, None, None))
    return ok(rows)


# ===== master-data =====
@router.get("/master-data/product-lines")
def product_lines():
    rows, _ = db.query("SELECT product_line_code, product_line_name, enabled FROM meta.product_line ORDER BY product_line_id")
    return ok(rows)


@router.get("/master-data/products")
def master_products(page: int = Query(1, ge=1), page_size: int = Query(50, ge=1, le=200)):
    # P2-03：移除无实际作用的 shop_code 参数（避免契约误导）
    rows, _ = db.query(
        "SELECT master_product_code, master_product_name, enabled FROM meta.master_product ORDER BY master_product_id LIMIT %s OFFSET %s",
        (page_size, (page - 1) * page_size))
    return ok(rows, {"page": page, "page_size": page_size})


@router.get("/master-data/resolve")
def resolve(shop_code: str = Query(...), platform_product_id: str = Query(...)):
    shop_name = resolve_shop_name(shop_code)
    # resolve_master_product(p_platform_code, p_shop_name, p_platform_product_id, p_biz_date)
    rows, _ = db.query(
        "SELECT * FROM mart.resolve_master_product(%s, %s, %s, CURRENT_DATE)",
        ("douyin", shop_name, platform_product_id))
    if not rows:
        raise ApiError("NO_DATA", "该商品无映射")
    return ok(rows[0])


# ===== priorities =====
def _priorities(router_fn, fn_name, platform_code, start_date, end_date, limit, item_type=None):
    check_period(start_date, end_date)
    # get_daily_action_list 需 item_type；risk/opportunity 无需
    if fn_name == "get_daily_action_list":
        rows, _ = db.query("SELECT * FROM mart.{}(%s, %s::date, %s::date, %s, %s)".format(fn_name),
                           (platform_code, start_date, end_date, item_type, limit))
    else:
        rows, _ = db.query("SELECT * FROM mart.{}(%s, %s::date, %s::date, %s)".format(fn_name),
                           (platform_code, start_date, end_date, limit))
    if not rows:
        raise ApiError("NO_DATA")
    return ok(rows)


@router.get("/priorities/risks")
def risks(platform_code: str = Query("douyin"), start_date: str = Query(...), end_date: str = Query(...),
          limit: int = Query(5, ge=1, le=50)):
    return _priorities("risks", "get_daily_risk_priorities", platform_code, start_date, end_date, limit)


@router.get("/priorities/opportunities")
def opportunities(platform_code: str = Query("douyin"), start_date: str = Query(...), end_date: str = Query(...),
                  limit: int = Query(5, ge=1, le=50)):
    return _priorities("opps", "get_daily_opportunity_priorities", platform_code, start_date, end_date, limit)


@router.get("/priorities/watchlist")
def watchlist(platform_code: str = Query("douyin"), start_date: str = Query(...), end_date: str = Query(...),
              item_type: str = Query(None), limit: int = Query(20, ge=1, le=100)):
    return _priorities("watch", "get_daily_action_list", platform_code, start_date, end_date, limit, item_type)


# ===== P2 骨架（READY / NOT_READY 明确返回） =====
@router.get("/business/rankings")
def rankings(shop_code: str = Query(None), start_date: str = Query(...), end_date: str = Query(...),
             metric_key: str = Query("user_pay_amount"), limit: int = Query(10, ge=1, le=100)):
    check_period(start_date, end_date)
    # P1-05 修复：rank_products 为店铺级能力，禁止用伪 'douyin' 代表整体
    shop_name = resolve_shop_name(shop_code)
    if not shop_name:
        raise ApiError("SELECT_SHOP_REQUIRED", "商品排名为店铺级能力，请选择店铺（正式接口无平台级商品排名）")
    rows, _ = db.query(
        "SELECT * FROM mart.rank_products(%s, %s::date, %s::date, %s, %s, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, metric_key, "current_value", "DESC", limit, None, None))
    return ok(rows)


@router.get("/diagnostics/snapshot")
def diag_snapshot(shop_code: str = Query(None), start_date: str = Query(...), end_date: str = Query(...),
                  domain_key: str = Query("shop")):
    check_period(start_date, end_date)
    shop_name = resolve_shop_name(shop_code)
    if shop_name:
        rows, _ = db.query(
            "SELECT * FROM mart.get_diagnostic_snapshot(%s, %s::date, %s::date, %s, %s, %s, %s, %s)",
            (shop_name, start_date, end_date, domain_key, None, None, None, None))
    else:
        rows, _ = db.query("SELECT * FROM mart.get_platform_diagnostic_snapshot(%s, %s::date, %s::date)",
                           ("douyin", start_date, end_date))
    if not rows:
        raise ApiError("NO_DATA")
    return ok(rows)


@router.get("/diagnostics/anomalies")
def anomalies(start_date: str = Query(...), end_date: str = Query(...)):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_anomalies(%s, %s::date, %s::date)", ("douyin", start_date, end_date))
    return ok(rows)


@router.get("/opportunities")
def opportunities_list(start_date: str = Query(...), end_date: str = Query(...)):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_growth_opportunities(%s, %s::date, %s::date, %s, %s)",
                       ("douyin", start_date, end_date, None, None))
    return ok(rows)


@router.get("/advertising/summary")
def advertising_summary(shop_code: str = Query(None), start_date: str = Query(...), end_date: str = Query(...),
                        scope_key: str = Query("全店")):
    check_period(start_date, end_date)
    shop_name = resolve_shop_name(shop_code)
    if not shop_name:
        raise ApiError("INVALID_ARGUMENT", "广告摘要需指定 shop_code")
    rows, _ = db.query("SELECT * FROM mart.get_advertising_period_summary(%s, %s::date, %s::date, %s)",
                       (shop_name, start_date, end_date, scope_key))
    if not rows:
        raise ApiError("NO_DATA")
    return ok(rows[0])
