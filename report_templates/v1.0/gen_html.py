# -*- coding: utf-8 -*-
"""生成最终日报/周报 HTML（单文件，内嵌全月数据，双击即可打开）。

用法：
    python gen_html.py
输出：html/report.html
"""
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent
TPL = BASE / "html" / "template.html"
DATA = BASE / "html" / "data" / "report_data.json"
OUT = BASE / "html" / "report.html"

MARK = "window.__REPORT_DATA__ = {};"


def main():
    tpl = TPL.read_text(encoding="utf-8")
    if MARK not in tpl:
        raise SystemExit("模板缺少数据占位符: " + MARK)
    data = json.loads(DATA.read_text(encoding="utf-8"))
    payload = json.dumps(data, ensure_ascii=False).replace("<", "\\u003c")
    html = tpl.replace(MARK, "window.__REPORT_DATA__ = " + payload + ";")
    OUT.write_text(html, encoding="utf-8")
    size_kb = OUT.stat().st_size / 1024
    print("生成完成: {} ({:.0f} KB, {} 天)".format(OUT, size_kb, len(data.get("dates", []))))


if __name__ == "__main__":
    main()
