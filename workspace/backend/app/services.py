# -*- coding: utf-8 -*-
"""F0.5/F1.0 共享校验与解析（P2-02：消除 api.py / api_f1.py 重复定义与分叉）
只做参数校验/名称解析，不做任何经营计算。"""
import datetime

import db
from errors import ApiError

# 正式 18 Scope（唯一常量，主 API 与趋势 API 共用）
VALID_SCOPES = {"全店", "自营", "合作", "商品卡", "短视频", "直播", "图文", "其他",
                "自营商品卡", "合作商品卡", "自营短视频", "合作短视频", "自营直播", "合作直播",
                "自营图文", "合作图文", "自营其他", "合作其他"}

# 趋势接口受控指标（白名单函数返回字段；metric_key 白名单化）
TREND_METRICS = {
    "transaction_amount": "成交金额",
    "user_pay_amount": "用户支付金额",
    "settlement_amount": "结算金额",
    "refund_rate_pay_time": "退款率(支付时间)",
    "ad_spend_shop_bound": "投放消耗(店铺绑定)",
}


def check_period(start_date, end_date):
    try:
        s = datetime.date.fromisoformat(start_date)
        e = datetime.date.fromisoformat(end_date)
    except ValueError:
        raise ApiError("INVALID_ARGUMENT", "日期格式须为 YYYY-MM-DD")
    if s > e:
        raise ApiError("INVALID_ARGUMENT", "start_date 不能晚于 end_date")
    return s, e


def resolve_shop_name(shop_code):
    """shop_code → shop_name（经 meta.shop 映射；含 enabled 检查，P2-01 统一）。"""
    if not shop_code:
        return None
    rows, _ = db.query("SELECT shop_name, enabled FROM meta.shop WHERE shop_code = %s", (shop_code,))
    if not rows:
        # 兼容 shop_code=shop_name
        rows, _ = db.query("SELECT shop_name, enabled FROM meta.shop WHERE shop_name = %s", (shop_code,))
    if not rows:
        raise ApiError("UNKNOWN_SHOP", "未知店铺: {}".format(shop_code))
    if not rows[0]["enabled"]:
        raise ApiError("FORBIDDEN", "店铺未启用: {}".format(shop_code))
    return rows[0]["shop_name"]
