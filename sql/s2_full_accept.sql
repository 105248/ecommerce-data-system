-- 阶段2完整专项验收 (提供SQL版函数)
\echo ===== S1. 12 Scope 30天 vs 直接SQL =====
WITH scopes AS (
  SELECT * FROM (VALUES
    ('全店'),('自营'),('合作'),('商品卡'),('短视频'),('直播'),('图文'),('其他'),
    ('自营商品卡'),('合作商品卡'),('自营短视频'),('合作短视频')
  ) v(scope_key)
),
fn_result AS (
  SELECT r.scope_key, r.user_pay_amount AS fn_amount
  FROM scopes s, LATERAL (
    SELECT scope_key, user_pay_amount
    FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30', s.scope_key)
  ) r
),
sql_result AS (
  SELECT r.scope_key,
    (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
     JOIN meta.shop sh ON d.shop_id=sh.shop_id
     WHERE sh.shop_name='弹动官方旗舰店'
       AND d.sale_scope=rs.sale_scope AND d.carrier_type=rs.carrier_type
       AND d.ad_period=rs.ad_period AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30') AS sql_amount
  FROM scopes r, LATERAL mart.resolve_scope(r.scope_key) rs
)
SELECT f.scope_key, f.fn_amount AS fn, s.sql_amount AS sql,
       round((f.fn_amount - s.sql_amount)::numeric, 2) AS diff,
       CASE WHEN abs(f.fn_amount - s.sql_amount) < 0.01 THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM fn_result f JOIN sql_result s USING (scope_key)
ORDER BY f.scope_key;

\echo ===== S2. 单日(06-12) vs mart.shop_daily =====
SELECT f.user_pay_amount AS fn_pay, d.user_pay_amount AS daily_pay,
       f.coverage_days, f.coverage_complete,
       CASE WHEN abs(f.user_pay_amount - d.user_pay_amount) < 0.01 THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-12','2026-06-12','全店') f
JOIN mart.shop_daily d ON d.shop_name = f.shop_name AND d.biz_date = f.start_date;

\echo ===== S3. 7天(06-08~14) vs 直接SQL(可加+客单价) =====
SELECT f.user_pay_amount AS fn_pay, f.avg_customer_amount AS fn_ac, f.coverage_days,
  (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
   JOIN meta.shop sh ON d.shop_id=sh.shop_id
   WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='全部'
     AND d.ad_period='不限' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14') AS sql_pay,
  (SELECT SUM(d.user_pay_amount)/NULLIF(SUM(d.transaction_buyer_count),0)
   FROM core.douyin_deal_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
   WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='全部'
     AND d.ad_period='不限' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14') AS sql_ac,
  CASE WHEN abs(f.avg_customer_amount - (SELECT SUM(d.user_pay_amount)/NULLIF(SUM(d.transaction_buyer_count),0)
           FROM core.douyin_deal_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
           WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='全部'
             AND d.ad_period='不限' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14')) < 0.001
       THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-08','2026-06-14','全店') f;

\echo ===== S4. 随机5个日期区间 =====
WITH periods AS (SELECT * FROM (VALUES
  ('2026-06-01','2026-06-03'),('2026-06-10','2026-06-12'),('2026-06-15','2026-06-25'),
  ('2026-06-02','2026-06-09'),('2026-06-26','2026-06-30')
) v(s,e)),
cmp AS (
  SELECT p.s,
    (SELECT f.user_pay_amount FROM mart.get_business_period_summary('弹动官方旗舰店', p.s::date, p.e::date, '全店') f) AS fn_pay,
    (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
     WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='全部'
       AND d.ad_period='不限' AND d.biz_date BETWEEN p.s::date AND p.e::date) AS sql_pay
  FROM periods p
)
SELECT s AS 区间, fn_pay AS 函数值, sql_pay AS 直接SQL,
       CASE WHEN abs(fn_pay - sql_pay) < 0.01 THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM cmp ORDER BY s;

\echo ===== S5. source_only专项: 待平台口径(两日发货率) + 缺基础字段(成交笔单价) =====
SELECT 'deal-两日发货率(待平台确认)' AS 指标,
  (SELECT ship_within_2_days_rate::text FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-01','全店')) AS 单日,
  (SELECT CASE WHEN ship_within_2_days_rate IS NULL THEN 'NULL' ELSE ship_within_2_days_rate::text END FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店')) AS 多日
UNION ALL
SELECT 'category-成交笔单价(缺基础字段)',
  (SELECT avg_transaction_order_amount::text FROM mart.get_category_period_summary('弹动官方旗舰店','2026-06-01','2026-06-01',3,NULL,NULL,NULL) LIMIT 1),
  (SELECT CASE WHEN avg_transaction_order_amount IS NULL THEN 'NULL' ELSE avg_transaction_order_amount::text END FROM mart.get_category_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',3,NULL,NULL,NULL) LIMIT 1)
UNION ALL
SELECT 'audience-复购率(缺基础字段)',
  (SELECT repeat_user_repeat_rate::text FROM mart.get_audience_period_summary('弹动官方旗舰店','2026-06-01','2026-06-01',NULL,'全部') LIMIT 1),
  (SELECT CASE WHEN repeat_user_repeat_rate IS NULL THEN 'NULL' ELSE repeat_user_repeat_rate::text END FROM mart.get_audience_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',NULL,'全部') LIMIT 1);

\echo ===== S6. 12条剔除退款分母=settlement_amount =====
SELECT count(*) AS 规则数,
       count(*) FILTER (WHERE denominator_expression='settlement_amount') AS 分母结算,
       count(*) FILTER (WHERE denominator_expression='net_transaction_amount') AS 残留净成交
FROM meta.metric_formula_rule
WHERE target_column_name LIKE '%net_refund%';

\echo ===== S7. 比例原值保护: 0.1972 / 9.625 =====
SELECT column_name, column_value
FROM (VALUES
  ('曝光-点击转化率(人数)', (SELECT exposure_to_click_rate_users::text FROM core.douyin_deal_daily WHERE exposure_to_click_rate_users = 0.1972 LIMIT 1)),
  ('点击-成交转化率(次数)', (SELECT click_to_transaction_rate_events::text FROM core.douyin_deal_daily WHERE click_to_transaction_rate_events = 9.625 LIMIT 1))
) v(column_name, column_value);

\echo ===== S8. 非法参数异常 =====
DO $$
BEGIN
  BEGIN PERFORM * FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-30','2026-06-01','全店');
        RAISE NOTICE 'FAIL: 日期未抛异常'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'PASS: 日期异常 (%)', SQLERRM; END;
  BEGIN PERFORM * FROM mart.get_business_period_summary('弹动官方旗舰店',NULL,NULL,'全店');
        RAISE NOTICE 'FAIL: 空日期未抛异常'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'PASS: 空日期异常 (%)', SQLERRM; END;
  BEGIN PERFORM * FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','未知语义');
        RAISE NOTICE 'FAIL: 未知scope未抛异常'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'PASS: 未知scope异常 (%)', SQLERRM; END;
  BEGIN PERFORM * FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','999999','不存在的商品','全部');
        RAISE NOTICE 'FAIL: 商品不匹配未抛异常'; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'PASS: 商品不匹配异常 (%)', SQLERRM; END;
END $$;

\echo ===== S9. 业务域7天抽查(可加=SUM) =====
SELECT 'carrier' AS 域,
  (SELECT SUM(user_pay_amount) FROM mart.get_carrier_period_summary('弹动官方旗舰店','2026-06-08','2026-06-14')) AS fn_sum,
  (SELECT SUM(user_pay_amount) FROM core.douyin_carrier_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
   WHERE sh.shop_name='弹动官方旗舰店' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14') AS sql_sum
UNION ALL
SELECT 'account',
  (SELECT SUM(user_pay_amount) FROM mart.get_account_period_summary('弹动官方旗舰店','2026-06-08','2026-06-14')),
  (SELECT SUM(user_pay_amount) FROM core.douyin_account_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
   WHERE sh.shop_name='弹动官方旗舰店' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14')
UNION ALL
SELECT 'content',
  (SELECT SUM(user_pay_amount) FROM mart.get_content_period_summary('弹动官方旗舰店','2026-06-08','2026-06-14')),
  (SELECT SUM(user_pay_amount) FROM core.douyin_content_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
   WHERE sh.shop_name='弹动官方旗舰店' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14')
UNION ALL
SELECT 'terminal',
  (SELECT SUM(user_pay_amount) FROM mart.get_terminal_period_summary('弹动官方旗舰店','2026-06-08','2026-06-14')),
  (SELECT SUM(user_pay_amount) FROM core.douyin_terminal_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
   WHERE sh.shop_name='弹动官方旗舰店' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14')
UNION ALL
SELECT 'product',
  (SELECT SUM(user_pay_amount) FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-08','2026-06-14',NULL,NULL,'全部')),
  (SELECT SUM(user_pay_amount) FROM core.douyin_product_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
   WHERE sh.shop_name='弹动官方旗舰店' AND d.carrier_type='全部' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14')
UNION ALL
SELECT 'price_band',
  (SELECT SUM(user_pay_amount) FROM mart.get_price_band_period_summary('弹动官方旗舰店','2026-06-08','2026-06-14')),
  (SELECT SUM(user_pay_amount) FROM core.douyin_price_band_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
   WHERE sh.shop_name='弹动官方旗舰店' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14')
UNION ALL
SELECT 'audience',
  (SELECT SUM(user_pay_amount) FROM mart.get_audience_period_summary('弹动官方旗舰店','2026-06-08','2026-06-14',NULL,'全部')),
  (SELECT SUM(user_pay_amount) FROM core.douyin_audience_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
   WHERE sh.shop_name='弹动官方旗舰店' AND d.carrier_type='全部' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14');
