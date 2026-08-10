-- 诊断 pg_depend deptype 分布
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'
SELECT d.deptype, count(*)
FROM pg_depend d
WHERE d.refobjid IN (SELECT c.oid FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                     WHERE n.nspname IN ('core','meta','audit','mart','stg'))
GROUP BY 1 ORDER BY 1;
