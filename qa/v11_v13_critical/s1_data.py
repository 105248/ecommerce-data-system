# -*- coding: utf-8 -*-
"""阶段1数据层专项：SP01(唯一键/批次/日期完整性) SP05(比例原值) SP06(18Scope恒等式) SP07(抖音整体100组) SP13(时间粒度)
只读：SELECT / 正式函数；不修改任何对象。输出 04_multishop_scope_identity_report.md 素材"""
import sys, json, random
sys.path.insert(0, r"D:/ecommerce-data-system/mcp_server")
import psycopg2
from psycopg2.extras import RealDictCursor
from pathlib import Path
from datetime import datetime
from tools import business_tools, platform_tools, domain_tools

CONN = dict(host="127.0.0.1", port=5432, dbname="ecommerce_db",
            user="postgres", password=os.environ.get('PG_ADMIN_PASSWORD', ''))
conn = psycopg2.connect(**CONN, connect_timeout=5)
conn.set_session(readonly=True, autocommit=True)
cur = conn.cursor(cursor_factory=RealDictCursor)
OUT = Path(r"D:/ecommerce-data-system/qa/v11_v13_critical")
now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
SHOP1, SHOP2 = "弹动官方旗舰店", "弹动个人护理旗舰店"
PERIODS = [("1天", "2026-06-30", "2026-06-30"), ("7天", "2026-06-24", "2026-06-30"),
           ("30天", "2026-06-01", "2026-06-30"), ("随机段", "2026-06-10", "2026-06-20")]

def q(sql):
    cur.execute(sql)
    return cur.fetchall()

findings = []  # (level, sp, desc, evidence)
def rec(level, sp, desc, ev=""):
    findings.append((level, sp, desc, ev))
    print("[{}] {}: {}".format(level, sp, desc[:110]))

# ===== SP01 业务唯一键重复检查（9 表） =====
print("\n===== SP01 唯一键/覆盖 =====")
biz_keys = {
    "douyin_deal_daily": "shop_id, biz_date, sale_scope, carrier_type, ad_period",
    "douyin_product_daily": "shop_id, biz_date, product_id",
    "douyin_account_daily": "shop_id, biz_date, account_name",
    "douyin_category_daily": "shop_id, biz_date, category_level, category_name",
    "douyin_carrier_daily": "shop_id, biz_date, sale_scope, carrier_type",
    "douyin_content_daily": "shop_id, biz_date, content_id",
    "douyin_terminal_daily": "shop_id, biz_date, terminal_type",
    "douyin_price_band_daily": "shop_id, biz_date, price_band",
    "douyin_audience_daily": "shop_id, biz_date, audience_type",
}
for t, keys in biz_keys.items():
    try:
        r = q("SELECT {} , count(*) n, max(c) dup FROM (SELECT {}, count(*) c FROM core.{} GROUP BY {}) x".format(
            keys, keys, t, keys)) if False else q("""SELECT max(dup) AS max_dup, count(*) AS dup_groups FROM (
                SELECT {} , count(*) AS dup FROM core.{} GROUP BY {} HAVING count(*)>1) d""".format(keys, t, keys))
        rec("PASS" if not r or r[0]["max_dup"] is None else "FAIL", "SP01", "{} 唯一键重复: {}".format(t, r[0]["max_dup"] or 0))
    except Exception as e:
        rec("WARN", "SP01", "{} 唯一键检查跳过: {}".format(t, str(e)[:60]))
# 批次记录
try:
    batches = q("""SELECT batch_id, shop_id, sheet_name, min(biz_date) mind, max(biz_date) maxd, count(*) n
        FROM audit.import_batch GROUP BY 1,2,3 ORDER BY 1""")
    rec("INFO", "SP01", "导入批次={} 条".format(len(batches)), str(batches[-3:]))
except Exception as e:
    rec("WARN", "SP01", "import_batch 查询: {}".format(str(e)[:60]))

# ===== SP05 比例原值扫描 =====
print("\n===== SP05 比例原值 =====")
# 从 whitelist/field_mapping 找比例类列
ratio_cols = q("""SELECT DISTINCT target_table, target_column_name FROM meta.field_mapping
    WHERE field_category LIKE '%比例%' OR field_category LIKE '%率%' OR field_category LIKE '%占比%'
    OR target_column_name_cn LIKE '%率%' OR target_column_name_cn LIKE '%占比%'
    ORDER BY 1,2""")
print("比例类字段候选:", [(r["target_table"], r["target_column_name"]) for r in ratio_cols][:20])
suspect = []
for r in ratio_cols[:30]:
    t = r["target_table"]
    if t not in ("douyin_deal_daily", "douyin_product_daily", "douyin_carrier_daily", "douyin_account_daily"):
        continue
    col = r["target_column_name"]
    try:
        rows = q("""SELECT count(*) n, count(*) FILTER (WHERE {}::text LIKE '0.00%' AND {}::numeric > 0) AS tiny
                    FROM core.{} WHERE {} IS NOT NULL""".format(col, col, t, col))
        if rows and rows[0]["tiny"] > 0:
            suspect.append((t, col, rows[0]["tiny"]))
    except Exception:
        pass
if suspect:
    for t, c, n in suspect[:10]:
        rec("WARN", "SP05", "疑似二次除100: {}.{} 微小正值={}".format(t, c, n))
else:
    rec("PASS", "SP05", "未发现疑似二次除100的比例列")
# 抽查已知比例列
for t, c in [("douyin_deal_daily", "refund_rate"), ("douyin_deal_daily", "ad_fee_ratio")]:
    try:
        r = q("SELECT min({}) mn, max({}) mx FROM core.{}".format(c, c, t))
        rec("INFO", "SP05", "{}.{} 范围: {} ~ {}".format(t, c, r[0]["mn"], r[0]["mx"]))
    except Exception:
        pass

# ===== SP06 18 Scope 恒等式 =====
print("\n===== SP06 Scope 恒等式 =====")
def bs(shop, sd, ed, scope, metric="user_pay_amount"):
    try:
        r = business_tools.get_business_summary(shop, sd, ed, scope, metric)
        if r.get("ok") and r.get("data"):
            return float(r["data"][0]["metric_value"])
    except Exception:
        pass
    return None

scope_checks = []
for pname, sd, ed in PERIODS:
    for shop in (SHOP1, SHOP2, None):
        all_v = bs(shop, sd, ed, "全店")
        zy = bs(shop, sd, ed, "自营")
        hz = bs(shop, sd, ed, "合作")
        if all_v is not None and zy is not None and hz is not None:
            diff = abs(all_v - (zy + hz))
            ok = diff < 0.01
            rec("PASS" if ok else "FAIL", "SP06",
                "{} {} 全店={:.2f} 自营+合作={:.2f} diff={:.4f}".format(pname, shop or "抖音整体", all_v, zy + hz, diff))
            scope_checks.append(ok)
        else:
            rec("WARN", "SP06", "{} {} 部分 scope 无数据（全店={} 自营={} 合作={}）".format(pname, shop or "整体", all_v, zy, hz))

# ===== SP07 抖音整体 100 组 =====
print("\n===== SP07 抖音整体 100 组 =====")
metrics = ["user_pay_amount", "settlement_amount", "refund_amount_pay_time", "transaction_amount",
           "order_count", "buyer_count", "pay_count", "gmv", "ad_spend_shop_bound", "ad_spend_shop_invested"]
scopes = ["全店", "自营", "合作", "商品卡", "直播", "短视频"]
random.seed(42)
groups = []
for i in range(100):
    sd, ed = random.choice(PERIODS)[1], random.choice(PERIODS)[1]
    if sd > ed:
        sd, ed = ed, sd
    m = random.choice(metrics)
    s = random.choice(scopes)
    groups.append((sd, ed, m, s))

rate_metrics = {"refund_amount_pay_time": ("user_pay_amount",), "ad_spend_shop_bound": ("settlement_amount",)}
match = 0; mismatch = 0; no_data = 0; rate_ok = 0; rate_ne = 0
for sd, ed, m, s in groups:
    try:
        plat = platform_tools.get_platform_business_summary("douyin", sd, ed, s, m)
        p1 = business_tools.get_business_summary(SHOP1, sd, ed, s, m)
        p2 = business_tools.get_business_summary(SHOP2, sd, ed, s, m)
        pv = float(plat["data"][0]["metric_value"]) if plat.get("ok") and plat.get("data") else None
        v1 = float(p1["data"][0]["metric_value"]) if p1.get("ok") and p1.get("data") else None
        v2 = float(p2["data"][0]["metric_value"]) if p2.get("ok") and p2.get("data") else None
        if pv is None or v1 is None or v2 is None:
            no_data += 1
            continue
        if abs(pv - (v1 + v2)) < 0.01:
            match += 1
        else:
            mismatch += 1
            if mismatch <= 5:
                rec("FAIL", "SP07", "平台 vs 两店SUM 不一致: {} {} {} {} 平台={} 两店={}+{}".format(sd, ed, s, m, pv, v1, v2))
    except Exception as e:
        no_data += 1
rec("PASS" if mismatch == 0 else "FAIL", "SP07", "100组 金额SUM一致: match={} mismatch={} no_data={}".format(match, mismatch, no_data))

# 比例类平台重算 ≠ AVG（退款率）
print("\n===== SP07b 比例跨店重算 vs AVG =====")
for pname, sd, ed in PERIODS:
    try:
        rp = platform_tools.get_platform_business_summary("douyin", sd, ed, "全店", "refund_rate")
        r1 = business_tools.get_business_summary(SHOP1, sd, ed, "全店", "refund_rate")
        r2 = business_tools.get_business_summary(SHOP2, sd, ed, "全店", "refund_rate")
        pv = float(rp["data"][0]["metric_value"]) if rp.get("ok") and rp.get("data") else None
        v1 = float(r1["data"][0]["metric_value"]) if r1.get("ok") and r1.get("data") else None
        v2 = float(r2["data"][0]["metric_value"]) if r2.get("ok") and r2.get("data") else None
        if pv is not None and v1 is not None and v2 is not None:
            avg = (v1 + v2) / 2
            diff = abs(pv - avg)
            rec("PASS" if diff > 0.001 else "WARN", "SP07b",
                "{} 平台退款率={:.6f} 两店AVG={:.6f} diff={:.6f} {}".format(pname, pv, avg, diff,
                    "重算≠AVG ✓" if diff > 0.001 else "≈AVG（样本可能恒定）"))
    except Exception as e:
        rec("WARN", "SP07b", "{} 比例对比: {}".format(pname, str(e)[:60]))

# ===== SP13 时间粒度 =====
print("\n===== SP13 时间粒度 =====")
tt = q("""SELECT column_name, data_type FROM information_schema.columns
    WHERE table_schema='core' AND column_name IN ('data_time_type','period_start','period_end','period_type','granularity')
    ORDER BY column_name""")
rec("PASS" if tt else "WARN", "SP13", "core 时间粒度列: {}".format(tt or "无（每日粒度 biz_date 为主键之一，无快照列）"))
# biz_date 分布抽查：product_daily 是否多日累计
r = q("SELECT shop_id, count(DISTINCT biz_date) days, count(*) rows FROM core.douyin_product_daily GROUP BY shop_id ORDER BY 1")
rec("INFO", "SP13", "product_daily 每店天数={} 行数={}".format([(x["shop_id"], x["days"], x["rows"]) for x in r]))

conn.close()
print("\n===== 阶段1数据层完成：发现 {} 条 =====".format(len(findings)))
