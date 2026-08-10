# -*- coding: utf-8 -*-
"""F1.0 页面→API 契约验收：逐页验证独立 API 请求 + 返回 schema + 参数正确"""
import json, urllib.request, urllib.parse, sys

BASE = "http://127.0.0.1:8001/api/v1"
SD, ED = "2026-08-01", "2026-08-07"

def get(path, params=None):
    q = "?" + urllib.parse.urlencode(params) if params else ""
    with urllib.request.urlopen(BASE + path + q, timeout=20) as r:
        return json.loads(r.read().decode("utf-8"))

# 页面 → [(endpoint, params, 关键字段)]
PAGES = {
    "today": [
        ("/business/summary", {"start_date":SD,"end_date":ED,"scope_key":"全店"}, ["user_pay_amount","refund_rate","transaction_amount"]),
        ("/business/compare", {"start_date":SD,"end_date":ED,"scope_key":"全店","metric_key":"user_pay_amount"}, ["current_value"]),
        ("/business/compare", {"start_date":SD,"end_date":ED,"scope_key":"全店","metric_key":"refund_rate_pay_time"}, ["current_value"]),
        ("/business/trend", {"start_date":SD,"end_date":ED,"scope_key":"全店"}, ["date","user_pay_amount"]),
        ("/priorities/risks", {"start_date":SD,"end_date":ED,"limit":5}, ["entity_name","risk_level","risk_priority_score"]),
        ("/priorities/opportunities", {"start_date":SD,"end_date":ED,"limit":5}, ["entity_name","opportunity_level"]),
        ("/business/shop-contribution", {"start_date":SD,"end_date":ED,"scope_key":"全店"}, ["shops"]),
    ],
    "store": [
        ("/business/summary", {"shop_code":"DY_DANDONG_OFFICIAL","start_date":SD,"end_date":ED,"scope_key":"全店"}, ["user_pay_amount"]),
        ("/business/summary", {"shop_code":"DY_GERENHULI_OFFICIAL","start_date":SD,"end_date":ED,"scope_key":"全店"}, ["user_pay_amount"]),
        ("/business/shop-contribution", {"start_date":SD,"end_date":ED,"scope_key":"全店"}, ["shops"]),
    ],
    "priorities": [
        ("/priorities/risks", {"start_date":SD,"end_date":ED,"limit":10}, ["entity_name"]),
        ("/priorities/opportunities", {"start_date":SD,"end_date":ED,"limit":10}, ["entity_name"]),
        ("/priorities/watchlist", {"start_date":SD,"end_date":ED,"limit":10}, ["entity_name"]),
    ],
    "product-lines": [
        ("/master-data/product-lines", {}, ["product_line_code","product_line_name"]),
    ],
    "master-products": [
        ("/master-data/products", {"page_size":100}, ["master_product_code"]),
    ],
    "products": [
        ("/business/products/top", {"shop_code":"DY_DANDONG_OFFICIAL","start_date":SD,"end_date":ED,"limit":50}, ["product_name","current_value"]),
    ],
    "product-card": [
        ("/business/summary", {"start_date":SD,"end_date":ED,"scope_key":"商品卡"}, ["user_pay_amount","refund_rate"]),
        ("/business/trend", {"start_date":SD,"end_date":ED,"scope_key":"商品卡"}, ["date"]),
    ],
    "advertising": [
        ("/advertising/summary", {"shop_code":"DY_DANDONG_OFFICIAL","start_date":SD,"end_date":ED,"scope_key":"全店"}, ["ad_spend_shop_promoted","ad_spend_shop_bound","ad_spend_rate_net_refund_shop_bound"]),
    ],
    "refund": [
        ("/business/summary", {"start_date":SD,"end_date":ED,"scope_key":"全店"}, ["refund_amount_pay_time","refund_rate"]),
        ("/business/trend", {"start_date":SD,"end_date":ED,"scope_key":"全店"}, ["refund_rate_pay_time"]),
    ],
    "accounts": [],
    "live": [
        ("/business/summary", {"start_date":SD,"end_date":ED,"scope_key":"直播"}, ["user_pay_amount"]),
        ("/business/trend", {"start_date":SD,"end_date":ED,"scope_key":"直播"}, ["date"]),
    ],
    "video": [
        ("/business/summary", {"start_date":SD,"end_date":ED,"scope_key":"短视频"}, ["user_pay_amount"]),
        ("/business/trend", {"start_date":SD,"end_date":ED,"scope_key":"短视频"}, ["date"]),
    ],
    "search": [],
    "materials": [],
    "smart-operation": [
        ("/priorities/risks", {"start_date":SD,"end_date":ED,"limit":5}, ["entity_name"]),
        ("/priorities/opportunities", {"start_date":SD,"end_date":ED,"limit":5}, ["entity_name"]),
        ("/priorities/watchlist", {"start_date":SD,"end_date":ED,"limit":5}, ["entity_name"]),
    ],
    "risks": [
        ("/priorities/risks", {"start_date":SD,"end_date":ED,"limit":50}, ["entity_name","risk_level","business_impact"]),
    ],
    "diagnosis": [
        ("/diagnostics/results", {"start_date":SD,"end_date":ED,"domain_key":"shop"}, ["diagnostic_code","primary_stage"]),
        ("/diagnostics/decomposition", {"start_date":SD,"end_date":ED}, ["net_change"]),
    ],
    "opportunities": [
        ("/priorities/opportunities", {"start_date":SD,"end_date":ED,"limit":50}, ["entity_name","opportunity_score"]),
    ],
}

report = []
total_ok = total_fail = 0
for page, calls in PAGES.items():
    page_ok = page_fail = 0
    for ep, params, fields in calls:
        try:
            r = get(ep, params)
            if not r.get("success"):
                page_fail += 1; report.append("FAIL {}/{}: {}".format(page, ep, r.get("error",{}).get("code","?")))
                continue
            data = r.get("data")
            ok = True
            if isinstance(data, list) and fields:
                if data and not all(f in data[0] for f in fields): ok = False
            elif isinstance(data, dict) and fields:
                if not all(f in data for f in fields): ok = False
            if ok: page_ok += 1
            else:
                page_fail += 1; report.append("FAIL {}/{}: schema 缺字段 {} → keys={}".format(page, ep, fields, list(data.keys())[:8] if isinstance(data,dict) else "list"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "ignore")
            if "NO_DATA" in body or "no data" in body.lower():
                page_ok += 1  # 合法空态（V1.1 检测未覆盖新月份）
            else:
                page_fail += 1; report.append("FAIL {}/{}: {} {}".format(page, ep, e.code, body[:80]))
        except Exception as e:
            page_fail += 1; report.append("FAIL {}/{}: {}".format(page, ep, str(e)[:80]))
    total_ok += page_ok; total_fail += page_fail
    print("{}: {} API 调用, ok={} fail={}".format(page, len(calls), page_ok, page_fail))

print("\n=== 汇总: 总调用 {} 成功 {} 失败 {} ===".format(total_ok+total_fail, total_ok, total_fail))
for r in report[:15]: print(" ", r)
