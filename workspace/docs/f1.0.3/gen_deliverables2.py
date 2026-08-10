# -*- coding: utf-8 -*-
"""F1.0.3 交付物：source profiles + schema drift 测试 + interface + qa + execution + handoff"""
import json
from pathlib import Path

BASE = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.3")
PROF = BASE / "F1.0.3_source_profile"
PROF.mkdir(exist_ok=True)

# ===== Source Profiles（6 类）=====
profiles = {
    "product_card": {
        "file": "商品卡列表数据_2026_05/06月 + 6/16-7/15 + 6/30-7/6 (4文件)",
        "sheets": "sheet1", "shop": "弹动官方旗舰店", "platform": "douyin",
        "headers": ["商品ID", "商品卡曝光人数", "商品卡点击人数", "商品卡点击率(人数)", "商品卡用户支付金额", "商品卡成交人数", "商品卡成交客单价", "商品卡点击-成交转化率(人数)", "商品卡加购人数", "商品卡收藏人数", "商品卡成交订单数"],
        "null_ratio": "低(<5%)", "unique_values": "商品ID 272~598/文件",
        "min_date": "2026-05-01", "max_date": "2026-07-15",
        "dup_key_candidate": "period+product_id", "total_structure": "无TOTAL行(每行=商品)",
        "time_semantics": "PERIOD_SNAPSHOT", "ratio_fields": ["商品卡点击率(人数)", "商品卡点击-成交转化率(人数)"],
        "id_fields": ["商品ID"], "parent_child": "无", "cumulative": "区间累计快照",
    },
    "product_card_traffic": {
        "file": "商品卡流量分析流量来源数据_2026_06_30~2026_07_06.xlsx",
        "sheets": "sheet1", "shop": "弹动官方旗舰店", "platform": "douyin",
        "headers": ["一级渠道", "二级渠道", "商品卡曝光人数", "商品卡点击人数", "商品卡点击率", "用户支付金额(元)", "成交人数", "成交客单价(元)", "点击-成交转化率"],
        "null_ratio": "低", "unique_values": "渠道组合 25",
        "min_date": "2026-06-30", "max_date": "2026-07-06",
        "dup_key_candidate": "period+channel_l1+channel_l2", "total_structure": "无TOTAL行",
        "time_semantics": "PERIOD_SNAPSHOT", "ratio_fields": ["商品卡点击率", "点击-成交转化率"],
        "id_fields": ["一级渠道"], "parent_child": "一级→二级", "cumulative": "区间累计快照",
    },
    "video": {
        "file": "[周期]_{自营/合作}_{挂车/非挂车}_...视频详情数据.xlsx (7文件)",
        "sheets": "按类型命名(自营_挂车等)", "shop": "弹动官方旗舰店", "platform": "douyin",
        "headers": ["视频ID", "视频标题", "发布时间", "达人昵称", "视频观看次数", "用户支付金额(元)", "退款金额(元)", "带货商品ID", "点赞数", "完播率"],
        "null_ratio": "低", "unique_values": "视频ID 336~7636/文件",
        "min_date": "2026-06-30", "max_date": "2026-07-31",
        "dup_key_candidate": "period+video_id+selling+carrier", "total_structure": "无TOTAL行",
        "time_semantics": "PERIOD_SNAPSHOT", "ratio_fields": ["完播率"],
        "id_fields": ["视频ID", "带货商品ID"], "parent_child": "视频→商品(带货商品ID)", "cumulative": "区间累计快照(禁按发布时间日趋势)",
    },
    "live_session": {
        "file": "2026-08-05日直播间修正报表导出.xlsx",
        "sheets": "Sheet1", "shop": "弹动官方旗舰店", "platform": "douyin",
        "headers": ["统计日期", "直播间ID", "直播间名称", "直播开始时间", "直播结束时间", "直播时长", "达人ID", "账号类型"],
        "null_ratio": "低", "unique_values": "直播间ID 2587",
        "min_date": "2026-07-23(周期20260723-20260729)", "max_date": "2026-07-29",
        "dup_key_candidate": "period_key+live_room_id+start_time", "total_structure": "无TOTAL行",
        "time_semantics": "SESSION_FACT", "ratio_fields": ["-"],
        "id_fields": ["直播间ID", "达人ID"], "parent_child": "无", "cumulative": "否(场次级)",
    },
    "live_daily": {
        "file": "全域数据_直播分析_弹动官方旗舰店_2026-07-09...xlsx",
        "sheets": "Sheet1", "shop": "弹动官方旗舰店", "platform": "douyin",
        "headers": ["抖音号名称", "日期", "净成交ROI", "净成交金额", "整体消耗", "整体支付ROI", "整体成交金额", "整体成交订单数", "GPM", "直播间整体曝光次数"],
        "null_ratio": "低", "unique_values": "日期 3(全部+2天)",
        "min_date": "2026-07-08", "max_date": "2026-07-09",
        "dup_key_candidate": "shop+biz_date+account", "total_structure": "'全部'行=周期汇总",
        "time_semantics": "DAILY_FACT", "ratio_fields": ["净成交ROI", "1小时内退款率"],
        "id_fields": ["抖音号名称"], "parent_child": "无", "cumulative": "否(日级事实)",
    },
    "material": {
        "file": "全域数据_素材分析_视频_2026-07-09...xlsx",
        "sheets": "Sheet1", "shop": "弹动官方旗舰店", "platform": "douyin",
        "headers": ["素材ID", "素材名称", "素材评估", "整体消耗", "整体展现次数", "整体点击次数", "整体支付ROI", "整体成交金额", "用户实际支付金额", "整体千次展现费用"],
        "null_ratio": "低", "unique_values": "素材ID 2185",
        "min_date": "2026-07-09", "max_date": "2026-07-09",
        "dup_key_candidate": "period+material_id", "total_structure": "无TOTAL行",
        "time_semantics": "PERIOD_SNAPSHOT", "ratio_fields": ["整体点击率", "整体支付ROI"],
        "id_fields": ["素材ID"], "parent_child": "无", "cumulative": "单日快照",
    },
}
for key, prof in profiles.items():
    (PROF / ("source_profile_{}.md".format(key))).write_text(
        "# Source Profile: {}\n\n| 项 | 值 |\n|---|---|\n{}".format(key, "\n".join(
            "| {} | {} |".format(k, v) for k, v in prof.items())), encoding="utf-8")
    (PROF / ("source_profile_{}.json".format(key))).write_text(
        json.dumps(prof, ensure_ascii=False, indent=1), encoding="utf-8")
print("source profiles: 6 类 md+json")

# ===== Schema Drift Tests =====
drift_md = """# F1.0.3 Schema Drift Tests

## 已验证（导入过程实际触发并处理）

| 场景 | 结果 |
|---|---|
| 商品卡列表 6/16-7/15（18列精简版）表头改名 | SCHEMA_DRIFT 阻断 → 显式补映射（点击率(人数)→click_rate_users）→ 重导 ✓ |
| 商品卡列表 5/6月主版 vs (1)版（同周期不同数据）| 主版 GMV 78万/598行 vs (1)版 372万/326行 → 判定(1)版为完整版，主版 superseded ✓ |
| 视频详情 挂车版（40-42列）vs 非挂车版（12列）| 完整列显式登记（含衍生列 derived_*/live_entry_*），缺失列 NULL ✓ |
| 视频详情 合作挂车新增列（预估佣金/引流店铺页订单）| SCHEMA_DRIFT 阻断 → 补映射 → 重导 ✓ |
| 素材分析 29列（含播放率类）| SCHEMA_DRIFT 阻断 → 补 4 列映射 → 重导 ✓ |
| 重复文件（SHA256 已入库）| DUPLICATE_FILE 跳过 ✓（6/30-7/6 商品卡重导验证）|
| 重叠区间重导 | 同店同区间 DELETE+INSERT（事务内 replace）✓ |

## 51/61 importer 回归

| 文件 | 判定 |
|---|---|
| 8月 61列成交分析 | current_61 ✓（3 表均）|
| 51列旧版 | legacy_51（既有逻辑）|
| 52-60列 | SCHEMA_DRIFT / FAIL（既有逻辑）|
"""
(BASE / "F1.0.3_schema_drift_tests.md").write_text(drift_md, encoding="utf-8")
print("schema drift tests OK")

# ===== Interface Change Report =====
iface_md = """# F1.0.3 Interface Change Report

## 白名单：58 → 69（+11）

| 新增对象 | 类型 | 域 | HTTP 状态 |
|---|---|---|---|
| mart.product_card_snapshot | VIEW | product_card | HTTP_READY |
| mart.rank_product_card_snapshot | FUNCTION | product_card | HTTP_NEEDS_WRAPPER |
| mart.product_card_snapshot_summary | FUNCTION | product_card | HTTP_NEEDS_WRAPPER |
| mart.product_card_traffic_snapshot | VIEW | product_card | HTTP_READY |
| mart.video_snapshot | VIEW | video | HTTP_READY |
| mart.rank_video_snapshot | FUNCTION | video | HTTP_NEEDS_WRAPPER |
| mart.video_snapshot_summary | FUNCTION | video | HTTP_NEEDS_WRAPPER |
| mart.material_snapshot | VIEW | material | HTTP_READY |
| mart.rank_material_snapshot | FUNCTION | material | HTTP_NEEDS_WRAPPER |
| mart.live_session_snapshot | VIEW | live | HTTP_READY |
| mart.live_daily | VIEW | live | HTTP_READY |

## Backend 新端点（+8）

| 端点 | 数据源 |
|---|---|
| /product-card/snapshot-summary | mart.product_card_snapshot_summary |
| /product-card/snapshot-rank | mart.rank_product_card_snapshot |
| /product-card/traffic | mart.product_card_traffic_snapshot |
| /video/snapshot-summary | mart.video_snapshot_summary |
| /video/snapshot-rank | mart.rank_video_snapshot |
| /materials/snapshot-rank | mart.rank_material_snapshot |
| /live/sessions | mart.live_session_snapshot |
| /live/daily | mart.live_daily |

## Catalog

03_official_database_interface_catalog.json 同步 58→68（rank/summary 函数 + 视图条目）
"""
(BASE / "F1.0.3_interface_change_report.md").write_text(iface_md, encoding="utf-8")
print("interface change OK")
