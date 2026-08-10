# -*- coding: utf-8 -*-
"""账号域 Tools：get_account_summary / rank_accounts / get_account_contribution"""
import database
import schemas
import config


def get_account_summary(shop_name=None, start_date=None, end_date=None,
                        sale_scope=None, account_name=None, metric_key="user_pay_amount"):
    """账号汇总。'更多账号' 是合作聚合桶（row_semantic=aggregate_bucket），不是具体达人。
    不用于回答全店/自营总成交。"""
    schemas.validate_period(start_date, end_date)
    if sale_scope is not None and sale_scope not in config.ACCOUNT_SCOPES:
        raise schemas.ArgError("INVALID_ARGUMENT", "account 的 sale_scope 仅允许 自营/合作")

    rows = database.query(
        "SELECT * FROM mart.get_account_period_summary(%s, %s::date, %s::date, %s, %s)",
        (shop_name, start_date, end_date, sale_scope, account_name),
    )
    data = [{
        "shop_name": r.get("shop_name"),
        "sale_scope": r.get("sale_scope"),
        "account_name": r.get("account_name"),
        "account_type": r.get("account_type"),
        "user_pay_amount": r.get("user_pay_amount"),
        "transaction_amount": r.get("transaction_amount"),
        "settlement_amount": r.get("settlement_amount"),
        "refund_amount_pay_time": r.get("refund_amount_pay_time"),
        "refund_rate_pay_time": r.get("refund_rate_pay_time"),
        "transaction_order_count": r.get("transaction_order_count"),
        "transaction_buyer_count": r.get("transaction_buyer_count"),
        "avg_customer_amount": r.get("avg_customer_amount"),
        "unrecalculable_metrics": r.get("unrecalculable_metrics"),
    } for r in rows]
    if not data:
        return schemas.err("get_account_summary", "NO_DATA", "无数据")
    return schemas.ok("get_account_summary", data, {"count": len(data)})


def rank_accounts(shop_name=None, start_date=None, end_date=None, sale_scope="合作",
                  metric_key="user_pay_amount", sort_by="current_value", sort_direction="DESC",
                  limit=20, include_aggregate_bucket=False, account_name=None):
    """账号排名。默认排除 aggregate_bucket（更多账号），避免把聚合桶当具体达人排名。"""
    schemas.validate_period(start_date, end_date)
    n = schemas.parse_limit(limit)
    schemas.check_sort(sort_by)
    schemas.check_direction(sort_direction)
    if sale_scope not in config.ACCOUNT_SCOPES:
        raise schemas.ArgError("INVALID_ARGUMENT", "account 的 sale_scope 仅允许 自营/合作")

    rows = database.query(
        "SELECT * FROM mart.rank_accounts(%s, %s::date, %s::date, %s, %s, %s, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, sale_scope, metric_key, sort_by, sort_direction,
         n, include_aggregate_bucket, account_name),
    )
    data = [{
        "account_name": r.get("account_name"),
        "sale_scope": r.get("sale_scope"),
        "account_role": r.get("account_role"),
        "current_value": r.get("current_value"),
        "previous_value": r.get("previous_value"),
        "absolute_change": r.get("absolute_change"),
        "relative_change": r.get("relative_change"),
        "current_rank": r.get("current_rank"),
        "previous_rank": r.get("previous_rank"),
        "rank_change": r.get("rank_change"),
        "rank_status": r.get("rank_status"),
    } for r in rows]
    if not data:
        return schemas.err("rank_accounts", "NO_DATA", "无数据")
    return schemas.ok("rank_accounts", data, {"count": len(data)})


def get_account_contribution(shop_name=None, start_date=None, end_date=None, sale_scope="合作",
                             metric_key="user_pay_amount", account_name=None,
                             include_aggregate_bucket=True, limit=20):
    """账号贡献度。分母来自 deal 权威 scope/全店 TOTAL，不来自 account 行 SUM。
    自营贡献和可能 <100%（coverage_note 会说明缺口）。"""
    schemas.validate_period(start_date, end_date)
    n = schemas.parse_limit(limit)
    if sale_scope not in config.ACCOUNT_SCOPES:
        raise schemas.ArgError("INVALID_ARGUMENT", "account 的 sale_scope 仅允许 自营/合作")

    rows = database.query(
        "SELECT * FROM mart.get_account_contribution(%s, %s::date, %s::date, %s, %s, %s, %s, %s)",
        (shop_name, start_date, end_date, sale_scope, metric_key, account_name,
         include_aggregate_bucket, n),
    )
    data = [{
        "account_name": r.get("account_name"),
        "sale_scope": r.get("sale_scope"),
        "account_role": r.get("row_semantic"),
        "numerator_value": r.get("numerator_value"),
        "scope_total": r.get("scope_total"),
        "contribution_to_scope": r.get("contribution_to_scope"),
        "store_total": r.get("store_total"),
        "contribution_to_store": r.get("contribution_to_store"),
        "coverage_note": r.get("coverage_note"),
    } for r in rows]
    if not data:
        return schemas.err("get_account_contribution", "NO_DATA", "无数据")
    return schemas.ok("get_account_contribution", data, {"count": len(data)})
