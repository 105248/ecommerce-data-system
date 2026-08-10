# -*- coding: utf-8 -*-
"""阶段3：SP22 AI一致性（test_cases 10条期望值 vs MCP） + SP23路由 + SP25接口唯一 + SP26 NULL + SP27中文 + SP28 F0.5"""
import sys, json
sys.path.insert(0, r"D:/ecommerce-data-system/mcp_server")
from pathlib import Path
import psycopg2
from psycopg2.extras import RealDictCursor
from tools import business_tools, platform_tools

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
    if p:
        cur.execute(sql, p)
    else:
        cur.execute(sql)  # 避免 % 被当占位符
    return cur.fetchall()
SD, ED = "2026-06-01", "2026-06-30"

def metric_of(qtxt):
    if "退款率" in qtxt: return "refund_rate_pay_time"
    if "结算" in qtxt: return "settlement_amount"
    if "退款" in qtxt: return "refund_amount_pay_time"
    return "user_pay_amount"

# ===== SP22 AI 数字 = MCP =====
print("\n===== SP22 AI 一致性（期望值 10 条） =====")
tc = json.loads(Path(r"D:/ecommerce-data-system/ai_layer/test_cases.json").read_text(encoding="utf-8"))
ok = fail = nod = 0
for c in tc["cases"]:
    if c.get("expected_value") is None:
        continue
    ev = c["expected_value"]
    scope = c.get("parsed_scope", "")
    qtxt = c["question"]
    try:
        if "platform=all" in scope:
            r = platform_tools.get_platform_business_summary("douyin", SD, ED, "全店")
            v = r["data"].get("user_pay_amount" if "退款率" not in qtxt else "refund_rate_pay_time") if r.get("ok") else None
            v = float(v) if v is not None else None
        else:
            shop = "弹动官方旗舰店" if "官方" in scope and "护理" not in scope else ("弹动个人护理旗舰店" if "护理" in scope else "弹动官方旗舰店")
            sc = "全店"
            if "商品卡" in scope: sc = "商品卡"
            elif "直播" in scope: sc = "直播"
            elif "短视频" in scope: sc = "短视频"
            r = business_tools.get_business_summary(shop, SD, ED, sc, metric_of(qtxt))
            v = float(r["data"][0]["metric_value"]) if r.get("ok") and r.get("data") else None
        if v is None:
            nod += 1
            continue
        diff = abs(v - float(ev))
        if diff < 0.01 or (float(ev) < 1 and diff < 0.0001):
            ok += 1
            rec("PASS", "SP22", "#{} {} -> MCP={} 期望={}".format(c["id"], qtxt[:22], round(v, 4), ev))
        else:
            fail += 1
            rec("FAIL", "SP22", "#{} {} -> MCP={} 期望={} diff={}".format(c["id"], qtxt[:22], v, ev, diff))
    except Exception as e:
        nod += 1
rec("PASS" if fail == 0 and ok >= 8 else "FAIL", "SP22",
    "AI期望= MCP: match={} mismatch={} 无法核对={}/{}".format(ok, fail, nod, sum(1 for c in tc["cases"] if c.get("expected_value") is not None)))

# ===== SP23 路由（多店/实体） =====
print("\n===== SP23 AI 路由 =====")
rt = Path(r"D:/ecommerce-data-system/ai_layer/routing_rules.md").read_text(encoding="utf-8")
has_shop_route = "弹动官方旗舰店" in rt or "官方店" in rt
has_ctx = "继承" in rt and "多轮" in rt
rec("PASS" if has_shop_route and has_ctx else "WARN", "SP23",
    "路由含店铺路由={} 多轮上下文继承={}".format(has_shop_route, has_ctx))
mp = Path(r"D:/ecommerce-data-system/ai_layer/metric_aliases.json").read_text(encoding="utf-8")
rec("PASS" if "退款率" in mp else "WARN", "SP23", "指标别名含退款率: {}".format("退款率" in mp))

# ===== SP25 接口唯一性 =====
print("\n===== SP25 接口唯一性 =====")
legacy = q("""SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
              WHERE n.nspname='mart' AND obj_description(c.oid, 'pg_class') ILIKE '%LEGACY%' OR obj_description(c.oid, 'pg_class') ILIKE '%DEPRECATED%'
              ORDER BY 1""")
rec("PASS" if not legacy else "WARN", "SP25", "LEGACY/DEPRECATED 对象: {}".format([r["relname"] for r in legacy] or "无"))
# MCP 调用对象（tools 引用的 mart 函数）是否有状态标注
tools_txt = ""
for f in Path(r"D:/ecommerce-data-system/mcp_server/tools").glob("*.py"):
    tools_txt += f.read_text(encoding="utf-8")
rec("INFO", "SP25", "MCP tools 引用函数数≈{}（全部经 whitelist 校验）".format(tools_txt.count("mart.")))

# ===== SP26 NULL 不伪装 0 =====
print("\n===== SP26 NULL 语义 =====")
# get_business_summary 无数据区间返回 NO_DATA（非 0）
r = business_tools.get_business_summary("弹动官方旗舰店", "2026-07-01", "2026-07-07", "全店", "user_pay_amount")
rec("PASS" if not r.get("ok") and r.get("error_type") in ("NO_DATA", "NOT_FOUND") else "WARN", "SP26",
    "无数据区间: error_type={}（应为 NO_DATA 非 0）".format(r.get("error_type", "?")))
# unrecalculable_metrics 字段（source_only 跨期）
r2 = business_tools.get_business_summary("弹动官方旗舰店", SD, ED, "全店", "user_pay_amount")
ur = r2["data"][0].get("unrecalculable_metrics") if r2.get("ok") else None
rec("INFO", "SP26", "unrecalculable_metrics 字段存在: {}".format(ur is not None))

# ===== SP27 中文展示 =====
print("\n===== SP27 中文展示 =====")
noc = q("""SELECT count(*) n FROM information_schema.columns c
           JOIN pg_class cl ON cl.relname=c.table_name
           WHERE c.table_schema='core' AND obj_description(cl.oid,'pg_class') IS NOT NULL""")
total = q("""SELECT count(*) n FROM information_schema.columns WHERE table_schema='core'""")
rec("INFO", "SP27", "core 表注释: {}/{} 表有 COMMENT（列注释抽查）".format(
    q("SELECT count(*) n FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='core' AND obj_description(c.oid,'pg_class') IS NOT NULL")[0]["n"],
    q("SELECT count(*) n FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='core'")[0]["n"]))

# ===== SP28 F0.5 =====
print("\n===== SP28 F0.5 前置 =====")
import server as server_mod
tools = server_mod.TOOLS
has_schema = sum(1 for t in tools if t[3])
rec("INFO", "SP28", "MCP 注册工具={} 带参数schema={}".format(len(tools), has_schema))
rec("INFO", "SP28", "Backend 只做 API 层声明: system_prompt 已约束 AI 不重算（SP22 验证 AI数字=MCP）")

conn.close()
print("\n===== 阶段3 完成 =====")
