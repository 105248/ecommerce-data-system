-- F3复测: product_id/name 一致性校验
\echo ===== F3a. 合法(匹配)调用: 不抛错并返回数据 =====
SELECT product_id, product_name, carrier_type, user_pay_amount
FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',
  '3523538019611183417', NULL, '全部') LIMIT 2;

\echo ===== F3b. 不匹配: 必须抛自定义错误 =====
DO $$
BEGIN
  BEGIN
    PERFORM * FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',
      '999999','不存在的商品','全部');
    RAISE NOTICE 'FAIL: 未抛异常';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'PASS: 已抛异常 (%)', SQLERRM;
  END;
END $$;
