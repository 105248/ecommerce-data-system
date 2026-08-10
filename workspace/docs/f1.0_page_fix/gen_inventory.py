# -*- coding: utf-8 -*-
"""F1.0 当前页面/API绑定盘点表生成（基于 app.js 实际代码扫描结论）"""
import csv
from pathlib import Path

rows = [
    ["今日经营", "/", "TodayPage(首页)", "MetricCard/TrendSvg", "summary+compare+trend+risks+opps+contribution",
     "api('/business/*')+api('/priorities/*')", "/business/summary /business/compare /business/trend /priorities/risks /priorities/opportunities /business/shop-contribution",
     "get_business_period_summary/get_platform_business_period_summary/get_daily_risk_priorities/get_daily_opportunity_priorities/get_shop_contribution",
     "是(自身)", "否", "否", "是", "READY(首页本体)"],
    ["店铺", "/shop", "StorePage(两店KPI+贡献)", "MetricCard/DataTable", "summary×2+contribution",
     "api('/business/summary')+api('/business/shop-contribution')", "/business/summary(shop×2) /business/shop-contribution",
     "get_business_period_summary(单店×2)/get_shop_contribution", "部分(用summary但按店)", "否", "否", "部分", "PARTIAL(缺对比表/环比)"],
    ["经营优先级", "/priorities", "PriorityPage(风险+机会+Watchlist)", "DataTable", "risks+opps+watchlist",
     "api('/priorities/*')", "/priorities/risks /priorities/opportunities /priorities/watchlist",
     "get_daily_risk_priorities/get_daily_opportunity_priorities/get_daily_action_list", "否", "否", "否", "是", "READY"],
    ["品线", "/product-lines", "ProductLinePage(品线+成员)", "DataTable", "product-lines+members",
     "api('/master-data/*')", "/master-data/product-lines /master-data/product-line-members",
     "meta.product_line+master_product 关联视图", "否", "否", "否", "是(结构)", "PARTIAL(无经营汇总)"],
    ["Master Product", "/master-products", "MasterProductPage(列表)", "DataTable", "master-data/products",
     "api('/master-data/products')", "/master-data/products",
     "meta.master_product", "否", "否", "否", "是(结构)", "PARTIAL(无经营维度)"],
    ["商品", "/products", "ProductPage(TOP50)", "DataTable", "products/top",
     "api('/business/products/top')", "/business/products/top",
     "mart.rank_products", "否", "否", "否", "是", "PARTIAL(无退款/投放列)"],
    ["商品卡", "/product-card", "ProductCardPage", "MetricCard", "summary(scope=商品卡)",
     "api('/business/summary')", "/business/summary?scope=商品卡",
     "get_business_period_summary(scope=商品卡)", "是(用经营摘要冒充)", "否", "否", "否", "WRONG_BINDING(经营摘要冒充商品卡页)"],
    ["投放", "/advertising", "AdvertisingPage(8广告指标)", "MetricCard", "advertising/summary",
     "api('/advertising/summary')", "/advertising/summary",
     "get_advertising_summary(白名单)", "否", "否", "否", "是", "READY"],
    ["退款", "/refunds", "RefundPage(3卡)", "MetricCard", "summary",
     "api('/business/summary')", "/business/summary",
     "get_business_period_summary", "是(用经营摘要冒充退款页)", "否", "否", "否", "WRONG_BINDING(退款页=summary 3卡)"],
    ["达人/账号", "/accounts", "AccountPage(静态NOTICE)", "Notice", "无",
     "无", "无", "core.douyin_account_daily 无白名单API", "否", "否", "是", "否", "NOT_READY(标注明确)"],
    ["直播", "/live", "LivePage(静态NOTICE)", "Notice", "无",
     "无", "无(声称摘要级但未调API)", "无", "否", "否", "是", "否", "WRONG_BINDING(声明≠实现,假占位)"],
    ["短视频", "/videos", "VideoPage(静态NOTICE)", "Notice", "无",
     "无", "无(同上)", "无", "否", "否", "是", "否", "WRONG_BINDING(声明≠实现,假占位)"],
    ["搜索", "/search", "SearchPage(静态)", "Notice", "无",
     "无", "无", "无", "否", "否", "是", "否", "NOT_READY(标注明确)"],
    ["素材", "/materials", "MaterialPage(静态)", "Notice", "无",
     "无", "无", "无", "否", "否", "是", "否", "NOT_READY(标注明确)"],
    ["智能经营总入口", "/smart-operation", "不存在", "-", "无",
     "无", "无", "无", "-", "-", "-", "否", "MISSING(菜单有但路由缺失)"],
    ["风险中心", "/risks", "RiskPage(完整列表)", "DataTable", "risks(limit50)",
     "api('/priorities/risks')", "/priorities/risks?limit=50",
     "get_daily_risk_priorities", "否", "否", "否", "是", "READY"],
    ["问题诊断", "/diagnostics", "DiagnosisPage(结果+拆解)", "DataTable", "diagnostics/results+decomposition",
     "api('/diagnostics/*')", "/diagnostics/results /diagnostics/decomposition",
     "get_diagnostic_result/decompose_platform_change_by_shop", "否", "否", "否", "是", "READY(路由名应为/diagnosis)"],
    ["增长机会", "/opportunities", "OpportunityPage(完整列表)", "DataTable", "opportunities(limit50)",
     "api('/priorities/opportunities')", "/priorities/opportunities?limit=50",
     "get_daily_opportunity_priorities", "否", "否", "否", "是", "READY"],
]

p = Path("F1.0_current_page_api_inventory.csv")
with p.open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["page_name", "route", "page_component", "shared_component", "data_hook", "frontend_service",
                "backend_endpoint", "database_interface", "调用今日经营接口", "使用假数据", "静态mock", "真正独立", "当前状态"])
    w.writerows(rows)
print("盘点表生成:", p, "| 页面数:", len(rows))
from collections import Counter
c = Counter(r[-1].split("(")[0] for r in rows)
print("状态分布:", dict(c))
