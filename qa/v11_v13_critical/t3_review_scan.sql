-- 第三步：REVIEW 对象依赖检查（metric_rule_v14 / format_percent_2）
\pset pager off
\echo '=== 1. format_percent_2 对象类型 ==='
SELECT c.relname, c.relkind FROM pg_class c WHERE c.relname='format_percent_2';
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) args
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE p.proname LIKE 'format_percent%';
\echo '=== 2. metric_rule_v14 被函数引用（prosrc） ==='
SELECT p.proname FROM pg_proc p WHERE p.prosrc LIKE '%metric_rule_v14%';
\echo '=== 3. metric_rule_v14 被视图引用 ==='
SELECT v.table_name FROM information_schema.views v WHERE v.view_definition LIKE '%metric_rule_v14%';
\echo '=== 4. format_percent 被函数/视图引用 ==='
SELECT p.proname FROM pg_proc p WHERE p.prosrc LIKE '%format_percent%';
\echo '=== 5. metric_rule_v14 依赖的下游对象（pg_depend） ==='
SELECT DISTINCT c2.relname, n2.nspname FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class c ON c.oid = r.ev_class AND c.relname='metric_rule_v14'
JOIN pg_class c2 ON c2.oid = d.refobjid
JOIN pg_namespace n2 ON n2.oid = c2.relnamespace;
