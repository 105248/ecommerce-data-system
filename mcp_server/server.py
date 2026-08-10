# -*- coding: utf-8 -*-
"""mart V1.0 Stage4 MCP Server（stdio 只读数据服务）。

职责边界：
- 只做：参数校验 → 调用已验收的 mart Function → 限制行数 → 结构化返回。
- 不做：自行 AVG 比例 / SUM 父子 TOTAL / 重算 V1.4 / 重建商品 TOTAL / 任意 SQL。
- 数据库账号：agent_readonly（只读）。
"""
import json
import logging
import time
from datetime import datetime

import mcp.server.stdio
import mcp.types as types
from mcp.server import NotificationOptions, Server
from mcp.server.models import InitializationOptions

import config
import database
import schemas
from tools import (account_tools, advertising_tools, anomaly_tools, business_tools,
                   catalog_tools, category_tools, diagnostic_tools,
                   diagnosis_tools, domain_tools, masterdata_tools, opportunity_tools,
                   platform_tools, priority_tools, product_tools)

# ---------------- 日志 ----------------
LOG_DIR = config.LOG_DIR
LOG_DIR.mkdir(parents=True, exist_ok=True)
log_file = LOG_DIR / "mcp_server.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s|%(levelname)s|%(message)s",
    handlers=[logging.FileHandler(log_file, encoding="utf-8"), logging.StreamHandler()],
)
logger = logging.getLogger("mart_mcp")

server = Server("mart-mcp-server")


# ---------------- 工具注册表 ----------------
# 每个工具: (名称, 描述, handler, 参数schema)
def _register_tools():
    tools = []

    def add(name, description, handler, schema):
        tools.append((name, description, handler, schema))

    # 基础目录
    add("list_shops", "列出可用店铺（shop_name）。",
        lambda a: catalog_tools.list_shops(), {})
    add("get_data_coverage", "返回店铺数据覆盖范围（min/max日期、天数、行数）。",
        lambda a: catalog_tools.get_data_coverage(a.get("shop_name")),
        {"shop_name": {"type": "string", "description": "店铺名，缺省=全部"}})
    add("get_metric_catalog", "返回分析指标目录（domain/metric_key/中文名/类型/是否可排名/可贡献度）。",
        lambda a: catalog_tools.get_metric_catalog(a.get("domain_key")),
        {"domain_key": {"type": "string", "description": "业务域: business/product/account/carrier/category/price_band/audience，缺省=全部"}})
    add("get_import_history", "返回最近导入批次历史（只读必要字段）。",
        lambda a: catalog_tools.get_import_history(a.get("limit")),
        {"limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})
    add("health_check", "MCP 服务健康检查（数据库连通+白名单可读）。",
        lambda a: catalog_tools.health_check(), {})

    # 经营总览 / 环比
    add("get_business_summary", "高频经营总览：按经营范围(全店/自营/合作/商品卡/短视频等)汇总任意区间。比例与均值已由数据库按V1.4跨期重算，客户端不要再次AVG。",
        lambda a: business_tools.get_business_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("scope_key", "全店"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string", "description": "店铺名，缺省=全部店铺"},
         "start_date": {"type": "string", "description": "开始日期 YYYY-MM-DD"},
         "end_date": {"type": "string", "description": "结束日期 YYYY-MM-DD"},
         "scope_key": {"type": "string", "description": "经营语义: 全店/自营/合作/商品卡/短视频/直播/图文/其他/组合", "default": "全店"},
         "metric_key": {"type": "string", "description": "指标，见 get_metric_catalog", "default": "user_pay_amount"}})
    add("compare_business", "环比：本期N天 vs 紧邻前N天。比例同时返回相对变化率与百分点变化。",
        lambda a: business_tools.compare_business(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("scope_key", "全店"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string", "description": "店铺名"},
         "start_date": {"type": "string", "description": "本期开始日期 YYYY-MM-DD"},
         "end_date": {"type": "string", "description": "本期结束日期 YYYY-MM-DD"},
         "scope_key": {"type": "string", "description": "经营语义", "default": "全店"},
         "metric_key": {"type": "string", "description": "指标", "default": "user_pay_amount"}})
    add("get_business_report", "日报/周报数据模板V1.0：一次返回三板块×六行(抖音整体/抖音弹动官方旗舰店/抖音弹动个人护理旗舰店 × 整体/自营直播/自营商品/达人直播/达人短视频/橱窗)，指标=成交金额/成交退款金额/结算金额/退款率/投放消耗/投放费比(剔除退款、店铺绑定)。比率已×100。日报传单日、周报传一周区间。用户要'日报/周报/经营报表模板'用此工具。",
        lambda a: business_tools.get_business_report(
            a.get("start_date"), a.get("end_date")),
        {"start_date": {"type": "string", "description": "开始日期 YYYY-MM-DD（日报=单日）"},
         "end_date": {"type": "string", "description": "结束日期 YYYY-MM-DD（日报=同日）"}})

    # V1.1 诊断基础层（Stage1：只返回基础诊断数据，不判异常）
    add("get_diagnostic_snapshot", "V1.1统一经营诊断快照：一行=一个对象×一个指标×当前期×上期。返回值/变化/排名/贡献/覆盖/数据状态。域=shop/scope/product/carrier/account/category。本阶段只返回基础诊断数据，不判异常、不出原因结论。",
        lambda a: diagnostic_tools.get_diagnostic_snapshot(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("domain_key"), a.get("scope_key"), a.get("entity_id"),
            a.get("entity_name"), a.get("category_level")),
        {"shop_name": {"type": "string", "description": "店铺名，缺省=平台汇总"},
         "start_date": {"type": "string", "description": "当前期开始日期 YYYY-MM-DD"},
         "end_date": {"type": "string", "description": "当前期结束日期 YYYY-MM-DD（上期=等长前置）"},
         "domain_key": {"type": "string", "description": "诊断域: shop/scope/product/carrier/account/category"},         "scope_key": {"type": "string", "description": "Scope过滤（scope/carrier/account 域用）"},
         "entity_id": {"type": "string", "description": "对象ID过滤（product 域=product_id）"},
         "entity_name": {"type": "string", "description": "对象名称过滤（product 域=product_name）"},
         "category_level": {"type": "integer", "description": "类目层级（category 域，默认3）"}})
    add("get_diagnostic_supported_metrics", "V1.1 支持的诊断指标目录（31个指标及类型/方向/排名/贡献属性）。",
        lambda a: diagnostic_tools.get_diagnostic_supported_metrics(), {})
    # V1.1 Stage5 优先级与每日行动（只读；AI 不得重排/不得执行动作）
    add("get_daily_risk_priorities", "今日风险 TOP（P1_URGENT~P4_LOW；同实体仅 1 主卡；含业务影响/排查方向，非已证原因）。",
        lambda a: priority_tools.get_daily_risk_priorities(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"), a.get("limit", 5)),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "limit": {"type": "integer", "default": 5}})
    add("get_daily_opportunity_priorities", "今日机会 TOP（O1_STRONG~O4_WATCH；同实体仅 1 主机会；机会质量排序分非成功概率）。",
        lambda a: priority_tools.get_daily_opportunity_priorities(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"), a.get("limit", 5)),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "limit": {"type": "integer", "default": 5}})
    add("get_daily_action_list", "今日行动清单（RISK/OPPORTUNITY/WATCH 混合，按优先级排序；行动是排查方向，不代表已证明原因）。",
        lambda a: priority_tools.get_daily_action_list(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"),
            a.get("item_type"), a.get("limit", 20)),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "item_type": {"type": "string", "enum": ["RISK", "OPPORTUNITY", "WATCH"]},
         "limit": {"type": "integer", "default": 20}})
    add("get_daily_business_brief", "每日经营简报：TOP5 风险 + TOP5 机会 + TOP5 Watchlist。",
        lambda a: priority_tools.get_daily_business_brief(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"}})

    # V1.1 Stage4 增长机会（只读；机会质量排序分，非成功概率；AI 不自行修改评分）
    add("get_growth_opportunities", "增长机会候选：O01-O08×9域，机会质量排序分0-100（非未来成功概率）。含同域peer基准/可用权重/风险标记。",
        lambda a: opportunity_tools.get_growth_opportunities(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"),
            a.get("domain_key"), a.get("opportunity_code"), a.get("min_level")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "domain_key": {"type": "string"},
         "opportunity_code": {"type": "string", "description": "O01-O08"},
         "min_level": {"type": "string", "enum": ["LOW","MEDIUM","HIGH","STRONG"]}})
    add("get_entity_opportunity", "单实体机会明细（域+实体名）。",
        lambda a: opportunity_tools.get_entity_opportunity(
            a.get("platform_code", "douyin"), a.get("domain_key"), a.get("entity_name"),
            a.get("start_date"), a.get("end_date")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "domain_key": {"type": "string"}, "entity_name": {"type": "string"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"}})
    add("get_opportunity_summary", "机会汇总：按域×类型统计事件数/最高分/平均分/等级分布。",
        lambda a: opportunity_tools.get_opportunity_summary(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"), a.get("status", "QUALIFIED")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "status": {"type": "string", "default": "QUALIFIED"}})

    # V1.1 Stage3 问题定位与漏斗诊断（只读；AI 只说数据拆分，不做因果/机会/优先级）
    add("get_diagnostic_result", "诊断结果（数据层问题定位）：层级/漏斗/贡献/投放拆解+证据链+置信度+primary_stage。",
        lambda a: diagnosis_tools.get_diagnostic_result(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"),
            a.get("domain_key"), a.get("status")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "domain_key": {"type": "string"}, "status": {"type": "string"}})
    add("get_entity_diagnosis", "单实体诊断结果（读已生成诊断）。",
        lambda a: diagnosis_tools.get_entity_diagnosis(
            a.get("platform_code", "douyin"), a.get("domain_key"), a.get("entity_name"),
            a.get("start_date"), a.get("end_date")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "domain_key": {"type": "string"}, "entity_name": {"type": "string"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"}})
    add("get_change_decomposition", "变化拆解：平台→店铺 或 Master Product→店铺商品。返回 net_change/gross_negative/gross_positive/negative_impact_share。用户问'哪家店/哪个商品拖累整体'用此工具。",
        lambda a: diagnosis_tools.get_change_decomposition(
            a.get("platform_code", "douyin"), a.get("master_product_id"),
            a.get("start_date"), a.get("end_date")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "master_product_id": {"type": "integer", "description": "指定则按店铺商品拆解，否则平台按店铺拆解"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"}})
    add("get_funnel_diagnosis", "漏斗诊断：曝光→点击→成交→退款 各环节变化。",
        lambda a: diagnosis_tools.get_funnel_diagnosis(
            a.get("domain_key"), a.get("entity_name"), a.get("start_date"), a.get("end_date"),
            a.get("shop_name"), a.get("scope_key")),
        {"domain_key": {"type": "string"}, "entity_name": {"type": "string"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "shop_name": {"type": "string"}, "scope_key": {"type": "string"}})
    add("get_advertising_diagnosis", "投放诊断（复用快照投放指标；平台=跨店加权，单店=原口径）。",
        lambda a: diagnosis_tools.get_advertising_diagnosis(
            a.get("domain_key"), a.get("entity_name"), a.get("start_date"), a.get("end_date"),
            a.get("shop_name")),
        {"domain_key": {"type": "string"}, "entity_name": {"type": "string"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "shop_name": {"type": "string"}})

    # V1.1 Stage2 异常检测（只读查询；异常来自 mart，AI 不做根因/机会/优先级）
    add("get_anomalies", "异常检测结果：哪里异常/多严重/是否持续/影响多大。域=platform/shop/scope/master_product/shop_product/product_line/carrier/account/category。只返回异常事实，不做根因结论。",
        lambda a: anomaly_tools.get_anomalies(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"),
            a.get("domain_key"), a.get("entity_name"), a.get("severity"), a.get("status", "OPEN")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "domain_key": {"type": "string", "description": "诊断域（platform/shop/...）"},
         "entity_name": {"type": "string"}, "severity": {"type": "string", "enum": ["INFO","LOW","MEDIUM","HIGH","CRITICAL"]},
         "status": {"type": "string", "default": "OPEN"}})
    add("get_anomaly_summary", "异常汇总：按域×类型统计事件数/严重度/影响额。",
        lambda a: anomaly_tools.get_anomaly_summary(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"), a.get("status", "OPEN")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "status": {"type": "string", "default": "OPEN"}})

    # V1.3 主数据（Stage3：公司级商品/SKU/品线，只读查询）
    add("list_master_products", "公司商品主档清单（可按品线/状态过滤，含已确认映射数）。",
        lambda a: masterdata_tools.list_master_products(a.get("product_line_name"), a.get("status")),
        {"product_line_name": {"type": "string"}, "status": {"type": "string", "enum": ["ACTIVE","DISCONTINUED","MERGED","TEST"]}})
    add("get_master_product_members", "公司商品跨店成员：同一真实商品在两家抖音店的平台商品（平台/店铺/ID/状态/有效期）。",
        lambda a: masterdata_tools.get_master_product_members(a.get("master_product_id"), a.get("master_product_code")),
        {"master_product_id": {"type": "integer"}, "master_product_code": {"type": "string"}})
    add("resolve_master_product", "查商品归属：平台+店铺+平台商品ID(+业务日期) → 公司商品/品线/映射状态。",
        lambda a: masterdata_tools.resolve_master_product(a.get("platform_code", "douyin"), a.get("shop_name"), a.get("platform_product_id"), a.get("biz_date")),
        {"platform_code": {"type": "string", "default": "douyin"}, "shop_name": {"type": "string"},
         "platform_product_id": {"type": "string"}, "biz_date": {"type": "string", "description": "业务日期 YYYY-MM-DD"}})
    add("list_product_lines", "品线清单（鱼子酱品线/人参品线等）。",
        lambda a: masterdata_tools.list_product_lines(), {})
    add("get_product_line_members", "品线成员：品线 → 公司商品 → 已确认映射数/店铺覆盖。",
        lambda a: masterdata_tools.get_product_line_members(a.get("product_line_name")),
        {"product_line_name": {"type": "string"}})
    add("get_unmapped_products", "未归属商品（按近30天成交金额降序；成交金额仅用于决定处理优先级，不用于自动匹配）。",
        lambda a: masterdata_tools.get_unmapped_products(a.get("limit", 50)),
        {"limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 50}})
    add("get_mapping_conflicts", "商品映射冲突（同一平台店铺商品多条启用映射/时间重叠）。",
        lambda a: masterdata_tools.get_mapping_conflicts(), {})


    # V1.3 平台统一经营（Stage2：抖音多店整体）
    add("get_platform_business_summary", "抖音平台整体经营汇总：两店合计+coverage(启用/覆盖/缺失店铺数)。比例=分子/分母重算、效率=加权；成交人数=各店之和(跨店不去重)。用户问'抖音整体/两家店合计/整个抖音怎么样'用此工具。",
        lambda a: platform_tools.get_platform_business_summary(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"),
            a.get("scope_key", "全店")),
        {"platform_code": {"type": "string", "description": "平台，默认 douyin", "default": "douyin"},
         "start_date": {"type": "string", "description": "开始日期 YYYY-MM-DD"},
         "end_date": {"type": "string", "description": "结束日期 YYYY-MM-DD"},
         "scope_key": {"type": "string", "description": "经营语义(全店/自营/合作/商品卡等)", "default": "全店"}})
    add("compare_platform_business", "抖音平台环比：本期N天 vs 等长前N天。比例返回百分点+相对变化。",
        lambda a: platform_tools.compare_platform_business(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"),
            a.get("scope_key", "全店"), a.get("metric_key", "user_pay_amount")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "scope_key": {"type": "string", "default": "全店"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("get_shop_contribution", "抖音店铺贡献度：单店值/平台总额/占比(本期+上期+变化)。贡献度和=100%(数据完整且指标可加时)。用户问'哪个店占比高/贡献大'用此工具。",
        lambda a: platform_tools.get_shop_contribution(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"),
            a.get("scope_key", "全店"), a.get("metric_key", "user_pay_amount")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "scope_key": {"type": "string", "default": "全店"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("decompose_platform_change_by_shop", "抖音平台变化按店铺拆解：net_change/gross_negative/gross_positive/negative_impact_share(单店负向/全部负向)。用户问'哪家店拖累/贡献了整体增长'用此工具。",
        lambda a: platform_tools.decompose_platform_change_by_shop(
            a.get("platform_code", "douyin"), a.get("start_date"), a.get("end_date"),
            a.get("scope_key", "全店"), a.get("metric_key", "user_pay_amount")),
        {"platform_code": {"type": "string", "default": "douyin"},
         "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "scope_key": {"type": "string", "default": "全店"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})

    # 投放经营 (V1.0.1)
    add("get_advertising_summary", "投放经营汇总：一次返回全部10项投放指标（消耗/贡献/费比/效率）+覆盖率。金额=SUM、比例与效率=加权源比率（非AVG）。用户问'投放表现怎么样'用此工具。",
        lambda a: advertising_tools.get_advertising_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("scope_key", "全店")),
        {"shop_name": {"type": "string", "description": "店铺名，缺省=全部店铺"},
         "start_date": {"type": "string", "description": "开始日期 YYYY-MM-DD"},
         "end_date": {"type": "string", "description": "结束日期 YYYY-MM-DD"},
         "scope_key": {"type": "string", "description": "经营语义: 全店/自营/合作/商品卡/短视频等", "default": "全店"}})
    add("compare_advertising", "投放环比：本期N天 vs 紧邻前N天，返回10项投放指标变化。比例=百分点+相对变化；效率=绝对+相对变化（不输出百分点）。用户问'最近7天投放比前7天'用此工具。",
        lambda a: advertising_tools.compare_advertising(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("scope_key", "全店")),
        {"shop_name": {"type": "string", "description": "店铺名"},
         "start_date": {"type": "string", "description": "本期开始日期 YYYY-MM-DD"},
         "end_date": {"type": "string", "description": "本期结束日期 YYYY-MM-DD"},
         "scope_key": {"type": "string", "description": "经营语义", "default": "全店"}})

    # 商品
    add("get_product_summary", "商品汇总。默认 carrier_type='全部'（平台独立TOTAL），不通过各载体明细重建。",
        lambda a: product_tools.get_product_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("product_id"), a.get("product_name"), a.get("carrier_type", "全部"),
            a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "product_id": {"type": "string", "description": "商品ID(文本)"},
         "product_name": {"type": "string", "description": "商品名称"},
         "carrier_type": {"type": "string", "description": "载体，缺省/全部=平台独立TOTAL", "default": "全部"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("rank_products", "商品排名/增长/下降/排名变化。排名使用 product carrier=全部 平台独立TOTAL；过滤商品时先全量排名再过滤。",
        lambda a: product_tools.rank_products(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("metric_key", "user_pay_amount"), a.get("sort_by", "current_value"),
            a.get("sort_direction", "DESC"), a.get("limit", 20),
            a.get("product_id"), a.get("product_name")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "description": "current_value/absolute_change/relative_change/rank_change", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20},
         "product_id": {"type": "string"}, "product_name": {"type": "string"}})
    add("get_product_contribution", "商品贡献度：同时返回 product 域占比与全店占比（双分母，平台口径差异不强制相等）。",
        lambda a: product_tools.get_product_contribution(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("metric_key", "user_pay_amount"), a.get("product_id"),
            a.get("product_name"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "product_id": {"type": "string"}, "product_name": {"type": "string"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})

    # 账号
    add("get_account_summary", "账号汇总。'更多账号'=合作聚合桶(aggregate_bucket)，不是具体达人；不用于回答全店/自营总成交。",
        lambda a: account_tools.get_account_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("sale_scope"), a.get("account_name"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "sale_scope": {"type": "string", "enum": ["自营", "合作"]}, "account_name": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("rank_accounts", "账号排名。默认排除 aggregate_bucket（更多账号），避免把聚合桶当具体达人排名。",
        lambda a: account_tools.rank_accounts(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("sale_scope", "合作"), a.get("metric_key", "user_pay_amount"),
            a.get("sort_by", "current_value"), a.get("sort_direction", "DESC"),
            a.get("limit", 20), a.get("include_aggregate_bucket", False), a.get("account_name")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "sale_scope": {"type": "string", "enum": ["自营", "合作"], "default": "合作"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20},
         "include_aggregate_bucket": {"type": "boolean", "default": False},
         "account_name": {"type": "string"}})
    add("get_account_contribution", "账号贡献度：分母来自 deal 权威 scope/全店 TOTAL；自营覆盖缺口在 coverage_note 说明。",
        lambda a: account_tools.get_account_contribution(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("sale_scope", "合作"), a.get("metric_key", "user_pay_amount"),
            a.get("account_name"), a.get("include_aggregate_bucket", True), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "sale_scope": {"type": "string", "enum": ["自营", "合作"], "default": "合作"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "account_name": {"type": "string"},
         "include_aggregate_bucket": {"type": "boolean", "default": True},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})

    # 类目
    add("get_category_summary", "类目汇总。必须明确 category_level(1/2/3/4)，禁止跨层级混合。",
        lambda a: category_tools.get_category_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("category_level", 3), a.get("category_l1"), a.get("category_l2"),
            a.get("category_l3"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "category_level": {"type": "integer", "enum": [1, 2, 3, 4], "default": 3},
         "category_l1": {"type": "string"}, "category_l2": {"type": "string"}, "category_l3": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("rank_categories", "类目排名：强制同一 category_level 内比较，L1/L2/L3 父子层级绝不混排。",
        lambda a: category_tools.rank_categories(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("category_level", 3), a.get("category_l1"), a.get("category_l2"),
            a.get("metric_key", "user_pay_amount"), a.get("sort_by", "current_value"),
            a.get("sort_direction", "DESC"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "category_level": {"type": "integer", "enum": [1, 2, 3, 4], "default": 3},
         "category_l1": {"type": "string"}, "category_l2": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})
    add("get_category_contribution", "类目贡献度：同时返回类目域占比与全店占比（双分母，允许平台口径差异）。",
        lambda a: category_tools.get_category_contribution(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("category_level", 3), a.get("category_l1"), a.get("category_l2"),
            a.get("metric_key", "user_pay_amount"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "category_level": {"type": "integer", "enum": [1, 2, 3, 4], "default": 3},
         "category_l1": {"type": "string"}, "category_l2": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})

    # 其他域
    add("get_carrier_summary", "载体/渠道汇总（拆分/排名用，不承担全店TOTAL；special_overlap 行不与明细混SUM）。",
        lambda a: domain_tools.get_carrier_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("sale_scope"), a.get("carrier_type"), a.get("account_channel"),
            a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "sale_scope": {"type": "string"}, "carrier_type": {"type": "string"}, "account_channel": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("get_content_summary", "内容汇总（当前真实样本仅验证商品卡载体）。",
        lambda a: domain_tools.get_content_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("selling_type"), a.get("carrier_type"), a.get("content_id"),
            a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "selling_type": {"type": "string"}, "carrier_type": {"type": "string"}, "content_id": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("get_terminal_summary", "终端汇总：terminal_type='整体' 为合法TOTAL（总览优先取），拆分只取具体终端，禁止整体+明细混SUM。",
        lambda a: domain_tools.get_terminal_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("terminal_type"), a.get("selling_type"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "terminal_type": {"type": "string"}, "selling_type": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("get_price_band_summary", "价格带汇总：6 带已验证互斥，可安全 SUM 重建店铺总量。",
        lambda a: domain_tools.get_price_band_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("price_band"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "price_band": {"type": "string"}, "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("get_audience_summary", "人群汇总：carrier_type='全部' 为合法TOTAL（总览优先），拆分只用5个明细载体，禁止全部+明细混SUM。",
        lambda a: domain_tools.get_audience_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("audience_type"), a.get("carrier_type", "全部"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "audience_type": {"type": "string"}, "carrier_type": {"type": "string", "default": "全部"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("rank_carriers", "载体排名：使用 deal 合法 TOTAL Scope（商品卡/短视频/直播/图文/其他），不通过账号渠道明细重建。",
        lambda a: domain_tools.rank_carriers(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("sale_scope", "全部"), a.get("metric_key", "user_pay_amount"),
            a.get("sort_by", "current_value"), a.get("sort_direction", "DESC"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "sale_scope": {"type": "string", "enum": ["全部", "自营", "合作"], "default": "全部"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})
    add("rank_price_bands", "价格带排名：6 带互斥可直接比较。",
        lambda a: domain_tools.rank_price_bands(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("metric_key", "user_pay_amount"), a.get("sort_by", "current_value"),
            a.get("sort_direction", "DESC"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})
    add("rank_audiences", "人群排名：默认 carrier_type='全部'（合法TOTAL），禁止 TOTAL+明细载体混排。",
        lambda a: domain_tools.rank_audiences(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("carrier_type", "全部"), a.get("metric_key", "user_pay_amount"),
            a.get("sort_by", "current_value"), a.get("sort_direction", "DESC"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "carrier_type": {"type": "string", "default": "全部"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})

    return tools


TOOLS = _register_tools()
TOOL_MAP = {name: (desc, handler, schema) for name, desc, handler, schema in TOOLS}


def _to_text_result(obj):
    return types.TextContent(type="text", text=json.dumps(obj, ensure_ascii=False, default=str))


@server.list_tools()
async def list_tools() -> list[types.Tool]:
    return [
        types.Tool(
            name=name,
            description=desc,
            inputSchema={
                "type": "object",
                "properties": schema,
            },
        )
        for name, desc, _handler, schema in TOOLS
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict):
    t0 = time.time()
    entry = TOOL_MAP.get(name)
    if entry is None:
        return [_to_text_result(schemas.err(name, "UNKNOWN_TOOL", "未知工具"))]
    desc, handler, _schema = entry
    try:
        result = handler(arguments or {})
        ok_flag = bool(result.get("ok"))
        error_type = result.get("error_type")
    except schemas.ArgError as e:
        result = schemas.err(name, e.error_type, str(e))
        ok_flag, error_type = False, e.error_type
    except database.DatabaseError as e:
        result = schemas.err(name, "DB_ERROR", str(e))
        ok_flag, error_type = False, "DB_ERROR"
    except Exception as e:  # noqa: BLE001
        logger.exception("tool %s 内部异常", name)
        result = schemas.err(name, "INTERNAL_ERROR", "内部错误，请查看日志")
        ok_flag, error_type = False, "INTERNAL_ERROR"

    duration_ms = int((time.time() - t0) * 1000)
    row_count = len(result.get("data", [])) if isinstance(result.get("data"), list) else 0
    logger.info("%s|tool=%s|args=%s|duration_ms=%d|row_count=%d|ok=%s|error=%s",
                datetime.now().isoformat(), name,
                json.dumps(arguments or {}, ensure_ascii=False)[:200],
                duration_ms, row_count, ok_flag, error_type)
    return [_to_text_result(result)]


async def main():
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="mart-mcp-server",
                server_version="1.0.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
