-- 阶段2验收B: 单日=DailyMart一致; 7天=7天SUM; 30天=月口径
\echo ===== B1. 单日(06-12) vs mart.shop_daily =====
SELECT f.user_pay_amount AS fn_pay, d.user_pay_amount AS daily_pay,
       f.transaction_amount AS fn_txn, d.transaction_amount AS daily_txn,
       f.transaction_order_count AS fn_ord, d.transaction_order_count AS daily_ord,
       CASE WHEN abs(f.user_pay_amount - d.user_pay_amount) < 0.01
             AND abs(f.transaction_amount - d.transaction_amount) < 0.01
            THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-12','2026-06-12','全店') f
JOIN mart.shop_daily d ON d.shop_name = f.shop_name AND d.biz_date = f.start_date;

\echo ===== B2. 7天(06-08~06-14) vs 直接7天SUM(可加指标) =====
SELECT f.user_pay_amount AS fn_pay,
       (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
        JOIN meta.shop sh ON d.shop_id=sh.shop_id
        WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='全部'
          AND d.ad_period='不限' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14') AS sql_pay,
       f.transaction_order_count AS fn_ord,
       (SELECT SUM(d.transaction_order_count) FROM core.douyin_deal_daily d
        JOIN meta.shop sh ON d.shop_id=sh.shop_id
        WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='全部'
          AND d.ad_period='不限' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14') AS sql_ord,
       CASE WHEN abs(f.user_pay_amount - (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
                JOIN meta.shop sh ON d.shop_id=sh.shop_id
                WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='全部'
                  AND d.ad_period='不限' AND d.biz_date BETWEEN '2026-06-08' AND '2026-06-14')) < 0.01
            THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-08','2026-06-14','全店') f;

\echo ===== B3. 7天客单价(非可加, V1.4加权) vs 直接SQL =====
SELECT f.avg_customer_amount AS fn_ac,
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

\echo ===== B4. 30天全店 vs 月总口径 =====
SELECT f.user_pay_amount AS fn_pay,
       (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
        JOIN meta.shop sh ON d.shop_id=sh.shop_id
        WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='全部'
          AND d.ad_period='不限' AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30') AS sql_pay,
       CASE WHEN abs(f.user_pay_amount - (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
                JOIN meta.shop sh ON d.shop_id=sh.shop_id
                WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='全部'
                  AND d.ad_period='不限' AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30')) < 0.01
            THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店') f;
