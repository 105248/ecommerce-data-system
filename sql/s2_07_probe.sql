-- 阶段2探查7: 维度字段类型(决定RETURNS TABLE列类型)
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema='core' AND table_name IN
('douyin_carrier_daily','douyin_account_daily','douyin_content_daily','douyin_terminal_daily',
 'douyin_category_daily','douyin_product_daily','douyin_price_band_daily','douyin_audience_daily')
AND column_name IN ('sale_scope','carrier_type','account_channel','account_name','account_type',
 'selling_type','content_id','content_title','terminal_type','category_level_1','category_level_2',
 'category_level_3','category_level_4','product_id','product_name','price_band','audience_type',
 'douyin_account_id')
ORDER BY table_name, ordinal_position;
