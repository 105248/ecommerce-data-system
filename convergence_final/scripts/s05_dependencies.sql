-- s05_dependencies.sql  对象依赖关系（完整版：视图经 pg_rewrite，函数直连）
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'

-- 视图/物化视图 → 表/视图（经 pg_rewrite）
SELECT onsp.nspname AS schema_name,
       oc.relname  AS object_name,
       'VIEW' AS object_type,
       dn.nspname AS dep_schema,
       dc.relname AS dep_object,
       CASE dc.relkind WHEN 'r' THEN 'TABLE' WHEN 'v' THEN 'VIEW'
            WHEN 'm' THEN 'MATERIALIZED_VIEW' WHEN 'S' THEN 'SEQUENCE'
            ELSE dc.relkind::text END AS dep_type
FROM pg_depend d
JOIN pg_rewrite rw ON rw.oid = d.objid
JOIN pg_class oc ON oc.oid = rw.ev_class
JOIN pg_namespace onsp ON onsp.oid = oc.relnamespace
JOIN pg_class dc ON dc.oid = d.refobjid
JOIN pg_namespace dn ON dn.oid = dc.relnamespace
WHERE d.deptype = 'n'
  AND oc.relkind IN ('v','m')
  AND dc.relkind IN ('r','v','m','S','f')
  AND onsp.nspname NOT IN ('pg_catalog','information_schema')
  AND dn.nspname NOT IN ('pg_catalog','information_schema')
UNION ALL
-- 函数/过程 → 表/视图
SELECT onsp.nspname, oc.proname, 'FUNCTION',
       dn.nspname, dc.relname,
       CASE dc.relkind WHEN 'r' THEN 'TABLE' WHEN 'v' THEN 'VIEW'
            WHEN 'm' THEN 'MATERIALIZED_VIEW' WHEN 'S' THEN 'SEQUENCE'
            ELSE dc.relkind::text END
FROM pg_depend d
JOIN pg_proc oc ON oc.oid = d.objid
JOIN pg_namespace onsp ON onsp.oid = oc.pronamespace
JOIN pg_class dc ON dc.oid = d.refobjid
JOIN pg_namespace dn ON dn.oid = dc.relnamespace
WHERE d.deptype = 'n'
  AND dc.relkind IN ('r','v','m','S','f')
  AND onsp.nspname NOT IN ('pg_catalog','information_schema')
  AND dn.nspname NOT IN ('pg_catalog','information_schema')
  AND oc.prokind IN ('f','p')
ORDER BY 1, 2, 4, 5;
