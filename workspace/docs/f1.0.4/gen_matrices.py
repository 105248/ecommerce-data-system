# -*- coding: utf-8 -*-
"""F1.0.4 矩阵交付物：route_page / filter_capability / metric_binding / capability_state / network_route"""
import csv
from pathlib import Path

BASE = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.4")

# ===== 1) Route Page Matrix =====
routes = [
    ("/today", "今日经营", "dashboard.TodayPage", "READY"), ("/store", "店铺经营", "store.StorePage", "READY"),
    ("/priorities", "经营优先级", "priorities.PrioritiesPage", "READY"),
    ("/product-lines", "品线分析", "product-lines.ProductLinesPage", "READY"),
    ("/master-products", "Master Product", "master-products.MasterProductsPage", "READY"),
    ("/products", "商品分析", "pages.ProductsPage", "READY"),
    ("/product-card", "商品卡经营", "product-card.ProductCardPage", "READY"),
    ("/advertising", "投放经营", "pages.AdvertisingPage", "READY"),
    ("/refunds", "退款分析", "pages.RefundsPage", "READY"),
    ("/accounts", "达人/账号", "pages.AccountsPage", "READY"),
    ("/live", "直播经营", "live.LivePage", "READY"),
    ("/videos", "短视频经营", "videos.VideosPage", "READY"),
    ("/search", "搜索", "pages.SearchPage", "SOURCE_NOT_AVAILABLE"),
    ("/materials", "素材", "materials.MaterialsPage", "READY"),
    ("/smart-operation", "智能经营", "pages.SmartOperationPage", "READY"),
    ("/risks", "风险中心", "pages.RisksPage", "READY"),
    ("/diagnostics", "问题诊断", "pages.DiagnosticsPage", "READY"),
    ("/opportunities", "增长机会", "pages.OpportunitiesPage", "READY"),
]
with (BASE / "F1.0.4_route_page_matrix.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["route", "page_title", "component", "capability_status"])
    w.writerows(routes)
print("route_page:", len(routes))

# ===== 2) Filter Capability Matrix =====
filters = [
    ("/today", "是", "是", "是", "是"), ("/store", "是", "否", "是", "是"),
    ("/priorities", "是", "否", "否", "否"), ("/product-lines", "是", "否", "否", "否"),
    ("/master-products", "是", "否", "否", "否"), ("/products", "是", "是", "否", "否"),
    ("/product-card", "是", "是", "是", "是"), ("/advertising", "是", "是", "是", "是"),
    ("/refunds", "是", "是", "是", "是"), ("/accounts", "是", "是", "否", "否"),
    ("/live", "是", "是", "是", "是"), ("/videos", "是", "是", "是", "是"),
    ("/search", "否", "否", "否", "否"), ("/materials", "是", "是", "否", "否"),
    ("/smart-operation", "是", "否", "否", "否"), ("/risks", "是", "否", "否", "否"),
    ("/diagnostics", "是", "否", "否", "否"), ("/opportunities", "是", "否", "否", "否"),
]
with (BASE / "F1.0.4_filter_capability_matrix.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["route", "supports_platform", "supports_shop", "supports_date", "supports_scope"])
    w.writerows(filters)
print("filter_capability:", len(filters))

# ===== 3) Metric Binding Audit =====
bindings = [
    ("今日经营", "成交金额", "transaction_amount", "transaction_amount", "成交金额", "OK"),
    ("今日经营", "用户支付金额", "user_pay_amount", "user_pay_amount", "用户支付金额", "OK"),
    ("今日经营", "成交退款金额", "transaction_refund_amount_pay_time", "transaction_refund_amount_pay_time", "成交退款金额(支付时间)", "OK"),
    ("今日经营", "退款率", "refund_rate", "refund_rate_pay_time", "退款率(支付时间)", "OK"),
    ("今日经营", "结算金额", "settlement_amount", "settlement_amount", "结算金额", "OK"),
    ("今日经营", "投放消耗", "ad_spend_shop_bound", "ad_spend_shop_bound", "投放消耗(店铺绑定)", "OK"),
    ("今日经营", "投放费比", "ad_spend_rate_net_refund_shop_bound", "ad_spend_rate_net_refund_shop_bound", "投放费比", "OK"),
    ("店铺", "贡献率", "contribution", "contribution", "贡献率", "OK"),
    ("商品", "用户支付金额", "current_value", "user_pay_amount", "用户支付金额", "OK"),
    ("商品卡", "成交金额", "transaction_amount", "transaction_amount", "成交金额", "OK"),
    ("投放", "投放消耗(被投)", "ad_spend_shop_promoted", "ad_spend_shop_promoted", "投放消耗(店铺被投)", "OK"),
    ("退款", "退款金额(支付时间)", "refund_amount_pay_time", "refund_amount_pay_time", "退款金额(支付时间)", "OK"),
    ("账号", "用户支付金额", "current_value", "user_pay_amount", "用户支付金额", "OK"),
    ("品线", "用户支付金额", "user_pay_amount", "user_pay_amount", "用户支付金额", "OK"),
    ("MP", "用户支付金额", "current_value", "user_pay_amount", "用户支付金额", "OK"),
]
with (BASE / "F1.0.4_metric_binding_audit.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["page", "ui_label", "frontend_field", "api_field", "db_cn_name", "result"])
    w.writerows(bindings)
print("metric_binding:", len(bindings))

# ===== 4) Capability State Audit =====
states = [
    ("今日经营", "READY", "全部指标可用"), ("店铺", "READY", ""),
    ("经营优先级", "READY", "STALE 提示"), ("品线", "READY", "结构+汇总"),
    ("Master Product", "READY", "排名+主档"), ("商品", "READY", "仅 user_pay；结算/投放 UNSUPPORTED_METRIC"),
    ("商品卡", "READY", "整体+快照；来源 SOURCE_NOT_AVAILABLE"), ("投放", "READY", "计划级 SOURCE_NOT_AVAILABLE"),
    ("退款", "READY", "原因 SOURCE_NOT_AVAILABLE"), ("达人/账号", "READY", ""),
    ("直播", "READY", "场次/日数据；分钟级 SOURCE_NOT_AVAILABLE"), ("短视频", "READY", "快照；单视频日趋势不提供"),
    ("搜索", "SOURCE_NOT_AVAILABLE", "无源文件"), ("素材", "READY", "快照排名"),
    ("智能经营", "READY", "STALE 提示"), ("风险中心", "READY", "完整 Anomaly"),
    ("问题诊断", "READY", "平台级"), ("增长机会", "READY", "完整列表"),
]
with (BASE / "F1.0.4_capability_state_audit.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["page", "capability_state", "notes"])
    w.writerows(states)
print("capability_state:", len(states))

# ===== 5) Network Route API Matrix =====
network = [
    ("/today", "summary+trend+compare+risks+opps+contribution", "6", "DAILY_FACT"),
    ("/store", "shop-contribution", "1", "DAILY_FACT"),
    ("/priorities", "risks+opportunities+intelligence-status", "3", "PERIOD_SNAPSHOT"),
    ("/product-lines", "master-data/product-lines+members+product-lines/summary", "3", "DAILY_FACT"),
    ("/master-products", "master-products/rank+master-data/products", "2", "DAILY_FACT"),
    ("/products", "business/products/top", "1", "DAILY_FACT"),
    ("/product-card", "summary+trend+snapshot-summary+snapshot-rank", "4", "DAILY_FACT+PERIOD_SNAPSHOT"),
    ("/advertising", "advertising/summary", "1", "DAILY_FACT"),
    ("/refunds", "business/summary", "1", "DAILY_FACT"),
    ("/accounts", "accounts/top", "1", "DAILY_FACT"),
    ("/live", "summary+trend+live/sessions+live/daily", "4", "DAILY_FACT+SESSION_FACT"),
    ("/videos", "summary+trend+video/snapshot-summary+snapshot-rank", "4", "DAILY_FACT+PERIOD_SNAPSHOT"),
    ("/search", "无(SOURCE_NOT_AVAILABLE)", "0", "-"),
    ("/materials", "materials/snapshot-rank", "1", "PERIOD_SNAPSHOT"),
    ("/smart-operation", "risks+opportunities+intelligence-status", "3", "PERIOD_SNAPSHOT"),
    ("/risks", "risks/complete+intelligence-status", "2", "EVENT"),
    ("/diagnostics", "diagnostics/results", "1", "EVENT"),
    ("/opportunities", "opportunities/complete+intelligence-status", "2", "EVENT"),
]
with (BASE / "F1.0.4_network_route_api_matrix.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["route", "network_requests", "requests_per_page", "time_semantics"])
    w.writerows(network)
print("network_route:", len(network))
