-- 查看 deptype=n 且 refobjid 指向业务表的原始记录
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'
SELECT d.classid::regclass AS obj_class,
       d.objid,
       d.objsubid,
       dc.relname AS ref_obj,
       dn.nspname AS ref_schema,
       d.refobjsubid
FROM pg_depend d
JOIN pg_class dc ON dc.oid = d.refobjid
JOIN pg_namespace dn ON dn.oid = dc.relnamespace
WHERE d.deptype = 'n'
  AND dn.nspname IN ('core','meta','audit','mart')
LIMIT 15;
