-- 阶段6A补充: 业务键唯一性(真正的重复) + 6C规则检查
\echo ===== A8. 业务键唯一性(重复=0 才正确) =====
SELECT 'deal' AS t, count(*) FROM (SELECT shop_id,biz_date,sale_scope,carrier_type,ad_period FROM core.douyin_deal_daily GROUP BY 1,2,3,4,5 HAVING count(*)>1) x
UNION ALL SELECT 'carrier', count(*) FROM (SELECT shop_id,biz_date,sale_scope,carrier_type,account_channel FROM core.douyin_carrier_daily GROUP BY 1,2,3,4,5 HAVING count(*)>1) x
UNION ALL SELECT 'account', count(*) FROM (SELECT shop_id,biz_date,sale_scope,account_name FROM core.douyin_account_daily GROUP BY 1,2,3,4 HAVING count(*)>1) x
UNION ALL SELECT 'content', count(*) FROM (SELECT shop_id,biz_date,selling_type,content_id FROM core.douyin_content_daily GROUP BY 1,2,3,4 HAVING count(*)>1) x
UNION ALL SELECT 'terminal', count(*) FROM (SELECT shop_id,biz_date,terminal_type,selling_type FROM core.douyin_terminal_daily GROUP BY 1,2,3,4 HAVING count(*)>1) x
UNION ALL SELECT 'category', count(*) FROM (SELECT shop_id,biz_date,category_level_1,category_level_2,category_level_3,category_level_4 FROM core.douyin_category_daily GROUP BY 1,2,3,4,5,6 HAVING count(*)>1) x
UNION ALL SELECT 'product', count(*) FROM (SELECT shop_id,biz_date,product_id,carrier_type FROM core.douyin_product_daily GROUP BY 1,2,3,4 HAVING count(*)>1) x
UNION ALL SELECT 'price_band', count(*) FROM (SELECT shop_id,biz_date,price_band FROM core.douyin_price_band_daily GROUP BY 1,2,3 HAVING count(*)>1) x
UNION ALL SELECT 'audience', count(*) FROM (SELECT shop_id,biz_date,audience_type,carrier_type FROM core.douyin_audience_daily GROUP BY 1,2,3,4 HAVING count(*)>1) x;

\echo ===== C1. V1.4 规则总数(应96) =====
SELECT count(*) AS total FROM meta.metric_formula_rule WHERE mapping_version='V1.4';
\echo ===== C2. auto_use_allowed=true(应79) =====
SELECT count(*) AS auto FROM meta.metric_formula_rule WHERE mapping_version='V1.4' AND auto_use_allowed=TRUE;
\echo ===== C3. 12条剔除退款分母(应12/12) =====
SELECT count(*) AS rules, count(*) FILTER (WHERE denominator_expression='settlement_amount') AS settle,
       count(*) FILTER (WHERE denominator_expression='net_transaction_amount') AS net_residual
FROM meta.metric_formula_rule WHERE target_column_name LIKE '%net_refund%';
\echo ===== C4. 比例原值保护(0.1972 / 9.625) =====
SELECT '0.1972' AS v, count(*) FROM core.douyin_deal_daily WHERE click_to_transaction_rate_users = 0.1972
UNION ALL SELECT '9.625', count(*) FROM core.douyin_deal_daily WHERE click_to_transaction_rate_users = 9.625;
