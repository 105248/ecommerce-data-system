# -*- coding: utf-8 -*-
"""F1.0.1-R1 一致性修正：重建 20 列 Capability Matrix + 29 函数分类 + 6 份报告 + 一致性检查。
规则：CSV 固定 20 列；gap_type 按列名读取；统计由 CSV 自动计算；所有状态只在一处定义。
本轮不改数据库、不建表、不进 F1.0.2。"""
import csv
import json
from pathlib import Path
from collections import Counter

BASE = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.1")
COLUMNS = ["page", "capability", "source_file", "source_exists", "source_time_type", "source_grain",
           "core_object", "core_exists", "supported_metrics", "unsupported_metrics", "mart_object",
           "mart_exists", "calculation_ready", "official_whitelist", "backend_endpoint", "frontend_status",
           "capability_status", "gap_type", "gap_reason", "recommended_action"]
assert len(COLUMNS) == 20, "列数必须 20"


def atomic_write(target, content_bytes):
    """写临时文件后 os.replace 原子替换（绕过查看器共享读锁）。"""
    import os
    tmp = target.with_suffix(target.suffix + ".tmp")
    tmp.write_bytes(content_bytes)
    os.replace(tmp, target)

# ============ 1) Capability Matrix（31 行，20 列） ============
# 列顺序见 COLUMNS；gap_reason 中 Source 类统一标注 LOCAL_SOURCE_FILE_NOT_FOUND / NEED_MANUAL_CONFIRMATION
rows = [
    # page, capability, source_file, source_exists, source_time_type, source_grain, core_object, core_exists,
    # supported_metrics, unsupported_metrics, mart_object, mart_exists, calculation_ready, official_whitelist,
    # backend_endpoint, frontend_status, capability_status, gap_type, gap_reason, recommended_action
    ["今日经营", "经营驾驶舱 KPI/趋势/贡献", "成交分析-成交概览/商品构成", "true", "DAILY_FACT", "day×shop×scope",
     "core.douyin_deal_daily", "true", "transaction_amount/user_pay_amount/refund_rate/ad_spend/settlement", "-",
     "get_business_period_summary/get_platform_business_period_summary", "true", "true", "true",
     "/business/summary /business/trend /business/compare /business/shop-contribution", "READY", "READY", "READY", "-", "无需动作"],
    ["店铺经营", "两店对比/贡献/环比", "成交分析-成交概览", "true", "DAILY_FACT", "day×shop",
     "core.douyin_deal_daily", "true", "transaction/user_pay/refund_rate/ad_spend/settlement/contribution", "-",
     "get_business_period_summary×2/get_shop_contribution", "true", "true", "true",
     "/business/summary /business/shop-contribution", "READY", "READY", "READY", "-", "无需动作"],
    ["经营优先级", "风险/机会/Action 优先级", "V1.1 智能层(6月基线)", "true", "PERIOD_SNAPSHOT", "period",
     "mart.daily_action_item", "true", "risk_priority_score/opportunity_priority_score/action", "-",
     "get_daily_risk_priorities/get_daily_opportunity_priorities/get_daily_action_list", "true", "true", "true",
     "/priorities/*", "READY", "STALE", "REFRESH_GAP", "智能结果停在 2026-06-24，事实已到 2026-08-07（REFRESH_GAP）",
     "建立导入后智能刷新调度链(阶段13)"],
    ["品线", "品线结构+成员", "成交分析-商品构成+主数据", "true", "VERSION", "structure",
     "meta.product_line/master_product", "true", "成员/映射数/覆盖店数", "-",
     "meta.product_line(直查)/get_product_line_members", "true", "true", "false",
     "/master-data/product-line-members(meta直查)", "READY", "READY", "READY", "页面走 meta 直查端点已可用；get_product_line_members 函数未入白名单(PUBLIC_CANDIDATE)",
     "函数纳入白名单后切换为正式函数接口"],
    ["品线", "品线经营汇总", "成交分析-商品构成×CONFIRMED映射", "true", "DAILY_FACT", "day×MP",
     "core.douyin_product_daily+映射", "true", "user_pay_amount/refund_amount/refund_rate/mapping_coverage",
     "transaction/settlement/ad_spend(无交叉事实)", "get_product_line_period_summary", "true", "true", "false",
     "无", "PARTIAL", "PARTIAL", "WHITELIST_GAP", "函数存在验证通过(鱼子酱30日881万)但未入白名单",
     "验收后纳入白名单；趋势需日层函数(MART_GAP)"],
    ["品线", "品线趋势", "core.douyin_product_daily(逐日已有)", "true", "DAILY_FACT", "day",
     "core.douyin_product_daily+映射", "true", "user_pay 逐日", "-", "无日层函数(仅区间汇总)", "false", "false", "false",
     "无", "NOT_DEPLOYED", "NOT_DEPLOYED", "MART_GAP", "无确定性日序列函数(避免Backend N次调用)",
     "经确认后在mart新增确定性日层函数(用户阶段5允许)"],
    ["Master Product", "主档列表/映射状态", "主数据", "true", "VERSION", "structure",
     "meta.master_product", "true", "编码/名称/状态", "-", "meta.master_product(直查)", "true", "true", "true",
     "/master-data/products", "READY", "READY", "READY", "-", "无需动作"],
    ["Master Product", "MP 经营汇总/跨店拆解", "成交分析-商品构成×CONFIRMED", "true", "DAILY_FACT", "day×MP×shop",
     "core.douyin_product_daily+映射", "true", "user_pay/refund/refund_rate/mapped_shop_count/店铺拆解",
     "transaction/settlement(无事实)", "get_master_product_period_summary/decompose_master_product_by_shop_product", "true", "true", "false",
     "无", "PARTIAL", "PARTIAL", "WHITELIST_GAP", "两函数验证通过(整体=两店之和)但未入白名单", "验收后纳入白名单"],
    ["Master Product", "MP 经营排名", "成交分析-商品构成×CONFIRMED", "true", "DAILY_FACT", "day×MP",
     "core.douyin_product_daily+映射", "true", "user_pay_amount(唯一真实指标)", "transaction/settlement(声明但未计算)",
     "rank_master_products", "true", "true", "false", "无", "PARTIAL", "PARTIAL", "WHITELIST_GAP",
     "metric_key 假契约(仅算user_pay,三种key值相同)", "先修正函数体(支持真实多指标或收紧契约)再入白名单"],
    ["商品", "商品排名", "成交分析-商品构成", "true", "DAILY_FACT", "day×product×shop",
     "core.douyin_product_daily", "true", "user_pay_amount", "-", "rank_products", "true", "true", "true",
     "/business/products/top", "READY", "READY", "READY", "-", "无需动作"],
    ["商品", "商品退款/结算/投放列", "成交分析-商品构成", "true", "-", "-",
     "core.douyin_product_daily(无这些列)", "true", "-", "settlement/transaction/ad_spend(商品事实无)",
     "-", "false", "false", "false", "无", "NOT_DEPLOYED", "NOT_DEPLOYED", "UNSUPPORTED_METRIC",
     "商品粒度源事实不含结算/投放/成交", "页面只展示用户支付金额(已修正标签)"],
    ["商品卡", "商品卡渠道整体", "成交分析-成交概览(scope=商品卡)", "true", "DAILY_FACT", "day×scope",
     "core.douyin_deal_daily", "true", "transaction/user_pay/refund/settlement/ad_spend", "-",
     "get_business_period_summary(scope=商品卡)", "true", "true", "true",
     "/business/summary?scope=商品卡", "READY", "READY", "READY", "-", "无需动作"],
    ["商品卡", "商品卡来源构成(曝光/点击/来源分解)", "无独立源文件", "false", "-", "-",
     "无对应表", "false", "-", "-", "-", "false", "false", "false", "无", "NOT_DEPLOYED", "NOT_DEPLOYED",
     "SOURCE_NOT_AVAILABLE",
     "LOCAL_SOURCE_FILE_NOT_FOUND：本机扫描范围未发现商品卡来源构成/流量来源文件；平台能否导出待人工确认(NEED_MANUAL_CONFIRMATION)",
     "人工确认平台导出能力后走标准接入流程；不造数据"],
    ["投放", "基础投放经营", "成交分析-成交概览(投放列)", "true", "DAILY_FACT", "day×shop",
     "core.douyin_deal_daily", "true", "ad_spend(被投/绑定)/归因成交/占比/费比/综合费比/效率", "-",
     "get_advertising_period_summary", "true", "true", "true", "/advertising/summary", "READY", "READY", "READY", "-", "无需动作"],
    ["投放", "计划/账户/单元/预算/状态", "无独立源文件", "false", "-", "-",
     "无对应表", "false", "-", "-", "-", "false", "false", "false", "无", "NOT_DEPLOYED", "NOT_DEPLOYED",
     "SOURCE_NOT_AVAILABLE",
     "LOCAL_SOURCE_FILE_NOT_FOUND：本机无计划级源文件；平台计划级导出能力待人工确认(NEED_MANUAL_CONFIRMATION)",
     "保持 KNOWN LIMITATION；不从店铺总投放推算计划级"],
    ["退款", "退款金额/率/订单/店铺退款", "成交分析-成交概览(退款列)", "true", "DAILY_FACT", "day×shop×scope",
     "core.douyin_deal_daily", "true", "refund_amount_pay_time/refund_rate/refund_order", "-",
     "get_business_period_summary", "true", "true", "true", "/business/summary /business/trend(refund_rate)",
     "READY", "READY", "READY", "-", "无需动作"],
    ["退款", "退款原因/售后原因", "无独立源文件", "false", "-", "-",
     "无对应表", "false", "-", "-", "-", "false", "false", "false", "无", "NOT_DEPLOYED", "NOT_DEPLOYED",
     "SOURCE_NOT_AVAILABLE",
     "LOCAL_SOURCE_FILE_NOT_FOUND：成交分析无退款原因列；平台退款原因明细导出能力待人工确认(NEED_MANUAL_CONFIRMATION)",
     "页面明确'当前数据源不支持退款原因分析'；AI不得猜原因"],
    ["达人/账号", "账号汇总/排名/贡献", "成交分析-账号构成", "true", "DAILY_FACT", "day×account×shop",
     "core.douyin_account_daily", "true", "transaction/user_pay/refund_rate/settlement/ad_spend/rank/contribution", "-",
     "get_account_period_summary/rank_accounts/get_account_contribution", "true", "true", "true",
     "/accounts/summary /accounts/top /accounts/contribution", "READY", "READY", "READY", "-", "已补齐(2026-08-10)"],
    ["直播", "直播渠道整体", "成交分析-成交概览(scope=直播)", "true", "DAILY_FACT", "day×scope",
     "core.douyin_deal_daily", "true", "transaction/user_pay/refund_rate/ad_spend", "-",
     "get_business_period_summary(scope=直播)", "true", "true", "true", "/business/summary?scope=直播",
     "READY", "READY", "READY", "-", "无需动作"],
    ["直播", "直播场次/直播商品/时段明细", "单载体构成sheet(仅商品卡内容)", "true", "DAILY_FACT", "content(商品卡)",
     "core.douyin_content_daily(仅carrier=商品卡)", "true", "-", "直播场次/商品/时段(无事实)", "-", "false", "false", "false",
     "无", "NOT_DEPLOYED", "NOT_DEPLOYED", "SOURCE_NOT_AVAILABLE",
     "LOCAL_SOURCE_FILE_NOT_FOUND：单载体构成sheet仅含商品卡内容(53024行/599内容)；平台直播明细导出能力待人工确认(NEED_MANUAL_CONFIRMATION)",
     "禁止用频道汇总冒充明细"],
    ["短视频", "短视频渠道整体", "成交分析-成交概览(scope=短视频)", "true", "DAILY_FACT", "day×scope",
     "core.douyin_deal_daily", "true", "transaction/user_pay/refund_rate/ad_spend", "-",
     "get_business_period_summary(scope=短视频)", "true", "true", "true", "/business/summary?scope=短视频",
     "READY", "READY", "READY", "-", "无需动作"],
    ["短视频", "单视频/视频素材级", "单载体构成sheet(仅商品卡内容)", "true", "DAILY_FACT", "content(商品卡)",
     "core.douyin_content_daily(仅carrier=商品卡)", "true", "-", "单视频/素材级(无事实)", "-", "false", "false", "false",
     "无", "NOT_DEPLOYED", "NOT_DEPLOYED", "SOURCE_NOT_AVAILABLE",
     "LOCAL_SOURCE_FILE_NOT_FOUND：单载体构成sheet无短视频内容；平台单视频/素材导出能力待人工确认(NEED_MANUAL_CONFIRMATION)",
     "禁止用频道汇总冒充明细"],
    ["搜索", "搜索成交/关键词", "无独立源文件", "false", "-", "-",
     "无对应表", "false", "-", "-", "-", "false", "false", "false", "无", "NOT_DEPLOYED", "NOT_DEPLOYED",
     "SOURCE_NOT_AVAILABLE",
     "LOCAL_SOURCE_FILE_NOT_FOUND：本机扫描范围未发现搜索核心数据文件；平台'本店搜索核心数据'导出能力待人工确认(NEED_MANUAL_CONFIRMATION)",
     "人工确认平台导出能力后走标准接入流程"],
    ["素材", "素材列表/表现", "无独立源文件", "false", "-", "-",
     "无对应表", "false", "-", "-", "-", "false", "false", "false", "无", "NOT_DEPLOYED", "NOT_DEPLOYED",
     "SOURCE_NOT_AVAILABLE",
     "LOCAL_SOURCE_FILE_NOT_FOUND：本机扫描范围未发现素材分析文件；平台素材分析导出能力待人工确认(NEED_MANUAL_CONFIRMATION)",
     "人工确认平台导出能力后走标准接入流程"],
    ["智能经营", "决策中心(风险/机会/Action摘要)", "V1.1 智能层", "true", "PERIOD_SNAPSHOT", "period",
     "mart.*_event/daily_action_item", "true", "risk/opportunity/action 摘要", "-",
     "get_daily_*_priorities/get_daily_action_list", "true", "true", "true", "/priorities/*", "READY", "STALE",
     "REFRESH_GAP", "智能结果停在6/24(REFRESH_GAP)", "同经营优先级"],
    ["风险中心", "风险完整列表(Anomaly)", "V1.1 anomaly_event", "true", "EVENT", "event",
     "mart.anomaly_event", "true", "anomaly_code/level/entity/evidence", "-",
     "get_anomalies/get_anomaly_summary/get_entity_anomalies", "true", "true", "true", "无(仅priority包装)",
     "PARTIAL", "PARTIAL", "WRAPPER_GAP", "3个白名单函数存在但Backend未包装", "补薄wrapper(参数/分页/JSON)，风险中心用完整Anomaly"],
    ["问题诊断", "诊断结果/拆解", "V1.1 diagnostic_result", "true", "EVENT", "event",
     "mart.diagnostic_result", "true", "diagnostic_code/stage/confidence/证据", "-",
     "get_diagnostic_result/decompose_platform_change_by_shop", "true", "true", "true",
     "/diagnostics/results /diagnostics/decomposition", "READY", "READY", "READY", "-", "无需动作"],
    ["问题诊断", "漏斗/广告诊断", "V1.1 诊断链", "true", "EVENT", "event",
     "mart.diagnostic_result", "true", "funnel/advertising", "-",
     "get_funnel_diagnosis/get_advertising_diagnosis", "true", "true", "true", "funnel已包装;advertising未包装",
     "PARTIAL", "PARTIAL", "WRAPPER_GAP", "get_funnel_diagnosis/get_advertising_diagnosis 已在白名单但 Backend 未包装",
     "补薄wrapper"],
    ["问题诊断", "实体指标(诊断支持指标清单)", "diagnostic_metric_rule(元数据)", "true", "VERSION", "structure",
     "mart.diagnostic_metric_rule", "true", "各域支持诊断的指标清单", "-",
     "get_diagnostic_entity_metrics", "true", "true", "false", "无", "NOT_DEPLOYED", "PARTIAL", "WHITELIST_GAP",
     "get_diagnostic_entity_metrics 当前不在正式白名单(被 detect_anomalies 内部引用，本身只读元数据查询)",
     "评估是否纳入 F1.0 正式公共接口(诊断页指标清单场景)；纳入前不入白名单"],
    ["增长机会", "机会完整列表", "V1.1 opportunity_event", "true", "EVENT", "event",
     "mart.opportunity_event", "true", "opportunity_code/score/evidence/peer", "-",
     "get_growth_opportunities/get_opportunity_summary/get_entity_opportunity", "true", "true", "true",
     "无(仅priority包装)", "PARTIAL", "PARTIAL", "WRAPPER_GAP", "3个白名单函数存在但Backend未包装",
     "补薄wrapper，机会中心用完整Opportunity"],
    ["智能刷新", "导入→异常→诊断→机会→优先级自动链", "V1.1 写库函数", "true", "PERIOD_SNAPSHOT", "period",
     "mart.*_event", "true", "-", "-",
     "detect_anomalies/diagnose_*/detect_growth_opportunities/generate_daily_action_items", "true", "false", "false",
     "无(人工触发)", "STALE", "STALE", "REFRESH_GAP", "5个写库函数存在但无调度；智能结果停在6/24(REFRESH_GAP)",
     "建立独立调度/Job层(导入成功后自动跑)，Web只读结果；运行日志进 audit.intelligence_run_log(新建)"],
]

# ---- 程序化验证：20 列 ----
bad = [i for i, r in enumerate(rows) if len(r) != 20]
assert not bad, "存在非 20 列行: %s" % bad

matrix_p = BASE / "F1.0.1_business_capability_matrix.csv"
import io as _io
buf = _io.StringIO()
w = csv.writer(buf)
w.writerow(COLUMNS)
w.writerows(rows)
atomic_write(matrix_p, buf.getvalue().encode("utf-8-sig"))

# 统计：按列名读取 gap_type（capability_status 不参与 gap 统计）
stats = Counter(r[COLUMNS.index("gap_type")] for r in rows)
GAP_ORDER = ["READY", "WRAPPER_GAP", "WHITELIST_GAP", "MART_GAP", "DATA_ONBOARDING_GAP",
             "UNSUPPORTED_METRIC", "SOURCE_NOT_AVAILABLE", "REFRESH_GAP"]
print("== Capability Matrix ==")
print("总行数:", len(rows), "| 列数:", len(COLUMNS), "| 20列校验 PASS")
for g in GAP_ORDER:
    print("  %s = %d" % (g, stats.get(g, 0)))
unknown = set(stats) - set(GAP_ORDER)
assert not unknown, "非法 gap_type: %s" % unknown

# ============ 2) 29 个未入白名单函数分类 ============
scan = json.load(open(BASE / "scan_objects.json", encoding="utf-8"))
non_wl = scan["mart_not_in_whitelist"]
assert len(non_wl) == 29, "mart_not_in_whitelist 必须=29，实际 %d" % len(non_wl)
fn_args = {f["fn"]: f["args"] for f in scan["mart_functions"]}

# 分类依据（基于函数体/引用关系/白名单扫描结论）
CLASS = {
    # PUBLIC_CANDIDATE：只读查询，业务页面可用，验收后入白名单
    "get_product_line_members": ("PUBLIC_CANDIDATE", "品线结构成员查询；验证通过", "验收后纳入正式接口治理"),
    "get_product_line_period_summary": ("PUBLIC_CANDIDATE", "品线经营汇总；鱼子酱30日881万验证通过", "验收后纳入白名单"),
    "get_master_product_period_summary": ("PUBLIC_CANDIDATE", "MP 经营汇总；整体=两店之和验证通过", "验收后纳入白名单"),
    "rank_master_products": ("PUBLIC_CANDIDATE", "MP 排名；**metric_key 假契约**（仅算 user_pay）", "先修契约（支持真实多指标或收紧声明）再入白名单"),
    "get_diagnostic_entity_metrics": ("PUBLIC_CANDIDATE", "诊断域支持指标清单（只读元数据）；被 detect_anomalies 内部引用", "评估纳入 F1.0 公共接口（诊断页指标清单）；暂不入白名单"),
    "get_masterdata_quality": ("PUBLIC_CANDIDATE", "主数据质量（销售×映射覆盖率）只读查询；无内部调用者", "主数据质量页可选用；暂不入白名单"),
    # WRITE_JOB_FUNCTION：写库批处理，只读角色不得执行
    "detect_anomalies": ("WRITE_JOB_FUNCTION", "异常检测写库", "保留仅 postgres；调度链 Job 触发"),
    "detect_growth_opportunities": ("WRITE_JOB_FUNCTION", "机会检测写库", "保留仅 postgres；调度链 Job 触发"),
    "diagnose_anomaly": ("WRITE_JOB_FUNCTION", "异常诊断写库", "保留仅 postgres；调度链 Job 触发"),
    "diagnose_entity": ("WRITE_JOB_FUNCTION", "实体诊断写库", "保留仅 postgres；调度链 Job 触发"),
    "generate_daily_action_items": ("WRITE_JOB_FUNCTION", "优先级/Action 写库", "保留仅 postgres；调度链 Job 触发"),
    # INTERNAL_HELPER：内部辅助/校验/解析，无独立业务查询价值
    "_diag_account": ("INTERNAL_HELPER", "诊断内部辅助(账号域)", "不对外"),
    "_diag_carrier": ("INTERNAL_HELPER", "诊断内部辅助(载体域)", "不对外"),
    "_diag_category": ("INTERNAL_HELPER", "诊断内部辅助(品类域)", "不对外"),
    "_diag_master_product": ("INTERNAL_HELPER", "诊断内部辅助(MP域)", "不对外"),
    "_diag_product": ("INTERNAL_HELPER", "诊断内部辅助(商品域)", "不对外"),
    "_diag_product_line": ("INTERNAL_HELPER", "诊断内部辅助(品线域)", "不对外"),
    "_diag_scope": ("INTERNAL_HELPER", "诊断内部辅助(Scope域)", "不对外"),
    "_diag_shop": ("INTERNAL_HELPER", "诊断内部辅助(店铺域)", "不对外"),
    "assert_period": ("INTERNAL_HELPER", "周期参数校验", "不对外"),
    "assert_rank_args": ("INTERNAL_HELPER", "排名参数校验", "不对外"),
    "period_scope_rule": ("INTERNAL_HELPER", "Scope 周期规则解析", "不对外"),
    "previous_period": ("INTERNAL_HELPER", "上期计算辅助", "不对外"),
    "resolve_scope": ("INTERNAL_HELPER", "Scope 归并解析", "不对外"),
    "scope_daily": ("INTERNAL_HELPER", "Scope 日层过滤辅助", "不对外"),
    "check_mapping_period_conflict": ("INTERNAL_HELPER", "主数据映射期间冲突校验（写流程辅助，secdef=false）", "不对外；主数据维护内部使用"),
    "resolve_diagnostic_period": ("INTERNAL_HELPER", "诊断周期解析（period_key→天数，secdef=false）", "不对外"),
    # LEGACY_REVIEW：历史遗留/弱依赖，评估后清理或保留
    "format_percent_2": ("LEGACY_REVIEW", "百分比格式化；历史脚本弱依赖", "评估脚本依赖后清理或保留"),
    # NOT_REQUIRED_F1：V1.0 Stage3 正式验收的"经营范围贡献度"函数（分子=指定Scope汇总/分母=该店全店TOTAL），
    # 功能正确且 ACL 已授权（agent_readonly），但 F1.0 页面无消费点（Backend 无 scope-contribution 端点，
    # 现有 /business/shop-contribution 消费的是 get_shop_contribution 平台店铺贡献）→ 保留待 F1.5
    "get_business_contribution": ("NOT_REQUIRED_F1", "经营范围贡献度（单店内 Scope 占全店比例）；V1.0 Stage3 正式验收、ACL 已授权；F1.0 无页面消费", "保留；F1.5 若做 Scope 贡献分析页再开放"),
}
assert set(CLASS) == set(non_wl), "分类集合必须等于 29 个未入白名单函数"

cls_csv = BASE / "F1.0.1_all_non_whitelist_function_classification.csv"
buf = _io.StringIO()
w = csv.writer(buf)
w.writerow(["function", "signature", "classification", "f1_relevance", "public_candidate", "reason", "next_action"])
for fn in non_wl:
    cls, relevance, action = CLASS[fn]
    w.writerow([fn, fn_args.get(fn, ""), cls, relevance, "是" if cls == "PUBLIC_CANDIDATE" else "否",
                relevance, action])
atomic_write(cls_csv, buf.getvalue().encode("utf-8-sig")) if False else None
# 容错：classification CSV 可能被外部查看器独占锁定 → 写 .tmp 保留新内容，最终由 r1_check 提示替换
try:
    atomic_write(cls_csv, buf.getvalue().encode("utf-8-sig"))
except PermissionError:
    (BASE / "F1.0.1_all_non_whitelist_function_classification.csv.new").write_bytes(
        buf.getvalue().encode("utf-8-sig"))
    print("WARN: classification CSV 被外部进程锁定，新内容已写入 .csv.new，待替换")
cls_cnt = Counter(v[0] for v in CLASS.values())
print("\n== 29 函数分类 ==")
print("总数:", len(non_wl), "| 已分类:", len(CLASS), "| 未分类:", len(non_wl) - len(CLASS))
for c, n in sorted(cls_cnt.items()):
    print("  %s = %d" % (c, n))

# ============ 3) promotion list（= PUBLIC_CANDIDATE） ============
publics = [fn for fn in non_wl if CLASS[fn][0] == "PUBLIC_CANDIDATE"]
promo = """# F1.0.1 已有 Function 白名单升级候选清单（R1 一致性版）

> 依据：2026-08-10 真实数值验证 + 29 函数全量分类（见 F1.0.1_all_non_whitelist_function_classification.csv）
> 本清单 = 分类结果中所有 PUBLIC_CANDIDATE（6 个）
> 原则：验收通过后才纳入正式接口治理；不批量加白名单；禁止 Contract 与实现不一致

## 一、PUBLIC_CANDIDATE（6 个）

| 函数 | 验证结论 | 纳入白名单前置条件 |
|---|---|---|
| `get_product_line_members` | 返回品线成员/映射数/覆盖店数，数值正确 | 无 |
| `get_product_line_period_summary` | 鱼子酱品线 30 日 user_pay=8,813,486.86、refund=1,567,613.44、18/18 映射、2 店覆盖 | 无 |
| `get_master_product_period_summary` | MP000002 整体=官方 5,653,849.01（护理 0 映射→空），整体语义=映射店之和 | 无 |
| `rank_master_products` | **metric_key 假契约确认**：三种 metric_key 返回完全相同 current_value（函数体无 transaction_amount） | **必须先修正**（真实支持多指标 或 收紧契约只声明 user_pay_amount） |
| `get_diagnostic_entity_metrics` | 诊断域支持指标清单（只读元数据）；被 detect_anomalies 内部引用 | 评估诊断页指标清单场景后决定是否纳入（暂不入） |
| `get_masterdata_quality` | 主数据质量（销售×映射覆盖率）只读查询；无内部调用者 | 主数据质量页需要时再纳入（暂不入） |

## 二、纳入白名单需同步的治理动作

1. Backend 补薄 wrapper（仅参数校验/分页/JSON/日志；禁计算）
2. 更新 03_official_database_interface_catalog.md + 04_database_public_interface_whitelist.json
3. 更新 Backend capability matrix
4. MCP 只读 / Backend 只读 / core 禁止直读（保持）

## 三、不纳入的内部函数（明确排除）

- `_diag_*`（8 个）：诊断内部辅助，不对外
- `assert_period/assert_rank_args/period_scope_rule/previous_period/resolve_scope/scope_daily/check_mapping_period_conflict/resolve_diagnostic_period`（8 个）：内部解析/校验/写流程辅助
- `detect_*/diagnose_*/generate_daily_action_items`（5 个写库函数）：只读角色不应执行（写型隔离，保持仅 postgres）
- `get_business_contribution`（1 个）：**NOT_REQUIRED_F1**——V1.0 Stage3 正式验收的"经营范围贡献度"函数（分子=指定Scope汇总/分母=该店全店TOTAL），ACL 已授权但 F1.0 无页面消费（Backend 无 scope-contribution 端点），保留待 F1.5
- `format_percent_2`（1 个）：LEGACY_REVIEW（历史弱依赖，待评估）

> ⚠️ 本轮未批量加入白名单，等待人工确认。
"""
(BASE / "F1.0.1_existing_function_whitelist_promotion_list.md").write_text(promo, encoding="utf-8")

# ============ 4) source_onboarding_gap_list.md（DATA_ONBOARDING_GAP=0） ============
onboard = """# F1.0.1 已有源数据待入库清单（DATA_ONBOARDING_GAP）

> 扫描结论：桌面「数据库/基础数据」两店各 8 个月「抖音电商罗盘-成交分析」文件（单一报表类型，11 sheet）
> **未发现"有源文件但未入库"的场景** —— 现有源文件已全部导入 core（9 表，2026-01~08 全量）。

| 源文件 | 状态 | 已入库 | 说明 |
|---|---|---|---|
| 成交分析 2026-01~08（两店）| 已导入 | core.douyin_*_daily 9 表 | batch 9-25，257,775 行 |
| 单载体构成 sheet（4月+）| 已导入 | core.douyin_content_daily | 但内容仅 carrier=商品卡（53024 行/599 内容）|

## 结论

DATA_ONBOARDING_GAP = **0**。
所有已获取的源数据均已完成 Source→mapping→core 接入；下一步缺口集中在"本机未发现源文件、需人工确认平台导出能力"的项（见 true_source_gap_list，reason 标注 LOCAL_SOURCE_FILE_NOT_FOUND / NEED_MANUAL_CONFIRMATION）。
"""
(BASE / "F1.0.1_source_onboarding_gap_list.md").write_text(onboard, encoding="utf-8")

# ============ 5) true_source_gap_list.md（= 矩阵 SOURCE_NOT_AVAILABLE 行） ============
src_rows = [r for r in rows if r[COLUMNS.index("gap_type")] == "SOURCE_NOT_AVAILABLE"]
lines = ["# F1.0.1 真实源数据缺口清单（SOURCE_NOT_AVAILABLE，R1 一致性版）", "",
         "> 判定标准：gap_type=SOURCE_NOT_AVAILABLE，reason 区分 LOCAL_SOURCE_FILE_NOT_FOUND（本机扫描未发现）与 NEED_MANUAL_CONFIRMATION（平台能否导出待人工确认）", ""]
lines.append("| 页面 | 能力 | reason | 处置 |")
lines.append("|---|---|---|---|")
for r in src_rows:
    idx = {c: i for i, c in enumerate(COLUMNS)}
    lines.append("| %s | %s | %s | %s |" % (r[idx["page"]], r[idx["capability"]], r[idx["gap_reason"]], r[idx["recommended_action"]]))
lines += ["", "## 处置", "", "- 直播/短视频：渠道整体（scope=直播/短视频）READY；明细禁止用频道汇总冒充明细（页面已标注）",
          "- 其余：页面明确'当前数据源不支持XX分析'；AI 不得猜测", "- 全部等待人工确认平台导出能力后走标准接入流程（Source→mapping→core→mart→whitelist→API→Web）"]
(BASE / "F1.0.1_true_source_gap_list.md").write_text("\n".join(lines), encoding="utf-8")

# ============ 6) intelligence_refresh_report.md（5 日期 + audit 复用结论） ============
refresh = """# F1.0.1 智能刷新链检查报告（REFRESH_GAP，R1 一致性版）

## 一、现状（2026-08-10 现场查询）

| 状态项 | 值 |
|---|---|
| latest_fact_date（core.douyin_deal_daily max biz_date）| **2026-08-07** |
| latest_anomaly_date（mart.anomaly_event max current_start_date）| **2026-06-24** |
| latest_diagnosis_date（mart.diagnostic_result max current_start_date）| **2026-06-24** |
| latest_opportunity_date（mart.opportunity_event max current_start_date）| **2026-06-24** |
| latest_action_date（mart.daily_action_item max current_start_date）| **2026-06-24** |
| latest_priority_date | 无独立表：风险优先级源自 anomaly_event、机会优先级源自 opportunity_event（=06-24）|
| 事件量级 | anomaly 104 / diagnosis 5 / opportunity 264 / action 368 |
| 导入批次 | batch 9-25（2026-08-10 完成 1-8 月全量导入）|

## 二、结论

**REFRESH_GAP 确认**：V1.1 智能层（异常/诊断/机会/优先级/Action）基于 2026-06 数据生成，1-8 月新导入事实**未触发智能重算**。当前风险/机会/诊断/优先级页面展示 6 月结果，8 月区间显示"无风险/无机会"是**智能未刷新**而非真实无风险。

## 三、写库函数（已存在，可复用）

```
detect_anomalies
diagnose_anomaly / diagnose_entity
detect_growth_opportunities
generate_daily_action_items
```

## 四、运行日志归属（R1 修正）

- 现有 `audit.ai_diagnosis_run` 为 **AI 问答运行日志**（run_id/occurred_at/intent/question_hash/tools_called/result_id/duration_ms/error_type），**不等价**于智能批处理运行日志。
- 方案：**新建 `audit.intelligence_run_log`**（批次/触发原因/各阶段结果行数/耗时/错误），不进入 mart 命名空间。
- 本轮仅更新方案，**不建表**。

## 五、方案（待人工确认后实施）

```
Import batch validated（成功）
  → 调度层触发 V1.1 批处理（detect → diagnose → opportunity → priority/action）
  → 记录运行日志（audit.intelligence_run_log）
  → Web 只读结果
```

- 建立独立调度/Job 层（不在 Web 查询时实时计算）
- 页面增加状态字段：latest_fact_date / latest_anomaly_generated_date / latest_diagnosis_generated_date / latest_opportunity_generated_date / latest_priority_generated_date / intelligence_status = FRESH | STALE
- 最新事实日期晚于智能结果日期时，页面显示 **"智能分析尚未刷新"**（不得显示"当前无风险"）

## 六、本轮动作

仅记录状态与方案；未创建调度 Job、未建表（等待人工确认）。
"""
(BASE / "F1.0.1_intelligence_refresh_report.md").write_text(refresh, encoding="utf-8")

# ============ 7) execution_report.md（统计由 CSV 自动计算） ============
def stat_line(g):
    return stats.get(g, 0)

exec_rep = """# F1.0.1 经营中心数据能力收口执行报告（R1 一致性版）

> 执行时间：2026-08-10 ｜ 模式：**数据库只读盘点 + 数值验证 + 应用层少量已存在整改同步；数据库 0 变更**
> 变更统计：**DB changes = 0 ｜ Backend changes = 账号 3 端点(api_f1.py) + 契约修复(api.py/api_f1.py/services.py) ｜ Frontend changes = StateNotice 9 态 + 搜索/素材文案**

## 一、真实扫描结论

- mart 75 函数 / 白名单 46 函数 → **29 个未入白名单**（分类见 F1.0.1_all_non_whitelist_function_classification.csv）
- core 9 表（douyin_*_daily）/ meta+audit 16 表；Backend 29 端点；前端 22 路由
- 源文件：两店各 8 个月「成交分析」（单一报表 11 sheet），**全部已入库**（DATA_ONBOARDING_GAP=0）
- content_daily 全局仅"商品卡"内容 → 直播/短视频内容级明细无事实

## 二、Capability Matrix 统计（由 CSV 自动计算）

| gap_type | 数量 | 明细 |
|---|---|---|
| READY | %d | 今日经营/店铺/商品排名/商品卡整体/投放基础/退款基础/账号/直播整体/短视频整体/主档/品线结构(meta直查)/诊断结果 |
| WRAPPER_GAP | %d | 风险完整列表(get_anomalies×3)/漏斗+广告诊断(get_funnel_diagnosis/get_advertising_diagnosis)/机会完整列表(get_growth_opportunities×3) |
| WHITELIST_GAP | %d | 品线经营汇总/MP 经营+跨店拆解/MP 排名(先修 metric_key)/诊断实体指标(get_diagnostic_entity_metrics) |
| MART_GAP | %d | 品线/MP 趋势日层函数（用户阶段5 允许但本轮未建）|
| UNSUPPORTED_METRIC | %d | 商品粒度结算/投放列（product_daily 无事实）|
| SOURCE_NOT_AVAILABLE | %d | 商品卡来源/搜索/素材/退款原因/投放计划级/直播明细/短视频明细（reason 标注 LOCAL_SOURCE_FILE_NOT_FOUND / NEED_MANUAL_CONFIRMATION）|
| DATA_ONBOARDING_GAP | %d | 现有源文件全部入库 |
| REFRESH_GAP | %d | 经营优先级/智能经营(数据停在6/24) + 智能刷新链 |

## 三、关键能力判断纠正

1. **账号页 NOT_READY 已纠正**：白名单 3 个账号函数存在 → 已补 wrapper（2026-08-10 上午完成），现为真实数据页
2. **品线/MP"数据库没有能力"已纠正**：4 个 V1.3 函数验证通过 → WHITELIST_GAP（非无能力）
3. **rank_master_products metric_key 假契约**：三种 metric_key 值相同 → 必须先修函数或收紧契约
4. **get_diagnostic_entity_metrics 状态纠正（R1）**：不在白名单 → WHITELIST_GAP（非 WRAPPER_GAP），评估后决定是否纳入 F1.0
5. **直播/短视频"数据源未接入"细化**：渠道整体 READY；内容级明细 SOURCE_NOT_AVAILABLE（reason=LOCAL_SOURCE_FILE_NOT_FOUND / NEED_MANUAL_CONFIRMATION）

## 四、可立即完成 / 待开放 / 待补 mart / 待入库 / 无源

| 类别 | 页面 | 动作 |
|---|---|---|
| 立即完成 | 风险中心完整列表 / 机会完整列表 / 漏斗+广告诊断 | 补薄 wrapper（白名单已有函数）|
| 只差开放已有函数 | 品线经营汇总 / MP 经营+跨店拆解 / MP 排名 | 6 个 PUBLIC_CANDIDATE 验收→入白名单（rank 先修 metric_key）|
| 需要补 mart | 品线/MP 趋势 | 经确认后新增确定性日层函数（用户阶段5 允许）|
| 已入库无需动作 | 全部 1-8 月事实 | batch 9-25 |
| 真无源/待确认 | 商品卡来源/搜索/素材/退款原因/投放计划/直播明细/短视频明细 | reason=LOCAL_SOURCE_FILE_NOT_FOUND / NEED_MANUAL_CONFIRMATION；人工确认平台导出能力 |
| 需调度链 | 智能刷新 | 建 Job 层（导入成功→detect→diagnose→opportunity→priority→日志 audit.intelligence_run_log）|

## 五、约束遵守

- 未批量修改数据库；未新增任何对象；未进入 F1.5；未用 F1.5 承接 F1.0 页面缺口
- 前端状态统一（READY/NO_DATA/PARTIAL_DATA/WHITELIST_GAP/WRAPPER_GAP/DATA_ONBOARDING_GAP/UNSUPPORTED_METRIC/SOURCE_NOT_AVAILABLE/REFRESH_STALE）已定义，页面逐步切换
- 等人工确认后分批实施
""" % (stat_line("READY"), stat_line("WRAPPER_GAP"), stat_line("WHITELIST_GAP"), stat_line("MART_GAP"),
      stat_line("UNSUPPORTED_METRIC"), stat_line("SOURCE_NOT_AVAILABLE"), stat_line("DATA_ONBOARDING_GAP"),
      stat_line("REFRESH_GAP"))
(BASE / "F1.0.1_execution_report.md").write_text(exec_rep, encoding="utf-8")

print("\n全部交付物已生成:", BASE)
