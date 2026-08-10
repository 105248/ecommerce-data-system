-- 覆盖重导后 mart 层回归
\echo '===== 1. 全店30天 (导入后) ====='
SELECT user_pay_amount, transaction_amount, refund_rate_pay_time, settlement_amount
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

\echo ''
\echo '===== 2. shop_daily 行数与唯一性 ====='
SELECT count(*) AS rows_cnt, count(DISTINCT (shop_name, biz_date)) AS uniq
FROM mart.shop_daily;

\echo ''
\echo '===== 3. 全店30天 vs shop_daily SUM 一致性 ====='
SELECT sum(user_pay_amount) AS shop_daily_sum
FROM mart.shop_daily;

\echo ''
\echo '===== 4. 单日核对 06-05 自营商品卡 (对比之前88274.54) ====='
SELECT user_pay_amount, transaction_amount, refund_rate_pay_time
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-05','2026-06-05','自营商品卡');

\echo ''
\echo '===== 5. deal 三层 total 结构 ====='
SELECT sale_scope, carrier_type, ad_period, count(*) AS cnt
FROM core.douyin_deal_daily
GROUP BY 1,2,3 ORDER BY 1,2,3 LIMIT 18;

\echo ''
\echo '===== 6. price_band 6带求和 vs 店铺TOTAL ====='
SELECT (SELECT sum(user_pay_amount) FROM core.douyin_price_band_daily) AS price_band_sum,
       (SELECT user_pay_amount FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店')) AS shop_total;
