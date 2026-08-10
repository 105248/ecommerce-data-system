# -*- coding: utf-8 -*-
"""F1.0.1 阶段1：真实对象扫描
1) mart 全部函数 + SECURITY DEFINER + 白名单对照（存在但未入白名单 = 候选 WHITELIST_GAP）
2) core/meta/audit 表清单
3) 54 白名单接口
4) Backend 端点
5) 前端页面
6) raw_files 源文件（两店）
7) importer field_mapping 支持的报表类型
"""
import json, sys, csv
from pathlib import Path

sys.path.insert(0, r"D:/ecommerce-data-system/mcp_server")
import psycopg2

env = {}
for l in Path(r"D:/ecommerce-data-system/mcp_server/.env").read_text(encoding="utf-8").splitlines():
    l = l.strip()
    if l and "=" in l and not l.startswith("#"):
        k, _, v = l.partition("=")
        env[k.strip()] = v.strip()
conn = psycopg2.connect(host="127.0.0.1", port=5432, dbname="ecommerce_db",
                        user="postgres", password=env.get("PG_ADMIN_PASSWORD", ""), connect_timeout=5)
conn.set_session(readonly=True, autocommit=True)
cur = conn.cursor()

out = {}

# 1) mart 函数全量 + prosecdef
cur.execute("""
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'mart' AND p.prokind = 'f'
ORDER BY 1
""")
mart_fns = [{"fn": r[0], "args": r[1], "secdef": r[2]} for r in cur.fetchall()]
out["mart_functions"] = mart_fns

# 2) 白名单 54
wl = json.loads(Path(r"D:/ecommerce-data-system/convergence_final/04_database_public_interface_whitelist.json").read_text(encoding="utf-8"))
wl_fns = set()
for i in wl["interfaces"]:
    nm = i.get("object_name") or i.get("name") or ""
    if i.get("object_type") in ("FUNCTION", "function") or "(" in nm:
        wl_fns.add(nm.split("(")[0])
out["whitelist_count"] = len(wl["interfaces"])
out["whitelist_functions"] = sorted(wl_fns)

# 白名单 vs mart：存在但未入白名单的 mart 函数
mart_names = {f["fn"] for f in mart_fns}
not_in_wl = sorted(mart_names - wl_fns)
out["mart_not_in_whitelist"] = not_in_wl

# 3) core/meta/audit 表
cur.execute("""SELECT table_schema, table_name FROM information_schema.tables
WHERE table_schema IN ('core','meta','audit') AND table_type='BASE TABLE' ORDER BY 1,2""")
tables = [{"schema": r[0], "table": r[1]} for r in cur.fetchall()]
out["tables"] = tables

# 4) Backend 端点
api_files = ["D:/ecommerce-data-system/workspace/backend/app/api.py", "D:/ecommerce-data-system/workspace/backend/app/api_f1.py"]
eps = []
for f in api_files:
    for line in Path(f).read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if s.startswith('@router.get('):
            eps.append(s.split('"')[1] if '"' in s else s)
out["backend_endpoints"] = eps

# 5) 前端页面
appjs = Path(r"D:/ecommerce-data-system/workspace/backend/static/app.js").read_text(encoding="utf-8")
pages = []
for line in appjs.splitlines():
    s = line.strip()
    if s.startswith("'/'") or (s.startswith("'") and s[1:3] in ("/t", "/s", "/p", "/m", "/a", "/r", "/l", "/v", "/d", "/o", "/i")):
        pages.append(s.split("'")[1])
out["frontend_pages"] = sorted(set(pages))

# 6) raw_files 源文件（两店）
rf = Path(r"D:/ecommerce-data-system/raw_files/douyin")
files = []
for p in sorted(rf.rglob("*.xlsx")):
    files.append(str(p).replace("D:/ecommerce-data-system/", ""))
out["raw_files"] = files

# 7) importer field_mapping 报表类型（sheet 去重）
cur.execute("SELECT DISTINCT source_sheet_name FROM meta.field_mapping ORDER BY 1")
sheets = [r[0] for r in cur.fetchall()]
out["importer_sheets"] = sheets

conn.close()

# 输出
base = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.1")
base.mkdir(exist_ok=True)
with (base / "scan_objects.json").open("w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=1)

print("mart 函数数:", len(mart_fns))
print("白名单接口数:", out["whitelist_count"], "| 白名单函数:", len(wl_fns))
print("mart 存在但未入白名单:", len(not_in_wl))
for n in not_in_wl: print("   ", n)
print("core/meta/audit 表:", len(tables))
print("Backend 端点:", len(eps))
print("前端页面:", len(out["frontend_pages"]))
print("raw_files:", len(files))
print("importer sheets:", sheets)
