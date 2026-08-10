-- F1修正: product 独立TOTAL vs 明细之和
WITH fn_all AS (
  SELECT SUM(user_pay_amount) AS v FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',NULL,NULL,'全部')
),
detail_sum AS (
  SELECT SUM(user_pay_amount) AS v FROM core.douyin_product_daily d
  JOIN meta.shop s ON s.shop_id=d.shop_id
  WHERE s.shop_name='弹动官方旗舰店' AND d.carrier_type IN ('商品卡','图文','直播','短视频','其他')
    AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30'
)
SELECT a.v AS fn_all_total, d.v AS detail_sum,
       round((a.v - d.v)::numeric,2) AS diff,
       CASE WHEN abs(a.v - d.v) > 100 THEN 'PASS(独立TOTAL≠明细之和,未被重建)' ELSE 'FAIL' END AS verdict
FROM fn_all a CROSS JOIN detail_sum d;
