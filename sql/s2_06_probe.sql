-- 阶段2探查6: 9个core表完整字段(排除技术字段)
SELECT table_name, string_agg(column_name, ',' ORDER BY ordinal_position) AS cols
FROM information_schema.columns
WHERE table_schema='core' AND table_name IN
('douyin_carrier_daily','douyin_account_daily','douyin_content_daily','douyin_terminal_daily',
 'douyin_category_daily','douyin_product_daily','douyin_price_band_daily','douyin_audience_daily')
GROUP BY table_name ORDER BY table_name;
