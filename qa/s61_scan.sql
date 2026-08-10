-- 阶段6.1: SECURITY DEFINER 函数安全属性扫描
\echo '===== 1. mart schema SECURITY DEFINER 函数清单 ====='
SELECT p.oid::regprocedure AS function_signature,
       pg_get_userbyid(p.proowner) AS owner,
       p.prosecdef AS prosecdef,
       COALESCE(p.proconfig::text, '(NULL - 未设置, 默认继承search_path)') AS proconfig,
       pg_get_functiondef(p.oid) LIKE '%EXECUTE format%' OR pg_get_functiondef(p.oid) LIKE '%EXECUTE ''%' OR pg_get_functiondef(p.oid) LIKE '%format(%' AS uses_dynamic_sql
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'mart' AND p.prosecdef
ORDER BY p.proname;

\echo ''
\echo '===== 2. PUBLIC 对 mart/core/meta/audit 的 CREATE 权限 ====='
SELECT n.nspname AS schema,
       has_schema_privilege('public', n.oid, 'CREATE') AS public_can_create
FROM pg_namespace n
WHERE n.nspname IN ('mart','core','meta','audit')
ORDER BY 1;

\echo ''
\echo '===== 3. PUBLIC 获得的 EXECUTE 权限 (mart 函数) ====='
SELECT DISTINCT p.oid::regprocedure AS function_signature,
       has_function_privilege('public', p.oid, 'EXECUTE') AS public_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'mart'
ORDER BY 1;

\echo ''
\echo '===== 4. agent_readonly 对 mart 函数的 EXECUTE 权限 ====='
SELECT p.oid::regprocedure AS function_signature,
       has_function_privilege('agent_readonly', p.oid, 'EXECUTE') AS ro_execute
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'mart'
ORDER BY 1;

\echo ''
\echo '===== 5. agent_readonly 对 core 的直接 SELECT 权限 ====='
SELECT has_table_privilege('agent_readonly', 'core.douyin_deal_daily', 'SELECT') AS can_select_core_deal,
       has_schema_privilege('agent_readonly', 'core', 'USAGE') AS can_usage_core;
