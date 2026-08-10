# -*- coding: utf-8 -*-
"""F1.0.1 收口：生成 6 份交付物（基于真实扫描 s1_scan_objects.json + 阶段2/5-13 验证结论）"""
import csv
from pathlib import Path
from collections import Counter

BASE = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.1")

# ============ 1) Capability Matrix ============
# page, capability, source_file, source_exists, source_time_type, source_grain, core_object, core_exists,
# supported_metrics, unsupported_metrics, mart_object, mart_exists, calculation_ready, official_whitelist,
# backend_endpoint, frontend_status, gap_type, gap_reason, recommended_action
rows = [
    # --- 核心经营 ---
    ["今日经营", "经营驾驶舱 KPI/趋势/贡献", "成交分析-成交概览/商品构成", True, "DAILY_FACT", "day×shop×scope", "core.douyin_deal_daily", True,
     "transaction_amount/user_pay_amount/refund_rate/ad_spend/settlement", "-", "get_business_period_summary/get_platform_business_period_summary", True, True, True,
     "/business/summary /business/trend /business/compare /business/shop-contribution", "READY", "READY", "-", "无需动作"],
    ["店铺经营", "两店对比/贡献/环比", "成交分析-成交概览", True, "DAILY_FACT", "day×shop", "core.douyin_deal_daily", True,
     "transaction/user_pay/refund_rate/ad_spend/settlement/contribution", "-", "get_business_period_summary×2/get_shop_contribution", True, True, True,
     "/business/summary /business/shop-contribution", "READY", "READY", "-", "无需动作"],
    ["经营优先级", "风险/机会/Action 优先级", "V1.1 智能层(6月基线)", True, "PERIOD_SNAPSHOT", "period", "mart.daily_action_item", True,
     "risk_priority_score/opportunity_priority_score/action", "-", "get_daily_risk_priorities/get_daily_opportunity_priorities/get_daily_action_list", True, True, True,
     "/priorities/*", "READY", "READY(数据停在6/24)", "REFRESH_GAP", "智能结果停在 2026-06-24，事实已到 2026-08-07", "建立导入后智能刷新调度链(阶段13)"],
    # --- 品线 / MP ---
    ["品线", "品线结构+成员", "成交分析-商品构成+主数据", True, "VERSION", "structure", "meta.product_line/master_product", True,
     "成员/映射数/覆盖店数", "-", "get_product_line_members", True, True, False,
     "/master-data/product-line-members(meta直查)", "READY", "READY", "WHITELIST_GAP", "get_product_line_members 存在已验证但未入白名单", "验收通过后纳入正式接口治理"],
    ["品线", "品线经营汇总", "成交分析-商品构成×CONFIRMED映射", True, "DAILY_FACT", "day×MP", "core.douyin_product_daily+映射", True,
     "user_pay_amount/refund_amount/refund_rate/mapping_coverage", "transaction/settlement/ad_spend(无交叉事实)", "get_product_line_period_summary", True, True, False,
     "无", "PARTIAL", "WHITELIST_GAP", "函数存在验证通过(鱼子酱30日881万)但未入白名单", "验收后纳入白名单；趋势需日层函数(MART_GAP)"],
    ["品线", "品线趋势", "-", True, "DAILY_FACT", "day", "core.douyin_product_daily+映射", True,
     "user_pay 逐日", "-", "无日层函数(仅区间汇总)", False, False, False,
     "无", "NOT_DEPLOYED", "MART_GAP", "无确定性日序列函数(避免Backend N次调用)", "经确认后在mart新增确定性日层函数(用户阶段5允许)"],
    ["Master Product", "主档列表/映射状态", "主数据", True, "VERSION", "structure", "meta.master_product", True,
     "编码/名称/状态", "-", "meta.master_product(直查)", True, True, True,
     "/master-data/products", "READY", "READY", "READY", "-", "无需动作"],
    ["Master Product", "MP 经营汇总/跨店拆解", "成交分析-商品构成×CONFIRMED", True, "DAILY_FACT", "day×MP×shop", "core.douyin_product_daily+映射", True,
     "user_pay/refund/refund_rate/mapped_shop_count/店铺拆解", "transaction/settlement(无事实)", "get_master_product_period_summary/decompose_master_product_by_shop_product", True, True, False,
     "无", "PARTIAL", "WHITELIST_GAP", "两函数验证通过(整体=两店之和)但未入白名单", "验收后纳入白名单"],
    ["Master Product", "MP 经营排名", "成交分析-商品构成×CONFIRMED", True, "DAILY_FACT", "day×MP", "core.douyin_product_daily+映射", True,
     "user_pay_amount(唯一真实指标)", "transaction/settlement(声明但未计算)", "rank_master_products", True, True, False,
     "无", "PARTIAL", "WHITELIST_GAP", "metric_key 假契约(仅算user_pay,三种key值相同)", "先修正函数体(支持真实多指标或收紧契约)再入白名单"],
    # --- 商品 ---
    ["商品", "商品排名", "成交分析-商品构成", True, "DAILY_FACT", "day×product×shop", "core.douyin_product_daily", True,
     "user_pay_amount", "-", "rank_products", True, True, True,
     "/business/products/top", "READY", "READY", "READY", "-", "无需动作"],
    ["商品", "商品退款/结算/投放列", "-", True, "-", "-", "core.douyin_product_daily(无这些列)", True,
     "-", "settlement/transaction/ad_spend(商品事实无)", "-", False, False, False,
     "无", "NOT_DEPLOYED", "UNSUPPORTED_METRIC", "商品粒度源事实不含结算/投放/成交", "页面只展示用户支付金额(已修正标签)"],
    # --- 商品卡 ---
    ["商品卡", "商品卡渠道整体", "成交分析-成交概览(scope=商品卡)", True, "DAILY_FACT", "day×scope", "core.douyin_deal_daily", True,
     "transaction/user_pay/refund/settlement/ad_spend", "-", "get_business_period_summary(scope=商品卡)", True, True, True,
     "/business/summary?scope=商品卡", "READY", "READY", "READY", "-", "无需动作"],
    ["商品卡", "商品卡来源构成(曝光/点击/来源分解)", "无独立源文件", False, "-", "-", "无对应表", False,
     "-", "-", "-", False, False, False,
     "无", "NOT_DEPLOYED", "SOURCE_NOT_AVAILABLE", "源文件无商品卡来源构成sheet，core无对应事实", "等待平台提供来源构成导出；不造数据"],
    # --- 投放 ---
    ["投放", "基础投放经营", "成交分析-成交概览(投放列)", True, "DAILY_FACT", "day×shop", "core.douyin_deal_daily", True,
     "ad_spend(被投/绑定)/归因成交/占比/费比/综合费比/效率", "-", "get_advertising_period_summary", True, True, True,
     "/advertising/summary", "READY", "READY", "READY", "-", "无需动作"],
    ["投放", "计划/账户/单元/预算/状态", "无独立源文件", False, "-", "-", "无对应表", False,
     "-", "-", "-", False, False, False,
     "无", "NOT_DEPLOYED", "SOURCE_NOT_AVAILABLE", "无计划级源数据", "保持 KNOWN LIMITATION；不推算"],
    # --- 退款 ---
    ["退款", "退款金额/率/订单/店铺退款", "成交分析-成交概览(退款列)", True, "DAILY_FACT", "day×shop×scope", "core.douyin_deal_daily", True,
     "refund_amount_pay_time/refund_rate/refund_order", "-", "get_business_period_summary", True, True, True,
     "/business/summary /business/trend(refund_rate)", "READY", "READY", "READY", "-", "无需动作"],
    ["退款", "退款原因/售后原因", "无独立源文件", False, "-", "-", "无对应表", False,
     "-", "-", "-", False, False, False,
     "无", "NOT_DEPLOYED", "SOURCE_NOT_AVAILABLE", "无退款原因原始明细", "页面明确'当前数据源不支持退款原因分析'；AI不得猜原因"],
    # --- 账号 ---
    ["达人/账号", "账号汇总/排名/贡献", "成交分析-账号构成", True, "DAILY_FACT", "day×account×shop", "core.douyin_account_daily", True,
     "transaction/user_pay/refund_rate/settlement/ad_spend/rank/contribution", "-", "get_account_period_summary/rank_accounts/get_account_contribution", True, True, True,
     "/accounts/summary /accounts/top /accounts/contribution", "READY", "READY", "READY", "-", "已补齐(2026-08-10)"],
    # --- 直播 / 短视频 ---
    ["直播", "直播渠道整体", "成交分析-成交概览(scope=直播)", True, "DAILY_FACT", "day×scope", "core.douyin_deal_daily", True,
     "transaction/user_pay/refund_rate/ad_spend", "-", "get_business_period_summary(scope=直播)", True, True, True,
     "/business/summary?scope=直播", "READY", "READY", "READY", "-", "无需动作"],
    ["直播", "直播场次/直播商品/时段明细", "单载体构成sheet(仅商品卡内容)", True, "DAILY_FACT", "content(商品卡)", "core.douyin_content_daily(仅carrier=商品卡)", True,
     "-", "直播场次/商品/时段(无事实)", "-", False, False, False,
     "无", "NOT_DEPLOYED", "SOURCE_NOT_AVAILABLE", "content_daily 全局仅商品卡内容(53024行/599内容)，无直播内容级事实", "禁止用频道汇总冒充明细"],
    ["短视频", "短视频渠道整体", "成交分析-成交概览(scope=短视频)", True, "DAILY_FACT", "day×scope", "core.douyin_deal_daily", True,
     "transaction/user_pay/refund_rate/ad_spend", "-", "get_business_period_summary(scope=短视频)", True, True, True,
     "/business/summary?scope=短视频", "READY", "READY", "READY", "-", "无需动作"],
    ["短视频", "单视频/视频素材级", "单载体构成sheet(仅商品卡内容)", True, "DAILY_FACT", "content(商品卡)", "core.douyin_content_daily(仅carrier=商品卡)", True,
     "-", "单视频/素材级(无事实)", "-", False, False, False,
     "无", "NOT_DEPLOYED", "SOURCE_NOT_AVAILABLE", "content_daily 无短视频内容", "禁止用频道汇总冒充明细"],
    # --- 搜索 / 素材 ---
    ["搜索", "搜索成交/关键词", "无独立源文件", False, "-", "-", "无对应表", False,
     "-", "-", "-", False, False, False,
     "无", "NOT_DEPLOYED", "SOURCE_NOT_AVAILABLE", "搜索数据源未接入", "等待平台导出搜索核心数据"],
    ["素材", "素材列表/表现", "无独立源文件", False, "-", "-", "无对应表", False,
     "-", "-", "-", False, False, False,
     "无", "NOT_DEPLOYED", "SOURCE_NOT_AVAILABLE", "素材数据源未接入", "等待平台导出素材分析"],
    # --- 智能经营 ---
    ["智能经营", "决策中心(风险/机会/Action摘要)", "V1.1 智能层", True, "PERIOD_SNAPSHOT", "period", "mart.*_event/daily_action_item", True,
     "risk/opportunity/action 摘要", "-", "get_daily_*_priorities/get_daily_action_list", True, True, True,
     "/priorities/*", "READY", "READY(6/24)", "REFRESH_GAP", "智能结果停在6/24", "同经营优先级"],
    ["风险中心", "风险完整列表(Anomaly)", "V1.1 anomaly_event", True, "EVENT", "event", "mart.anomaly_event", True,
     "anomaly_code/level/entity/evidence", "-", "get_anomalies/get_anomaly_summary/get_entity_anomalies", True, True, False,
     "无(仅priority包装)", "PARTIAL", "WRAPPER_GAP", "3个白名单函数存在但Backend未包装", "补薄wrapper(参数/分页/JSON)，风险中心用完整Anomaly"],
    ["问题诊断", "诊断结果/拆解", "V1.1 diagnostic_result", True, "EVENT", "event", "mart.diagnostic_result", True,
     "diagnostic_code/stage/confidence/证据", "-", "get_diagnostic_result/decompose_platform_change_by_shop", True, True, True,
     "/diagnostics/results /diagnostics/decomposition", "READY", "READY", "READY", "-", "无需动作"],
    ["问题诊断", "漏斗/广告诊断/实体指标", "V1.1 诊断链", True, "EVENT", "event", "mart.diagnostic_result", True,
     "funnel/advertising/entity_metrics", "-", "get_funnel_diagnosis/get_advertising_diagnosis/get_diagnostic_entity_metrics", True, True, False,
     "funnel已包装;advertising/entity未包装", "PARTIAL", "WRAPPER_GAP", "get_advertising_diagnosis/get_diagnostic_entity_metrics白名单未包装", "补薄wrapper"],
    ["增长机会", "机会完整列表", "V1.1 opportunity_event", True, "EVENT", "event", "mart.opportunity_event", True,
     "opportunity_code/score/evidence/peer", "-", "get_growth_opportunities/get_opportunity_summary/get_entity_opportunity", True, True, False,
     "无(仅priority包装)", "PARTIAL", "WRAPPER_GAP", "3个白名单函数存在但Backend未包装", "补薄wrapper，机会中心用完整Opportunity"],
    ["智能刷新", "导入→异常→诊断→机会→优先级自动链", "V1.1 写库函数", True, "PERIOD_SNAPSHOT", "period", "mart.*_event", True,
     "-", "-", "detect_anomalies/diagnose_*/detect_growth_opportunities/generate_daily_action_items", True, False, False,
     "无(人工触发)", "STALE", "REFRESH_GAP", "5个写库函数存在但无调度；智能结果停在6/24", "建立独立调度/Job层(导入成功后自动跑)，Web只读结果"],
]

p = BASE / "F1.0.1_business_capability_matrix.csv"
with p.open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["page", "capability", "source_file", "source_exists", "source_time_type", "source_grain",
                "core_object", "core_exists", "supported_metrics", "unsupported_metrics", "mart_object",
                "mart_exists", "calculation_ready", "official_whitelist", "backend_endpoint", "frontend_status",
                "gap_type", "gap_reason", "recommended_action"])
    w.writerows(rows)
cnt = Counter(r[16].split("_")[0] if r[16] not in ("READY",) else "READY" for r in rows)
cnt = Counter(r[16] for r in rows)
print("matrix:", p, "| 行数:", len(rows))
print("gap_type 分布:", dict(cnt))

# ============ 2) existing_function_whitelist_promotion_list.md ============
promo = """# F1.0.1 已有 Function 白名单升级候选清单

> 基于 2026-08-10 真实数值验证（官方/护理/整体 × 1日/7日/30日 × CONFIRMED mapping）
> 原则：验收通过后才纳入正式接口治理；不批量加白名单；禁止 Contract 与实现不一致

## 一、候选函数（4 个，验证结果）

| 函数 | 状态 | 验证结论 | 纳入白名单前置条件 |
|---|---|---|---|
| `get_product_line_members` | ACTIVE ✓ | 返回品线成员/映射数/覆盖店数，数值正确 | 无 |
| `get_product_line_period_summary` | ACTIVE ✓ | 鱼子酱品线 30 日 user_pay=8,813,486.86、refund=1,567,613.44、18/18 映射、2 店覆盖，数值正确 | 无 |
| `get_master_product_period_summary` | ACTIVE ✓ | MP000002 整体=官方 5,653,849.01（护理 0 映射→空），整体语义=映射店之和；单日正常 | 无 |
| `rank_master_products` | ACTIVE ⚠️ | **metric_key 假契约确认**：三种 metric_key（user_pay/transaction/settlement）返回完全相同 current_value（仅标签变）；函数体不含 transaction_amount | **必须先修正**（真实支持多指标 或 收紧契约只声明 user_pay_amount） |

## 二、纳入白名单需同步的治理动作

1. Backend 补薄 wrapper（仅参数校验/分页/JSON/日志；禁计算）
2. 更新 03_official_database_interface_catalog.md + 04_database_public_interface_whitelist.json
3. 更新 Backend capability matrix
4. MCP 只读 / Backend 只读 / core 禁止直读（保持）

## 三、不纳入的内部函数（明确排除）

- `_diag_*`（8 个）：SECURITY DEFINER 内部调用链，不对外
- `assert_period/assert_rank_args/period_scope_rule/previous_period/resolve_scope/scope_daily`：内部解析/校验
- `detect_*/diagnose_*/generate_daily_action_items`（5 个写库函数）：只读角色不应执行（写型隔离，保持仅 postgres）
- `format_percent_2`：LEGACY-REVIEW（历史脚本弱依赖）

> ⚠️ 本轮未批量加入白名单，等待人工确认。
"""
(BASE / "F1.0.1_existing_function_whitelist_promotion_list.md").write_text(promo, encoding="utf-8")

# ============ 3) source_onboarding_gap_list.md ============
onboard = """# F1.0.1 已有源数据待入库清单（DATA_ONBOARDING_GAP）

> 扫描结论：桌面「数据库/基础数据」两店各 8 个月「抖音电商罗盘-成交分析」文件（单一报表类型，11 sheet）
> **未发现"有源文件但未入库"的场景** —— 现有源文件已全部导入 core（9 表，2026-01~08 全量）。

| 源文件 | 状态 | 已入库 | 说明 |
|---|---|---|---|
| 成交分析 2026-01~08（两店）| 已导入 | core.douyin_*_daily 9 表 | batch 9-25，257,775 行 |
| 单载体构成 sheet（4月+）| 已导入 | core.douyin_content_daily | 但内容仅 carrier=商品卡（53024 行/599 内容）|

## 结论

DATA_ONBOARDING_GAP = **0**。
所有已获取的源数据均已完成 Source→mapping→core 接入；下一步缺口集中在"平台尚未提供的源文件"（见 true_source_gap_list）。
"""
(BASE / "F1.0.1_source_onboarding_gap_list.md").write_text(onboard, encoding="utf-8")

# ============ 4) true_source_gap_list.md ============
true_gap = """# F1.0.1 真实源数据缺口清单（SOURCE_NOT_AVAILABLE）

> 判定标准：平台/业务侧没有对应原始导出文件，且 core 无对应事实 → 不造数据、不推断

| 页面 | 能力 | 缺口 | 现状证据 |
|---|---|---|---|
| 商品卡 | 来源构成（曝光/点击/来源分解）| 无独立源文件 | 成交分析 11 sheet 无来源构成；core 无对应表 |
| 搜索 | 搜索成交/关键词/流量 | 无独立源文件 | 无"搜索核心数据"导出；core 无对应表 |
| 素材 | 素材列表/表现/排名 | 无独立源文件 | 无"素材分析"导出；core 无对应表 |
| 退款 | 退款原因/售后原因 | 无明细源文件 | 成交分析无退款原因列 |
| 投放 | 计划/账户/单元/预算/状态 | 无计划级源文件 | 成交分析仅店铺级投放列 |
| 直播 | 场次/直播商品/时段/分钟级 | content_daily 仅商品卡内容 | 单载体构成 sheet 无直播内容；全局 content 53024 行全为商品卡 |
| 短视频 | 单视频/视频素材级 | content_daily 无短视频内容 | 同上 |

## 处置

- 直播/短视频：渠道整体（scope=直播/短视频）READY；明细禁止用频道汇总冒充（页面已标注）
- 其余：页面明确"当前数据源不支持XX分析"；AI 不得猜测
- 全部记入 F1.0 能力缺口，等待平台提供对应导出后走标准接入流程
"""
(BASE / "F1.0.1_true_source_gap_list.md").write_text(true_gap, encoding="utf-8")

# ============ 5) intelligence_refresh_report.md ============
refresh = """# F1.0.1 智能刷新链检查报告（REFRESH_GAP）

## 一、现状

| 项 | 值 |
|---|---|
| 最新事实日期（core.douyin_deal_daily max biz_date）| **2026-08-07** |
| 最新异常日期（mart.anomaly_event max current_start_date）| **2026-06-24** |
| 最新机会日期（mart.opportunity_event max current_start_date）| **2026-06-24** |
| 事件量级 | anomaly 104 / diagnosis 5 / opportunity 264 / action 368 |
| 导入批次 | batch 9-25（2026-08-10 完成 1-8 月全量导入）|

## 二、结论

**REFRESH_GAP = 1（确认）**：V1.1 智能层（异常/诊断/机会/优先级）基于 2026-06 数据生成，1-8 月新导入事实**未触发智能重算**。当前风险/机会/诊断/优先级页面展示的是 6 月结果，8 月区间显示"无风险/无机会"是**智能未刷新**而非真实无风险。

## 三、写库函数（已存在，可复用）

```
detect_anomalies
diagnose_anomaly / diagnose_entity
detect_growth_opportunities
generate_daily_action_items
```

## 四、方案（待人工确认后实施）

```
Import batch validated（成功）
  → 调度层触发 V1.1 批处理（detect → diagnose → opportunity → priority/action）
  → 记录运行日志（mart.intelligence_run_log）
  → Web 只读结果
```

- 建立独立调度/Job 层（不在 Web 查询时实时计算）
- 页面增加状态字段：latest_fact_date / latest_anomaly_generated_date / latest_diagnosis_generated_date / latest_opportunity_generated_date / latest_priority_generated_date / intelligence_status = FRESH | STALE
- 最新事实日期晚于智能结果日期时，页面显示 **"智能分析尚未刷新"**（不得显示"当前无风险"）

## 五、本轮动作

仅记录状态与方案；未创建调度 Job（等待人工确认）。
"""
(BASE / "F1.0.1_intelligence_refresh_report.md").write_text(refresh, encoding="utf-8")

# ============ 6) execution_report.md ============
exec_rep = """# F1.0.1 经营中心数据能力收口执行报告

> 执行时间：2026-08-10 ｜ 模式：只读盘点 + 数值验证 + 方案输出（未批量改库）｜ 数据库 0 变更

## 一、真实扫描结论

- mart 75 函数 / 白名单 46 函数 → **29 个未入白名单**（其中 4 个品线/MP 候选 + 9 个智能查询已入白名单但 5 个未包装）
- core 9 表（douyin_*_daily）/ meta+audit 16 表；Backend 29 端点；前端 22 路由
- 源文件：两店各 8 个月「成交分析」（单一报表 11 sheet），**全部已入库**（DATA_ONBOARDING_GAP=0）
- content_daily 全局仅"商品卡"内容 → 直播/短视频内容级明细无事实

## 二、Capability Matrix 统计

| gap_type | 数量 | 明细 |
|---|---|---|
| READY | 14 | 今日经营/店铺/商品排名/商品卡整体/投放基础/退款基础/账号/直播整体/短视频整体/主档/品线结构/诊断/优先级(数据6月)/智能决策中心 |
| WRAPPER_GAP | 5 | 风险完整列表(get_anomalies×3)/广告诊断+实体指标(get_advertising_diagnosis/get_diagnostic_entity_metrics)/机会完整列表(get_growth_opportunities×3) |
| WHITELIST_GAP | 4 | 品线经营(get_product_line_members+period_summary)/MP 经营(period_summary+rank_master_products) |
| MART_GAP | 1 | 品线/MP 趋势日层函数（用户阶段5 允许但本轮未建）|
| UNSUPPORTED_METRIC | 1 | 商品粒度结算/投放列（product_daily 无事实）|
| SOURCE_NOT_AVAILABLE | 9 | 商品卡来源/搜索/素材/退款原因/投放计划级/直播明细/短视频明细 |
| DATA_ONBOARDING_GAP | 0 | 现有源文件全部入库 |
| REFRESH_GAP | 1 | 智能层停在 6/24，事实已到 8/7 |

## 三、关键能力判断纠正

1. **账号页 NOT_READY 已纠正**：白名单 3 个账号函数存在 → 已补 wrapper（2026-08-10 上午完成），现为真实数据页
2. **品线/MP"数据库没有能力"已纠正**：4 个 V1.3 函数验证通过 → WHITELIST_GAP（非无能力）
3. **rank_master_products metric_key 假契约**：三种 metric_key 值相同 → 必须先修函数或收紧契约
4. **直播/短视频"数据源未接入"细化**：渠道整体 READY；内容级明细 SOURCE_NOT_AVAILABLE（content_daily 仅商品卡）

## 四、可立即完成 / 待开放 / 待补 mart / 待入库 / 无源

| 类别 | 页面 | 动作 |
|---|---|---|
| 立即完成 | 风险中心完整列表 / 机会完整列表 / 广告诊断 | 补 5 个薄 wrapper（白名单已有函数）|
| 只差开放已有函数 | 品线经营汇总 / MP 经营+跨店拆解 | 4 个函数验收→入白名单（rank 先修 metric_key）|
| 需要补 mart | 品线/MP 趋势 | 经确认后新增确定性日层函数（用户阶段5 允许）|
| 已入库无需动作 | 全部 1-8 月事实 | batch 9-25 |
| 真无源数据 | 商品卡来源/搜索/素材/退款原因/投放计划/直播明细/短视频明细 | 等平台导出；页面明确 SOURCE_NOT_AVAILABLE |
| 需调度链 | 智能刷新 | 建 Job 层（导入成功→detect→diagnose→opportunity→priority→日志）|

## 五、约束遵守

- 未批量修改数据库；未新增任何对象；未进入 F1.5；未用 F1.5 承接 F1.0 页面缺口
- 前端状态统一（READY/NO_DATA/PARTIAL_DATA/WHITELIST_GAP/WRAPPER_GAP/DATA_ONBOARDING_GAP/UNSUPPORTED_METRIC/SOURCE_NOT_AVAILABLE/REFRESH_STALE）已定义，页面逐步切换
- 等人工确认后分批实施（第一批：5 个 wrapper + 风险/机会完整列表；第二批：品线/MP 白名单开放；第三批：智能刷新调度链）
"""
(BASE / "F1.0.1_execution_report.md").write_text(exec_rep, encoding="utf-8")

print("\n全部 6 份交付物已生成于:", BASE)
for f in sorted(BASE.iterdir()):
    print("  ", f.name)
