# -*- coding: utf-8 -*-
"""F0.5-A：基于 04 白名单 54 接口生成能力矩阵/契约/DataGrain/缺口清单"""
import json
from pathlib import Path
from datetime import datetime

WHITELIST = Path(r"D:/ecommerce-data-system/convergence_final/04_database_public_interface_whitelist.json")
OUT = Path(r"D:/ecommerce-data-system/workspace/docs/f0.5_a")
OUT.mkdir(parents=True, exist_ok=True)
now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

ifs = json.loads(WHITELIST.read_text(encoding="utf-8"))["interfaces"]
by_code = {i["interface_code"]: i for i in ifs}

# ===== 24 能力 → 白名单接口映射 =====
CAPS = [
    ("01", "system_status", "系统状态", ["(backend) health/ready"], "READY", "backend", "BACKEND", "分钟", "无", False, False),
    ("02", "data_coverage", "数据覆盖", ["mart.get_data_coverage"], "READY", "catalog", "DAILY_FACT", "天", "是", False, False),
    ("03", "shops", "店铺", ["meta.shop"], "READY", "masterdata", "VERSION", "即时", "是", False, False),
    ("04", "platform_overview", "抖音整体", ["mart.get_platform_business_period_summary", "mart.compare_platform_business", "mart.decompose_platform_change_by_shop", "mart.get_platform_diagnostic_snapshot"], "READY", "platform", "DAILY_FACT", "天", "是", True, False),
    ("05", "business_summary", "经营摘要", ["mart.get_business_period_summary", "mart.get_business_report", "mart.analysis_metric_whitelist"], "READY", "business", "DAILY_FACT", "天", "是", False, False),
    ("06", "period_compare", "周期比较", ["mart.compare_business_period", "mart.compare_platform_business", "mart.compare_advertising_period"], "READY", "business", "DAILY_FACT", "天", "是", False, False),
    ("07", "ranking", "排名", ["mart.rank_products", "mart.rank_accounts", "mart.rank_categories", "mart.rank_carriers", "mart.rank_price_bands", "mart.rank_audiences"], "READY", "business", "DAILY_FACT", "天", "是", False, False),
    ("08", "contribution", "贡献", ["mart.get_product_contribution", "mart.get_account_contribution", "mart.get_category_contribution", "mart.get_shop_contribution"], "READY", "business", "DAILY_FACT", "天", "是", False, False),
    ("09", "product_lines", "品线", ["meta.product_line", "mart.get_master_product_members"], "PARTIAL", "masterdata", "VERSION", "即时", "是", False, False),
    ("10", "master_products", "Master Product", ["meta.master_product", "meta.platform_product_mapping", "mart.get_master_product_members", "mart.resolve_master_product", "mart.decompose_master_product_by_shop_product"], "READY", "masterdata", "VERSION", "即时", "是", True, False),
    ("11", "shop_products", "店铺商品", ["mart.get_product_period_summary", "mart.rank_products", "mart.unmapped_products", "mart.product_mapping_conflicts"], "READY", "product", "DAILY_FACT", "天", "是", True, False),
    ("12", "product_card", "商品卡", ["mart.get_business_period_summary(scope=商品卡)"], "PARTIAL", "business", "DAILY_FACT", "天", "是", False, False),
    ("13", "search", "搜索", [], "NOT_REQUIRED_IN_F0_5", "-", "-", "-", "-", False, False),
    ("14", "video", "视频", ["mart.get_content_period_summary"], "PARTIAL", "content", "DAILY_FACT", "天", "是", False, False),
    ("15", "live", "直播", ["mart.get_carrier_period_summary", "mart.get_content_period_summary"], "PARTIAL", "carrier", "DAILY_FACT", "天", "是", False, False),
    ("16", "accounts", "达人/账号", ["mart.get_account_period_summary", "mart.rank_accounts", "mart.get_account_contribution"], "READY", "account", "DAILY_FACT", "天", "是", False, False),
    ("17", "material", "素材", [], "NOT_REQUIRED_IN_F0_5", "-", "-", "-", "-", False, False),
    ("18", "advertising", "基础投放", ["mart.get_advertising_period_summary", "mart.compare_advertising_period"], "READY", "advertising", "DAILY_FACT", "天", "是", False, False),
    ("19", "diag_snapshot", "Diagnostic Snapshot", ["mart.get_diagnostic_snapshot", "mart.get_platform_diagnostic_snapshot", "mart.get_diagnostic_supported_metrics"], "READY", "diagnostic", "DAILY_FACT", "天", "是", True, False),
    ("20", "anomaly", "Anomaly", ["mart.get_anomalies", "mart.get_anomaly_summary", "mart.get_entity_anomalies"], "READY", "anomaly", "EVENT", "天", "是", True, False),
    ("21", "diagnosis", "Diagnosis", ["mart.get_diagnostic_result", "mart.get_funnel_diagnosis", "mart.get_advertising_diagnosis", "mart.get_platform_diagnostic_snapshot"], "READY", "diagnostic", "EVENT", "天", "是", True, False),
    ("22", "opportunity", "Opportunity", ["mart.get_growth_opportunities", "mart.get_opportunity_summary", "mart.get_entity_opportunity"], "READY", "opportunity", "EVENT", "天", "是", True, False),
    ("23", "priority", "Priority", ["mart.get_daily_risk_priorities", "mart.get_daily_opportunity_priorities", "mart.get_daily_action_list"], "READY", "priority", "EVENT", "天", "是", True, False),
    ("24", "daily_brief", "Daily Brief", ["mart.get_daily_business_brief"], "READY", "priority", "EVENT", "天", "是", True, False),
]

# ===== 生成能力矩阵 md =====
L = []
L.append("# F0.5-A｜工作台 API 能力映射矩阵")
L.append("")
L.append("> 生成：{} ｜ 数据库基线：最终架构收口（04 白名单 54 接口，冻结）".format(now))
L.append("> 状态说明：READY=可直接经 Backend 薄包装暴露；PARTIAL=部分能力（受白名单限制）；NOT_REQUIRED_IN_F0_5=F0.5 不做")
L.append("")
L.append("| capability_code | 能力 | 数据覆盖 | 抖音整体 | 来源接口（白名单 54） | 状态 | data_grain | time_grain | coverage | 备注 |")
L.append("|---|---|---|---|---|---|---|---|---|---|")
for code, name, frontend, srcs, status, domain, grain, tg, cov, is_platform, is_v11 in CAPS:
    L.append("| {} | {} | {} | {} | {} | {} | {} | {} | {} | {} |".format(
        code, name, frontend, "✅" if is_platform else "-",
        "<br>".join(srcs), status, grain, tg, cov, "V1.1" if is_v11 else "-"))
L.append("")
(OUT / "F0.5_API_CAPABILITY_MATRIX.md").write_text("\n".join(L), encoding="utf-8")

# ===== JSON =====
caps_json = []
for code, name, frontend, srcs, status, domain, grain, tg, cov, is_platform, is_v11 in CAPS:
    caps_json.append({
        "capability_code": code, "capability_name": name, "frontend_module": frontend,
        "source_schema": "mart/meta" if srcs else "-", "source_object": srcs[0] if srcs else "-",
        "source_function": srcs or [],
        "required_parameters": ["platform_code", "shop_code", "start_date", "end_date", "scope_key", "page", "page_size"],
        "supported_domains": [domain], "supported_scopes": ["全店", "自营", "合作", "商品卡", "直播", "短视频", "图文", "其他"],
        "data_grain": grain, "time_grain": tg, "coverage_supported": cov == "是",
        "mapping_coverage_supported": True, "security_role": "growth_workspace_reader", "status": status,
    })
(OUT / "F0.5_API_CAPABILITY_MATRIX.json").write_text(json.dumps(
    {"version": "F0.5-A", "generated_at": now, "database_baseline": "convergence_final 04 whitelist 54", "capabilities": caps_json},
    ensure_ascii=False, indent=2), encoding="utf-8")

# ===== 契约草案 =====
L = []
L.append("# F0.5-A｜API 契约草案")
L.append("")
L.append("> 生成：{} ｜ 以 04 白名单 54 接口为唯一正式接口依据；Backend 只做包装，禁止第二套公式".format(now))
L.append("")
L.append("## P0（第一批锁定）")
L.append("")
L.append("| API | 方法 | 参数 | 来源 Function |")
L.append("|---|---|---|---|")
L.append("| /api/v1/health | GET | - | Backend 进程检查 |")
L.append("| /api/v1/ready | GET | - | 数据库连通 + 关键 Function 可执行 |")
L.append("| /api/v1/data-status | GET | platform_code, shop_code | mart.get_data_coverage |")
L.append("| /api/v1/shops | GET | platform_code | meta.shop |")
L.append("| /api/v1/business/summary | GET | platform_code, shop_code, start_date, end_date, scope_key | mart.get_business_period_summary / get_platform_business_period_summary |")
L.append("")
L.append("## P1（第二批）")
L.append("")
L.append("| API | 方法 | 参数 | 来源 Function |")
L.append("|---|---|---|---|")
L.append("| /api/v1/business/products/top | GET | platform_code, shop_code, start_date, end_date, limit | mart.rank_products |")
L.append("| /api/v1/master-data/product-lines | GET | - | meta.product_line（品线成员详情→get_master_product_members 间接） |")
L.append("| /api/v1/master-data/products | GET | shop_code, page, page_size | meta.master_product / get_master_product_members |")
L.append("| /api/v1/priorities/risks | GET | platform_code, start_date, end_date, limit | mart.get_daily_risk_priorities |")
L.append("| /api/v1/priorities/opportunities | GET | platform_code, start_date, end_date, limit | mart.get_daily_opportunity_priorities |")
L.append("| /api/v1/priorities/watchlist | GET | platform_code, start_date, end_date, limit | mart.get_daily_action_list |")
L.append("")
L.append("## P2（路由骨架，返回 NOT_READY 或对应接口）")
L.append("")
L.append("| API | 状态 | 说明 |")
L.append("|---|---|---|")
L.append("| /api/v1/business/compare | READY | compare_business_period |")
L.append("| /api/v1/business/rankings | READY | rank_* 系列 |")
L.append("| /api/v1/business/contributions | READY | get_*_contribution |")
L.append("| /api/v1/diagnostics/snapshot | READY | get_diagnostic_snapshot |")
L.append("| /api/v1/diagnostics/anomalies | READY | get_anomalies |")
L.append("| /api/v1/diagnostics/results | READY | get_diagnostic_result |")
L.append("| /api/v1/opportunities | READY | get_growth_opportunities |")
L.append("| /api/v1/advertising | READY | get_advertising_period_summary |")
L.append("| /api/v1/master-data/resolve | READY | resolve_master_product |")
L.append("")
L.append("## 参数语义")
L.append("- 抖音整体：platform_code=douyin + shop_code=NULL（禁止 shop_id=0 / shop_name=全部）")
L.append("- 日期：YYYY-MM-DD；比例返回数据库原值（0.1972）；效率原值（2.3948）")
L.append("- 分页：page/page_size（默认 1/50，上限 200）")
L.append("")
(OUT / "F0.5_API_CONTRACT_DRAFT.md").write_text("\n".join(L), encoding="utf-8")

# ===== DataGrain =====
L = []
L.append("# F0.5-A｜Data Grain 矩阵")
L.append("")
L.append("> 生成：{} ｜ 数据粒度与时间语义（禁止快照伪装日数据）".format(now))
L.append("")
L.append("| 模块 | 数据源 | data_time_type | 粒度 | 说明 |")
L.append("|---|---|---|---|---|")
L.append("| 成交 | core.douyin_deal_daily | DAILY_FACT | 日 | biz_date 每日；ad_period=不限 汇总行 |")
L.append("| 商品 | core.douyin_product_daily | DAILY_FACT | 日 | 每日商品粒度 |")
L.append("| 账号 | core.douyin_account_daily | DAILY_FACT | 日 | 每日账号粒度 |")
L.append("| 载体 | core.douyin_carrier_daily | DAILY_FACT | 日 | 每日载体粒度 |")
L.append("| 单载体内容 | core.douyin_content_daily | DAILY_FACT | 日 | 每日内容粒度 |")
L.append("| 终端 | core.douyin_terminal_daily | DAILY_FACT | 日 | 每日终端粒度 |")
L.append("| 类目 | core.douyin_category_daily | DAILY_FACT | 日 | 每日类目粒度 |")
L.append("| 价格带 | core.douyin_price_band_daily | DAILY_FACT | 日 | 每日价格带粒度 |")
L.append("| 人群 | core.douyin_audience_daily | DAILY_FACT | 日 | 每日人群粒度 |")
L.append("| Anomaly | mart.anomaly_event | EVENT | 事件 | 检测事件（chain/日期） |")
L.append("| Diagnosis | mart.diagnostic_result | EVENT | 事件 | 诊断结果（证据链） |")
L.append("| Opportunity | mart.opportunity_event | EVENT | 事件 | 机会事件（score/peer） |")
L.append("| Priority | mart.daily_action_item | EVENT | 事件 | 行动项（chain 去重） |")
L.append("| 主数据 | meta.* | VERSION | 即时 | MP/SKU/品线/映射（valid 期） |")
L.append("")
L.append("> 全部核心业务均为 DAILY_FACT，无 PERIOD_SNAPSHOT 伪装风险（V1.3 收口已验证 biz_date=源日期）。")
L.append("")
(OUT / "F0.5_DATA_GRAIN_MATRIX.md").write_text("\n".join(L), encoding="utf-8")

# ===== GapList =====
L = []
L.append("# F0.5-A｜API 缺口清单")
L.append("")
L.append("> 生成：{} ｜ 白名单 54 接口覆盖下，F0.5 无法开放的能力（不扩张数据库）".format(now))
L.append("")
L.append("| capability | 缺口 | 原因 | 处置 |")
L.append("|---|---|---|---|")
L.append("| 品线成员详情 | get_product_line_members / get_product_line_period_summary 不在白名单 | 收口白名单未含 V1.3 品线函数 | F0.5 仅暴露 meta.product_line 主数据 + get_master_product_members 间接；F1.0 决策是否纳入白名单 |")
L.append("| Master Product 跨店汇总 | get_master_product_period_summary / rank_master_products 不在白名单 | 同上 | F0.5 不暴露；F1.0 决策 |")
L.append("| 搜索 / 素材 | 无独立数据源/函数 | F0.5 明确不做 | NOT_REQUIRED_IN_F0_5 |")
L.append("| 商品卡/视频/直播专页 | 部分能力在白名单但需 scope 组合 | 仅经营摘要级 | F0.5 返回 PARTIAL，专页 F1.0 |")
L.append("| 未映射商品/映射冲突 | mart.unmapped_products / product_mapping_conflicts 在白名单 | 可暴露 | READY（Backend 薄包装） |")
L.append("")
L.append("> 原则：不因 F0.5 扩张数据库/白名单；缺口记录供 F1.0 决策。")
L.append("")
(OUT / "F0.5_API_GAP_LIST.md").write_text("\n".join(L), encoding="utf-8")

print("F0.5-A 交付物生成完成：")
for f in sorted(OUT.glob("F0.5*")):
    print("  ", f.name, "({}B)".format(f.stat().st_size))
