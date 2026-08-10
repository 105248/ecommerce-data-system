-- 阶段2探查5: 8个业务域mart View字段
SELECT table_name, string_agg(column_name, ',' ORDER BY ordinal_position) AS cols
FROM information_schema.columns
WHERE table_schema='mart' AND table_name IN
('carrier_daily','account_daily','content_daily','terminal_daily',
 'category_daily','product_daily','price_band_daily','audience_daily')
GROUP BY table_name ORDER BY table_name;
