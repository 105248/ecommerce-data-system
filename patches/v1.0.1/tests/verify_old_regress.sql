-- V1.0.1 验收: 旧V1.0数字回归 + 新投放指标
\echo '===== 1. 旧V1.0核心数字回归 (必须不变) ====='
SELECT scope_key, user_pay_amount
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');
SELECT '商品卡' AS scope, user_pay_amount FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','商品卡')
UNION ALL SELECT '自营', user_pay_amount FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','自营')
UNION ALL SELECT '合作', user_pay_amount FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','合作');

\echo ''
\echo '===== 2. 退款率/客单价回归 ====='
SELECT refund_rate_pay_time, avg_customer_amount
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

\echo ''
\echo '===== 3. 新10投放指标 (全店30天, batch9后应有值) ====='
SELECT ad_spend_shop_promoted, ad_spend_shop_bound, ad_attributed_transaction_amount,
       round(ad_attributed_transaction_share, 6) AS share,
       round(ad_spend_rate_net_refund_shop_bound, 6) AS spend_rate,
       round(total_expense_rate_net_refund_shop_bound, 6) AS expense_rate,
       round(ad_efficiency_shop_promoted, 4) AS ad_eff_promo,
       round(ad_efficiency_shop_bound, 4) AS ad_eff_bound,
       round(store_efficiency_shop_promoted, 4) AS store_eff_promo,
       round(store_efficiency_shop_bound, 4) AS store_eff_bound
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

\echo ''
\echo '===== 4. 商品排名/贡献度回归 ====='
SELECT product_name, current_value
FROM mart.rank_products('弹动官方旗舰店','2026-06-01','2026-06-30','user_pay_amount','current_value','DESC',3,NULL,NULL);
\echo '--- 商品卡贡献度 ---'
SELECT carrier_type, contribution_to_scope
FROM mart.get_business_contribution('弹动官方旗舰店','2026-06-01','2026-06-30','全店')
ORDER BY contribution_to_scope DESC LIMIT 3;

\echo ''
\echo '===== 5. core 9表行数 ====='
SELECT
  (SELECT count(*) FROM core.douyin_deal_daily)+(SELECT count(*) FROM core.douyin_carrier_daily)+(SELECT count(*) FROM core.douyin_account_daily)+(SELECT count(*) FROM core.douyin_content_daily)+(SELECT count(*) FROM core.douyin_terminal_daily)+(SELECT count(*) FROM core.douyin_category_daily)+(SELECT count(*) FROM core.douyin_product_daily)+(SELECT count(*) FROM core.douyin_price_band_daily)+(SELECT count(*) FROM core.douyin_audience_daily) AS core_total;
