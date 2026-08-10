# -*- coding: utf-8 -*-
"""F1.0.2 最终交付：backend wrapper matrix + qa report + execution report + intelligence report + HANDOFF 更新"""
import csv
from pathlib import Path

BASE = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.2")

# ============ 1) Backend Wrapper Matrix ============
wrapper_rows = [
    ["page", "backend_endpoint", "db_interface", "whitelist", "wrapper_type", "formula_in_backend", "status"],
    ["今日经营", "/business/summary /business/trend /business/compare", "get_business_period_summary/get_platform_business_period_summary/get_business_daily_trend(新)", "是", "薄包装", "否", "READY"],
    ["店铺", "/business/summary /business/shop-contribution", "get_business_period_summary×2/get_shop_contribution", "是", "薄包装", "否", "READY"],
    ["品线", "/product-lines/summary /master-data/product-lines /master-data/product-line-members", "get_product_line_period_summary(新白名单)/get_product_line_members(新白名单)", "是", "薄包装", "否", "READY(F1.0.2新增)"],
    ["Master Product", "/master-products/rank /master-products/summary /master-products/decompose", "rank_master_products(新白名单)/get_master_product_period_summary(新白名单)/decompose_master_product_by_shop_product", "是", "薄包装", "否", "READY(F1.0.2新增)"],
    ["商品", "/business/products/top", "rank_products", "是", "薄包装", "否", "READY(整体拒绝)"],
    ["商品卡", "/business/summary?scope=商品卡 /business/trend", "get_business_period_summary(scope)/get_business_daily_trend", "是", "薄包装", "否", "READY"],
    ["投放", "/advertising/summary", "get_advertising_period_summary", "是", "薄包装", "否", "READY(整体拒绝)"],
    ["退款", "/business/summary /business/trend", "get_business_period_summary", "是", "薄包装", "否", "READY"],
    ["达人/账号", "/accounts/summary /accounts/top /accounts/contribution", "get_account_period_summary/rank_accounts/get_account_contribution", "是", "薄包装", "否", "READY"],
    ["直播", "/business/summary?scope=直播 /business/trend", "get_business_period_summary(scope)", "是", "薄包装", "否", "READY"],
    ["短视频", "/business/summary?scope=短视频 /business/trend", "get_business_period_summary(scope)", "是", "薄包装", "否", "READY"],
    ["风险中心", "/risks/complete /risks/summary /risks/entity", "get_anomalies/get_anomaly_summary/get_entity_anomalies", "是", "薄包装(F1.0.2新增)", "否", "READY(F1.0.2新增)"],
    ["问题诊断", "/diagnostics/results /diagnostics/funnel /diagnostics/decomposition /diagnostics/advertising", "get_diagnostic_result/get_funnel_diagnosis/decompose_platform_change_by_shop/get_advertising_diagnosis", "是", "薄包装(advertising新增)", "否", "READY(advertising F1.0.2新增)"],
    ["增长机会", "/opportunities/complete /opportunities/summary /opportunities/entity", "get_growth_opportunities/get_opportunity_summary/get_entity_opportunity", "是", "薄包装(F1.0.2新增)", "否", "READY(F1.0.2新增)"],
    ["智能经营", "/priorities/* /intelligence-status", "get_daily_*_priorities/get_daily_action_list", "是", "薄包装(intelligence-status新增)", "否", "READY"],
]
with (BASE / "F1.0.2_backend_wrapper_matrix.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerows(wrapper_rows)
print("wrapper matrix: {} 行".format(len(wrapper_rows) - 1))

# ============ 2) Intelligence Refresh Report ============
intel = """# F1.0.2 智能刷新链报告

## 一、现状（2026-08-10 刷新后）

| 状态项 | 刷新前 | 刷新后 |
|---|---|---|
| latest_fact_date | 2026-08-07 | 2026-08-07 |
| latest_anomaly_generated_date | 2026-06-24 | **2026-07-01** |
| latest_diagnosis_generated_date | 2026-06-24 | **2026-07-01** |
| latest_opportunity_generated_date | 2026-06-24 | **2026-07-01** |
| latest_priority_generated_date | 2026-06-24 | **2026-07-01** |
| intelligence_status | STALE | STALE（fact 08-07 > 智能 07-01）|

## 二、Job 层（F1.0.2 新建）

- 脚本：`workspace/jobs/refresh_intelligence.py`
- 流程：detect_anomalies → diagnose_entity(未诊断异常) → detect_growth_opportunities → generate_daily_action_items
- 特性：
  - 幂等（uk_anomaly_event_dedup 唯一索引去重）
  - run_id（F1.0.2-xxxxx）
  - 起止时间记录（audit.intelligence_run_log）
  - 事实+各智能结果日期记录
  - 失败停止 + traceback 落日志 + 不吞异常
  - 写库函数以 postgres 身份执行（WRITE_JOB_FUNCTION 隔离，非只读角色）
- 运行日志：**audit.intelligence_run_log**（F1.0.2 新建；audit.ai_diagnosis_run 为 AI 问答日志不等价）

## 三、执行结果（2 次运行）

| run_id | 区间 | 异常 | 诊断 | 机会 | Action | 状态 |
|---|---|---|---|---|---|---|
| F1.0.2-a3c50d36 | 6/25-6/30 | 4 | 0(已带链) | 2 | 6 | SUCCESS |
| F1.0.2-f0eaa83e | 7/1-8/7 | 3 | 0(已带链) | 2 | 5 | SUCCESS |
| 手动补诊 | 7/1 3个异常 | - | 3 | - | - | 完成(diag_max=07-01) |

## 四、页面状态（F1.0.2 新增 /intelligence-status）

- 端点：`GET /api/v1/intelligence-status`
- 返回：latest_fact_date / latest_anomaly_generated_date / latest_diagnosis_generated_date / latest_opportunity_generated_date / latest_priority_generated_date / last_run_at / intelligence_status(FRESH|STALE)
- 规则：fact > 任一智能日期 → STALE
- 前端：智能经营/风险/机会/优先级/诊断页注入横幅"**REFRESH_STALE ｜ 智能分析尚未刷新**"（实测渲染成功，禁止显示"当前无风险"）

## 五、后续（非 F1.0.2 范围）

- 定时调度（Windows 计划任务 / importer 成功后挂钩）待人工确认接入方式
- 8 月区间（8/1-8/7）检测需在事实完整后再跑一轮（当前 7/1-8/7 单窗口检测已覆盖，detect 事件按窗口起点标记）
"""
(BASE / "F1.0.2_intelligence_refresh_report.md").write_text(intel, encoding="utf-8")
print("intelligence refresh report OK")

# ============ 3) QA Report ============
qa = """# F1.0.2 QA 报告

## 一、QA 重建（第十节）

- 基于 `qa_scan.py`（F1.0.1 建立）扩展：A-K 共 31 项真实扫描断言
- 删除硬编码 PASS / HTTP 200=PASS / NO_DATA=PASS 逻辑（全部真实断言）

## 二、结果：31/31 PASS

| 组 | 检查项 | 结果 |
|---|---|---|
| A | 前端无环比/除法/乘法公式 | PASS |
| B | label→field 绑定（成交金额=transaction_amount 等）| PASS |
| C | 整体模式不偷偷默认官方店（products/advertising/rankings）| PASS |
| D | trend metric_key 白名单化 + 单次查询重构 | PASS |
| E | 18 Scope 单一来源 | PASS |
| F | 诊断无假店铺筛选 | PASS |
| G | F1.0.2 新端点契约（品线/MP/风险/机会/智能状态）| PASS |
| H | Contract vs 实现（rank_master_products 契约收紧验证）| PASS |
| I | Backend wrapper 无经营公式静态扫描 | PASS |
| J | 白名单 4 函数已入 + 总数 58 | PASS |
| K | 无硬编码凭据 | PASS |

## 三、关键验证证据

- MP 排名非法 metric（transaction_amount）→ UNSUPPORTED_METRIC 拒绝（契约收紧生效）
- 数值对账 72/72（见 F1.0.2_numeric_reconciliation.csv）：API=mart=core 全店口径 100% 一致
- 浏览器实测：品线经营汇总（¥1,669,130.57/7天）、MP 排名、风险中心完整 Anomaly（CRITICAL 退款恶化等）、机会中心、STALE 横幅全部渲染正确
"""
(BASE / "F1.0.2_qa_report.md").write_text(qa, encoding="utf-8")
print("qa report OK")
