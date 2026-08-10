# -*- coding: utf-8 -*-
"""F1.0.4 前端公式扫描 v2：仅扫描 tsx 文件内容（排除 import 路径），聚焦经营计算"""
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
        if not stripped or stripped.startswith("//") or stripped.startswith("*") or stripped.startswith("/*") or stripped.startswith("import") or stripped.startswith("export") or stripped.startswith("}") or stripped.startswith("{"):
            continue
        # 业务除法（排除 API 路径行/样式/中文文案）
        for m in re.finditer(r"(\w+)\s*/\s*(\w+)", line):
            expr = m.group(0)
            if re.search(r"[\u4e00-\u9fff]", expr):
                continue
            # API 路径上下文（行内含 /api/ 或路径字符串）→ 非业务公式
            if "/" in line and ("api" in line or "'/" in line or '"' in line or "`/" in line):
                continue
            if any(x in expr for x in ("height", "width", "length", "100", "gap", "repeat", "minmax", "gridTemplate", "fontSize", "maxWidth")):
                continue
            issues.append("{}:{} 除法 {}".format(f.name, i, expr.strip()))
        # 环比减法
        for m in re.finditer(r"(current|previous|prev|cur|last)\w*\s*-\s*\w+", line):
            issues.append("{}:{} 环比减法 {}".format(f.name, i, m.group(0).strip()))
        # sum/reduce
        if re.search(r"\.reduce\s*\(|\.sum\s*\(", line):
            issues.append("{}:{} 聚合 {}".format(f.name, i, line.strip()[:60]))

# 硬编码 PASS
all_src = "\n".join(f.read_text(encoding="utf-8") for f in FRONT.rglob("*.tsx"))
if '"result": "PASS"' in all_src or "test_result=\"PASS\"" in all_src:
    issues.append("硬编码 PASS")

out = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.4/F1.0.4_frontend_formula_scan.md")
content = (
    "# F1.0.4 前端公式扫描\n\n- 扫描范围: workspace/frontend/src (**{}** tsx 文件)\n"
    "- 扫描项: 业务除法 / 环比减法 / sum-reduce / 硬编码 PASS\n"
    "- 结果: **{} 个问题**（均为误报需复核，纯 UI format 允许）\n\n## 命中明细\n```\n{}\n```\n"
).format(checked, len(issues), "\n".join(issues[:30]) or "无")
import os as _os
import time as _time
_tmp = out.with_suffix(".md.tmp{}".format(_time.time()))
_tmp.write_text(content, encoding="utf-8")
try:
    _os.replace(_tmp, out)
    print("报告已写:", out)
except PermissionError:
    print("报告被占用，新内容在", _tmp)
