# -*- coding: utf-8 -*-
"""V1.1 Stage4 机会只读 Tools：get_growth_opportunities / get_entity_opportunity / get_opportunity_summary"""
import database
import schemas


def get_growth_opportunities(platform_code="douyin", start_date=None, end_date=None,
                             domain_key=None, opportunity_code=None, min_level=None):
    """增长机会候选（机会质量排序分，非未来成功概率）：O01-O08 × 9 域。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_growth_opportunities(%s, %s::date, %s::date, %s, %s, %s)",
        (platform_code, start_date, end_date, domain_key, opportunity_code, min_level))
    if not rows:
        return schemas.ok("get_growth_opportunities", [], {"note": "该区间/条件无机会事件"})
    return schemas.ok("get_growth_opportunities", [dict(r) for r in rows])


def get_entity_opportunity(platform_code="douyin", domain_key=None, entity_name=None,
                           start_date=None, end_date=None):
    """单实体机会明细。"""
    if not domain_key or not entity_name:
        raise schemas.ArgError("INVALID_ARGUMENT", "需提供 domain_key 与 entity_name")
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_entity_opportunity(%s, %s, %s, %s::date, %s::date)",
        (platform_code, domain_key, entity_name, start_date, end_date))
    if not rows:
        return schemas.ok("get_entity_opportunity", [], {"note": "该实体无机会"})
    return schemas.ok("get_entity_opportunity", [dict(r) for r in rows])


def get_opportunity_summary(platform_code="douyin", start_date=None, end_date=None, status="QUALIFIED"):
    """机会汇总：按域×类型统计事件数/最高分/平均分/等级分布。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_opportunity_summary(%s, %s::date, %s::date, %s)",
        (platform_code, start_date, end_date, status))
    if not rows:
        return schemas.ok("get_opportunity_summary", [], {"note": "该区间无机会汇总"})
    return schemas.ok("get_opportunity_summary", [dict(r) for r in rows])
