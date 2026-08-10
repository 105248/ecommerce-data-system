# V1.1 Stage1 诊断域支持矩阵（diagnostic_domain_support_matrix）

> 来源：`mart.diagnostic_entity_rule` + `mart.get_diagnostic_entity_metrics(domain)`。
> 指标支持按各 core 表实际字段能力限定。

## 一、域注册

| domain_key | 中文 | 启用 | 对象唯一标识 | 展示名称 | 支持排名 | 支持贡献 | 支持Scope | 底层来源 |
|---|---|---|---|---|---|---|---|---|
| shop | 店铺整体 | ✅ | shop_id | shop_name | - | - | - | core.douyin_deal_daily |
| scope | 经营Scope | ✅ | scope_key | scope | - | ✅ | ✅ | core.douyin_deal_daily |
| product | 商品 | ✅ | product_id | product_name | ✅ | ✅ | - | core.douyin_product_daily |
| carrier | 载体 | ✅ | (sale_scope, carrier_type) | carrier_type | ✅ | - | ✅ | core.douyin_carrier_daily |
| account | 账号 | ✅ | (sale_scope, account_name) | account_name | ✅ | ✅ | ✅ | core.douyin_account_daily |
| category | 类目 | ✅ | category_level_3 | category_level_3 | ✅ | ✅ | - | core.douyin_category_daily |
| product_line | 品线 | ❌ | - | - | - | - | - | unavailable（V1.0.2 未通过） |

## 二、域-指标支持矩阵

| metric_key | shop | scope | carrier | account | product | category |
|---|---|---|---|---|---|---|
| user_pay_amount | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| transaction_amount | ✅ | ✅ | ✅ | ✅ | - | - |
| settlement_amount | ✅ | ✅ | ✅ | ✅ | - | - |
| transaction_order_count | ✅ | ✅ | ✅ | ✅ | - | - |
| transaction_buyer_count | ✅ | ✅ | ✅ | ✅ | - | - |
| transaction_item_count | ✅ | ✅ | ✅ | ✅ | - | - |
| avg_customer_amount | ✅ | ✅ | ✅ | ✅ | - | - |
| avg_item_amount | ✅ | ✅ | ✅ | ✅ | - | - |
| product_exposure_user_count | ✅ | ✅ | ✅ | ✅ | - | - |
| product_click_user_count | ✅ | ✅ | ✅ | ✅ | - | - |
| exposure_to_click_rate_users | ✅ | ✅ | ✅ | ✅ | - | - |
| click_to_transaction_rate_users | ✅ | ✅ | ✅ | ✅ | - | - |
| exposure_to_transaction_rate_users | ✅ | ✅ | ✅ | ✅ | - | - |
| product_exposure_count | ✅ | ✅ | ✅ | ✅ | - | - |
| product_click_count | ✅ | ✅ | ✅ | ✅ | - | - |
| exposure_to_click_rate_events | ✅ | ✅ | ✅ | ✅ | - | - |
| click_to_transaction_rate_events | ✅ | ✅ | ✅ | ✅ | - | - |
| exposure_to_transaction_rate_events | ✅ | ✅ | ✅ | ✅ | - | - |
| transaction_refund_amount_pay_time | ✅ | ✅ | ✅ | ✅ | - | - |
| refund_amount_pay_time | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| refund_rate_pay_time | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| ad_spend_shop_promoted | ✅ | ✅ | ✅ | ✅ | - | - |
| ad_spend_shop_bound | ✅ | ✅ | ✅ | ✅ | - | - |
| ad_attributed_transaction_amount | ✅ | ✅ | ✅ | ✅ | - | - |
| ad_attributed_transaction_share | ✅ | ✅ | ✅ | ✅ | - | - |
| ad_spend_rate_net_refund_shop_bound | ✅ | ✅ | ✅ | ✅ | - | - |
| total_expense_rate_net_refund_shop_bound | ✅ | ✅ | ✅ | ✅ | - | - |
| ad_efficiency_shop_promoted | ✅ | ✅ | - | - | - | - |
| ad_efficiency_shop_bound | ✅ | ✅ | - | - | - | - |
| store_efficiency_shop_promoted | ✅ | ✅ | - | - | - | - |
| store_efficiency_shop_bound | ✅ | ✅ | - | - | - | - |
| **指标数** | **31** | **31** | **27** | **27** | **3** | **3** |

## 三、排名/贡献能力（按白名单）

| domain | 排名指标（rank_allowed） | 贡献指标（contribution_allowed） |
|---|---|---|
| shop | - | - |
| scope | - | user_pay_amount / transaction_amount / refund_amount_pay_time |
| product | user_pay_amount / refund_amount_pay_time / refund_rate_pay_time | user_pay_amount / refund_amount_pay_time |
| carrier | user_pay_amount / transaction_amount / refund_amount_pay_time / refund_rate_pay_time | user_pay_amount / transaction_amount / refund_amount_pay_time |
| account | user_pay_amount / transaction_amount / transaction_order_count / transaction_buyer_count / avg_customer_amount / refund_amount_pay_time / refund_rate_pay_time | user_pay_amount / transaction_amount / refund_amount_pay_time |
| category | user_pay_amount / refund_amount_pay_time / refund_rate_pay_time | user_pay_amount / refund_amount_pay_time |

## 四、对象规模（真实数据）

| domain | 对象数 | 说明 |
|---|---|---|
| shop | 2 店 | 弹动官方旗舰店 / 抖音个人护理旗舰店（NULL=平台汇总） |
| scope | 18 | 全店/自营/合作/商品卡/短视频/直播/图文/其他 + 自营×/合作× 组合 |
| product | 商品（carrier=全部 独立 TOTAL） | 未指定对象时返回当前期 TOP100 |
| carrier | 10 | 自营/合作 × 5 载体 |
| account | 102 | 自营 1 + 合作 101（含"更多账号"聚合桶） |
| category | L3 类目 | 默认 L3 粒度（排除"全部"父级占位） |

## 五、快照返回行数（单对象示例）

- shop 域单对象：31 行（31 指标）
- product 域 TOP100：300 行（100 × 3）
- carrier 域自营：135 行（5 载体 × 27 指标）
- account 域合作：2727 行（101 × 27，含更多账号）
