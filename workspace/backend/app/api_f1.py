# -*- coding: utf-8 -*-
"""F1.0 扩展 API：趋势/店铺贡献/诊断详情/拆解/漏斗/实体详情
全部包装白名单函数（不新增数据库对象）；Backend 只做参数校验与格式。"""
import datetime

from fastapi import APIRouter, Query

import db
from errors import ApiError, ok

router = APIRouter(prefix="/api/v1", tags=["f1.0"])

# Scope / 趋势指标 / 周期 / 店铺解析：统一使用共享模块（P2-02）
from services import VALID_SCOPES, TREND_METRICS, check_period, resolve_shop_name






# ===== 趋势（DAILY_FACT 日序列；Backend 包装逐日查询，不新增 DB 对象） =====
@router.get("/business/trend")
def business_trend(shop_code: str = Query(None), start_date: str = Query(...), end_date: str = Query(...),
                   scope_key: str = Query("全店"), metric_key: str = Query("transaction_amount")):
    # F1.0.2 第八节重构：单次 SELECT（mart.get_business_daily_trend 确定性日序列函数），不再按天循环调用
    s, e = check_period(start_date, end_date)
    if scope_key not in VALID_SCOPES:
        raise ApiError("UNKNOWN_SCOPE", "未知经营口径: {}".format(scope_key))
    if metric_key not in TREND_METRICS:
        raise ApiError("UNKNOWN_METRIC", "趋势接口不支持指标: {}（受控集合: {}）".format(metric_key, sorted(TREND_METRICS)))
    shop_name = resolve_shop_name(shop_code)
    rows, _ = db.query(
        "SELECT biz_date, metric_key, metric_value FROM mart.get_business_daily_trend(%s, %s::date, %s::date, %s, %s)",
        (shop_name, start_date, end_date, scope_key, metric_key))
    points = [{"date": r["biz_date"].isoformat(), "metric_value": r["metric_value"]} for r in rows]
    return ok(points, {"metric_key": metric_key, "metric_name_cn": "成交金额" if metric_key == "transaction_amount" else metric_key,
                       "data_time_type": "DAILY_FACT", "grain": "day"})


# ===== 店铺贡献（平台模式：两店贡献 + 净变化拆解） =====
@router.get("/business/shop-contribution")
def shop_contribution(start_date: str = Query(...), end_date: str = Query(...), scope_key: str = Query("全店"),
                      metric_key: str = Query("user_pay_amount")):
    check_period(start_date, end_date)
    # get_shop_contribution(p_platform_code, p_sd, p_ed, p_scope, p_metric)
    shops_rows, _ = db.query("SELECT * FROM mart.get_shop_contribution(%s, %s::date, %s::date, %s, %s)",
                             ("douyin", start_date, end_date, scope_key, metric_key))
    # decompose_platform_change_by_shop(p_platform_code, p_sd, p_ed, p_scope, p_metric)
    dec_rows, _ = db.query("SELECT * FROM mart.decompose_platform_change_by_shop(%s, %s::date, %s::date, %s, %s)",
                           ("douyin", start_date, end_date, scope_key, metric_key))
    return ok({"shops": shops_rows or [], "decomposition": dec_rows[0] if dec_rows else None})


# ===== 诊断结果（详情/路径/漏斗/拆解） =====
@router.get("/diagnostics/results")
def diagnostic_results(start_date: str = Query(...), end_date: str = Query(...),
                       domain_key: str = Query("shop")):
    check_period(start_date, end_date)
    # P0-03 修复：get_diagnostic_result 为平台级正式函数（无店铺维度），移除假 shop_code 参数；
    # 页面明确为"平台级诊断"（supports_shop=false），避免"UI 筛店、数据没筛店"
    rows, _ = db.query("SELECT * FROM mart.get_diagnostic_result(%s, %s::date, %s::date, %s, %s)",
                       ("douyin", start_date, end_date, domain_key, None))
    return ok(rows)


@router.get("/diagnostics/funnel")
def diagnostic_funnel(shop_code: str = Query(...), domain_key: str = Query("shop"),
                      entity_name: str = Query(...), start_date: str = Query(...), end_date: str = Query(...)):
    check_period(start_date, end_date)
    shop_name = resolve_shop_name(shop_code)
    rows, _ = db.query("SELECT * FROM mart.get_funnel_diagnosis(%s, %s, %s::date, %s::date, %s, %s)",
                       (domain_key, entity_name, start_date, end_date, shop_name, "全店"))
    return ok(rows)


@router.get("/diagnostics/decomposition")
def decomposition(start_date: str = Query(...), end_date: str = Query(...), scope_key: str = Query("全店")):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.decompose_platform_change_by_shop(%s, %s::date, %s::date, %s, %s)",
                       ("douyin", start_date, end_date, scope_key, "user_pay_amount"))
    if not rows:
        raise ApiError("NO_DATA")
    return ok(rows[0])


# ===== 风险详情（实体异常） / 机会详情（实体机会） =====
@router.get("/risks/detail")
def risk_detail(domain_key: str = Query(...), entity_name: str = Query(...),
                start_date: str = Query(...), end_date: str = Query(...)):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_entity_anomalies(%s, %s, %s, %s::date, %s::date)",
                       ("douyin", domain_key, entity_name, start_date, end_date))
    return ok(rows)


@router.get("/opportunities/detail")
def opportunity_detail(domain_key: str = Query(...), entity_name: str = Query(...),
                       start_date: str = Query(...), end_date: str = Query(...)):
    check_period(start_date, end_date)
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


# ===== 达人/账号（P1-06：白名单已有正式函数，补薄包装；不再标 NOT_READY） =====
SALE_SCOPES = {"全部", "自营", "合作"}


@router.get("/accounts/summary")
def accounts_summary(shop_code: str = Query(...), start_date: str = Query(...), end_date: str = Query(...),
                     sale_scope: str = Query("全部"), account_name: str = Query(None)):
    check_period(start_date, end_date)
    if sale_scope not in SALE_SCOPES:
        raise ApiError("UNKNOWN_SCOPE", "账号接口 sale_scope 仅支持: 全部/自营/合作")
    shop = resolve_shop_name(shop_code)
    if not shop:
        raise ApiError("SELECT_SHOP_REQUIRED", "账号分析为店铺级能力，请选择店铺")
    rows, _ = db.query("SELECT * FROM mart.get_account_period_summary(%s, %s::date, %s::date, %s, %s)",
                       (shop, start_date, end_date, sale_scope, account_name))
    return ok(rows)


@router.get("/accounts/top")
def accounts_top(shop_code: str = Query(...), start_date: str = Query(...), end_date: str = Query(...),
                 sale_scope: str = Query("全部"), metric_key: str = Query("user_pay_amount"),
                 limit: int = Query(50, ge=1, le=100)):
    check_period(start_date, end_date)
    if sale_scope not in SALE_SCOPES:
        raise ApiError("UNKNOWN_SCOPE", "账号接口 sale_scope 仅支持: 全部/自营/合作")
    shop = resolve_shop_name(shop_code)
    if not shop:
        raise ApiError("SELECT_SHOP_REQUIRED", "账号分析为店铺级能力，请选择店铺")
    rows, _ = db.query(
        "SELECT * FROM mart.rank_accounts(%s, %s::date, %s::date, %s, %s, %s, %s, %s, %s, %s)",
        (shop, start_date, end_date, sale_scope, metric_key, "current_value", "DESC", limit, False, None))
    return ok(rows)


@router.get("/accounts/contribution")
def accounts_contribution(shop_code: str = Query(...), start_date: str = Query(...), end_date: str = Query(...),
                          sale_scope: str = Query("全部"), metric_key: str = Query("user_pay_amount"),
                          limit: int = Query(20, ge=1, le=100)):
    check_period(start_date, end_date)
    if sale_scope not in SALE_SCOPES:
        raise ApiError("UNKNOWN_SCOPE", "账号接口 sale_scope 仅支持: 全部/自营/合作")
    shop = resolve_shop_name(shop_code)
    if not shop:
        raise ApiError("SELECT_SHOP_REQUIRED", "账号分析为店铺级能力，请选择店铺")
    rows, _ = db.query(
        "SELECT * FROM mart.get_account_contribution(%s, %s::date, %s::date, %s, %s, %s, %s, %s)",
        (shop, start_date, end_date, sale_scope, metric_key, None, False, limit))
    return ok(rows)


# ===== F1.0.2 7.2 风险中心完整列表（get_anomalies ×3，白名单已有，补薄包装） =====
@router.get("/risks/complete")
def risks_complete(start_date: str = Query(...), end_date: str = Query(...),
                   domain_key: str = Query(None), entity_name: str = Query(None),
                   severity: str = Query(None), status: str = Query(None),
                   limit: int = Query(100, ge=1, le=500)):
    check_period(start_date, end_date)
    rows, _ = db.query(
        "SELECT * FROM mart.get_anomalies(%s, %s::date, %s::date, %s, %s, %s, %s)",
        ("douyin", start_date, end_date, domain_key, entity_name, severity, status))
    if limit and len(rows) > limit:
        rows = rows[:limit]
    return ok(rows)


@router.get("/risks/summary")
def risks_summary(start_date: str = Query(...), end_date: str = Query(...),
                  status: str = Query(None)):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_anomaly_summary(%s, %s::date, %s::date, %s)",
                       ("douyin", start_date, end_date, status))
    return ok(rows)


@router.get("/risks/entity")
def risks_entity(domain_key: str = Query(...), entity_name: str = Query(...),
                 start_date: str = Query(...), end_date: str = Query(...)):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_entity_anomalies(%s, %s, %s, %s::date, %s::date)",
                       ("douyin", domain_key, entity_name, start_date, end_date))
    return ok(rows)


# ===== F1.0.2 7.3 机会中心完整列表（get_growth_opportunities ×3） =====
@router.get("/opportunities/complete")
def opportunities_complete(start_date: str = Query(...), end_date: str = Query(...),
                           domain_key: str = Query(None), opportunity_code: str = Query(None),
                           min_level: str = Query(None), limit: int = Query(100, ge=1, le=500)):
    check_period(start_date, end_date)
    rows, _ = db.query(
        "SELECT * FROM mart.get_growth_opportunities(%s, %s::date, %s::date, %s, %s, %s)",
        ("douyin", start_date, end_date, domain_key, opportunity_code, min_level))
    if limit and len(rows) > limit:
        rows = rows[:limit]
    return ok(rows)


@router.get("/opportunities/summary")
def opportunities_summary(start_date: str = Query(...), end_date: str = Query(...),
                          status: str = Query(None)):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_opportunity_summary(%s, %s::date, %s::date, %s)",
                       ("douyin", start_date, end_date, status))
    return ok(rows)


@router.get("/opportunities/entity")
def opportunities_entity(domain_key: str = Query(...), entity_name: str = Query(...),
                         start_date: str = Query(...), end_date: str = Query(...)):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_entity_opportunity(%s, %s, %s, %s::date, %s::date)",
                       ("douyin", domain_key, entity_name, start_date, end_date))
    return ok(rows)


# ===== F1.0.2 7.4 广告诊断（get_advertising_diagnosis，白名单已有；domain_key 有效值 shop/scope） =====
@router.get("/diagnostics/advertising")
def advertising_diagnosis(domain_key: str = Query("shop"), entity_name: str = Query(None),
                          start_date: str = Query(...), end_date: str = Query(...),
                          shop_code: str = Query(None)):
    check_period(start_date, end_date)
    shop = resolve_shop_name(shop_code)
    rows, _ = db.query(
        "SELECT * FROM mart.get_advertising_diagnosis(%s, %s, %s::date, %s::date, %s)",
        (domain_key, entity_name, start_date, end_date, shop))
    return ok(rows)


# ===== F1.0.2 7.5/7.6 品线 / Master Product 经营（白名单 4 新函数，薄包装） =====
@router.get("/product-lines/summary")
def product_line_summary(product_line_name: str = Query(...),
                         start_date: str = Query(...), end_date: str = Query(...)):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.get_product_line_period_summary(%s, %s::date, %s::date)",
                       (product_line_name, start_date, end_date))
    if not rows:
        raise ApiError("NO_DATA")
    return ok(rows[0])


@router.get("/master-products/summary")
def master_product_summary(master_product_id: int = Query(...),
                           start_date: str = Query(...), end_date: str = Query(...),
                           shop_code: str = Query(None)):
    check_period(start_date, end_date)
    shop = resolve_shop_name(shop_code)
    rows, _ = db.query("SELECT * FROM mart.get_master_product_period_summary(%s, %s::date, %s::date, %s)",
                       (master_product_id, start_date, end_date, shop))
    if not rows:
        raise ApiError("NO_DATA")
    return ok(rows[0])


@router.get("/master-products/rank")
def master_product_rank(start_date: str = Query(...), end_date: str = Query(...),
                        metric_key: str = Query("user_pay_amount"),
                        sort_direction: str = Query("DESC"), limit: int = Query(50, ge=1, le=100)):
    check_period(start_date, end_date)
    if metric_key != "user_pay_amount":
        raise ApiError("UNSUPPORTED_METRIC", "rank_master_products 仅支持 metric_key=user_pay_amount")
    rows, _ = db.query(
        "SELECT * FROM mart.rank_master_products(%s::date, %s::date, %s, %s, %s, %s)",
        (start_date, end_date, metric_key, "current_value", sort_direction, limit))
    return ok(rows)


@router.get("/master-products/decompose")
def master_product_decompose(master_product_id: int = Query(...),
                             start_date: str = Query(...), end_date: str = Query(...)):
    check_period(start_date, end_date)
    rows, _ = db.query("SELECT * FROM mart.decompose_master_product_by_shop_product(%s, %s::date, %s::date)",
                       (master_product_id, start_date, end_date))
    return ok(rows)


# ===== F1.0.2 九：智能刷新状态（只读；FRESH=智能≥事实 / STALE=事实更新未重算） =====
@router.get("/intelligence-status")
def intelligence_status():
    # 事实日期经正式白名单函数 get_data_coverage（core 不可直读）
    rows, _ = db.query("SELECT * FROM mart.get_data_coverage(NULL)")
    fact = rows[0]["max_date"] if rows else None
    srows, _ = db.query("""
SELECT
  (SELECT max(current_start_date) FROM mart.anomaly_event) AS anomaly_max,
  (SELECT max(current_start_date) FROM mart.diagnostic_result) AS diagnosis_max,
  (SELECT max(current_start_date) FROM mart.opportunity_event) AS opportunity_max,
  (SELECT max(current_start_date) FROM mart.daily_action_item) AS action_max,
  (SELECT max(triggered_at) FROM audit.intelligence_run_log WHERE status='SUCCESS') AS last_run_at
""")
    r = srows[0] if srows else {}
    anomaly = r.get("anomaly_max")
    diagnosis = r.get("diagnosis_max")
    opportunity = r.get("opportunity_max")
    action = r.get("action_max")
    stale = bool(fact and (not anomaly or fact > anomaly))
    return ok({
        "latest_fact_date": fact.isoformat() if fact else None,
        "latest_anomaly_generated_date": anomaly.isoformat() if anomaly else None,
        "latest_diagnosis_generated_date": diagnosis.isoformat() if diagnosis else None,
        "latest_opportunity_generated_date": opportunity.isoformat() if opportunity else None,
        "latest_priority_generated_date": action.isoformat() if action else None,
        "last_run_at": r.get("last_run_at").isoformat() if r.get("last_run_at") else None,
        "intelligence_status": "STALE" if stale else "FRESH",
    })


# ===== F1.0.3 商品卡快照（PERIOD_SNAPSHOT：周期×商品，禁日趋势；白名单 mart.product_card_*） =====
@router.get("/product-card/snapshot-summary")
def product_card_snapshot_summary(start_date: str = Query(...), end_date: str = Query(...),
                                  shop_code: str = Query(None)):
    check_period(start_date, end_date)
    shop = resolve_shop_name(shop_code)
    rows, _ = db.query("SELECT * FROM mart.product_card_snapshot_summary(%s, %s::date, %s::date)",
                       (shop, start_date, end_date))
    if not rows:
        raise ApiError("NO_DATA", "该区间无商品卡快照数据（统计周期以源文件导出周期为准）")
    return ok(rows[0])


@router.get("/product-card/snapshot-rank")
def product_card_snapshot_rank(start_date: str = Query(...), end_date: str = Query(...),
                               shop_code: str = Query(None),
                               metric_key: str = Query("user_pay_amount"),
                               sort_direction: str = Query("DESC"), limit: int = Query(50, ge=1, le=200)):
    check_period(start_date, end_date)
    shop = resolve_shop_name(shop_code)
    try:
        rows, _ = db.query(
            "SELECT * FROM mart.rank_product_card_snapshot(%s, %s::date, %s::date, %s, %s, %s)",
            (shop, start_date, end_date, metric_key, sort_direction, limit))
    except Exception as e:
        if "UNSUPPORTED_METRIC" in str(e):
            raise ApiError("UNSUPPORTED_METRIC", "商品卡快照仅支持 user_pay_amount/transaction_users/exposure_users/click_users/transaction_orders")
        raise
    return ok(rows)


# ===== F1.0.3 视频快照（PERIOD_SNAPSHOT，周期×视频；禁日趋势） =====
@router.get("/video/snapshot-summary")
def video_snapshot_summary(start_date: str = Query(...), end_date: str = Query(...),
                           shop_code: str = Query(None)):
    check_period(start_date, end_date)
    shop = resolve_shop_name(shop_code)
    rows, _ = db.query("SELECT * FROM mart.video_snapshot_summary(%s, %s::date, %s::date)",
                       (shop, start_date, end_date))
    if not rows:
        raise ApiError("NO_DATA", "该周期无视频快照数据（统计周期以源文件导出周期为准）")
    return ok(rows[0])


@router.get("/video/snapshot-rank")
def video_snapshot_rank(start_date: str = Query(...), end_date: str = Query(...),
                        shop_code: str = Query(None), selling_type: str = Query(None),
                        carrier_type: str = Query(None),
                        metric_key: str = Query("user_pay_amount"),
                        sort_direction: str = Query("DESC"), limit: int = Query(50, ge=1, le=200)):
    check_period(start_date, end_date)
    shop = resolve_shop_name(shop_code)
    try:
        rows, _ = db.query(
            "SELECT * FROM mart.rank_video_snapshot(%s, %s::date, %s::date, %s, %s, %s, %s, %s)",
            (shop, start_date, end_date, selling_type, carrier_type, metric_key, sort_direction, limit))
    except Exception as e:
        if "UNSUPPORTED_METRIC" in str(e):
            raise ApiError("UNSUPPORTED_METRIC", "视频快照仅支持 user_pay_amount/view_count/transaction_orders/transaction_users")
        raise
    return ok(rows)


# ===== F1.0.3 素材快照（PERIOD_SNAPSHOT，周期×素材） =====
@router.get("/materials/snapshot-rank")
def material_snapshot_rank(start_date: str = Query(...), end_date: str = Query(...),
                           shop_code: str = Query(None), metric_key: str = Query("user_pay_amount"),
                           sort_direction: str = Query("DESC"), limit: int = Query(50, ge=1, le=200)):
    check_period(start_date, end_date)
    shop = resolve_shop_name(shop_code)
    try:
        rows, _ = db.query("SELECT * FROM mart.rank_material_snapshot(%s, %s::date, %s::date, %s, %s, %s)",
                           (shop, start_date, end_date, metric_key, sort_direction, limit))
    except Exception as e:
        if "UNSUPPORTED_METRIC" in str(e):
            raise ApiError("UNSUPPORTED_METRIC", "素材快照仅支持 user_pay_amount/ad_spend/exposure_count/transaction_orders")
        raise
    return ok(rows)


# ===== F1.0.3 直播场次（SESSION_FACT）与直播日数据（DAILY_FACT） =====
@router.get("/live/sessions")
def live_sessions(shop_code: str = Query(None), period_key: str = Query(None), limit: int = Query(200, ge=1, le=500)):
    shop = resolve_shop_name(shop_code)
    sql = "SELECT * FROM mart.live_session_snapshot WHERE 1=1"
    args = []
    if shop:
        sql += " AND shop_name=%s"; args.append(shop)
    if period_key:
        sql += " AND period_key=%s"; args.append(period_key)
    sql += " ORDER BY start_time DESC LIMIT %s"; args.append(limit)
    rows, _ = db.query(sql, tuple(args))
    return ok(rows)


@router.get("/live/daily")
def live_daily(shop_code: str = Query(None)):
    shop = resolve_shop_name(shop_code)
    sql = "SELECT * FROM mart.live_daily"
    args = []
    if shop:
        sql += " WHERE shop_name=%s"; args.append(shop)
    sql += " ORDER BY biz_date NULLS LAST"
    rows, _ = db.query(sql, tuple(args) if args else None)
    return ok(rows)


# ===== F1.0.3 商品卡流量来源（PERIOD_SNAPSHOT，周期×渠道） =====
@router.get("/product-card/traffic")
def product_card_traffic(start_date: str = Query(...), end_date: str = Query(...),
                         shop_code: str = Query(None)):
    check_period(start_date, end_date)
    shop = resolve_shop_name(shop_code)
    sql = "SELECT * FROM mart.product_card_traffic_snapshot WHERE period_start=%s::date AND period_end=%s::date"
    args = [start_date, end_date]
    if shop:
        sql += " AND shop_name=%s"; args.append(shop)
    sql += " ORDER BY user_pay_amount DESC"
    rows, _ = db.query(sql, tuple(args))
    return ok(rows)
