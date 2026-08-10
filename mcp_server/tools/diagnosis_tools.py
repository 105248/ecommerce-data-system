# -*- coding: utf-8 -*-
"""V1.1 Stage3 诊断只读 Tools：get_diagnostic_result / get_change_decomposition / get_funnel_diagnosis / get_advertising_diagnosis"""
import database
import schemas


def get_diagnostic_result(platform_code="douyin", start_date=None, end_date=None,
                          domain_key=None, status=None):
    """诊断结果（数据层问题定位）：层级/漏斗/贡献/投放拆解 + 证据链 + 置信度。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_diagnostic_result(%s, %s::date, %s::date, %s, %s)",
        (platform_code, start_date, end_date, domain_key, status))
    if not rows:
        return schemas.ok("get_diagnostic_result", [], {"note": "该区间无诊断结果"})
    return schemas.ok("get_diagnostic_result", [dict(r) for r in rows])


def get_entity_diagnosis(platform_code="douyin", domain_key=None, entity_name=None,
                         start_date=None, end_date=None):
    """单实体诊断结果（读已生成诊断）。"""
    if not domain_key or not entity_name:
        raise schemas.ArgError("INVALID_ARGUMENT", "需提供 domain_key 与 entity_name")
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_diagnostic_result(%s, %s::date, %s::date, %s, NULL) WHERE entity_name = %s",
        (platform_code, start_date, end_date, domain_key, entity_name))
    if not rows:
        return schemas.ok("get_entity_diagnosis", [], {"note": "该实体无诊断结果"})
    return schemas.ok("get_entity_diagnosis", [dict(r) for r in rows])


def get_change_decomposition(platform_code="douyin", master_product_id=None,
                             start_date=None, end_date=None):
    """变化拆解：master_product_id 为空 → 平台按店铺拆解；指定 → Master Product 按店铺商品拆解。
    返回 net_change / gross_negative / gross_positive / negative_impact_share。"""
    schemas.validate_period(start_date, end_date)
    if master_product_id:
        rows = database.query(
            "SELECT * FROM mart.decompose_master_product_by_shop_product(%s, %s::date, %s::date)",
            (master_product_id, start_date, end_date))
        if not rows:
            return schemas.err("get_change_decomposition", "NO_DATA", "该 Master Product 无拆解数据")
        return schemas.ok("get_change_decomposition", [dict(r) for r in rows])
    rows = database.query(
        "SELECT * FROM mart.decompose_platform_change_by_shop(%s, %s::date, %s::date, '全店', 'user_pay_amount')",
        (platform_code, start_date, end_date))
    if not rows:
        return schemas.err("get_change_decomposition", "NO_DATA", "该区间无拆解数据")
    return schemas.ok("get_change_decomposition", [dict(r) for r in rows])


def get_funnel_diagnosis(domain_key=None, entity_name=None, start_date=None, end_date=None,
                         shop_name=None, scope_key=None):
    """漏斗诊断：曝光→点击→成交→退款 各环节变化（缺字段跳过，不跨 domain 补数）。"""
    if not domain_key or not entity_name:
        raise schemas.ArgError("INVALID_ARGUMENT", "需提供 domain_key 与 entity_name")
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_funnel_diagnosis(%s, %s, %s::date, %s::date, %s, %s)",
        (domain_key, entity_name, start_date, end_date, shop_name, scope_key))
    if not rows:
        return schemas.err("get_funnel_diagnosis", "NO_DATA", "该实体无漏斗数据（可能域不支持流量指标）")
    return schemas.ok("get_funnel_diagnosis", [dict(r) for r in rows])


def get_advertising_diagnosis(domain_key=None, entity_name=None, start_date=None, end_date=None,
                              shop_name=None):
    """投放诊断（复用快照投放指标；平台=跨店加权，单店=原口径）。"""
    if not domain_key or not entity_name:
        raise schemas.ArgError("INVALID_ARGUMENT", "需提供 domain_key 与 entity_name")
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_advertising_diagnosis(%s, %s, %s::date, %s::date, %s)",
        (domain_key, entity_name, start_date, end_date, shop_name))
    if not rows:
        return schemas.err("get_advertising_diagnosis", "NO_DATA", "该实体无投放诊断数据")
    return schemas.ok("get_advertising_diagnosis", [dict(r) for r in rows])
