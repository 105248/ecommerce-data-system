\echo '=== 治理表是否引用旧ad_period值 (全域投放时段) ==='
SELECT dimension_name, dimension_value, rule_type, rule_status
FROM mart.mart_dimension_rule
WHERE dimension_value LIKE '%全域%' OR dimension_value LIKE '%投放时段%';

\echo ''
\echo '=== period_scope_rule 定义中是否含旧值 ==='
SELECT count(*) AS ref_cnt
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart' AND p.proname='period_scope_rule'
  AND pg_get_functiondef(p.oid) LIKE '%全域投放时段%';

\echo ''
\echo '=== resolve_scope 定义中是否含旧值 ==='
SELECT count(*) AS ref_cnt
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart' AND p.proname='resolve_scope'
  AND pg_get_functiondef(p.oid) LIKE '%全域投放时段%';

\echo ''
\echo '=== 当前库中 ad_period distinct 值 ==='
SELECT DISTINCT ad_period FROM core.douyin_deal_daily ORDER BY 1;
