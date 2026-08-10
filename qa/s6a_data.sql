-- 阶段6A: 底层数据完整性检查
\echo ===== A1. core 9表 行数/日期范围 =====
SELECT table_name, count(*) AS rows_cnt, min(biz_date) AS min_d, max(biz_date) AS max_d
FROM (
  SELECT 'deal' AS table_name, biz_date FROM core.douyin_deal_daily
  UNION ALL SELECT 'carrier', biz_date FROM core.douyin_carrier_daily
  UNION ALL SELECT 'account', biz_date FROM core.douyin_account_daily
  UNION ALL SELECT 'content', biz_date FROM core.douyin_content_daily
  UNION ALL SELECT 'terminal', biz_date FROM core.douyin_terminal_daily
  UNION ALL SELECT 'category', biz_date FROM core.douyin_category_daily
  UNION ALL SELECT 'product', biz_date FROM core.douyin_product_daily
  UNION ALL SELECT 'price_band', biz_date FROM core.douyin_price_band_daily
  UNION ALL SELECT 'audience', biz_date FROM core.douyin_audience_daily
) t GROUP BY table_name ORDER BY table_name;

\echo ===== A2. core 总行数(应18809) =====
SELECT (SELECT count(*) FROM core.douyin_deal_daily)+(SELECT count(*) FROM core.douyin_carrier_daily)
 +(SELECT count(*) FROM core.douyin_account_daily)+(SELECT count(*) FROM core.douyin_content_daily)
 +(SELECT count(*) FROM core.douyin_terminal_daily)+(SELECT count(*) FROM core.douyin_category_daily)
 +(SELECT count(*) FROM core.douyin_product_daily)+(SELECT count(*) FROM core.douyin_price_band_daily)
 +(SELECT count(*) FROM core.douyin_audience_daily) AS core_total;

\echo ===== A3. 非法shop_id(不在meta.shop) =====
SELECT 'deal' AS t, count(*) FROM core.douyin_deal_daily d LEFT JOIN meta.shop s USING(shop_id) WHERE s.shop_id IS NULL
UNION ALL SELECT 'carrier', count(*) FROM core.douyin_carrier_daily d LEFT JOIN meta.shop s USING(shop_id) WHERE s.shop_id IS NULL
UNION ALL SELECT 'account', count(*) FROM core.douyin_account_daily d LEFT JOIN meta.shop s USING(shop_id) WHERE s.shop_id IS NULL
UNION ALL SELECT 'content', count(*) FROM core.douyin_content_daily d LEFT JOIN meta.shop s USING(shop_id) WHERE s.shop_id IS NULL
UNION ALL SELECT 'terminal', count(*) FROM core.douyin_terminal_daily d LEFT JOIN meta.shop s USING(shop_id) WHERE s.shop_id IS NULL
UNION ALL SELECT 'category', count(*) FROM core.douyin_category_daily d LEFT JOIN meta.shop s USING(shop_id) WHERE s.shop_id IS NULL
UNION ALL SELECT 'product', count(*) FROM core.douyin_product_daily d LEFT JOIN meta.shop s USING(shop_id) WHERE s.shop_id IS NULL
UNION ALL SELECT 'price_band', count(*) FROM core.douyin_price_band_daily d LEFT JOIN meta.shop s USING(shop_id) WHERE s.shop_id IS NULL
UNION ALL SELECT 'audience', count(*) FROM core.douyin_audience_daily d LEFT JOIN meta.shop s USING(shop_id) WHERE s.shop_id IS NULL;

\echo ===== A4. 未来日期(>2026-06-30) =====
SELECT 'deal' AS t, count(*) FROM core.douyin_deal_daily WHERE biz_date > '2026-06-30'
UNION ALL SELECT 'carrier', count(*) FROM core.douyin_carrier_daily WHERE biz_date > '2026-06-30'
UNION ALL SELECT 'account', count(*) FROM core.douyin_account_daily WHERE biz_date > '2026-06-30'
UNION ALL SELECT 'content', count(*) FROM core.douyin_content_daily WHERE biz_date > '2026-06-30'
UNION ALL SELECT 'terminal', count(*) FROM core.douyin_terminal_daily WHERE biz_date > '2026-06-30'
UNION ALL SELECT 'category', count(*) FROM core.douyin_category_daily WHERE biz_date > '2026-06-30'
UNION ALL SELECT 'product', count(*) FROM core.douyin_product_daily WHERE biz_date > '2026-06-30'
UNION ALL SELECT 'price_band', count(*) FROM core.douyin_price_band_daily WHERE biz_date > '2026-06-30'
UNION ALL SELECT 'audience', count(*) FROM core.douyin_audience_daily WHERE biz_date > '2026-06-30';

\echo ===== A5. 日期完整性: 每表 expected=30, actual, missing, duplicate =====
WITH gen AS (SELECT generate_series('2026-06-01'::date,'2026-06-30'::date,'1 day') AS d)
SELECT 'deal' AS t,
  (SELECT count(*) FROM gen) AS expected,
  (SELECT count(DISTINCT biz_date) FROM core.douyin_deal_daily) AS actual,
  (SELECT count(*) FROM gen WHERE d NOT IN (SELECT DISTINCT biz_date FROM core.douyin_deal_daily)) AS missing,
  (SELECT count(*) FROM (SELECT biz_date FROM core.douyin_deal_daily GROUP BY biz_date HAVING count(*)>1) x) AS dup
UNION ALL
SELECT 'carrier',
  (SELECT count(*) FROM gen),
  (SELECT count(DISTINCT biz_date) FROM core.douyin_carrier_daily),
  (SELECT count(*) FROM gen WHERE d NOT IN (SELECT DISTINCT biz_date FROM core.douyin_carrier_daily)),
  (SELECT count(*) FROM (SELECT biz_date FROM core.douyin_carrier_daily GROUP BY biz_date HAVING count(*)>1) x)
UNION ALL
SELECT 'account',
  (SELECT count(*) FROM gen),
  (SELECT count(DISTINCT biz_date) FROM core.douyin_account_daily),
  (SELECT count(*) FROM gen WHERE d NOT IN (SELECT DISTINCT biz_date FROM core.douyin_account_daily)),
  (SELECT count(*) FROM (SELECT biz_date FROM core.douyin_account_daily GROUP BY biz_date HAVING count(*)>1) x)
UNION ALL
SELECT 'content',
  (SELECT count(*) FROM gen),
  (SELECT count(DISTINCT biz_date) FROM core.douyin_content_daily),
  (SELECT count(*) FROM gen WHERE d NOT IN (SELECT DISTINCT biz_date FROM core.douyin_content_daily)),
  (SELECT count(*) FROM (SELECT biz_date FROM core.douyin_content_daily GROUP BY biz_date HAVING count(*)>1) x)
UNION ALL
SELECT 'terminal',
  (SELECT count(*) FROM gen),
  (SELECT count(DISTINCT biz_date) FROM core.douyin_terminal_daily),
  (SELECT count(*) FROM gen WHERE d NOT IN (SELECT DISTINCT biz_date FROM core.douyin_terminal_daily)),
  (SELECT count(*) FROM (SELECT biz_date FROM core.douyin_terminal_daily GROUP BY biz_date HAVING count(*)>1) x)
UNION ALL
SELECT 'category',
  (SELECT count(*) FROM gen),
  (SELECT count(DISTINCT biz_date) FROM core.douyin_category_daily),
  (SELECT count(*) FROM gen WHERE d NOT IN (SELECT DISTINCT biz_date FROM core.douyin_category_daily)),
  (SELECT count(*) FROM (SELECT biz_date FROM core.douyin_category_daily GROUP BY biz_date HAVING count(*)>1) x)
UNION ALL
SELECT 'product',
  (SELECT count(*) FROM gen),
  (SELECT count(DISTINCT biz_date) FROM core.douyin_product_daily),
  (SELECT count(*) FROM gen WHERE d NOT IN (SELECT DISTINCT biz_date FROM core.douyin_product_daily)),
  (SELECT count(*) FROM (SELECT biz_date FROM core.douyin_product_daily GROUP BY biz_date HAVING count(*)>1) x)
UNION ALL
SELECT 'price_band',
  (SELECT count(*) FROM gen),
  (SELECT count(DISTINCT biz_date) FROM core.douyin_price_band_daily),
  (SELECT count(*) FROM gen WHERE d NOT IN (SELECT DISTINCT biz_date FROM core.douyin_price_band_daily)),
  (SELECT count(*) FROM (SELECT biz_date FROM core.douyin_price_band_daily GROUP BY biz_date HAVING count(*)>1) x)
UNION ALL
SELECT 'audience',
  (SELECT count(*) FROM gen),
  (SELECT count(DISTINCT biz_date) FROM core.douyin_audience_daily),
  (SELECT count(*) FROM gen WHERE d NOT IN (SELECT DISTINCT biz_date FROM core.douyin_audience_daily)),
  (SELECT count(*) FROM (SELECT biz_date FROM core.douyin_audience_daily GROUP BY biz_date HAVING count(*)>1) x);

\echo ===== A6. 店铺检查: meta.shop 完整性 =====
SELECT shop_id, shop_name, shop_code, platform_code, enabled,
  count(*) FILTER (WHERE duplicate_code) AS dup_code
FROM (
  SELECT s.*,
    (SELECT count(*) FROM meta.shop s2 WHERE s2.shop_code = s.shop_code) > 1 AS duplicate_code
  FROM meta.shop s
) x GROUP BY shop_id, shop_name, shop_code, platform_code, enabled;

\echo ===== A7. NULL异常抽查(deal关键字段) =====
SELECT count(*) AS total,
  count(*) FILTER (WHERE user_pay_amount IS NULL) AS pay_null,
  count(*) FILTER (WHERE transaction_amount IS NULL) AS txn_null,
  count(*) FILTER (WHERE biz_date IS NULL) AS date_null
FROM core.douyin_deal_daily;
