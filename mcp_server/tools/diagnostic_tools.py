# -*- coding: utf-8 -*-
"""V1.1 诊断基础层 Tools：get_diagnostic_snapshot / get_diagnostic_supported_metrics"""
import database
import schemas


def get_diagnostic_snapshot(shop_name=None, start_date=None, end_date=None,
                            domain_key=None, scope_key=None, entity_id=None,
                            entity_name=None, category_level=None):
    """统一经营诊断快照：一个对象×一个指标×当前期×上期，含值/变化/排名/贡献/覆盖/数据状态。
    域=platform/shop/scope/product/shop_product/master_product/product_line/carrier/account/category。
    本阶段只返回基础诊断数据，不判异常、不出原因结论。"""
    schemas.validate_period(start_date, end_date)
    if not domain_key:
        raise schemas.ArgError("INVALID_ARGUMENT", "domain_key 不能为空（platform/shop/scope/product/shop_product/master_product/product_line/carrier/account/category）")
    schemas.check_shop(shop_name, required=False)

    if domain_key == "platform":
        # 平台模式：p_platform_code=douyin + shop_name=NULL → 抖音整体快照（含 coverage）
        rows = database.query(
            "SELECT platform_code, platform_name, scope_key, entity_id, entity_name, "
            "metric_key, metric_name_cn, metric_group, metric_type, display_format, "
            "current_start_date, current_end_date, previous_start_date, previous_end_date, "
            "current_value, previous_value, absolute_change, relative_change, percentage_point_change, "
            "enabled_shop_count, covered_shop_count, current_coverage_complete, previous_coverage_complete, data_status "
            "FROM mart.get_platform_diagnostic_snapshot('douyin', %s::date, %s::date, %s)",
            (start_date, end_date, scope_key or "全店"))
        if not rows:
            return schemas.err("get_diagnostic_snapshot", "NO_DATA", "该区间无数据")
        return schemas.ok("get_diagnostic_snapshot", [dict(r) for r in rows])

    rows = database.query(
        "SELECT shop_name, domain_key, domain_name_cn, entity_id, entity_name, scope_key, "
        "metric_key, metric_name_cn, metric_group, metric_type, display_format, "
        "current_start_date, current_end_date, previous_start_date, previous_end_date, "
        "current_value, previous_value, absolute_change, relative_change, percentage_point_change, "
        "current_rank, previous_rank, rank_change, "
        "current_contribution, previous_contribution, contribution_change, "
        "contribution_denominator_type, contribution_denominator_value, "
        "current_coverage_days, expected_current_days, previous_coverage_days, expected_previous_days, "
        "current_coverage_complete, previous_coverage_complete, calculation_status, data_status, notes "
        "FROM mart.get_diagnostic_snapshot(%s, %s::date, %s::date, %s, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, domain_key, scope_key, entity_id, entity_name, category_level),
    )
    if not rows:
        return schemas.err("get_diagnostic_snapshot", "NO_DATA", "该区间/域无数据")
    data = []
    for r in rows:
        data.append({
            "shop_name": r.get("shop_name"),
            "domain_key": r.get("domain_key"),
            "domain_name_cn": r.get("domain_name_cn"),
            "entity_id": r.get("entity_id"),
            "entity_name": r.get("entity_name"),
            "scope_key": r.get("scope_key"),
            "metric_key": r.get("metric_key"),
            "metric_name_cn": r.get("metric_name_cn"),
            "metric_group": r.get("metric_group"),
            "metric_type": r.get("metric_type"),
            "display_format": r.get("display_format"),
            "current_start_date": schemas.serialize(r.get("current_start_date")),
            "current_end_date": schemas.serialize(r.get("current_end_date")),
            "previous_start_date": schemas.serialize(r.get("previous_start_date")),
            "previous_end_date": schemas.serialize(r.get("previous_end_date")),
            "current_value": r.get("current_value"),
            "previous_value": r.get("previous_value"),
            "absolute_change": r.get("absolute_change"),
            "relative_change": r.get("relative_change"),
            "percentage_point_change": r.get("percentage_point_change"),
            "current_rank": r.get("current_rank"),
            "previous_rank": r.get("previous_rank"),
            "rank_change": r.get("rank_change"),
            "current_contribution": r.get("current_contribution"),
            "previous_contribution": r.get("previous_contribution"),
            "contribution_change": r.get("contribution_change"),
            "contribution_denominator_type": r.get("contribution_denominator_type"),
            "contribution_denominator_value": r.get("contribution_denominator_value"),
            "current_coverage_days": r.get("current_coverage_days"),
            "expected_current_days": r.get("expected_current_days"),
            "previous_coverage_days": r.get("previous_coverage_days"),
            "expected_previous_days": r.get("expected_previous_days"),
            "current_coverage_complete": r.get("current_coverage_complete"),
            "previous_coverage_complete": r.get("previous_coverage_complete"),
            "calculation_status": r.get("calculation_status"),
            "data_status": r.get("data_status"),
            "notes": r.get("notes"),
        })
    return schemas.ok("get_diagnostic_snapshot", data)


def get_diagnostic_supported_metrics():
    """支持的诊断指标目录（已注册且 diagnostic_enabled=true 的指标）。"""
    rows = database.query("SELECT * FROM mart.get_diagnostic_supported_metrics()")
    if not rows:
        return schemas.err("get_diagnostic_supported_metrics", "NO_DATA", "无诊断指标")
    return schemas.ok("get_diagnostic_supported_metrics", rows)
