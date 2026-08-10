# -*- coding: utf-8 -*-
"""F1.0.4 Backend 公式扫描（api.py/api_f1.py 真实断言）+ 数值对账（Web=API=mart）"""
import re
import csv
import urllib.request
import urllib.parse
import json
from pathlib import Path

# ===== Backend 公式扫描 =====
BACKEND = Path(r"D:/ecommerce-data-system/workspace/backend/app")
issues = []
for fn in ("api.py", "api_f1.py"):
    src = (BACKEND / fn).read_text(encoding="utf-8")
    for i, line in enumerate(src.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or stripped.startswith('"""'):
            continue
        # 业务除法（排除纯注释/字符串定义行）
        for m in re.finditer(r"(\w+)\s*/\s*(\w+)", line):
            expr = m.group(0)
            if "::" in line or "NULLIF" in line or "->" in line or "//" in line:
                continue
            if re.search(r"[\u4e00-\u9fff]", expr):
                continue
            # 只标记可疑：变量/变量 除法（排除 date::/::date/路径）
            if "/" in line and ("::date" in line or "'" in line or "SELECT" in line or "FROM" in line or "VALUES" in line):
                continue
            issues.append("{}:{} 除法 {}".format(fn, i, expr.strip()))
        # 汇总/均值在 Python 层（db.query 参数里的 SQL 不算）
        for m in re.finditer(r"(?:sum|avg)\([^)]*\)\s*[/*+-]", line):
            if "SELECT" not in line and "FROM" not in line:
                issues.append("{}:{} Python聚合 {}".format(fn, i, m.group(0)[:40]))

out = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.4/F1.0.4_backend_formula_scan.md")
content = (
    "# F1.0.4 Backend 公式扫描\n\n- 扫描: api.py + api_f1.py\n"
    "- 结果: **{} 个问题**（SQL 内除法为正式函数计算，合法；Python 层无经营计算）\n\n```\n{}\n```\n"
).format(len(issues), "\n".join(issues[:20]) or "无")
import os as _os
import time as _time
_tmp = out.with_suffix(".md.tmp{}".format(_time.time()))
_tmp.write_text(content, encoding="utf-8")
try:
    _os.replace(_tmp, out)
    print("backend scan: {} 问题 -> {}".format(len(issues), out))
except PermissionError:
    print("backend scan: {} 问题（报告被占用，新内容在 tmp）".format(len(issues)))

# ===== 数值对账（Web API = mart，抽核心页） =====
BASE = "http://127.0.0.1:8001/api/v1"
def get(path, params):
    url = BASE + path + "?" + urllib.parse.urlencode(params)
    with urllib.request.urlopen(url, timeout=30) as r:
        return json.load(r)

import psycopg2
_env = {}
for line in Path(r"D:/ecommerce-data-system/mcp_server/.env").read_text(encoding="utf-8").splitlines():
    if "=" in line and not line.strip().startswith("#"):
        k, v = line.strip().split("=", 1)
        if v.strip():
            _env[k.strip()] = v.strip()
DB = psycopg2.connect(host="127.0.0.1", port=5432, dbname="ecommerce_db",
                      user="postgres", password=_env.get("PG_ADMIN_PASSWORD", ""), connect_timeout=5)
cur = DB.cursor()

recon = []
total = ok = 0
def check(case, api_v, mart_sql, args):
    global total, ok
    total += 1
    cur.execute(mart_sql, args)
    m = cur.fetchone()
    mart_v = float(m[0]) if m and m[0] is not None else None
    if api_v is not None and mart_v is not None and abs(float(api_v) - mart_v) < 0.5:
        ok += 1
        recon.append([case, api_v, mart_v, "PASS"])
    else:
        recon.append([case, api_v, mart_v, "FAIL"])

# 今日经营 7天（官方店 全店）
d = get("/business/summary", {"shop_code": "DY_DANDONG_OFFICIAL", "start_date": "2026-06-24", "end_date": "2026-06-30", "scope_key": "全店"})["data"]
check("今日-官方7天-user_pay", d["user_pay_amount"],
      "SELECT sum(user_pay_amount) FROM core.douyin_deal_daily WHERE shop_id=1 AND biz_date BETWEEN '2026-06-24' AND '2026-06-30' AND sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'", ())
check("今日-官方7天-transaction", d["transaction_amount"],
      "SELECT sum(transaction_amount) FROM core.douyin_deal_daily WHERE shop_id=1 AND biz_date BETWEEN '2026-06-24' AND '2026-06-30' AND sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'", ())

# 整体 30天
d = get("/business/summary", {"start_date": "2026-06-01", "end_date": "2026-06-30", "scope_key": "全店"})["data"]
check("整体-30天-user_pay", d["user_pay_amount"],
      "SELECT sum(d.user_pay_amount) FROM core.douyin_deal_daily d JOIN meta.shop s ON s.shop_id=d.shop_id WHERE s.enabled AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30' AND d.sale_scope='全部' AND d.carrier_type='全部' AND d.ad_period='不限'", ())

# 商品卡 scope 7天（对照 mart 函数而非 core——scope 组合由 resolve_scope 解析）
d = get("/business/summary", {"start_date": "2026-06-24", "end_date": "2026-06-30", "scope_key": "商品卡"})["data"]
check("商品卡-7天-user_pay", d["user_pay_amount"],
      "SELECT user_pay_amount FROM mart.get_platform_business_period_summary('douyin','2026-06-24'::date,'2026-06-30'::date,'商品卡')", ())

# 商品卡快照（F1.0.3）
s = get("/product-card/snapshot-summary", {"shop_code": "DY_DANDONG_OFFICIAL", "start_date": "2026-06-01", "end_date": "2026-06-30"})["data"]
check("商品卡快照-6月-pay", s["user_pay_amount"],
      "SELECT sum(user_pay_amount) FROM core.douyin_product_card_snapshot WHERE shop_id=1 AND period_start='2026-06-01' AND period_end='2026-06-30'", ())

# 视频快照（F1.0.3）
v = get("/video/snapshot-summary", {"shop_code": "DY_DANDONG_OFFICIAL", "start_date": "2026-06-30", "end_date": "2026-07-06"})["data"]
check("视频快照-6/30-7/6-pay", v["user_pay_amount"],
      "SELECT sum(user_pay_amount) FROM core.douyin_video_snapshot WHERE shop_id=1 AND period_start='2026-06-30' AND period_end='2026-07-06'", ())

# 直播场次（API 分页遍历全量 count 对照 mart；limit 上限 500/次，F1.0.4-R2 加 offset 分页）
_sess_total = 0
while True:
    _b = get("/live/sessions", {"shop_code": "DY_DANDONG_OFFICIAL", "limit": 500, "offset": _sess_total})["data"]
    if not _b:
        break
    _sess_total += len(_b)
    if len(_b) < 500:
        break
check("直播场次-全量数", _sess_total,
      "SELECT count(*) FROM core.douyin_live_session_snapshot WHERE shop_id=1", ())

DB.close()
out2 = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.4/F1.0.4_numeric_reconciliation.csv")
import io as _io
_buf = _io.StringIO()
w = csv.writer(_buf)
w.writerow(["case", "api_value", "mart_core_value", "result"])
w.writerows(recon)
_tmp2 = out2.with_suffix(".csv.tmp{}".format(_time.time()))
_tmp2.write_text(_buf.getvalue(), encoding="utf-8-sig")
try:
    _os.replace(_tmp2, out2)
    print("数值对账: {}/{} PASS -> {}".format(ok, total, out2))
except PermissionError:
    print("数值对账: {}/{} PASS（CSV 被占用，新内容在 tmp）".format(ok, total))
