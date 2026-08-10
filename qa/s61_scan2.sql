-- 阶段6.1: 精确检查动态SQL + 同名重载 + 引用schema前缀
\echo '===== 6. 同名函数重载检查 (mart) ====='
SELECT proname, count(*) AS overload_cnt
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart'
GROUP BY proname HAVING count(*) > 1;

\echo ''
\echo '===== 7. SECURITY DEFINER 函数体动态SQL检查 (EXECUTE/format 模式) ====='
SELECT p.oid::regprocedure AS function_signature,
       (pg_get_functiondef(p.oid) ~* 'EXECUTE\s+(format|''|QUERY|IMMEDIATE)' OR pg_get_functiondef(p.oid) ~* 'format\(') AS dyn_sql_flag
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='mart' AND p.prosecdef
ORDER BY p.proname;

\echo ''
\echo '===== 8. PUBLIC 对 public schema 的 CREATE (用于评估调用者可控 search_path 风险) ====='
SELECT n.nspname, has_schema_privilege('public', n.oid, 'CREATE') AS public_create
FROM pg_namespace n WHERE n.nspname='public';
