# Source Profile: product_card_traffic

| 项 | 值 |
|---|---|
| file | 商品卡流量分析流量来源数据_2026_06_30~2026_07_06.xlsx |
| sheets | sheet1 |
| shop | 弹动官方旗舰店 |
| platform | douyin |
| headers | ['一级渠道', '二级渠道', '商品卡曝光人数', '商品卡点击人数', '商品卡点击率', '用户支付金额(元)', '成交人数', '成交客单价(元)', '点击-成交转化率'] |
| null_ratio | 低 |
| unique_values | 渠道组合 25 |
| min_date | 2026-06-30 |
| max_date | 2026-07-06 |
| dup_key_candidate | period+channel_l1+channel_l2 |
| total_structure | 无TOTAL行 |
| time_semantics | PERIOD_SNAPSHOT |
| ratio_fields | ['商品卡点击率', '点击-成交转化率'] |
| id_fields | ['一级渠道'] |
| parent_child | 一级→二级 |
| cumulative | 区间累计快照 |