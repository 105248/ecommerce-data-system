# V1.3 Stage2 抖音多店指标规则（douyin_multishop_metric_rules）

> 平台整体 = enabled=true AND platform_code='douyin' 店铺的两店合法汇总（文档第五~十七节）。
> 平台整体只存在于 mart 查询语义，不建 shop_id=0 / 虚拟店铺。

## 一、可加指标（两店 SUM）

| 指标 | 平台规则 | 说明 |
|---|---|---|
| user_pay_amount / transaction_amount / settlement_amount / refund_amount_pay_time | 两店 SUM | 核心金额 |
| transaction_order_count / transaction_item_count | 两店 SUM | 计数 |
| transaction_buyer_count | 两店 SUM | **= sum_of_shop_transaction_users**，跨店不去重，不得伪称"全抖音唯一成交人数" |
| ad_spend_shop_promoted / ad_spend_shop_bound | 两店 SUM | 投放消耗 |
| ad_attributed_transaction_amount | 两店 SUM | 投放贡献 |

## 二、跨店比例重算（禁止 AVG）

| 指标 | 平台公式 | 验证（真实数据） |
|---|---|---|
| 退款率 | SUM(两店 refund_amount_pay_time) / SUM(两店 user_pay_amount) | 30天全店：平台 19.06% vs AVG两店 21.62% |
| 投放费比(剔除退款、绑定) | SUM(ad_spend_shop_bound) / SUM(settlement_amount) | 30天 41.32%（非 AVG） |
| 投放贡献成交占比 | SUM(ad_attributed_transaction_amount) / SUM(transaction_amount) | 30天 95.47% |
| 综合费比(剔除退款、绑定) | SUM(费率×结算) / SUM(结算)（weighted_source_ratio） | 30天 45.74% |
| 投放效率/全店效率（4 个） | SUM(效率×消耗) / SUM(消耗)（加权） | 30天 投放效率 2.3661 |
| CTR/CVR 类 | SUM(分子) / SUM(分母) | 平台级重算 |

## 三、验证证明（比例 ≠ 简单 AVG，6 案例）

| 区间 | Scope | 平台退款率 | AVG两店退款率 | 差 |
|---|---|---|---|---|
| 06-01~30 | 全店 | 19.06% | 21.62% | 2.56pp |
| 06-01~30 | 商品卡 | 19.95% | 26.45% | 6.51pp |
| 06-01~30 | 直播 | 17.89% | 19.24% | 1.34pp |
| 06-24~30 | 全店 | 18.73% | 23.13% | 4.40pp |
| 06-24~30 | 商品卡 | 18.93% | 25.55% | 6.61pp |
| 06-24~30 | 直播 | 17.94% | 20.69% | 2.75pp |

平台结果全部为"汇总分子/汇总分母"，与简单 AVG 存在显著差异，证明未做 AVG。

## 四、18 Scope 平台汇总

全店/自营/合作/商品卡/短视频/直播/图文/其他 + 自营×/合作× 组合，全部支持平台级（同 Scope 跨 enabled 店铺按合法指标规则汇总）。实测 8 个主要 Scope 通过（全店/自营/合作/商品卡/直播/短视频/图文/其他）。

## 五、商品级限制（文档 25/26/53 节）

- **禁止跨店同名商品合并**（不得 GROUP BY product_name）；同名商品在两店是两个对象（"官方店｜商品" vs "个人护理店｜商品"）。
- 平台商品排名/贡献保持"店铺+店内商品"对象语义；跨店商品主数据统一属 Stage3（master_product/master_sku）。
