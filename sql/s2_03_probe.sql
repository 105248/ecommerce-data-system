-- 阶段2探查3: resolve_scope 签名 + shop_daily 字段 + 治理表样例
SELECT p.proname, pg_get_function_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS result
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname='mart' AND p.proname IN ('resolve_scope','scope_daily')
ORDER BY p.proname;

\echo ====== mart.shop_daily 字段 ======
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='mart' AND table_name='shop_daily' ORDER BY ordinal_position;

\echo ====== mart_dimension_rule 样例 ======
SELECT rule_id, dimension_name, dimension_value, rule_type,
       aggregation_allowed, preferred_total, rule_status
FROM mart.mart_dimension_rule
WHERE dimension_name IN ('sale_scope','carrier_type','ad_period','terminal_type')
ORDER BY dimension_name, rule_id LIMIT 20;
