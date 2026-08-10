-- s06_function_sources.sql  提取全部函数源码（供依赖静态分析）
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|||'
SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid), p.prosrc
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND p.prokind IN ('f','p')
  AND n.nspname IN ('mart','meta','audit','core','stg','public')
ORDER BY 1, 2;
