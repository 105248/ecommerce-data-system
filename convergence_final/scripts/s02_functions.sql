-- ============================================================
-- s02_functions.sql  函数/过程盘点
-- 输出列: schema_name|object_name|object_type|owner|comment|argument_summary
-- ============================================================
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'

SELECT n.nspname AS schema_name,
       p.proname AS object_name,
       CASE p.prokind
         WHEN 'f' THEN 'FUNCTION'
         WHEN 'p' THEN 'PROCEDURE'
         WHEN 'a' THEN 'AGGREGATE'
         WHEN 'w' THEN 'WINDOW'
         ELSE 'FUNCTION' END AS object_type,
       pg_get_userbyid(p.proowner) AS owner,
       COALESCE(obj_description(p.oid, 'pg_proc'), '') AS comment,
       pg_get_function_identity_arguments(p.oid) AS argument_summary
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND n.nspname NOT LIKE 'pg_temp%'
  AND p.prokind IN ('f','p')
ORDER BY 1, 2;
