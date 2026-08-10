# -*- coding: utf-8 -*-
"""投放经营 Tools：get_advertising_summary / compare_advertising (V1.0.1)"""
import database
import schemas


# 10 个投放指标: key -> (中文名, 类型)
AD_METRICS = [
    ("ad_spend_shop_promoted", "投放消耗(店铺被投)", "amount"),
    ("ad_spend_shop_bound", "投放消耗(店铺绑定)", "amount"),
    ("ad_attributed_transaction_amount", "投放贡献成交金额", "amount"),
    ("ad_attributed_transaction_share", "投放贡献成交占比", "ratio"),
    ("ad_spend_rate_net_refund_shop_bound", "投放费比(剔除退款、店铺绑定)", "ratio"),
    ("total_expense_rate_net_refund_shop_bound", "综合费比(剔除退款、店铺绑定)", "ratio"),
    ("ad_efficiency_shop_promoted", "投放效率(店铺被投)", "efficiency"),
    ("ad_efficiency_shop_bound", "投放效率(店铺绑定)", "efficiency"),
    ("store_efficiency_shop_promoted", "全店效率(店铺被投)", "efficiency"),
    ("store_efficiency_shop_bound", "全店效率(店铺绑定)", "efficiency"),
]


def get_advertising_summary(shop_name=None, start_date=None, end_date=None, scope_key="全店"):
    """投放经营汇总：一次返回全部10项投放指标 + coverage。
    指标计算全部由 mart 完成（金额SUM / 比例与效率为加权源比率，非AVG），客户端禁止重算。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_scope(scope_key)
    schemas.check_shop(shop_name, required=True)

    rows = database.query(
        "SELECT * FROM mart.get_advertising_period_summary(%s, %s::date, %s::date, %s)",
        (shop_name, start_date, end_date, scope_key),
    )
    if not rows:
        return schemas.err("get_advertising_summary", "NO_DATA", "本期无投放数据")

    r = rows[0]
    metrics = []
    for key, cn, vtype in AD_METRICS:
        metrics.append({"metric_key": key, "metric_name_cn": cn, "value_type": vtype, "metric_value": r.get(key)})

    data = {
        "shop_name": r.get("shop_name"),
        "scope_key": r.get("scope_key"),
        "period_start": schemas.serialize(r.get("period_start")),
        "period_end": schemas.serialize(r.get("period_end")),
        "expected_days": r.get("expected_days"),
        "coverage_days": r.get("coverage_days"),
        "coverage_complete": r.get("coverage_complete"),
        "calculation_notes": r.get("calculation_notes"),
        "metrics": metrics,
    }
    return schemas.ok("get_advertising_summary", data, {"metric_count": len(metrics)})


def compare_advertising(shop_name=None, start_date=None, end_date=None, scope_key="全店"):
    """投放环比：本期N天 vs 紧邻前N天。比例输出百分点+相对变化；效率输出绝对+相对变化（无百分点）。"""
    schemas.validate_period(start_date, end_date)
    schemas.check_scope(scope_key)
    schemas.check_shop(shop_name, required=True)

    rows = database.query(
        "SELECT * FROM mart.compare_advertising_period(%s, %s::date, %s::date, %s)",
        (shop_name, start_date, end_date, scope_key),
    )
    if not rows:
        return schemas.err("compare_advertising", "NO_DATA", "本期或上期无投放数据")

    data = {
        "shop_name": shop_name,
        "scope_key": scope_key,
        "start_date": schemas.serialize(start_date),
        "end_date": schemas.serialize(end_date),
        "metrics": [
            {
                "metric_key": r["metric_key"],
                "metric_name_cn": r["metric_name_cn"],
                "value_type": r["value_type"],
                "current_value": r["current_value"],
                "previous_value": r["previous_value"],
                "absolute_change": r["absolute_change"],
                "relative_change": r["relative_change"],
                "percentage_point_change": r["percentage_point_change"],
            }
            for r in rows
        ],
    }
    return schemas.ok("compare_advertising", data, {"metric_count": len(rows)})
