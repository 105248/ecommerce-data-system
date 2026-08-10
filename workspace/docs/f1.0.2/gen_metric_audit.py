# -*- coding: utf-8 -*-
"""F1.0.2 metric binding audit：全仓扫描 app.js 中 成交金额/用户支付金额/user_pay_amount/transaction_amount 绑定"""
import re
import csv
from pathlib import Path

APP = Path(r"D:/ecommerce-data-system/workspace/backend/static/app.js").read_text(encoding="utf-8")

# 定位各页面段
pages = {}
for m in re.finditer(r"'/([a-z-]+)':\s*(?:async\s*)?\(f\)\s*=>\s*\{", APP):
    pages[m.group(1)] = m.start()

page_order = ["today", "store", "priorities", "product-lines", "master-products", "products",
              "product-card", "advertising", "refund", "accounts", "live", "video",
              "search", "materials", "smart-operation", "risks", "diagnosis", "opportunities"]

rows = []
issues = []

def page_slice(name):
    start = pages.get(name)
    if start is None:
        return ""
    nxt = [v for k, v in pages.items() if v > start]
    end = min(nxt) if nxt else len(APP)
    return APP[start:end]

# 规则：transaction_amount → 成交金额；user_pay_amount → 用户支付金额
# 检查点：MetricCard('成交金额', X) 必须 X 含 transaction_amount；MetricCard('用户支付金额', X) 必须含 user_pay_amount
for pg in page_order:
    seg = page_slice(pg)
    # MetricCard 调用
    for m in re.finditer(r"MetricCard\('([^']+)'\s*,\s*([^,)]+)", seg):
        label, expr = m.group(1), m.group(2).strip()
        result = "OK"
        note = ""
        if label == "成交金额":
            if "transaction_amount" not in expr:
                result = "FAIL"; issues.append(f"{pg}/成交金额 → {expr}")
        elif label == "用户支付金额":
            if "user_pay_amount" not in expr:
                result = "FAIL"; issues.append(f"{pg}/用户支付金额 → {expr}")
        elif label == "退款金额(支付时间)":
            if "refund_amount_pay_time" not in expr:
                result = "FAIL"; issues.append(f"{pg}/退款金额(支付时间) → {expr}")
        elif label == "成交退款金额":
            if "transaction_refund_amount_pay_time" not in expr:
                result = "FAIL"; issues.append(f"{pg}/成交退款金额 → {expr}")
        rows.append([pg, label, expr, "api_field", "db_field", "db_cn_name", result])
    # 趋势标题 + TrendSvg 指标
    for m in re.finditer(r"<h3>([^<]*成交金额趋势[^<]*)</h3>", seg):
        rows.append([pg, m.group(1), "TrendSvg(metric)", "-", "-", "-", "INFO"])

# 表格表头检查：用户支付金额 列
for pg in page_order:
    seg = page_slice(pg)
    for m in re.finditer(r"<th>([^<]*(?:成交金额|用户支付金额)[^<]*)</th>", seg):
        hdr = m.group(1)
        # 找该表格对应数据行（简化：仅记录）
        rows.append([pg, hdr, "table-header", "-", "-", "-", "INFO"])

p = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.2/F1.0.2_metric_binding_audit.csv")
p.parent.mkdir(parents=True, exist_ok=True)
with p.open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["page", "ui_label", "frontend_field", "api_field", "db_field", "db_cn_name", "result"])
    w.writerows(rows)

print("metric binding audit 行数:", len(rows))
print("FAIL 数:", len(issues))
for i in issues:
    print("  FAIL:", i)
