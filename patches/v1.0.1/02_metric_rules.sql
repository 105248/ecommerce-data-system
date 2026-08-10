-- V1.0.1: 新增10条投放指标规则到 metric_formula_rule
BEGIN;

-- 3条可加金额
INSERT INTO meta.metric_formula_rule
(target_schema, target_table, target_column_name_cn, target_column_name, metric_category, calculation_mode,
 formula_cn, numerator_expression, denominator_expression, multiplier, single_row_formula, period_formula_sql,
 zero_denominator_rule, cross_period_recalculable, auto_use_allowed, rule_status, display_format, mapping_version, notes)
VALUES
('core','douyin_deal_daily','投放消耗(店铺被投)','ad_spend_shop_promoted','投放指标-可加金额','sum',
 'SUM(投放消耗(店铺被投))','SUM(ad_spend_shop_promoted)',NULL,1,'ad_spend_shop_promoted','SUM(ad_spend_shop_promoted)',
 'N/A',TRUE,TRUE,'已明确（V1.0.1新增）','金额','V1.0.1','V1.0.1新增投放指标'),
('core','douyin_deal_daily','投放消耗(店铺绑定)','ad_spend_shop_bound','投放指标-可加金额','sum',
 'SUM(投放消耗(店铺绑定))','SUM(ad_spend_shop_bound)',NULL,1,'ad_spend_shop_bound','SUM(ad_spend_shop_bound)',
 'N/A',TRUE,TRUE,'已明确（V1.0.1新增）','金额','V1.0.1','V1.0.1新增投放指标'),
('core','douyin_deal_daily','投放贡献成交金额','ad_attributed_transaction_amount','投放指标-可加金额','sum',
 'SUM(投放贡献成交金额)','SUM(ad_attributed_transaction_amount)',NULL,1,'ad_attributed_transaction_amount','SUM(ad_attributed_transaction_amount)',
 'N/A',TRUE,TRUE,'已明确（V1.0.1新增）','金额','V1.0.1','V1.0.1新增投放指标');

-- 3条比例
INSERT INTO meta.metric_formula_rule
(target_schema, target_table, target_column_name_cn, target_column_name, metric_category, calculation_mode,
 formula_cn, numerator_expression, denominator_expression, multiplier, single_row_formula, period_formula_sql,
 zero_denominator_rule, cross_period_recalculable, auto_use_allowed, rule_status, display_format, mapping_version, notes)
VALUES
('core','douyin_deal_daily','投放贡献成交占比','ad_attributed_transaction_share','投放指标-比例','ratio',
 'SUM(投放贡献成交金额)/SUM(成交金额)','SUM(ad_attributed_transaction_amount)','SUM(transaction_amount)',1,
 'ad_attributed_transaction_amount/NULLIF(transaction_amount,0)',
 'SUM(ad_attributed_transaction_amount)/NULLIF(SUM(transaction_amount),0)',
 '分母为0返回NULL',TRUE,TRUE,'已明确（V1.0.1新增）','百分比','V1.0.1','V1.0.1新增投放比例指标，禁止AVG'),
('core','douyin_deal_daily','投放费比(剔除退款、店铺绑定)','ad_spend_rate_net_refund_shop_bound','投放指标-比例','ratio',
 'SUM(投放消耗(店铺绑定))/SUM(结算金额)','SUM(ad_spend_shop_bound)','SUM(settlement_amount)',1,
 'ad_spend_shop_bound/NULLIF(settlement_amount,0)',
 'SUM(ad_spend_shop_bound)/NULLIF(SUM(settlement_amount),0)',
 '分母为0返回NULL',TRUE,TRUE,'已明确（V1.0.1新增）','百分比','V1.0.1','V1.0.1新增投放费比，剔除退款分母锁定settlement_amount'),
('core','douyin_deal_daily','综合费比(剔除退款、店铺绑定)','total_expense_rate_net_refund_shop_bound','投放指标-比例','weighted_source_ratio',
 'SUM(日综合费比×日结算金额)/SUM(结算金额)（成交主表缺佣金分子字段，V1.0.1用结算金额加权源比率）',
 'total_expense_rate_net_refund_shop_bound * settlement_amount','SUM(settlement_amount)',1,
 'total_expense_rate_net_refund_shop_bound',
 'SUM(total_expense_rate_net_refund_shop_bound * settlement_amount)/NULLIF(SUM(settlement_amount),0)',
 '分母为0返回NULL',TRUE,TRUE,'已明确（按源比率分母加权）','百分比','V1.0.1',
 '当前成交主表缺少完整费用分子字段；跨期不是简单AVG，而是按结算金额加权平台日源值；后续若抖音提供全店佣金基础字段，再升级为精确分子/分母公式');

-- 4条效率 (weighted_source_ratio)
INSERT INTO meta.metric_formula_rule
(target_schema, target_table, target_column_name_cn, target_column_name, metric_category, calculation_mode,
 formula_cn, numerator_expression, denominator_expression, multiplier, single_row_formula, period_formula_sql,
 zero_denominator_rule, cross_period_recalculable, auto_use_allowed, rule_status, display_format, mapping_version, notes)
VALUES
('core','douyin_deal_daily','投放效率(店铺被投)','ad_efficiency_shop_promoted','投放指标-效率','weighted_source_ratio',
 'SUM(日投放效率(被投)×日投放消耗(被投))/SUM(日投放消耗(被投))',
 'ad_efficiency_shop_promoted * ad_spend_shop_promoted','SUM(ad_spend_shop_promoted)',1,
 'ad_efficiency_shop_promoted',
 'SUM(ad_efficiency_shop_promoted * ad_spend_shop_promoted)/NULLIF(SUM(ad_spend_shop_promoted),0)',
 '分母为0返回NULL',TRUE,TRUE,'已明确（按源消耗加权）','倍数','V1.0.1',
 '单日=平台源值；多日按对应投放消耗加权源效率，禁止AVG；平台完整底层分子公式待官方口径进一步确认；V1.0.1使用对应投放消耗加权源效率'),
('core','douyin_deal_daily','投放效率(店铺绑定)','ad_efficiency_shop_bound','投放指标-效率','weighted_source_ratio',
 'SUM(日投放效率(绑定)×日投放消耗(绑定))/SUM(日投放消耗(绑定))',
 'ad_efficiency_shop_bound * ad_spend_shop_bound','SUM(ad_spend_shop_bound)',1,
 'ad_efficiency_shop_bound',
 'SUM(ad_efficiency_shop_bound * ad_spend_shop_bound)/NULLIF(SUM(ad_spend_shop_bound),0)',
 '分母为0返回NULL',TRUE,TRUE,'已明确（按源消耗加权）','倍数','V1.0.1',
 '单日=平台源值；多日按对应投放消耗加权源效率，禁止AVG；平台完整底层分子公式待官方口径进一步确认；V1.0.1使用对应投放消耗加权源效率'),
('core','douyin_deal_daily','全店效率(店铺被投)','store_efficiency_shop_promoted','投放指标-效率','weighted_source_ratio',
 'SUM(日全店效率(被投)×日投放消耗(被投))/SUM(日投放消耗(被投))',
 'store_efficiency_shop_promoted * ad_spend_shop_promoted','SUM(ad_spend_shop_promoted)',1,
 'store_efficiency_shop_promoted',
 'SUM(store_efficiency_shop_promoted * ad_spend_shop_promoted)/NULLIF(SUM(ad_spend_shop_promoted),0)',
 '分母为0返回NULL',TRUE,TRUE,'已明确（按源消耗加权）','倍数','V1.0.1',
 '单日=平台源值；多日按对应投放消耗加权源效率，禁止AVG；平台完整底层分子公式待官方口径进一步确认；V1.0.1使用对应投放消耗加权源效率'),
('core','douyin_deal_daily','全店效率(店铺绑定)','store_efficiency_shop_bound','投放指标-效率','weighted_source_ratio',
 'SUM(日全店效率(绑定)×日投放消耗(绑定))/SUM(日投放消耗(绑定))',
 'store_efficiency_shop_bound * ad_spend_shop_bound','SUM(ad_spend_shop_bound)',1,
 'store_efficiency_shop_bound',
 'SUM(store_efficiency_shop_bound * ad_spend_shop_bound)/NULLIF(SUM(ad_spend_shop_bound),0)',
 '分母为0返回NULL',TRUE,TRUE,'已明确（按源消耗加权）','倍数','V1.0.1',
 '单日=平台源值；多日按对应投放消耗加权源效率，禁止AVG；平台完整底层分子公式待官方口径进一步确认；V1.0.1使用对应投放消耗加权源效率');

COMMIT;

\echo '=== V1.0.1 规则数 (应106) ==='
SELECT count(*) FROM meta.metric_formula_rule;
\echo '=== 新10条 ==='
SELECT target_column_name_cn, calculation_mode, auto_use_allowed, rule_status
FROM meta.metric_formula_rule WHERE mapping_version='V1.0.1' ORDER BY target_column_name;
