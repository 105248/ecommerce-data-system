-- 阶段2验收F: 随机5个日期区间 + 非法参数 + 业务域7天抽样
\echo ===== F1. 随机5个日期区间(全店, 与直接SQL对比) =====
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

\echo ===== F2. 非法日期校验: start>end 必须报错 =====
DO $$
BEGIN
  BEGIN
    PERFORM * FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-30','2026-06-01','全店');
    RAISE NOTICE 'FAIL: 未抛出异常';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PASS: 已抛异常 (%)', SQLERRM;
  END;
  BEGIN
    PERFORM * FROM mart.get_business_period_summary('弹动官方旗舰店', NULL, NULL, '全店');
    RAISE NOTICE 'FAIL: 空日期未抛出异常';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PASS: 空日期已抛异常 (%)', SQLERRM;
  END;
  BEGIN
    PERFORM * FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','未知语义');
    RAISE NOTICE 'FAIL: 未知scope未抛异常';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PASS: 未知scope已抛异常 (%)', SQLERRM;
  END;
END $$;

\echo ===== F3. product_id/name 不匹配必须报错 =====
DO $$
BEGIN
  BEGIN
    PERFORM * FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','999999','不存在的商品','全部');
    RAISE NOTICE 'FAIL: 商品不匹配未抛异常';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PASS: 商品不匹配已抛异常 (%)', SQLERRM;
  END;
END $$;

\echo ===== F4. 业务域7天抽样: carrier/account/terminal 可加=7天SUM =====
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
SELECT 'terminal',
  (SELECT SUM(user_pay_amount) FROM mart.get_terminal_period_summary('弹动官方旗舰店','2026-06-08','2026-06-14')),
  (SELECT SUM(user_pay_amount) FROM core.douyin_terminal_daily d JOIN meta.shop sh ON d.shop_id=sh.shop_id
   WHERE sh.shop_name='弹动官方旗舰店' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14');
