# V1.1 Stage1 诊断指标目录（diagnostic_metric_catalog）

> 来源：`mart.diagnostic_metric_rule`（31 条，全部 `diagnostic_enabled=true`）。
> `source_rule_reference`：`mfr_*` = 引用 `meta.metric_formula_rule` 同名指标跨期公式；`direct_sum` = 纯 SUM 字段。

## 一、成交类（8）

| metric_key | 中文 | type | display | 越高越好 | 支持百分点 | 支持排名 | 支持贡献 |
|---|---|---|---|---|---|---|---|
| user_pay_amount | 用户支付金额 | amount | 金额 | ✅ | - | ✅ | ✅ |
| transaction_amount | 成交金额 | amount | 金额 | ✅ | - | ✅ | ✅ |
| settlement_amount | 结算金额 | amount | 金额 | ✅ | - | ✅ | - |
| transaction_order_count | 成交订单数 | count | 整数 | ✅ | - | ✅ | - |
| transaction_buyer_count | 成交人数 | count | 整数 | ✅ | - | ✅ | - |
| transaction_item_count | 成交件数 | count | 整数 | ✅ | - | ✅ | - |
| avg_customer_amount | 客单价 | average | 0.00 | ✅ | - | ✅ | - |
| avg_item_amount | 件单价 | average | 0.00 | ✅ | - | ✅ | - |

## 二、流量/漏斗类（10）

| metric_key | 中文 | type | display | 越高越好 | 支持百分点 | 支持排名 | 支持贡献 |
|---|---|---|---|---|---|---|---|
| product_exposure_user_count | 商品曝光人数 | count | 整数 | ✅ | - | - | - |
| product_click_user_count | 商品点击人数 | count | 整数 | ✅ | - | - | - |
| exposure_to_click_rate_users | 商品曝光-点击转化率(人数) | ratio | 0.00% | ✅ | ✅ | ✅ | - |
| click_to_transaction_rate_users | 商品点击-成交转化率(人数) | ratio | 0.00% | ✅ | ✅ | ✅ | - |
| exposure_to_transaction_rate_users | 商品曝光-成交转化率(人数) | ratio | 0.00% | ✅ | ✅ | - | - |
| product_exposure_count | 商品曝光次数 | count | 整数 | ✅ | - | - | - |
| product_click_count | 商品点击次数 | count | 整数 | ✅ | - | - | - |
| exposure_to_click_rate_events | 商品曝光-点击转化率(次数) | ratio | 0.00% | ✅ | ✅ | - | - |
| click_to_transaction_rate_events | 商品点击-成交转化率(次数) | ratio | 0.00% | ✅ | ✅ | - | - |
| exposure_to_transaction_rate_events | 商品曝光-成交转化率(次数) | ratio | 0.00% | ✅ | ✅ | - | - |

## 三、售后类（3）

| metric_key | 中文 | type | display | 越高越好 | 支持百分点 | 支持排名 | 支持贡献 |
|---|---|---|---|---|---|---|---|
| transaction_refund_amount_pay_time | 成交退款金额(支付时间) | amount | 金额 | ❌ | - | - | - |
| refund_amount_pay_time | 退款金额(支付时间) | amount | 金额 | ❌ | - | ✅ | ✅ |
| refund_rate_pay_time | 退款率(支付时间) | ratio | 0.00% | ❌ | ✅ | ✅ | - |

## 四、投放类（10）

| metric_key | 中文 | type | display | 越高越好 | 支持百分点 | 支持排名 | 支持贡献 |
|---|---|---|---|---|---|---|---|
| ad_spend_shop_promoted | 投放消耗(店铺被投) | amount | 金额 | ❌ | - | - | - |
| ad_spend_shop_bound | 投放消耗(店铺绑定) | amount | 金额 | ❌ | - | - | - |
| ad_attributed_transaction_amount | 投放贡献成交金额 | amount | 金额 | ✅ | - | - | - |
| ad_attributed_transaction_share | 投放贡献成交占比 | ratio | 0.00% | ✅ | ✅ | - | - |
| ad_spend_rate_net_refund_shop_bound | 投放费比(剔除退款、店铺绑定) | ratio | 0.00% | ❌ | ✅ | - | - |
| total_expense_rate_net_refund_shop_bound | 综合费比(剔除退款、店铺绑定) | ratio | 0.00% | ❌ | ✅ | - | - |
| ad_efficiency_shop_promoted | 投放效率(店铺被投) | efficiency | 0.00 | ✅ | - | - | - |
| ad_efficiency_shop_bound | 投放效率(店铺绑定) | efficiency | 0.00 | ✅ | - | - | - |
| store_efficiency_shop_promoted | 全店效率(店铺被投) | efficiency | 0.00 | ✅ | - | - | - |
| store_efficiency_shop_bound | 全店效率(店铺绑定) | efficiency | 0.00 | ✅ | - | - | - |

## 五、排除说明

- **source_only 指标不进入首批诊断**（`diagnostic_enabled=false`，未注册）：两日内发货率、发货前退款率、未收货退款率、已收货退款率、已收货退货退款率、1 小时退款率等——多日不可精确重算，禁止 AVG 日比例。
- `supports_percentage_point` 仅 ratio 类型；效率指标 `percentage_point_change=NULL`（文档 12.3）。
