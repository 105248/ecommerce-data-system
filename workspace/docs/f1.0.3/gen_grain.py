# -*- coding: utf-8 -*-
"""F1.0.3 grain/key matrix：17 文件 → 6 类报表 → 粒度/业务键/时间语义判定"""
import csv
from pathlib import Path

rows = [
    # report, time_semantics, grain, business_key, parent_total_rule, additive_dims, non_additive, dedupe_rule, overlap_rule, status
    ["商品卡列表", "PERIOD_SNAPSHOT", "period × product",
     "period_start+period_end+shop+product_id",
     "无TOTAL行(每行=商品)", "product(商品维度可加)", "CTR/转化率/占比(比例非加总)",
     "同 period+product_id 唯一(商品ID 272唯一)",
     "同区间同店同商品ID replace;不同区间共存",
     "READY_TO_ONBOARD"],
    ["商品卡流量来源", "PERIOD_SNAPSHOT", "period × 渠道",
     "period_start+period_end+shop+一级渠道+二级渠道",
     "渠道TOTAL行存在与否待核(25行小表)", "渠道(曝光/点击/支付可加)", "CTR/占比(比例)",
     "同 period+渠道 唯一",
     "同区间同渠道 replace",
     "READY_TO_ONBOARD"],
    ["视频详情-自营挂车", "PERIOD_SNAPSHOT", "period × video",
     "period_start+period_end+shop+selling_type+carrier_type+video_id",
     "无TOTAL(每行=视频)", "video(观看/支付/退款可加)", "完播率/CTR(比例)",
     "同 period+video_id 唯一",
     "同区间同视频ID replace(四类分表分别存)",
     "READY_TO_ONBOARD"],
    ["视频详情-自营非挂车", "PERIOD_SNAPSHOT", "period × video", "同上+非挂车",
     "无TOTAL", "video", "比例", "同 period+video_id 唯一", "同区间 replace", "READY_TO_ONBOARD"],
    ["视频详情-合作挂车", "PERIOD_SNAPSHOT", "period × video", "同上+合作挂车",
     "无TOTAL", "video", "比例", "同 period+video_id 唯一", "同区间 replace", "READY_TO_ONBOARD"],
    ["视频详情-合作非挂车", "PERIOD_SNAPSHOT", "period × video", "同上+合作非挂车",
     "无TOTAL", "video", "比例", "同 period+video_id 唯一", "同区间 replace", "READY_TO_ONBOARD"],
    ["直播场次(修正报表)", "SESSION_FACT", "session(场次)",
     "统计周期+直播间ID+开始时间(场次键)",
     "无TOTAL(每行=场次)", "场次维度可加", "直播时长(分钟,可加但非经营金额)", "直播间ID+开始时间唯一(2587唯一)",
     "同 session key upsert(replace);场次跨天不重复",
     "READY_TO_ONBOARD"],
    ["直播分析(店铺级)", "PERIOD_SNAPSHOT", "period × shop",
     "period+shop", "无TOTAL(每行=店铺)", "-", "ROI/退款率(比例)", "同 period+shop 唯一", "同区间 replace", "PARTIAL(仅店铺级汇总,无场次明细)"],
    ["素材分析", "PERIOD_SNAPSHOT", "period × material",
     "period_start+period_end+shop+素材ID",
     "无TOTAL(每行=素材)", "material(消耗/成交可加)", "ROI/CTR(比例)", "同 period+素材ID 唯一",
     "同区间 replace", "READY_TO_ONBOARD"],
]

out = Path(r"D:/ecommerce-data-system/workspace/docs/f1.0.3/F1.0.3_grain_key_matrix.csv")
with out.open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["report", "time_semantics", "grain", "business_key", "parent_total_rule",
                "additive_dimensions", "non_additive_dimensions", "dedupe_rule", "overlap_rule", "status"])
    w.writerows(rows)
print("grain/key matrix: {} 类".format(len(rows)))
