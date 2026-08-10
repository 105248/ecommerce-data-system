# -*- coding: utf-8 -*-
"""第七步：MCP 真实依赖扫描——统计唯一数据库对象数（不凑54）
扫描 mcp_server/tools/*.py + server.py 中 mart./meta./audit./core. 引用。"""
import re
from pathlib import Path
from collections import Counter

SRC = Path(r"D:/ecommerce-data-system/mcp_server")
objs = Counter()  # (schema, kind_guess, name)
raw_refs = Counter()

for f in list(SRC.glob("*.py")) + list(SRC.glob("tools/*.py")):
    if f.name == "config.py":
        continue
    txt = f.read_text(encoding="utf-8")
    # 匹配 schema.object 引用（SQL 与函数调用）
    for m in re.finditer(r"\b(mart|meta|audit|core)\.([a-z_][a-z0-9_]*)\b", txt):
        raw_refs[(m.group(1), m.group(2))] += 1

print("MCP 代码扫描文件: mcp_server/*.py + tools/*.py")
print("原始引用总数(去重前):", sum(raw_refs.values()))
print("唯一对象引用数:", len(raw_refs))
print()
# 分类统计
by_schema = Counter(s for s, _ in raw_refs)
print("按 schema 唯一对象数:", dict(by_schema))
# mart 函数 vs 视图：需要区分（查 pg 分类太重，先用命名推断：函数名含 get_/rank_/compare_/decompose_/detect_/diagnose_/generate_/assert_/previous_/period_/resolve_/list_/check_）
def kind_of(name):
    if re.match(r"^(get_|rank_|compare_|decompose_|detect_|diagnose_|generate_|assert_|previous_|period_|resolve_|list_|check_|_diag_|validate_|format_)", name):
        return "function"
    return "view_or_table"
mart_fns = [n for s, n in raw_refs if s == "mart" and kind_of(n) == "function"]
mart_other = [n for s, n in raw_refs if s == "mart" and kind_of(n) != "function"]
print("mart 函数引用数:", len(mart_fns))
print("mart 视图/表引用数:", len(mart_other), sorted(mart_other))
print("meta 对象:", sorted(n for s, n in raw_refs if s == "meta"))
print("audit 对象:", sorted(n for s, n in raw_refs if s == "audit"))
print("core 对象:", sorted(n for s, n in raw_refs if s == "core"))
# 全列表输出（供报告）
print()
print("=== 完整引用清单（schema, name, 次数） ===")
for (s, n), c in sorted(raw_refs.items()):
    print("  {}.{}  x{}".format(s, n, c))
