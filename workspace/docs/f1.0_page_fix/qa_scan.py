# -*- coding: utf-8 -*-
"""QA 重建（P1-07）：真实扫描 + 断言，替代硬编码 PASS。
扫描项：
  A. formula_in_frontend：app.js 经营计算扫描（环比/除法/乘法）
  B. label→field 绑定：中文标签与 API 字段一致性
  C. 整体 vs 店铺：整体模式不得偷偷默认官方店
  D. 趋势 metric_key 白名单化
  E. 18 Scope 单一常量
  F. 诊断页假店铺筛选（应已移除）
"""
import json, re, sys, urllib.request, urllib.parse
from pathlib import Path

BASE = "http://127.0.0.1:8001/api/v1"
SD, ED = "2026-06-24", "2026-06-30"
APP = Path("static/app.js").read_text(encoding="utf-8")
results = []  # (check, pass?, detail)

def check(name, ok, detail=""):
    results.append((name, ok, detail))
    print("{} {} {}".format("PASS" if ok else "FAIL", name, detail[:110]))

# ============ A. 前端经营计算扫描 ============
# 环比计算（cur-prev）
bad_arith = []
for m in re.finditer(r"const d = cur - prev|cur - prev|prev - cur|/\s*prev\b|cur\s*/\s*prev", APP):
    bad_arith.append(m.group(0))
# 除法（除 d*100 格式化与工具函数）
divs = []
for _line in APP.splitlines():
    if _line.strip().startswith("//") or _line.strip().startswith("*"):
        continue
    for _m in re.finditer(r"(\w+)\.(\w+)\s*/\s*(\w+)", _line):
        if "toFixed" in _m.group(0) or "100" in _m.group(0):
            continue
        divs.append(_m.group(0))
check("A1 前端无环比 cur-prev 计算", len(bad_arith) == 0, str(bad_arith[:3]))
check("A2 前端无业务除法", len(divs) == 0, str(divs[:3]))
# 乘法（非格式化）
muls = [m.group(0) for m in re.finditer(r"[a-z_]\w*\s*\*\s*[a-z_]\w*", APP) if "*100" not in m.group(0) and "0.5" not in m.group(0)]
check("A3 前端无业务乘法", len(muls) == 0, str(muls[:3]))

# ============ B. label→field 绑定 ============
bindings = [
    ("成交金额 → transaction_amount", r"MetricCard\('成交金额', (\w+)\.transaction_amount"),
    ("用户支付金额 → user_pay_amount", r"MetricCard\('用户支付金额', (\w+)\.user_pay_amount"),
    ("退款金额(支付时间) → refund_amount_pay_time", r"MetricCard\('退款金额\(支付时间\)', (\w+)\.refund_amount_pay_time"),
    ("成交金额趋势 → metric_value（F1.0.2 单次查询）", r"TrendSvg\(trend\.data, 'metric_value'\)"),
]
for name, pat in bindings:
    check("B1 " + name, bool(re.search(pat, APP)))
# 错误绑定（成交金额绑 user_pay_amount）
bad_label = re.findall(r"MetricCard\('成交金额', (\w+)\.user_pay_amount", APP)
check("B2 无'成交金额'绑 user_pay_amount", len(bad_label) == 0, str(bad_label))
bad_refund = re.findall(r"MetricCard\('成交退款金额', (\w+)\.refund_amount_pay_time", APP)
check("B3 无'成交退款金额'绑 refund_amount_pay_time", len(bad_refund) == 0, str(bad_refund))

# ============ C. 整体 vs 店铺 ============
def get(path, params=None):
    q = "?" + urllib.parse.urlencode(params) if params else ""
    try:
        with urllib.request.urlopen(BASE + path + q, timeout=20) as r:
            return json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode("utf-8", "ignore"))

for page, path, params in [
    ("products", "/business/products/top", {"start_date": SD, "end_date": ED}),
    ("advertising", "/advertising/summary", {"start_date": SD, "end_date": ED}),
    ("accounts", "/accounts/top", {"start_date": SD, "end_date": ED}),
    ("rankings", "/business/rankings", {"start_date": SD, "end_date": ED}),
]:
    r = get(path, params)
    code = r.get("error", {}).get("code", "?")
    blocked = (not r.get("success")) and code in ("SELECT_SHOP_REQUIRED", "INVALID_ARGUMENT", "UNKNOWN_SHOP", "missing") or (r.get("detail") and any(x.get("type")=="missing" for x in r["detail"]))
    check("C1 {} 整体模式不偷偷默认官方店".format(page), blocked, code)

# ============ D. trend metric_key 白名单化 ============
r = get("/business/trend", {"start_date": SD, "end_date": ED, "metric_key": "not_a_metric"})
check("D1 trend 非法 metric 拒绝", (not r.get("success")) and r.get("error", {}).get("code") == "UNKNOWN_METRIC", r.get("error", {}).get("code", "?"))
r = get("/business/trend", {"start_date": SD, "end_date": ED, "metric_key": "transaction_amount"})
# F1.0.2 重构：单次 SELECT 返回 [{date, metric_value}]（原逐日循环已废弃）
ok = r.get("success") and r["data"] and "metric_value" in r["data"][0] and r["data"][0]["metric_value"] is not None
check("D2 trend 真正支持 transaction_amount（单次查询 metric_value）", ok)

# ============ E. 18 Scope 单一常量 ============
svc = Path("app/services.py").read_text(encoding="utf-8")
scope_cnt = len(set(re.findall(r'"([^"]+)"', re.search(r"VALID_SCOPES = \{(.*?)\}", svc, flags=re.S).group(1))))
check("E1 共享 VALID_SCOPES = 18", scope_cnt == 18, str(scope_cnt))
r = get("/business/trend", {"start_date": SD, "end_date": ED, "scope_key": "自营商品卡"})
check("E2 trend 支持 18 Scope（自营商品卡）", r.get("success"), r.get("error", {}).get("code", "?"))

# ============ F. 诊断页假店铺筛选（已移除） ============
api_f1 = Path("app/api_f1.py").read_text(encoding="utf-8")
sig = re.search(r"def diagnostic_results\(([^)]*)\)", api_f1)
no_shop_param = bool(sig) and "shop_code" not in sig.group(1)
check("F1 诊断接口已移除 shop_code 假参数", no_shop_param, sig.group(1) if sig else "no-sig")
meta_fix = re.search(r"'/diagnosis':\s*\{title:'问题诊断', supports_shop:false", APP)
check("F2 诊断页 supports_shop=false", bool(meta_fix))

# ============ G. F1.0.2 新端点契约（品线/MP/风险/机会/趋势日层） ============
r = get("/product-lines/summary", {"product_line_name": "鱼子酱洗发水品线", "start_date": SD, "end_date": ED})
check("G1 品线经营汇总（正式函数）", r.get("success") and r["data"].get("user_pay_amount") is not None, r.get("error", {}).get("code", "?"))
r = get("/master-products/rank", {"start_date": SD, "end_date": ED, "metric_key": "user_pay_amount", "limit": 3})
check("G2 MP 排名（user_pay_amount）", r.get("success") and len(r["data"]) > 0, r.get("error", {}).get("code", "?"))
r = get("/master-products/rank", {"start_date": SD, "end_date": ED, "metric_key": "transaction_amount", "limit": 3})
check("G3 MP 排名非法 metric 拒绝（契约收紧）", (not r.get("success")) and r.get("error", {}).get("code") == "UNSUPPORTED_METRIC", r.get("error", {}).get("code", "?"))
r = get("/risks/complete", {"start_date": SD, "end_date": ED, "limit": 5})
check("G4 风险中心完整 Anomaly 列表", r.get("success"), r.get("error", {}).get("code", "?"))
r = get("/opportunities/complete", {"start_date": SD, "end_date": ED, "limit": 5})
check("G5 机会中心完整列表", r.get("success"), r.get("error", {}).get("code", "?"))
r = get("/intelligence-status")
check("G6 智能刷新状态（FRESH/STALE 语义）", r.get("success") and r["data"].get("intelligence_status") in ("FRESH", "STALE"), r.get("error", {}).get("code", "?"))

# ============ H. Contract vs 实现（rank_master_products 函数体） ============
try:
    import psycopg2, os
    _env = {}
    for line in Path("../../mcp_server/.env").read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.strip().startswith("#"):
            k, v = line.strip().split("=", 1); _env[k.strip()] = v.strip()
    _c = psycopg2.connect(host="127.0.0.1", port=5432, dbname="ecommerce_db", user="postgres", password=_env.get("PG_ADMIN_PASSWORD", ""), connect_timeout=5)
    _cur = _c.cursor()
    _cur.execute("SELECT prosrc FROM pg_proc WHERE proname='rank_master_products'")
    _body = (_cur.fetchone() or ["",])[0]
    _cur.execute("SELECT prosrc FROM pg_proc WHERE proname='get_business_daily_trend'")
    _trend_body = (_cur.fetchone() or ["",])[0]
    _c.close()
    check("H1 rank_master_products 契约收紧（UNSUPPORTED_METRIC 拒绝逻辑在函数体）", "UNSUPPORTED_METRIC" in _body)
    check("H2 日层趋势函数存在（单次查询替代 N 次循环）", "get_business_daily_trend" in Path("app/api_f1.py").read_text(encoding="utf-8"))
except Exception as e:
    check("H1/H2 函数体检查", False, str(e)[:100])

# ============ I. Backend wrapper 无经营公式（静态扫描） ============
api_f1_txt = Path("app/api_f1.py").read_text(encoding="utf-8")
api_txt = Path("app/api.py").read_text(encoding="utf-8")
wrapper_arith = re.findall(r"(?:sum|avg|count)\s*\([^)]*\)\s*[/*+-]", api_f1_txt + api_txt)
check("I1 Backend 无经营公式（sum/avg 参与运算）", len(wrapper_arith) == 0, str(wrapper_arith[:3]))

# ============ J. 白名单/ACL（品线/MP 函数已入 58 白名单） ============
try:
    wl = json.load(open("../../convergence_final/04_database_public_interface_whitelist.json", encoding="utf-8"))
    wl_names = {i.get("object_name") for i in wl.get("interfaces", [])}
    need = {"get_product_line_members", "get_product_line_period_summary", "get_master_product_period_summary", "rank_master_products"}
    check("J1 品线/MP 4 函数已入白名单", need.issubset(wl_names), str(need - wl_names) if need - wl_names else "全含")
    check("J2 白名单总数=70(F1.0.4-R3)", wl.get("interface_count") == 70, str(wl.get("interface_count")))
except Exception as e:
    check("J1/J2 白名单检查", False, str(e)[:100])

# ============ K. secret scan（wrapper 无硬编码密码） ============
secret_hits = re.findall(r"(password|secret|token)\s*=\s*['\"][^'\"]{6,}", (api_f1_txt + api_txt).lower())
check("K1 Backend 无硬编码凭据", len(secret_hits) == 0, str(secret_hits[:2]))

# ============ 汇总 ============
fails = [r for r in results if not r[1]]
print("\n=== QA 扫描汇总: {} 项, PASS {} / FAIL {} ===".format(len(results), len(results) - len(fails), len(fails)))
for f in fails: print("  FAIL:", f[0], f[2])
sys.exit(1 if fails else 0)
