-- 覆盖重导后: 全量核对
\echo '===== 1. 9表总行数 (期望18809) ====='
SELECT
  (SELECT count(*) FROM core.douyin_deal_daily) AS deal,
  (SELECT count(*) FROM core.douyin_carrier_daily) AS carrier,
  (SELECT count(*) FROM core.douyin_account_daily) AS account,
  (SELECT count(*) FROM core.douyin_content_daily) AS content,
  (SELECT count(*) FROM core.douyin_terminal_daily) AS terminal,
  (SELECT count(*) FROM core.douyin_category_daily) AS category,
  (SELECT count(*) FROM core.douyin_product_daily) AS product,
  (SELECT count(*) FROM core.douyin_price_band_daily) AS price_band,
  (SELECT count(*) FROM core.douyin_audience_daily) AS audience;

\echo ''
\echo '===== 2. 日期范围 ====='
SELECT min(biz_date) AS min_date, max(biz_date) AS max_date, count(DISTINCT biz_date) AS days
FROM core.douyin_deal_daily;

\echo ''
\echo '===== 3. 全店30天关键值 (导入后, 对比导入前9397490.90) ====='
SELECT user_pay_amount, transaction_amount, refund_rate_pay_time, settlement_amount,
       ad_spend_shop_promoted, ad_spend_shop_bound
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

\echo ''
\echo '===== 4. 比例原值 (0.1972/9.625) ====='
SELECT '0.1972: '|| count(*) || ' 行' AS v FROM core.douyin_deal_daily WHERE refund_rate_pay_time = 0.1972
UNION ALL SELECT '9.625: '|| count(*) || ' 行' FROM core.douyin_deal_daily WHERE click_to_transaction_rate_users = 9.625;

\echo ''
\echo '===== 5. batch 记录 ====='
SELECT batch_id, source_file_name, inserted_row_count, import_status
FROM audit.import_batch ORDER BY batch_id;

\echo ''
\echo '===== 6. deal_daily 投放字段非空情况 (导入后) ====='
SELECT count(*) AS total_rows,
       count(ad_spend_shop_promoted) FILTER (WHERE ad_spend_shop_promoted IS NOT NULL) AS promo_filled,
       count(ad_spend_shop_bound) FILTER (WHERE ad_spend_shop_bound IS NOT NULL) AS bound_filled,
       count(settlement_amount) FILTER (WHERE settlement_amount IS NOT NULL) AS settle_filled
FROM core.douyin_deal_daily;
