-- 视图依赖诊断
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'
SELECT d.deptype, d.objsubid, d.refobjsubid, count(*)
FROM pg_depend d
JOIN pg_rewrite rw ON rw.oid = d.objid
JOIN pg_class oc ON oc.oid = rw.ev_class
JOIN pg_class dc ON dc.oid = d.refobjid
WHERE oc.relkind IN ('v','m')
  AND dc.relkind IN ('r','v','m','S','f')
GROUP BY 1,2,3 ORDER BY 1,2,3;
