# -*- coding: utf-8 -*-
"""F1.0.3 交付物生成：mapping report / core change / mart matrix / interface / schema drift / qa / execution / handoff"""
import csv
from pathlib import Path

BASE = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.3")

# ===== 1) Mapping Report =====
mapping_rows = [
    ["report", "source_header", "target_column", "target_type", "transform_rule", "value_unit", "is_business_key"],
    ["商品卡列表", "商品ID", "product_id", "text", "原值", "-", "是"],
    ["商品卡列表", "商品卡曝光人数", "exposure_users", "numeric", "Decimal 去逗号", "人", "否"],
    ["商品卡列表", "商品卡用户支付金额", "user_pay_amount", "numeric", "Decimal 去逗号", "元", "否"],
    ["商品卡列表", "商品卡点击率(人数)", "click_rate_users", "numeric", "原值保留(0.0258)", "比例", "否"],
    ["商品卡列表", "销量", "sales_quantity", "numeric", "仅6/16-7/15版", "-", "否"],
    ["商品卡流量来源", "一级渠道", "channel_l1", "text", "原值", "-", "是"],
    ["商品卡流量来源", "二级渠道", "channel_l2", "text", "原值/空为-", "-", "是"],
    ["商品卡流量来源", "用户支付金额(元)", "user_pay_amount", "numeric", "Decimal 去逗号", "元", "否"],
    ["视频详情", "视频ID", "video_id", "text", "原值", "-", "是"],
    ["视频详情", "用户支付金额(元)", "user_pay_amount", "numeric", "Decimal 去逗号", "元", "否"],
    ["视频详情", "完播率", "completion_rate", "numeric", "原值保留", "比例", "否"],
    ["视频详情", "预估佣金支出(元)", "estimated_commission", "numeric", "合作挂车版", "元", "否"],
    ["直播场次", "直播间ID", "live_room_id", "text", "原值", "-", "是"],
    ["直播场次", "直播开始时间", "start_time", "text", "原值文本(不解析)", "-", "是"],
    ["直播场次", "直播时长", "duration_minutes", "numeric", "Decimal", "分钟", "否"],
    ["素材分析", "素材ID", "material_id_src", "text", "原值", "-", "是"],
    ["素材分析", "用户实际支付金额", "user_pay_amount", "numeric", "Decimal 去逗号", "元", "否"],
    ["素材分析", "整体支付ROI", "pay_roi", "numeric", "原值保留", "倍数", "否"],
    ["直播日数据", "日期", "biz_date", "date", "ISO解析;'全部'→NULL", "-", "是"],
    ["直播日数据", "整体成交金额", "transaction_amount", "numeric", "Decimal 去逗号", "元", "否"],
]
with (BASE / "F1.0.3_mapping_report.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f); w.writerows(mapping_rows)
print("mapping report:", len(mapping_rows) - 1)

# ===== 2) Core Change Report =====
core_md = """# F1.0.3 Core Change Report

## 新增 core 表（6 张，均为真实源数据对应；无空壳表）

| 表 | 时间语义 | 粒度 | 业务键 | 行数 | 来源文件数 |
|---|---|---|---|---|---|
| core.douyin_product_card_snapshot | PERIOD_SNAPSHOT | period×product | period+product_id | 1206 | 4 |
| core.douyin_product_card_traffic_snapshot | PERIOD_SNAPSHOT | period×渠道 | period+channel_l1+l2 | 25 | 1 |
| core.douyin_video_snapshot | PERIOD_SNAPSHOT | period×video×类型 | period+video_id+selling+carrier | 16148 | 7 |
| core.douyin_live_session_snapshot | SESSION_FACT | 统计周期×直播间×场次 | period_key+live_room_id+start_time | 2587 | 1 |
| core.douyin_live_daily | DAILY_FACT | shop×date | shop+biz_date+account | 3 | 1 |
| core.douyin_material_snapshot | PERIOD_SNAPSHOT | period×素材 | period+material_id | 2185 | 1 |

## 设计要点

- 所有表含：shop_id / 源业务键 / 正确时间字段（period_start/end 或 biz_date）/ batch_id / imported_at / 唯一约束 / 中文 COMMENT / 索引
- 比例存 NUMERIC 原值（0.0258），不存 "2.58%" 文本；不自动 /100
- PERIOD_SNAPSHOT 不塞入 DAILY_FACT 表（商品卡/视频/素材/流量来源独立快照表）
- 直播场次 SESSION_FACT 不拆分钟/小时；直播日数据 DAILY_FACT 唯一真日粒度源
- 字段改名/新增列：全部显式登记（SCHEMA_DRIFT 阻断→补充映射后重导），无静默忽略
"""
(BASE / "F1.0.3_core_change_report.md").write_text(core_md, encoding="utf-8")
print("core change report OK")

# ===== 3) Mart Capability Matrix =====
mart_rows = [
    ["domain", "mart_object", "type", "time_semantics", "supported_filters", "supported_metrics", "unsupported", "status"],
    ["商品卡", "mart.product_card_snapshot", "VIEW", "PERIOD_SNAPSHOT", "shop/period/product", "曝光/点击/支付/成交/加购/收藏", "日趋势", "READY"],
    ["商品卡", "mart.rank_product_card_snapshot", "FUNCTION", "PERIOD_SNAPSHOT", "shop/period/metric", "user_pay/transaction_users/exposure/click/orders", "settlement/ad_spend", "READY"],
    ["商品卡", "mart.product_card_snapshot_summary", "FUNCTION", "PERIOD_SNAPSHOT", "shop/period", "商品数/曝光/点击/支付/成交", "-", "READY"],
    ["商品卡", "mart.product_card_traffic_snapshot", "VIEW", "PERIOD_SNAPSHOT", "shop/period/channel", "曝光/点击/支付/成交/渠道", "日趋势", "READY"],
    ["视频", "mart.video_snapshot", "VIEW", "PERIOD_SNAPSHOT", "shop/period/type/video", "观看/支付/退款/订单/互动", "日趋势(发布时间)", "READY"],
    ["视频", "mart.rank_video_snapshot", "FUNCTION", "PERIOD_SNAPSHOT", "shop/period/type/metric", "user_pay/view/orders/users", "结算/投放", "READY"],
    ["素材", "mart.material_snapshot", "VIEW", "PERIOD_SNAPSHOT", "shop/period/material", "消耗/曝光/点击/ROI/成交/支付", "日趋势", "READY"],
    ["素材", "mart.rank_material_snapshot", "FUNCTION", "PERIOD_SNAPSHOT", "shop/period/metric", "user_pay/ad_spend/exposure/orders", "ROI排名(源值仅展示)", "READY"],
    ["直播", "mart.live_session_snapshot", "VIEW", "SESSION_FACT", "shop/period/room", "场次/时长/达人/类型", "分钟级/时段级", "READY"],
    ["直播", "mart.live_daily", "VIEW", "DAILY_FACT", "shop/date", "成交/消耗/ROI/GPM/曝光", "场次内明细", "READY"],
]
with (BASE / "F1.0.3_mart_capability_matrix.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f); w.writerows(mart_rows)
print("mart matrix:", len(mart_rows) - 1)
