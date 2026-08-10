# -*- coding: utf-8 -*-
"""前端公式扫描最终验证"""
import re
from pathlib import Path

FRONT = Path(r"D:/ecommerce-data-system/workspace/frontend/src")
issues = []
checked = 0
for f in sorted(FRONT.rglob("*.tsx")):
    src = f.read_text(encoding="utf-8")
    checked += 1
    for i, line in enumerate(src.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("import") or stripped.startswith("export") or stripped.startswith("}") or stripped.startswith("{"):
            continue
        for m in re.finditer(r"(\w+)\s*/\s*(\w+)", line):
            expr = m.group(0)
            if re.search(r"[\u4e00-\u9fff]", expr):
                continue
            if "/" in line and ("api" in line or "'/" in line or '"' in line or "`/" in line):
                continue
            if any(x in expr for x in ("height", "width", "length", "100", "gap", "repeat", "minmax", "gridTemplate", "fontSize", "maxWidth")):
                continue
            issues.append("{}:{} 除法 {}".format(f.name, i, expr.strip()))
        for m in re.finditer(r"(current|previous|prev|cur|last)\w*\s*-\s*\w+", line):
            issues.append("{}:{} 环比减法 {}".format(f.name, i, m.group(0).strip()))
        if re.search(r"\.reduce\s*\(|\.sum\s*\(", line):
            issues.append("{}:{} 聚合".format(f.name, i))
all_src = "\n".join(f.read_text(encoding="utf-8") for f in FRONT.rglob("*.tsx"))
if '"result": "PASS"' in all_src or 'test_result="PASS"' in all_src:
    issues.append("硬编码 PASS")

print("扫描 {} 文件，问题 {} 条".format(checked, len(issues)))
for i in issues[:8]:
    print("  ", i)
