-- 阶段6.1 复测1: 修复后核心函数回归 (search_path 固定不影响业务)
\echo '===== A. get_business_period_summary 全店30天 (应=9397490.90) ====='
SELECT shop_name, expected_days, coverage_days, coverage_complete,
       user_pay_amount, transaction_amount, refund_rate_pay_time
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

\echo ''
\echo '===== B. get_data_coverage (应正常返回) ====='
SELECT * FROM mart.get_data_coverage('弹动官方旗舰店');

\echo ''
\echo '===== C. 修复后 agent_readonly 读操作 ====='
\connect ecommerce_db agent_readonly
SELECT shop_name, day_count FROM mart.get_data_coverage(NULL);
