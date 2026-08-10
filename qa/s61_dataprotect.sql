-- 阶段6.1: 数据保护核对
\echo '===== 数据保护 ====='
SELECT
  (SELECT count(*) FROM core.douyin_deal_daily)+(SELECT count(*) FROM core.douyin_carrier_daily)+(SELECT count(*) FROM core.douyin_account_daily)+(SELECT count(*) FROM core.douyin_content_daily)+(SELECT count(*) FROM core.douyin_terminal_daily)+(SELECT count(*) FROM core.douyin_category_daily)+(SELECT count(*) FROM core.douyin_product_daily)+(SELECT count(*) FROM core.douyin_price_band_daily)+(SELECT count(*) FROM core.douyin_audience_daily) AS core_total_18809,
  (SELECT count(*) FROM meta.metric_formula_rule WHERE mapping_version='V1.4') AS v14_rules_96,
  (SELECT count(*) FROM meta.metric_formula_rule WHERE mapping_version='V1.4' AND auto_use_allowed=TRUE) AS auto_79,
  (SELECT count(*) FROM meta.metric_formula_rule WHERE target_column_name LIKE '%net_refund%' AND denominator_expression='settlement_amount') AS settle_12,
  (SELECT count(*) FROM meta.metric_formula_rule WHERE target_column_name LIKE '%net_refund%' AND denominator_expression='net_transaction_amount') AS net_residual_0;

\echo ''
\echo '===== 比例原值 0.1972 / 9.625 ====='
SELECT table_name, column_name, count(*) AS cnt
FROM (
  SELECT 'carrier_daily' AS table_name, '商品点击-成交转化率(人数)' AS column_name
  UNION ALL SELECT 'carrier_daily', '商品点击-成交转化率(次数)'
) x, LATERAL (
  SELECT 1 FROM core.douyin_carrier_daily c WHERE c.click_to_transaction_rate_users = 0.1972 OR c.click_to_transaction_rate_events = 0.1972
  UNION ALL
  SELECT 1 FROM core.douyin_carrier_daily c2 WHERE c2.exposure_to_click_rate_users = 9.625 OR c2.exposure_to_click_rate_events = 9.625
) y
GROUP BY 1,2;
