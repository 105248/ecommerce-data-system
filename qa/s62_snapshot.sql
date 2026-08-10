-- 覆盖重导: 导入前快照
\echo '===== 1. 9表行数 ====='
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
\echo '===== 2. 全店30天关键值 (导入前) ====='
SELECT user_pay_amount, transaction_amount, refund_rate_pay_time, settlement_amount
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

\echo ''
\echo '===== 3. deal 三层total (导入前) ====='
SELECT sale_scope, carrier_type, ad_period, count(*) AS rows_cnt
FROM core.douyin_deal_daily
WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30'
GROUP BY 1,2,3
ORDER BY 1,2,3
LIMIT 12;

\echo ''
\echo '===== 4. 比例原值位置 (导入前) ====='
SELECT '0.1972: '|| count(*) || ' 行' FROM core.douyin_deal_daily WHERE refund_rate_pay_time = 0.1972
UNION ALL
SELECT '9.625: '|| count(*) || ' 行' FROM core.douyin_deal_daily WHERE click_to_transaction_rate_users = 9.625;

\echo ''
\echo '===== 5. batch7 状态 ====='
SELECT batch_id, source_file_name, file_sha256, inserted_row_count, import_status
FROM audit.import_batch WHERE batch_id = 7;
