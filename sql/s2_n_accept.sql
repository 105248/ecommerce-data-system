-- 阶段2正式验收: 提供SQL内置N1-N8
\echo ===== N1. core 总行数(应18809) =====
SELECT
    (SELECT COUNT(*) FROM core.douyin_deal_daily) +
    (SELECT COUNT(*) FROM core.douyin_carrier_daily) +
    (SELECT COUNT(*) FROM core.douyin_account_daily) +
    (SELECT COUNT(*) FROM core.douyin_content_daily) +
    (SELECT COUNT(*) FROM core.douyin_terminal_daily) +
    (SELECT COUNT(*) FROM core.douyin_category_daily) +
    (SELECT COUNT(*) FROM core.douyin_product_daily) +
    (SELECT COUNT(*) FROM core.douyin_price_band_daily) +
    (SELECT COUNT(*) FROM core.douyin_audience_daily) AS core_total_rows;

\echo ===== N2a. 全店30天 =====
SELECT scope_key, user_pay_amount, transaction_amount, refund_rate_pay_time, coverage_days, coverage_complete
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

\echo ===== N2b. 商品卡30天 =====
SELECT scope_key, user_pay_amount, transaction_amount, refund_rate_pay_time, coverage_days, coverage_complete
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','商品卡');

\echo ===== N2c. 合作短视频30天 =====
SELECT scope_key, user_pay_amount, transaction_amount, refund_rate_pay_time, coverage_days, coverage_complete
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','合作短视频');

\echo ===== N3. 退款率: 加权 vs AVG(日比例) =====
WITH daily AS (
    SELECT refund_rate_pay_time, refund_amount_pay_time, user_pay_amount
    FROM core.douyin_deal_daily d
    JOIN meta.shop s ON s.shop_id=d.shop_id
    WHERE s.shop_name='弹动官方旗舰店'
      AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30'
      AND d.sale_scope='全部' AND d.carrier_type='全部' AND d.ad_period='不限'
)
SELECT
    SUM(refund_amount_pay_time)/NULLIF(SUM(user_pay_amount),0) AS weighted_correct,
    AVG(refund_rate_pay_time) AS avg_daily_wrong,
    SUM(refund_amount_pay_time)/NULLIF(SUM(user_pay_amount),0) - AVG(refund_rate_pay_time) AS difference
FROM daily;

\echo ===== N4a. source_only 单日(06-01) =====
SELECT start_date,end_date,ship_within_2_days_rate,one_hour_refund_rate_pay_time,unrecalculable_metrics
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-01','全店');

\echo ===== N4b. source_only 30天(应NULL) =====
SELECT start_date,end_date,ship_within_2_days_rate,one_hour_refund_rate_pay_time,unrecalculable_metrics
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

\echo ===== N5. 商品默认 carrier=全部(独立TOTAL) =====
SELECT product_id,product_name,carrier_type,user_pay_amount,refund_rate_pay_time
FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',NULL,NULL,'全部')
ORDER BY user_pay_amount DESC NULLS LAST LIMIT 3;

\echo ===== N6. 类目 L3 =====
SELECT category_level,category_l1,category_l2,category_l3,user_pay_amount
FROM mart.get_category_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',3,NULL,NULL,NULL)
ORDER BY user_pay_amount DESC NULLS LAST LIMIT 3;

\echo ===== N7. 价格带求和 vs 全店TOTAL =====
WITH pb AS (
    SELECT SUM(user_pay_amount) AS v
    FROM mart.get_price_band_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',NULL)
), st AS (
    SELECT user_pay_amount AS v
    FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店')
)
SELECT pb.v AS price_band_sum, st.v AS store_total, pb.v-st.v AS diff
FROM pb CROSS JOIN st;

\echo ===== N8. 人群 carrier=全部 =====
SELECT audience_type,carrier_type,user_pay_amount,avg_customer_amount,repeat_user_repeat_rate
FROM mart.get_audience_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',NULL,'全部');
