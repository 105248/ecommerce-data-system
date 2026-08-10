-- 视图对表的依赖
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'
SELECT onsp.nspname AS v_schema, oc.relname AS view_name,
       dn.nspname AS t_schema, dc.relname AS table_name,
       d.deptype, d.objsubid, d.refobjsubid
FROM pg_depend d
JOIN pg_class oc ON oc.oid = d.objid
JOIN pg_namespace onsp ON onsp.oid = oc.relnamespace
JOIN pg_class dc ON dc.oid = d.refobjid
JOIN pg_namespace dn ON dn.oid = dc.relnamespace
WHERE oc.relkind = 'v'
  AND dc.relkind IN ('r','v','m','S','f')
  AND onsp.nspname NOT IN ('pg_catalog','information_schema')
  AND dn.nspname NOT IN ('pg_catalog','information_schema')
LIMIT 10;
