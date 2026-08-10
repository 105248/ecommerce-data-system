\pset pager off
\echo '--- 1. biz_date 来源映射 ---'
SELECT source_sheet_name, source_column_name, transform_rule FROM meta.field_mapping WHERE target_column_name='biz_date' ORDER BY source_sheet_name;
\echo '--- 2. exposure_to_transaction_rate_events 分布 ---'
SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY exposure_to_transaction_rate_events)::numeric,6) p50,
       round(percentile_cont(0.9) WITHIN GROUP (ORDER BY exposure_to_transaction_rate_events)::numeric,6) p90,
       round(percentile_cont(0.99) WITHIN GROUP (ORDER BY exposure_to_transaction_rate_events)::numeric,6) p99,
       max(exposure_to_transaction_rate_events) mx,
       count(*) FILTER (WHERE exposure_to_transaction_rate_events>1) over1,
       count(*) FILTER (WHERE exposure_to_transaction_rate_events>0 AND exposure_to_transaction_rate_events<=1) in01
FROM core.douyin_account_daily;
\echo '--- 3. 其余率列 max ---'
SELECT max(exposure_to_click_rate_events) e2c, max(click_to_transaction_rate_events) c2t,
       max(user_pay_amount_per_1000_exposures) pay1000 FROM core.douyin_account_daily;
\echo '--- 4. exposure>1 样本 ---'
SELECT shop_id, biz_date, account_name, exposure_to_transaction_rate_events
FROM core.douyin_account_daily WHERE exposure_to_transaction_rate_events>1 ORDER BY 4 DESC LIMIT 5;
\echo '--- 5. 完整维度键重复（9表真重复） ---'
SELECT 'deal' t, count(*) dup FROM (SELECT shop_id,biz_date,sale_scope,carrier_type,ad_period,count(*) c FROM core.douyin_deal_daily GROUP BY 1,2,3,4,5 HAVING count(*)>1) x
UNION ALL SELECT 'product', count(*) FROM (SELECT shop_id,biz_date,product_id,carrier_type,count(*) c FROM core.douyin_product_daily GROUP BY 1,2,3,4 HAVING count(*)>1) x
UNION ALL SELECT 'carrier', count(*) FROM (SELECT shop_id,biz_date,sale_scope,carrier_type,account_channel,douyin_account_id,count(*) c FROM core.douyin_carrier_daily GROUP BY 1,2,3,4,5,6 HAVING count(*)>1) x
UNION ALL SELECT 'content', count(*) FROM (SELECT shop_id,biz_date,selling_type,carrier_type,content_id,count(*) c FROM core.douyin_content_daily GROUP BY 1,2,3,4,5 HAVING count(*)>1) x
UNION ALL SELECT 'terminal', count(*) FROM (SELECT shop_id,biz_date,terminal_type,selling_type,count(*) c FROM core.douyin_terminal_daily GROUP BY 1,2,3,4 HAVING count(*)>1) x
UNION ALL SELECT 'audience', count(*) FROM (SELECT shop_id,biz_date,audience_type,carrier_type,count(*) c FROM core.douyin_audience_daily GROUP BY 1,2,3,4 HAVING count(*)>1) x
UNION ALL SELECT 'account', count(*) FROM (SELECT shop_id,biz_date,account_name,account_type,sale_scope,count(*) c FROM core.douyin_account_daily GROUP BY 1,2,3,4,5 HAVING count(*)>1) x
UNION ALL SELECT 'category', count(*) FROM (SELECT shop_id,biz_date,category_level_1,category_level_2,category_level_3,category_level_4,count(*) c FROM core.douyin_category_daily GROUP BY 1,2,3,4,5,6 HAVING count(*)>1) x
UNION ALL SELECT 'price_band', count(*) FROM (SELECT shop_id,biz_date,price_band,count(*) c FROM core.douyin_price_band_daily GROUP BY 1,2,3 HAVING count(*)>1) x;
