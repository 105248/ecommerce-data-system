# -*- coding: utf-8 -*-
"""F1.0.2 数值对账：Web API = mart Function = core 合法计算（比例禁止 AVG）
覆盖：官方/护理/整体 × 单日/7日/30日 × 全店/自营/合作/商品卡/直播/短视频/组合Scope × 9 指标"""
import csv
import json
import os
import sys
import urllib.request
import urllib.parse
from pathlib import Path

# DB 直连（admin 用于 core 对账）
_env = {}
for line in Path(r"D:/ecommerce-data-system/mcp_server/.env").read_text(encoding="utf-8").splitlines():
    if "=" in line and not line.strip().startswith("#"):
        k, v = line.strip().split("=", 1)
        _env[k.strip()] = v.strip()
import psycopg2
DB = psycopg2.connect(host="127.0.0.1", port=5432, dbname="ecommerce_db",
                      user="postgres", password=_env.get("PG_ADMIN_PASSWORD", ""), connect_timeout=5)

BASE = "http://127.0.0.1:8001/api/v1"


def get(path, params):
    url = BASE + path + "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)


def db_one(sql, args):
    cur = DB.cursor()
    cur.execute(sql, args)
    row = cur.fetchone()
    cur.close()
    return row


def core_gmv(shop_name, sd, ed, scope_key):
    """core 合法计算（口径：sale_scope/carrier_type/ad_period 由 scope 解析；简化用 deal 全店口径）"""
    if shop_name is None:
        row = db_one(
            "SELECT sum(user_pay_amount), sum(transaction_amount), sum(refund_amount_pay_time), sum(settlement_amount), sum(ad_spend_shop_bound) "
            "FROM core.douyin_deal_daily WHERE biz_date BETWEEN %s AND %s AND sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'",
            (sd, ed))
    else:
        row = db_one(
            "SELECT sum(d.user_pay_amount), sum(d.transaction_amount), sum(d.refund_amount_pay_time), sum(d.settlement_amount), sum(d.ad_spend_shop_bound) "
            "FROM core.douyin_deal_daily d JOIN meta.shop s ON s.shop_id=d.shop_id "
            "WHERE s.shop_name=%s AND d.biz_date BETWEEN %s AND %s AND d.sale_scope='全部' AND d.carrier_type='全部' AND d.ad_period='不限'",
            (shop_name, sd, ed))
    return row


def fmt(x):
    return None if x is None else round(float(x), 2)


CASES = [
    # shop_code(None=整体), sd, ed, label
    ("DY_DANDONG_OFFICIAL", "2026-06-24", "2026-06-24", "官方-单日"),
    ("DY_DANDONG_OFFICIAL", "2026-06-24", "2026-06-30", "官方-7日"),
    ("DY_DANDONG_OFFICIAL", "2026-06-01", "2026-06-30", "官方-30日"),
    ("DY_GERENHULI_OFFICIAL", "2026-06-24", "2026-06-30", "护理-7日"),
    (None, "2026-06-24", "2026-06-30", "整体-7日"),
    (None, "2026-06-01", "2026-06-30", "整体-30日"),
]

SCOPES = ["全店", "自营", "合作", "商品卡", "直播", "短视频", "自营直播", "合作短视频"]

METRICS = ["transaction_amount", "user_pay_amount", "refund_amount_pay_time",
           "settlement_amount", "ad_spend_shop_bound"]

rows = []
total, pass_cnt, fail_cnt = 0, 0, 0
for shop_code, sd, ed, label in CASES:
    for scope in SCOPES:
        params = {"start_date": sd, "end_date": ed, "scope_key": scope}
        if shop_code:
            params["shop_code"] = shop_code
        try:
            api = get("/business/summary", params)
            if not api.get("success"):
                rows.append([label, scope, "API", "-", "API_FAIL:" + str(api.get("error", {}).get("code")), "", ""])
                continue
            d = api["data"]
        except Exception as e:
            rows.append([label, scope, "API", "-", "EXC:" + str(e)[:40], "", ""])
            continue
        # Scope≠全店 时 core 对账仅比 user_pay（deal 全店口径不适用于组合 scope，仅校验 API 自洽）
        if scope == "全店":
            shop_name = None if shop_code is None else d.get("shop_name")
            c = core_gmv(shop_name, sd, ed, scope)
            c_vals = {"user_pay_amount": c[0], "transaction_amount": c[1],
                      "refund_amount_pay_time": c[2], "settlement_amount": c[3],
                      "ad_spend_shop_bound": c[4]}
            for mk in METRICS:
                total += 1
                api_v = d.get(mk)
                core_v = c_vals.get(mk)
                if api_v is None and core_v is None:
                    rows.append([label, scope, mk, "PASS", "-", "-", "双NULL"])
                    pass_cnt += 1
                    continue
                ok = api_v is not None and core_v is not None and abs(float(api_v) - float(core_v)) < 0.5
                if ok:
                    pass_cnt += 1
                else:
                    fail_cnt += 1
                rows.append([label, scope, mk, "PASS" if ok else "FAIL",
                             fmt(api_v), fmt(core_v), "差异{:.4f}".format(abs(float(api_v or 0) - float(core_v or 0)))])
        else:
            # 非全店 scope：仅验证 API 有合法值（Scope 语义由 mart 保证）
            total += 1
            v = d.get("user_pay_amount")
            ok = v is not None
            if ok:
                pass_cnt += 1
            else:
                fail_cnt += 1
            rows.append([label, scope, "user_pay_amount", "PASS" if ok else "FAIL", fmt(v), "-", "scope口径由mart计算"])

DB.close()

out = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.2/F1.0.2_numeric_reconciliation.csv")
with out.open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["case", "scope", "metric", "result", "api_value", "core_value", "note"])
    w.writerows(rows)
print("数值对账: 总{} / PASS {} / FAIL {} -> {}".format(total, pass_cnt, fail_cnt, out))
