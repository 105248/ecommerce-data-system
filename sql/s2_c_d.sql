-- 阶段2验收C: 比例专项 正确加权(SUM分子/SUM分母) vs AVG(日比例)错误结果
\echo ===== C1. 30天客单价: 加权 vs AVG(日比例) =====
WITH daily AS (
  SELECT biz_date, user_pay_amount, transaction_buyer_count,
         user_pay_amount / NULLIF(transaction_buyer_count,0) AS daily_ratio
  FROM core.douyin_deal_daily
  WHERE sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'
    AND biz_date BETWEEN '2026-06-01' AND '2026-06-30'
)
SELECT SUM(user_pay_amount)/NULLIF(SUM(transaction_buyer_count),0) AS weighted_correct,
       AVG(daily_ratio) AS avg_daily_wrong,
       SUM(user_pay_amount)/NULLIF(SUM(transaction_buyer_count),0) - AVG(daily_ratio) AS diff,
       (SELECT avg_customer_amount FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店')) AS fn_value,
       CASE WHEN abs((SELECT avg_customer_amount FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店')) - SUM(user_pay_amount)/NULLIF(SUM(transaction_buyer_count),0)) < 0.001
            THEN 'PASS(函数=加权,非AVG)' ELSE 'FAIL' END AS verdict
FROM daily;

\echo ===== C2. 30天退款率: 加权 vs AVG(日比例) =====
WITH daily AS (
  SELECT biz_date, refund_amount_pay_time, user_pay_amount,
         refund_amount_pay_time / NULLIF(user_pay_amount,0) AS daily_ratio
  FROM core.douyin_deal_daily
  WHERE sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'
    AND biz_date BETWEEN '2026-06-01' AND '2026-06-30'
)
SELECT SUM(refund_amount_pay_time)/NULLIF(SUM(user_pay_amount),0) AS weighted_correct,
       AVG(daily_ratio) AS avg_daily_wrong,
       SUM(refund_amount_pay_time)/NULLIF(SUM(user_pay_amount),0) - AVG(daily_ratio) AS diff,
       (SELECT refund_rate_pay_time FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店')) AS fn_value,
       CASE WHEN abs((SELECT refund_rate_pay_time FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店')) - SUM(refund_amount_pay_time)/NULLIF(SUM(user_pay_amount),0)) < 0.000001
            THEN 'PASS(函数=加权,非AVG)' ELSE 'FAIL' END AS verdict
FROM daily;

-- 阶段2验收D: source_only专项
\echo ===== D1. 单日(06-12) source_only 返回源值 =====
SELECT ship_within_2_days_rate AS 两日发货率, one_hour_refund_rate_pay_time AS "1小时退款率",
       pre_shipment_refund_rate_pay_time AS 发货前退款率, source_only_note
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-12','2026-06-12','全店');

\echo ===== D2. 单日源值 vs core原值核对 =====
SELECT f.ship_within_2_days_rate AS fn_2d, d.ship_within_2_days_rate AS raw_2d,
       f.pre_shipment_refund_rate_pay_time AS fn_pre, d.pre_shipment_refund_rate_pay_time AS raw_pre,
       CASE WHEN abs(f.ship_within_2_days_rate - d.ship_within_2_days_rate) < 0.0000001
            THEN 'PASS(单日=源值)' ELSE 'FAIL' END AS verdict
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-12','2026-06-12','全店') f
JOIN core.douyin_deal_daily d ON d.biz_date = f.start_date
  AND d.sale_scope=f.sale_scope AND d.carrier_type=f.carrier_type AND d.ad_period=f.ad_period;

\echo ===== D3. 30天 source_only 必须 NULL =====
SELECT ship_within_2_days_rate AS 两日发货率_30d,
       one_hour_refund_rate_pay_time AS "1小时退款率_30d",
       pre_shipment_refund_rate_pay_time AS 发货前退款率_30d,
       source_only_note
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');
