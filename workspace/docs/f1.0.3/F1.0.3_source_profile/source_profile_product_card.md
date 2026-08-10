# Source Profile: product_card

| 项 | 值 |
|---|---|
| file | 商品卡列表数据_2026_05/06月 + 6/16-7/15 + 6/30-7/6 (4文件) |
| sheets | sheet1 |
| shop | 弹动官方旗舰店 |
| platform | douyin |
| headers | ['商品ID', '商品卡曝光人数', '商品卡点击人数', '商品卡点击率(人数)', '商品卡用户支付金额', '商品卡成交人数', '商品卡成交客单价', '商品卡点击-成交转化率(人数)', '商品卡加购人数', '商品卡收藏人数', '商品卡成交订单数'] |
| null_ratio | 低(<5%) |
| unique_values | 商品ID 272~598/文件 |
| min_date | 2026-05-01 |
| max_date | 2026-07-15 |
| dup_key_candidate | period+product_id |
| total_structure | 无TOTAL行(每行=商品) |
| time_semantics | PERIOD_SNAPSHOT |
| ratio_fields | ['商品卡点击率(人数)', '商品卡点击-成交转化率(人数)'] |
| id_fields | ['商品ID'] |
| parent_child | 无 |
| cumulative | 区间累计快照 |