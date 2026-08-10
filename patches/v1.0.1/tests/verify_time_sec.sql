-- V1.0.1: 时间窗口测试 + 安全复测
\echo '===== 1. 投放指标 1/3/7/15/30天 (全店 投放消耗绑定 + 投放贡献占比) ====='
SELECT '1天' AS win, ad_spend_shop_bound, round(ad_attributed_transaction_share,6) AS share FROM mart.get_advertising_period_summary('弹动官方旗舰店','2026-06-05','2026-06-05','全店')
UNION ALL SELECT '3天', ad_spend_shop_bound, round(ad_attributed_transaction_share,6) FROM mart.get_advertising_period_summary('弹动官方旗舰店','2026-06-03','2026-06-05','全店')
UNION ALL SELECT '7天', ad_spend_shop_bound, round(ad_attributed_transaction_share,6) FROM mart.get_advertising_period_summary('弹动官方旗舰店','2026-06-01','2026-06-07','全店')
UNION ALL SELECT '15天', ad_spend_shop_bound, round(ad_attributed_transaction_share,6) FROM mart.get_advertising_period_summary('弹动官方旗舰店','2026-06-01','2026-06-15','全店')
UNION ALL SELECT '30天', ad_spend_shop_bound, round(ad_attributed_transaction_share,6) FROM mart.get_advertising_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

\echo ''
\echo '===== 2. 单日=平台源值 / 7天=加权非AVG 证明 ===='
\echo '--- 7天加权 vs AVG(日值) 差异 ---'
SELECT
  sum(ad_spend_shop_bound) AS 7天SUM,
  round(sum(total_expense_rate_net_refund_shop_bound*settlement_amount)/NULLIF(sum(settlement_amount),0),6) AS 综合费比加权,
  round(avg(total_expense_rate_net_refund_shop_bound),6) AS 综合费比AVG日值,
  round((sum(total_expense_rate_net_refund_shop_bound*settlement_amount)/NULLIF(sum(settlement_amount),0)) - avg(total_expense_rate_net_refund_shop_bound), 6) AS 差值
FROM core.douyin_deal_daily
WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-07' AND sale_scope='全部' AND carrier_type='全部' AND ad_period='不限';

\echo ''
\echo '===== 3. 安全: 新函数 SECURITY DEFINER + search_path + PUBLIC EXECUTE ====='
SELECT p.oid::regprocedure AS fn, p.prosecdef, p.proconfig
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart' AND p.proname IN ('get_advertising_period_summary','compare_advertising_period');
\echo '--- PUBLIC EXECUTE (应f) ---'
SELECT p.oid::regprocedure, has_function_privilege('public', p.oid, 'EXECUTE') AS pub_exec
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart' AND p.proname IN ('get_advertising_period_summary','compare_advertising_period');
\echo '--- agent_readonly EXECUTE (应t) ---'
SELECT p.oid::regprocedure, has_function_privilege('agent_readonly', p.oid, 'EXECUTE') AS ro_exec
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart' AND p.proname IN ('get_advertising_period_summary','compare_advertising_period');
