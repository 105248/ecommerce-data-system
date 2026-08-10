# -*- coding: utf-8 -*-
"""SP03/04(比例禁AVG) + SP06(18Scope恒等式) + SP07(抖音整体100组) 综合验证
正式结果=正式函数/MCP；错误AVG=SQL AVG(日率) 或 两店AVG；证明正式≠AVG。只读。"""
import sys, random, os
sys.path.insert(0, r"D:/ecommerce-data-system/mcp_server")
import psycopg2
from psycopg2.extras import RealDictCursor
from pathlib import Path
from tools import business_tools, platform_tools, advertising_tools

# 密码从 .env 读取（17:52 已轮换，禁止硬编码）
_env = {}
for _l in Path(r"D:/ecommerce-data-system/mcp_server/.env").read_text(encoding="utf-8").splitlines():
    _l = _l.strip()
    if _l and "=" in _l and not _l.startswith("#"):
        _k, _, _v = _l.partition("=")
        _env[_k.strip()] = _v.strip()
CONN = dict(host="127.0.0.1", port=5432, dbname="ecommerce_db",
            user="postgres", password=_env.get("PG_ADMIN_PASSWORD", os.environ.get("PG_ADMIN_PASSWORD", "")))
conn = psycopg2.connect(**CONN, connect_timeout=5)
conn.set_session(readonly=True, autocommit=True)
cur = conn.cursor(cursor_factory=RealDictCursor)
SHOP1, SHOP2 = "弹动官方旗舰店", "弹动个人护理旗舰店"
findings = []
def rec(level, sp, desc, ev=""):
    findings.append((level, sp, desc, ev))
    print("[{}] {}: {}".format(level, sp, desc[:120]))

def q(sql, params=()):
    if params:
        cur.execute(sql, params)
    else:
        cur.execute(sql)
    return cur.fetchall()

def bs(shop, sd, ed, scope, metric):
    r = business_tools.get_business_summary(shop, sd, ed, scope, metric)
    if r.get("ok") and r.get("data"):
        return float(r["data"][0]["metric_value"])
    return None

def ad_metric(shop, sd, ed, scope, metric):
    """广告域指标：get_advertising_summary 返回 metrics 列表"""
    r = advertising_tools.get_advertising_summary(shop, sd, ed, scope)
    if r.get("ok") and r.get("data"):
        for m in r["data"]["metrics"]:
            if m["metric_key"] == metric and m["metric_value"] is not None:
                return float(m["metric_value"])
    return None

def pf(platform, sd, ed, scope, field):
    r = platform_tools.get_platform_business_summary(platform, sd, ed, scope)
    if r.get("ok") and r.get("data"):
        v = r["data"].get(field)
        return float(v) if v is not None else None
    return None

# ===== SP03/04 比例指标：正式 vs 错误AVG =====
print("\n===== SP03/04 比例禁AVG =====")
# (指标, 域, 日率列, 分子SQL列, 分母SQL列)
RATE_CASES = [
    ("refund_rate_pay_time", "business", "refund_rate_pay_time", "refund_amount_pay_time", "user_pay_amount"),
    ("click_to_transaction_rate_events", "business", "click_to_transaction_rate_events", "product_click_count", "product_exposure_count"),
    ("ad_spend_rate_net_refund_shop_bound", "advertising", "ad_spend_rate_net_refund_shop_bound", "ad_spend_shop_bound", "settlement_amount"),
    ("total_expense_rate_net_refund_shop_bound", "advertising", "total_expense_rate_net_refund_shop_bound", "ad_spend_shop_bound", "settlement_amount"),
    ("ad_efficiency_shop_bound", "advertising", "ad_efficiency_shop_bound", "ad_attributed_transaction_amount", "ad_spend_shop_bound"),
]
PERIODS = [("7天", "2026-06-24", "2026-06-30"), ("30天", "2026-06-01", "2026-06-30"), ("随机段", "2026-06-10", "2026-06-20")]
TARGETS = [("官方", SHOP1), ("护理", SHOP2), ("整体", None)]
SCOPES = ["全店", "自营", "商品卡"]
rate_cnt = {"ok": 0, "eq_avg": 0, "err": 0, "nod": 0}
for metric, domain, daycol, num, den in RATE_CASES:
    for pname, sd, ed in PERIODS:
        for tname, shop in TARGETS:
            for scope in SCOPES:
                try:
                    if shop is None:
                        formal = pf("douyin", sd, ed, scope, metric)
                    elif domain == "business":
                        formal = bs(shop, sd, ed, scope, metric)
                    else:
                        formal = ad_metric(shop, sd, ed, scope, metric)
                    if formal is None:
                        rate_cnt["nod"] += 1
                        continue
                    # 错误AVG-日：同过滤集下 AVG(日率列)
                    if shop is None:
                        r = q("""SELECT AVG({}) avgd FROM core.douyin_deal_daily
                                  WHERE ad_period='不限' AND sale_scope='全部' AND carrier_type='全部'
                                  AND biz_date BETWEEN %s AND %s""".format(daycol), (sd, ed))
                    else:
                        r = q("""SELECT AVG({}) avgd FROM core.douyin_deal_daily
                                  WHERE shop_id=%s AND ad_period='不限' AND sale_scope='全部' AND carrier_type='全部'
                                  AND biz_date BETWEEN %s AND %s""".format(daycol),
                              (1 if shop == SHOP1 else 2, sd, ed))
                    wrong_avg = float(r[0]["avgd"]) if r[0]["avgd"] is not None else None
                    if wrong_avg is None:
                        rate_cnt["nod"] += 1
                        continue
                    diff = abs(formal - wrong_avg)
                    if diff > 1e-6:
                        rate_cnt["ok"] += 1
                    else:
                        rate_cnt["eq_avg"] += 1
                        rec("WARN", "SP03", "{} {} {} {} 正式={:.6f}=AVG日率={:.6f}（样本可能恒定）".format(metric, pname, tname, scope, formal, wrong_avg))
                except Exception as e:
                    rate_cnt["err"] += 1
                    if rate_cnt["err"] <= 5:
                        rec("ERR", "SP03", "{} {} {} {} 异常: {}".format(metric, pname, tname, scope, str(e)[:80]))
rec("PASS" if rate_cnt["eq_avg"] == 0 and rate_cnt["err"] == 0 else "WARN", "SP03",
    "比例指标正式≠AVG日率: 验证组={} 相等={} 错误={} 无数据={}".format(
        rate_cnt["ok"] + rate_cnt["eq_avg"], rate_cnt["eq_avg"], rate_cnt["err"], rate_cnt["nod"]))

# 整体：比例 正式 vs 两店AVG（非恒定样本应不等）
print("\n--- 整体比例: 正式 vs 两店简单AVG ---")
avg_ok = avg_eq = 0
for metric, domain in (("refund_rate_pay_time", "business"), ("ad_spend_rate_net_refund_shop_bound", "advertising")):
    for pname, sd, ed in PERIODS:
        for scope in ("全店", "自营"):
            pv = pf("douyin", sd, ed, scope, metric)
            if domain == "business":
                v1, v2 = bs(SHOP1, sd, ed, scope, metric), bs(SHOP2, sd, ed, scope, metric)
            else:
                v1, v2 = ad_metric(SHOP1, sd, ed, scope, metric), ad_metric(SHOP2, sd, ed, scope, metric)
            if pv is None or v1 is None or v2 is None:
                continue
            avg = (v1 + v2) / 2
            if abs(pv - avg) > 1e-6:
                avg_ok += 1
            else:
                avg_eq += 1
rec("PASS" if avg_eq == 0 else "WARN", "SP07b",
    "整体比例≠两店AVG: 验证组={} 相等={}".format(avg_ok + avg_eq, avg_eq))

# ===== SP06 Scope 恒等式（SQL 直查 deal_daily，金额） =====
print("\n===== SP06 Scope 恒等式 =====")
def deal_sum(shop_filter, sd, ed, sale_scope, carrier_type, ad_period):
    f = ["ad_period='{}'".format(ad_period), "sale_scope='{}'".format(sale_scope), "carrier_type='{}'".format(carrier_type)]
    if shop_filter:
        f.append("shop_id=" + shop_filter)
    f.append("biz_date BETWEEN '{}' AND '{}'".format(sd, ed))
    r = q("SELECT COALESCE(SUM(user_pay_amount),0) v FROM core.douyin_deal_daily WHERE {}".format(" AND ".join(f)))
    return float(r[0]["v"])

ids = 0
for pname, sd, ed in [("7天", "2026-06-24", "2026-06-30"), ("30天", "2026-06-01", "2026-06-30")]:
    for shop_f in (None, "1", "2"):
        sname = "整体" if shop_f is None else ("官方" if shop_f == "1" else "护理")
        # 全部=自营+合作
        a = deal_sum(shop_f, sd, ed, "全部", "全部", "不限")
        b = deal_sum(shop_f, sd, ed, "自营", "全部", "不限") + deal_sum(shop_f, sd, ed, "合作", "全部", "不限")
        ok = abs(a - b) < 0.01
        ids += 0 if ok else 1
        rec("PASS" if ok else "FAIL", "SP06", "{} {} 全部={:.2f} =自营+合作={:.2f}".format(pname, sname, a, b))
        # 载体：全部=商品卡+直播+短视频+图文+其他（sale_scope=全部）
        c = deal_sum(shop_f, sd, ed, "全部", "全部", "不限")
        d = sum(deal_sum(shop_f, sd, ed, "全部", ct, "不限") for ct in ("商品卡", "直播", "短视频", "图文", "其他"))
        ok2 = abs(c - d) < 0.01
        ids += 0 if ok2 else 1
        rec("PASS" if ok2 else "FAIL", "SP06", "{} {} 载体全部={:.2f} =明细和={:.2f}".format(pname, sname, c, d))
        # 投放：不限=全域+乘方投放时段+标准+品牌投放+非投放时段
        e = deal_sum(shop_f, sd, ed, "全部", "全部", "不限")
        f_ = sum(deal_sum(shop_f, sd, ed, "全部", "全部", ap) for ap in ("全域+乘方投放时段", "标准+品牌投放", "非投放时段"))
        ok3 = abs(e - f_) < 0.01
        ids += 0 if ok3 else 1
        rec("PASS" if ok3 else "FAIL", "SP06", "{} {} 投放不限={:.2f} =全域+标准品牌+非投放={:.2f}".format(pname, sname, e, f_))
rec("PASS" if ids == 0 else "FAIL", "SP06", "Scope 恒等式差异数={}".format(ids))

# ===== SP07 抖音整体 100 组 =====
print("\n===== SP07 抖音整体 100 组 =====")
random.seed(7)
metrics = ["user_pay_amount", "settlement_amount", "refund_amount_pay_time", "transaction_amount",
           "transaction_order_count", "transaction_buyer_count", "transaction_item_count"]
scopes = ["全店", "自营", "合作", "商品卡", "直播", "短视频"]
P = [("1天", "2026-06-30", "2026-06-30"), ("7天", "2026-06-24", "2026-06-30"), ("30天", "2026-06-01", "2026-06-30"),
     ("随机", "2026-06-10", "2026-06-20"), ("随机2", "2026-06-05", "2026-06-15")]
mm = mm2 = nod = 0
for i in range(100):
    pname, sd, ed = random.choice(P)
    m = random.choice(metrics)
    s = random.choice(scopes)
    pv = pf("douyin", sd, ed, s, m)
    v1 = bs(SHOP1, sd, ed, s, m)
    v2 = bs(SHOP2, sd, ed, s, m)
    if pv is None or v1 is None or v2 is None:
        nod += 1
        continue
    if abs(pv - (v1 + v2)) < 0.01:
        mm += 1
    else:
        mm2 += 1
        if mm2 <= 3:
            rec("FAIL", "SP07", "平台{} {} {} {} ={} vs 两店{}+{}".format(pname, s, m, sd, pv, v1, v2))
rec("PASS" if mm2 == 0 else "FAIL", "SP07", "100组 金额=两店SUM: match={} mismatch={} no_data={}".format(mm, mm2, nod))

conn.close()
print("\n===== SP03/04/06/07 完成，发现 {} 条 =====".format(len(findings)))
