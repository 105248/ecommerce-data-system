-- 随机5天数据核对: shop_daily vs deal合法TOTAL
SELECT d.biz_date, s.user_pay_amount AS shop_daily_amt, d.user_pay_amount AS deal_total_amt,
       round(s.user_pay_amount - d.user_pay_amount, 2) AS diff,
       CASE WHEN round(s.user_pay_amount - d.user_pay_amount, 2) = 0 THEN 'OK' ELSE 'MISMATCH' END AS status
FROM mart.shop_daily s
JOIN core.douyin_deal_daily d
  ON d.shop_id = 1 AND d.biz_date = s.biz_date
 AND d.sale_scope = '全部' AND d.carrier_type = '全部' AND d.ad_period = '不限'
WHERE s.biz_date IN ('2026-06-05','2026-06-12','2026-06-18','2026-06-25','2026-06-30')
ORDER BY d.biz_date;
