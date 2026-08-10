# -*- coding: utf-8 -*-
"""阶段2 修正版：SP14/15/16/17/19/20/21（列名已按实际表结构修正）。只读。"""
import sys
sys.path.insert(0, r"D:/ecommerce-data-system/mcp_server")
from pathlib import Path
import psycopg2
from psycopg2.extras import RealDictCursor
from tools import priority_tools, diagnostic_tools

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
def rec(level, sp, desc):
    findings.append((level, sp, desc))
    print("[{}] {}: {}".format(level, sp, desc[:115]))
def q(sql, p=()):
    cur.execute(sql, p)
    return cur.fetchall()

# ===== SP15 异常 Low Base =====
print("\n===== SP15 异常 Low Base =====")
rules = q("""SELECT rule_code, metric_key, low_base_metric, low_base_value, threshold_relative, threshold_pp, severity_base, enabled
             FROM mart.anomaly_rule ORDER BY rule_code""")
has_lb = any(r["low_base_metric"] and r["low_base_value"] is not None for r in rules)
rec("PASS" if has_lb and rules else "FAIL", "SP15",
    "anomaly_rule={} 条, LowBase 配置: {}".format(len(rules), has_lb))
for r in rules[:8]:
    rec("INFO", "SP15", "  {} metric={} low_base={}={} thr_rel={} thr_pp={}".format(
        r["rule_code"], r["metric_key"], r["low_base_metric"], r["low_base_value"],
        r["threshold_relative"], r["threshold_pp"]))

# ===== SP16 异常幂等/生命周期 =====
print("\n===== SP16 异常幂等/生命周期 =====")
dup = q("""SELECT max(c) maxc FROM (SELECT diagnostic_chain_key, count(*) c FROM mart.anomaly_event GROUP BY 1) x""")
rec("PASS" if dup[0]["maxc"] <= 1 else "FAIL", "SP16",
    "anomaly_event diagnostic_chain_key 重复最大={}".format(dup[0]["maxc"]))
st = q("""SELECT status, count(*) n FROM mart.anomaly_event GROUP BY 1 ORDER BY 2 DESC""")
rec("INFO", "SP16", "异常生命周期状态分布: {}".format({r["status"]: r["n"] for r in st}))
oc = q("""SELECT max(occurrence_count) mx FROM mart.anomaly_event""") if False else None

# ===== SP17 诊断因果边界 =====
print("\n===== SP17 诊断因果 =====")
dc = q("""SELECT diagnostic_code, primary_stage, count(*) n FROM mart.diagnostic_result GROUP BY 1,2 ORDER BY 3 DESC LIMIT 8""")
rec("INFO", "SP17", "诊断 code/stage 分布: {}".format([(r["diagnostic_code"], r["primary_stage"], r["n"]) for r in dc]))
ev = q("""SELECT evidence_json FROM mart.diagnostic_result WHERE evidence_json IS NOT NULL LIMIT 1""")
if ev:
    import json as _j
    try:
        e = _j.loads(ev[0]["evidence_json"]) if isinstance(ev[0]["evidence_json"], str) else ev[0]["evidence_json"]
        rec("PASS", "SP17", "evidence_json 结构（数据证据链，非因果结论）: keys={}".format(
            list(e.keys()) if isinstance(e, dict) else type(e).__name__))
    except Exception:
        rec("INFO", "SP17", "evidence_json 非 JSON: {}".format(str(ev[0]["evidence_json"])[:60]))
# AI 模板禁止因果
p = Path(r"D:/ecommerce-data-system/ai_layer/system_prompt.md")
txt = p.read_text(encoding="utf-8")
has_ban = "不写因果" in txt or "不伪造" in txt or "证据" in txt
rec("PASS" if has_ban else "WARN", "SP17", "AI prompt 因果边界: {}".format(has_ban))

# ===== SP19 Opportunity 权重 =====
print("\n===== SP19 Opportunity 权重 =====")
rl = q("""SELECT rule_code, weight_growth, weight_persistence, weight_conversion, weight_refund,
                 weight_ad_efficiency, weight_materiality, weight_contribution, min_peer_count, min_materiality, min_growth
          FROM mart.opportunity_rule ORDER BY rule_code""")
wsum_ok = True
for r in rl:
    w = float(r["weight_growth"] or 0) + float(r["weight_persistence"] or 0) + float(r["weight_conversion"] or 0) + \
        float(r["weight_refund"] or 0) + float(r["weight_ad_efficiency"] or 0) + float(r["weight_materiality"] or 0) + \
        float(r["weight_contribution"] or 0)
    if abs(w - 1.0) > 0.001:
        wsum_ok = False
    rec("INFO", "SP19", "  {} 权重和={:.3f} min_peer={} min_mat={} min_growth={}".format(
        r["rule_code"], w, r["min_peer_count"], r["min_materiality"], r["min_growth"]))
rec("PASS" if wsum_ok else "FAIL", "SP19", "opportunity_rule 权重归一(和=1): {}".format(wsum_ok))
# peer pool 分池验证（opportunity_event.benchmark_pool）
bp = q("""SELECT benchmark_pool, count(*) n FROM mart.opportunity_event GROUP BY 1 ORDER BY 2 DESC""")
rec("INFO", "SP19", "benchmark_pool 分池: {}".format({r["benchmark_pool"]: r["n"] for r in bp}))
aw = q("""SELECT count(*) FILTER (WHERE available_weight < 0.7) lt70, count(*) n FROM mart.opportunity_event""")
rec("INFO", "SP19", "opportunity_event available_weight<0.7: {}/{}（<70% 不输出正式分）".format(aw[0]["lt70"], aw[0]["n"]))

# ===== SP20 Priority 去重 =====
print("\n===== SP20 Priority 去重 =====")
# 1. dedupe_group_key 分布（去重键）
dg = q("""SELECT dedupe_group_key, count(*) n FROM mart.daily_action_item
          WHERE dedupe_group_key IS NOT NULL GROUP BY 1 ORDER BY 2 DESC LIMIT 6""")
rec("INFO", "SP20", "dedupe_group_key 最大组={} 样本={}".format(
    dg[0]["n"] if dg else 0, [(r["dedupe_group_key"][:30], r["n"]) for r in dg[:3]]))
# 2. 正式 TOP 输出：get_daily_risk_priorities 前5
try:
    r = priority_tools.get_daily_risk_priorities(platform_code="douyin", start_date="2026-06-24", end_date="2026-06-30", limit=5)
    if r.get("ok") and r.get("data"):
        top = r["data"]
        chains = [str(x.get("diagnostic_chain_id") or x.get("diagnostic_chain_key") or "?")[:25] for x in top]
        uniq = len(set(chains))
        rec("PASS" if uniq >= 2 or len(top) <= 1 else "FAIL", "SP20",
            "风险 TOP{} 链去重: 不同链数={} chains={}".format(len(top), uniq, chains))
        for x in top[:5]:
            rec("INFO", "SP20", "  TOP项: type={} entity={} chain={}".format(
                x.get("item_type") or x.get("risk_level"), str(x.get("entity_name"))[:12],
                str(x.get("diagnostic_chain_id") or "?")[:25]))
    else:
        rec("WARN", "SP20", "risk priorities: {}".format(r.get("error_type", r.get("message", ""))[:40]))
except Exception as e:
    rec("WARN", "SP20", "risk priorities: {}".format(str(e)[:50]))

# ===== SP21 风险机会并存 =====
print("\n===== SP21 风险机会并存 =====")
both = q("""SELECT count(*) n FROM (
    SELECT shop_name, current_start_date FROM mart.anomaly_event GROUP BY 1,2
    INTERSECT SELECT shop_name, current_start_date FROM mart.opportunity_event GROUP BY 1,2) x""")
rec("INFO", "SP21", "同店同日期风险+机会并存={} 组（表独立→可并存）".format(both[0]["n"]))
both2 = q("""SELECT count(*) n FROM mart.daily_action_item
             WHERE item_type='RISK' AND source_opportunity_code IS NOT NULL
             OR item_type='OPPORTUNITY' AND source_anomaly_code IS NOT NULL""")
rec("INFO", "SP21", "行动项中 RISK+OPPORTUNITY 混合来源: {}".format(both2[0]["n"]))

conn.close()
print("\n===== 阶段2修正版完成 =====")
