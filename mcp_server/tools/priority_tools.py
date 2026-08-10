# -*- coding: utf-8 -*-
"""V1.1 Stage5 优先级/行动清单只读 Tools：get_daily_risk_priorities / get_daily_opportunity_priorities / get_daily_action_list / get_daily_business_brief"""
import database
import schemas


def get_daily_risk_priorities(platform_code="douyin", start_date=None, end_date=None, limit=5):
    """今日风险 TOP（P1_URGENT~P4_LOW；同实体仅 1 主卡；含业务影响/排查方向）。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_daily_risk_priorities(%s, %s::date, %s::date, %s)",
        (platform_code, start_date, end_date, limit))
    if not rows:
        return schemas.ok("get_daily_risk_priorities", [], {"note": "今日无风险"})
    return schemas.ok("get_daily_risk_priorities", [dict(r) for r in rows])


def get_daily_opportunity_priorities(platform_code="douyin", start_date=None, end_date=None, limit=5):
    """今日机会 TOP（O1_STRONG~O4_WATCH；同实体仅 1 主机会）。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_daily_opportunity_priorities(%s, %s::date, %s::date, %s)",
        (platform_code, start_date, end_date, limit))
    if not rows:
        return schemas.ok("get_daily_opportunity_priorities", [], {"note": "今日无机会"})
    return schemas.ok("get_daily_opportunity_priorities", [dict(r) for r in rows])


def get_daily_action_list(platform_code="douyin", start_date=None, end_date=None,
                          item_type=None, limit=20):
    """今日行动清单（RISK/OPPORTUNITY/WATCH 混合，按优先级排序）。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_daily_action_list(%s, %s::date, %s::date, %s, %s)",
        (platform_code, start_date, end_date, item_type, limit))
    if not rows:
        return schemas.ok("get_daily_action_list", [], {"note": "今日无行动项"})
    return schemas.ok("get_daily_action_list", [dict(r) for r in rows])


def get_daily_business_brief(platform_code="douyin", start_date=None, end_date=None):
    """每日经营简报：TOP5 风险 + TOP5 机会 + TOP5 Watchlist。"""
    schemas.validate_period(start_date, end_date)
    rows = database.query(
        "SELECT * FROM mart.get_daily_business_brief(%s, %s::date, %s::date)",
        (platform_code, start_date, end_date))
    if not rows:
        return schemas.ok("get_daily_business_brief", [], {"note": "今日无简报内容"})
    return schemas.ok("get_daily_business_brief", [dict(r) for r in rows])
