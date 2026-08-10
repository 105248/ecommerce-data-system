# Stage5 路由规则（routing_rules）

> 自然语言 → 意图识别 → Tool 选择。V1.0 与 Stage4 MCP 工具一一对应。

## 1. 路由总表

| 意图 | 关键词 | Tool | 关键参数 |
|---|---|---|---|
| 店铺列表 | 有哪些店、几家店 | list_shops | - |
| 数据覆盖 | 数据到什么时候、覆盖、有没有数据 | get_data_coverage | shop_name |
| 指标目录 | 指标怎么算、公式、指标列表 | get_metric_catalog | domain_key(可选) |
| 导入历史 | 导入、批次、最近导入 | get_import_history | limit |
| 经营总览 | 全店/自营/合作/商品卡/短视频/直播/图文/其他 | get_business_summary | scope_key, dates, metric_key |
| 环比 | 环比、比前面、比之前、增长/下降多少 | compare_business | scope_key, dates, metric_key |
| 商品表现 | 商品+表现/成交/情况 | get_product_summary | product_id/name, carrier=全部 |
| 商品排名 | 商品+TOP/排名/增长最快/下降最大 | rank_products | sort_by/direction/limit |
| 商品贡献 | 商品+贡献/占比 | get_product_contribution | product_id/name |
| 账号表现 | 账号/达人+表现 | get_account_summary | sale_scope, account_name |
| 账号排名 | 账号+TOP/排名 | rank_accounts | sale_scope, include_aggregate_bucket=false |
| 账号贡献 | 账号+占比/贡献 | get_account_contribution | sale_scope |
| 类目表现 | 类目+表现 | get_category_summary | category_level=3 默认 |
| 类目排名 | 类目+TOP/排名 | rank_categories | category_level |
| 类目贡献 | 类目+占比/贡献 | get_category_contribution | category_level |
| 载体 | 载体/渠道 | get_carrier_summary / rank_carriers | sale_scope, carrier_type |
| 内容 | 内容/素材 | get_content_summary | selling_type, content_id |
| 终端 | 终端 | get_terminal_summary | terminal_type |
| 价格带 | 价格带 | get_price_band_summary / rank_price_bands | price_band |
| 人群 | 人群/首购/复购 | get_audience_summary / rank_audiences | carrier=全部 |

## 2. 意图优先级（歧义时）

1. 明确"环比/比之前/增长多少/下降多少" → compare_business
2. 明确"TOP/排名/增长最快/下降最大/排名变化" → rank_*
3. 明确"贡献/占比" → *_contribution
4. 明确"表现/成交/汇总/多少" → *_summary / get_business_summary
5. 仅"数据/覆盖/导入/指标" → 基础目录工具

## 3. 时间解析规则

| 用户说法 | 解析 |
|---|---|
| 最近N天 | get_data_coverage 取 max_date，往前 N-1 天（max_date 为结束日） |
| 今天/昨天 | 现实日期 → 查 coverage；无数据则明确说明 |
| 6月/3月等月份 | 唯一年份自动补全并注明；多年份追问 |
| 具体日期 | 直接使用 |
| 没有时间 | 默认取最新可用完整区间或 max_date 单日，并说明 |

## 4. 业务域默认值

- 店铺：唯一启用店铺自动使用
- metric：user_pay_amount（除非用户明确说退款率/客单价等）
- rank limit：10（上限100）
- 商品 carrier_type：全部
- 人群 carrier_type：全部
- 类目 category_level：3
- 账号 sale_scope：用户说"合作账号/达人"→合作；"自营账号"→自营；只说账号→按语境

## 5. 禁止路由

- 不提供任何 SQL 类工具调用路径
- 不为"为什么/原因"直接输出因果，只做数据拆分（最多5个工具）
- 不把"销售额/GMV"永久硬映射；按 user_pay_amount 口径回答时必须注明"按用户支付金额口径"

## 6. 多轮上下文继承

上一轮确定的时间/店铺/scope 在下一轮继承；只变化用户新指定的维度。歧义明显时追问。
