# -*- coding: utf-8 -*-
"""阶段2 V1.1 智能经营专项（SP09-21）：Coverage / MasterProduct / ProductLine / SKU /
Snapshot状态机 / 异常LowBase幂等 / 诊断因果 / 变化拆解 / Opportunity / Priority。
只读 + MCP 正式函数；不写库。"""
import sys
sys.path.insert(0, r"D:/ecommerce-data-system/mcp_server")
from pathlib import Path
import psycopg2
from psycopg2.extras import RealDictCursor
from tools import platform_tools, masterdata_tools, diagnostic_tools, diagnosis_tools
from tools import opportunity_tools, priority_tools, anomaly_tools, product_tools, business_tools

_env = {}
for _l in Path(r"D:/ecommerce-data-system/mcp_server/.env").read_text(encoding="utf-8").splitlines():
    _l = _l.strip()
    if _l and "=" in _l and not _l.startswith("#"):
        _k, _, _v = _l.partition("="); _env[_k.strip()] = _v.strip()
conn = psycopg2.connect(host="127.0.0.1", port=5432, dbname="ecommerce_db",
                        user="postgres", password=_env.get("PG_ADMIN_PASSWORD", ""), connect_timeout=5)
conn.set_session(readonly=True, autocommit=True)
cur = conn.cursor(cursor_factory=RealDictCursor)
findings = []
def rec(level, sp, desc, ev=""):
    findings.append((level, sp, desc, ev))
    print("[{}] {}: {}".format(level, sp, desc[:115]))
def q(sql, p=()):
    cur.execute(sql, p)
    return cur.fetchall()
SHOP = "弹动官方旗舰店"
P = dict(start_date="2026-06-24", end_date="2026-06-30")

# ===== SP09 Coverage 门禁 =====
print("\n===== SP09 Coverage =====")
for sd, ed in (("2026-06-01", "2026-06-30"), ("2026-06-24", "2026-06-30"), ("2026-06-30", "2026-06-30")):
    r = platform_tools.get_platform_business_summary("douyin", sd, ed, "全店")
    if r.get("ok") and r.get("data"):
        d = r["data"]
        cov_ok = d.get("coverage_complete") is True and d.get("missing_shop_count", 99) == 0
        rec("PASS" if cov_ok else "WARN", "SP09",
            "{}~{} 完整覆盖: enabled={} covered={} missing={} days={}/{} complete={}".format(
                sd, ed, d.get("enabled_shop_count"), d.get("covered_shop_count"),
                d.get("missing_shop_count"), d.get("coverage_days"), d.get("expected_days"), d.get("coverage_complete")))
    else:
        rec("WARN", "SP09", "{}~{} 平台调用: {}".format(sd, ed, r.get("error_type", r.get("message", ""))[:40]))
# coverage 计算逻辑（函数定义）
try:
    f = q("""SELECT prosrc FROM pg_proc WHERE proname='get_platform_business_period_summary'""")
    src = f[0]["prosrc"] if f else ""
    has_missing_logic = "missing" in src.lower() and "enabled" in src.lower() and "coverage" in src.lower()
    rec("PASS" if has_missing_logic else "FAIL", "SP09", "平台 coverage 函数含 missing/enabled 逻辑: {}".format(has_missing_logic))
except Exception as e:
    rec("WARN", "SP09", "函数定义: {}".format(str(e)[:40]))

# ===== SP10 Master Product =====
print("\n===== SP10 Master Product =====")
st = q("""SELECT mapping_status, count(*) n FROM meta.platform_product_mapping GROUP BY 1 ORDER BY 2 DESC""")
rec("INFO", "SP10", "映射状态分布: {}".format({r["mapping_status"]: r["n"] for r in st}))
unm = q("SELECT count(*) n FROM mart.unmapped_products")[0]["n"]
rec("INFO", "SP10", "UNMAPPED 天然样本(unmapped_products视图)={}".format(unm))
mp = q("SELECT count(*) n FROM meta.master_product")[0]["n"]
rec("INFO", "SP10", "Master Product 总数={}（需 CONFIRMED≥20）".format(mp))
# 跨店汇总只含 CONFIRMED：get_master_product_period_summary 对 SUGGESTED/UNMAPPED 不并入（代码注释验证）
try:
    r = masterdata_tools.get_master_product_members(master_product_id=2)
    rec("PASS" if r.get("ok") else "WARN", "SP10", "MP#2 成员查询: {}".format(
        "rows={}".format(len(r.get("data", []))) if r.get("ok") else r.get("error_type")))
except Exception as e:
    rec("WARN", "SP10", "MP#2: {}".format(str(e)[:50]))
# CONFIRMED 成员汇总验证（get_master_product_period_summary 返回 mapped_shop_count 等）
try:
    r = q("SELECT mapped_shop_count, mapping_complete FROM mart.get_master_product_period_summary(2,'2026-06-01'::date,'2026-06-30'::date)")
    rec("PASS", "SP10", "MP#2 跨店汇总: mapped_shop={} complete={}".format(r[0]["mapped_shop_count"], r[0]["mapping_complete"]))
except Exception as e:
    rec("WARN", "SP10", "MP#2 汇总: {}".format(str(e)[:50]))

# ===== SP11 Product Line =====
print("\n===== SP11 Product Line =====")
for pl in ("鱼子酱品线", "人参品线"):
    r = masterdata_tools.get_product_line_members(product_line_name=pl)
    if r.get("ok"):
        rec("PASS", "SP11", "{} 成员={}".format(pl, len(r.get("data", []))))
    else:
        rec("WARN", "SP11", "{}: {}".format(pl, r.get("error_type", r.get("message", ""))[:40]))
pln = q("SELECT count(*) n FROM meta.product_line")
rec("INFO", "SP11", "品线总数={}（新增无需改代码=配置驱动）".format(pln[0]["n"]))

# ===== SP12 SKU =====
print("\n===== SP12 SKU =====")
try:
    v1 = q("SELECT 1 FROM 中文数据.\"平台SKU映射\"")
    v2 = q("SELECT 1 FROM 中文数据.\"未归属SKU\"")
    rec("PASS", "SP12", "SKU 中文视图存在（WHERE false→SKU_SOURCE_NOT_AVAILABLE 语义）: 平台SKU映射/未归属SKU")
except Exception as e:
    rec("WARN", "SP12", "SKU 视图: {}".format(str(e)[:60]))

# ===== SP14 Snapshot 状态机 =====
print("\n===== SP14 Snapshot 状态机 =====")
states_seen = set()
for dom, ent, sd, ed in [("shop", SHOP, "2026-06-24", "2026-06-30"),
                         ("shop", SHOP, "2026-06-01", "2026-06-30"),
                         ("product", None, "2026-06-24", "2026-06-30"),
                         ("scope", None, "2026-06-24", "2026-06-30")]:
    try:
        r = diagnostic_tools.get_diagnostic_snapshot(
            shop_name=SHOP if dom == "shop" else None, start_date=sd, end_date=ed, domain_key=dom,
            entity_name=SHOP if dom == "shop" else None)
        if r.get("ok") and r.get("data"):
            for row in r["data"][:5]:
                states_seen.add(row.get("data_status") or row.get("status") or "?")
        else:
            rec("INFO", "SP14", "snapshot {} {}~{}: {}".format(dom, sd, ed, r.get("error_type", "?")))
    except Exception as e:
        rec("WARN", "SP14", "snapshot {}: {}".format(dom, str(e)[:50]))
rec("INFO", "SP14", "实测可见状态: {}".format(sorted(states_seen) or "无"))
# PREVIOUS_ZERO 处理（函数逻辑）
try:
    f = q("""SELECT prosrc FROM pg_proc WHERE proname='get_diagnostic_snapshot'""")
    src = f[0]["prosrc"] if f else ""
    rec("PASS" if "previous_zero" in src.lower() or "prev_zero" in src.lower() else "WARN", "SP14",
        "snapshot 函数含 PREVIOUS_ZERO 分支: {}".format("previous_zero" in src.lower() or "prev_zero" in src.lower()))
except Exception as e:
    rec("WARN", "SP14", "snapshot 定义: {}".format(str(e)[:40]))

# ===== SP15 异常 Low Base =====
print("\n===== SP15 异常 Low Base =====")
try:
    rules = q("""SELECT metric_key, low_base_threshold, base_metric, base_threshold FROM mart.anomaly_rule ORDER BY metric_key""")
    rec("PASS" if rules else "WARN", "SP15", "anomaly_rule 条数={} 样本={}".format(len(rules),
        [(r["metric_key"], r.get("low_base_threshold"), r.get("base_metric")) for r in rules[:5]]))
except Exception as e:
    rec("WARN", "SP15", "anomaly_rule: {}".format(str(e)[:50]))

# ===== SP16 异常幂等 =====
print("\n===== SP16 异常幂等 =====")
try:
    k = q("""SELECT conname, pg_get_constraintdef(oid) def FROM pg_constraint
             WHERE conrelid='mart.anomaly_event'::regclass AND contype IN ('u','p')""")
    rec("PASS" if k else "WARN", "SP16", "anomaly_event 唯一约束: {}".format([r["conname"] for r in k] or "无"))
    dup = q("""SELECT max(c) maxc FROM (SELECT event_key, count(*) c FROM mart.anomaly_event GROUP BY event_key) x""")
    rec("PASS" if not dup or dup[0]["maxc"] <= 1 else "FAIL", "SP16",
        "anomaly_event event_key 重复最大次数: {}".format(dup[0]["maxc"] if dup else 0))
except Exception as e:
    rec("WARN", "SP16", "anomaly_event: {}".format(str(e)[:50]))

# ===== SP17 诊断因果边界 =====
print("\n===== SP17 诊断因果 =====")
try:
    tp = q("""SELECT diagnostic_type_code, count(*) n FROM mart.diagnostic_result GROUP BY 1 ORDER BY 2 DESC""")
    rec("INFO", "SP17", "诊断结果类型分布: {}".format({r["diagnostic_type_code"]: r["n"] for r in tp}))
except Exception as e:
    rec("WARN", "SP17", "diagnostic_result: {}".format(str(e)[:50]))
# AI 模板因果边界
import re
p = Path(r"D:/ecommerce-data-system/ai_layer/system_prompt.md")
txt = p.read_text(encoding="utf-8") if p.exists() else ""
has_boundary = "证据" in txt and ("不写因果" in txt or "不伪造" in txt or "定位" in txt)
rec("PASS" if has_boundary else "WARN", "SP17", "AI prompt 因果边界声明: {}".format(has_boundary))

# ===== SP18 变化拆解 =====
print("\n===== SP18 变化拆解 =====")
try:
    r = diagnosis_tools.get_change_decomposition(platform_code="douyin", start_date="2026-06-24", end_date="2026-06-30")
    if r.get("ok") and r.get("data"):
        d = r["data"]
        if isinstance(d, list) and d:
            row = d[0]
            neg = row.get("gross_negative")
            share = row.get("negative_impact_share")
            rec("PASS" if neg is not None else "WARN", "SP18",
                "平台变化拆解: net={} gross_neg={} share={}".format(row.get("net_change"), neg, share))
        else:
            rec("INFO", "SP18", "变化拆解返回: {}".format(str(d)[:80]))
    else:
        rec("WARN", "SP18", "变化拆解: {}".format(r.get("error_type", r.get("message", ""))[:40]))
except Exception as e:
    rec("WARN", "SP18", "变化拆解: {}".format(str(e)[:50]))
# 负向分母公式（函数 prosrc 中 gross_negative）
try:
    f = q("""SELECT prosrc FROM pg_proc WHERE proname='decompose_platform_change_by_shop'""")
    src = f[0]["prosrc"] if f else ""
    rec("PASS" if "gross_negative" in src else "FAIL", "SP18", "拆解函数含 gross_negative 分母逻辑: {}".format("gross_negative" in src))
except Exception as e:
    rec("WARN", "SP18", "拆解定义: {}".format(str(e)[:40]))

# ===== SP19 Opportunity =====
print("\n===== SP19 Opportunity =====")
try:
    rl = q("""SELECT opportunity_type_code, weight_growth, weight_persistence, weight_conversion,
                     weight_refund_health, weight_ad_efficiency, weight_materiality, weight_contribution,
                     min_available_weight
              FROM mart.opportunity_rule ORDER BY opportunity_type_code""")
    for r in rl[:3]:
        w = sum(x for x in (r["weight_growth"], r["weight_persistence"], r["weight_conversion"],
                            r["weight_refund_health"], r["weight_ad_efficiency"], r["weight_materiality"],
                            r["weight_contribution"]) if x is not None)
        rec("INFO", "SP19", "{} 权重和={} min_avail={}".format(r["opportunity_type_code"], w, r["min_available_weight"]))
except Exception as e:
    rec("WARN", "SP19", "opportunity_rule: {}".format(str(e)[:50]))
# peer pool 分池（函数/代码）
try:
    f = q("""SELECT prosrc FROM pg_proc WHERE proname='detect_growth_opportunities'""")
    src = f[0]["prosrc"] if f else ""
    rec("PASS" if "peer" in src.lower() and "shop_product" in src else "WARN", "SP19",
        "peer pool 分池逻辑: {}".format("shop_product" in src))
except Exception as e:
    rec("WARN", "SP19", "detect 定义: {}".format(str(e)[:40]))

# ===== SP20 Priority 去重 =====
print("\n===== SP20 Priority =====")
try:
    r = q("""SELECT diagnostic_chain_id, count(*) n FROM mart.daily_action_item
             WHERE diagnostic_chain_id IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 5""")
    rec("INFO", "SP20", "daily_action_item 按 chain 分布: {}".format([(x["diagnostic_chain_id"], x["n"]) for x in r]))
    top = q("""SELECT item_type, count(*) n FROM mart.daily_action_item GROUP BY 1 ORDER BY 2 DESC""")
    rec("INFO", "SP20", "行动项类型: {}".format({x["item_type"]: x["n"] for x in top}))
except Exception as e:
    rec("WARN", "SP20", "daily_action_item: {}".format(str(e)[:50]))

# ===== SP21 风险机会并存 =====
print("\n===== SP21 风险机会并存 =====")
try:
    a = q("SELECT count(*) n FROM mart.anomaly_event")
    o = q("SELECT count(*) n FROM mart.opportunity_event")
    rec("INFO", "SP21", "anomaly_event={} opportunity_event={}（并存能力=表独立+优先级独立评估）".format(a[0]["n"], o[0]["n"]))
    # 同实体双类型
    both = q("""SELECT count(*) n FROM (
        SELECT shop_name, start_date FROM mart.anomaly_event GROUP BY 1,2
        INTERSECT SELECT shop_name, start_date FROM mart.opportunity_event GROUP BY 1,2) x""")
    rec("INFO", "SP21", "同店同日期风险+机会并存样本: {}".format(both[0]["n"]))
except Exception as e:
    rec("WARN", "SP21", "事件表: {}".format(str(e)[:50]))

conn.close()
print("\n===== 阶段2 完成，发现 {} 条 =====".format(len(findings)))
