-- 阶段2冒烟测试: 各业务域函数 30天全量
\echo ===== carrier(30天, 前5行) =====
SELECT shop_name, day_count, sale_scope, carrier_type, account_channel, user_pay_amount
FROM mart.get_carrier_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30') LIMIT 5;
\echo ===== account(30天) 行数 =====
SELECT count(*) FROM mart.get_account_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30');
\echo ===== content(30天) 行数 =====
SELECT count(*) FROM mart.get_content_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30');
\echo ===== terminal(30天) 前5行 =====
SELECT shop_name, terminal_type, selling_type, user_pay_amount
FROM mart.get_terminal_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30') ORDER BY terminal_type, selling_type LIMIT 5;
\echo ===== category(L3, 30天) 行数 =====
SELECT count(*) FROM mart.get_category_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30', 3);
\echo ===== product(全部, 30天) 前3行 =====
SELECT shop_name, product_id, carrier_type, user_pay_amount
FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30') LIMIT 3;
\echo ===== price_band(30天) =====
SELECT price_band, user_pay_amount
FROM mart.get_price_band_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30') ORDER BY price_band;
\echo ===== audience(全部, 30天) 前5行 =====
SELECT audience_type, carrier_type, user_pay_amount
FROM mart.get_audience_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30') ORDER BY audience_type, carrier_type LIMIT 5;
