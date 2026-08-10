-- 诊断 core/stg/public/中文数据 对象（所有对象类型）
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'
SELECT n.nspname, c.relname, c.relkind
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND n.nspname NOT LIKE 'pg_temp%'
ORDER BY 1, c.relkind, 2;
