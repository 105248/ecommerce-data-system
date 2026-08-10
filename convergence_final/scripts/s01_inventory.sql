-- ============================================================
-- s01_inventory.sql  完整对象盘点 V2（pg_class 视角，超级用户可见全部）
-- 输出: schema|object|type|owner|comment|estimated_rows|detail
-- 对象类型: TABLE / VIEW / MATERIALIZED_VIEW / SEQUENCE / INDEX / CONSTRAINT_* / TRIGGER
-- ============================================================
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'

-- 表 / 视图 / 物化视图 / 序列 / 外部表
SELECT n.nspname AS schema_name,
       c.relname AS object_name,
       CASE c.relkind
         WHEN 'r' THEN 'TABLE'
         WHEN 'p' THEN 'TABLE_PARTITIONED'
         WHEN 'v' THEN 'VIEW'
         WHEN 'm' THEN 'MATERIALIZED_VIEW'
         WHEN 'S' THEN 'SEQUENCE'
         WHEN 'f' THEN 'FOREIGN_TABLE'
         ELSE 'RELKIND_' || c.relkind::text END AS object_type,
       pg_get_userbyid(c.relowner) AS owner,
       COALESCE(obj_description(c.oid, 'pg_class'), '') AS comment,
       CASE WHEN c.relkind IN ('r','p','m') THEN c.reltuples::bigint ELSE NULL END AS estimated_rows,
       '' AS detail
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r','p','v','m','S','f')
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND n.nspname NOT LIKE 'pg_temp%'
ORDER BY 1, c.relkind, 2;

-- 触发器
SELECT n.nspname AS schema_name,
       t.tgname  AS object_name,
       'TRIGGER' AS object_type,
       pg_get_userbyid(c.relowner) AS owner,
       '' AS comment,
       NULL AS estimated_rows,
       'table=' || c.relname::text || ';event_bits=' || t.tgtype::int AS detail
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT t.tgisinternal
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY 1, 2;

-- 用户索引
SELECT n.nspname AS schema_name,
       ic.relname AS object_name,
       'INDEX' AS object_type,
       pg_get_userbyid(ic.relowner) AS owner,
       '' AS comment,
       NULL AS estimated_rows,
       'table=' || t.relname::text || ';unique=' || ix.indisunique || ';primary=' || ix.indisprimary || ';def=' || pg_get_indexdef(ix.indexrelid) AS detail
FROM pg_index ix
JOIN pg_class ic ON ic.oid = ix.indexrelid
JOIN pg_class t ON t.oid = ix.indrelid
JOIN pg_namespace n ON n.oid = ic.relnamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND NOT ix.indisprimary
ORDER BY 1, 2;

-- 约束（PK 通过 INDEX primary 已排除，此处单独列出 PK/FK/UNIQUE/CHECK）
SELECT n.nspname AS schema_name,
       con.conname AS object_name,
       CASE con.contype
         WHEN 'p' THEN 'CONSTRAINT_PRIMARY_KEY'
         WHEN 'f' THEN 'CONSTRAINT_FOREIGN_KEY'
         WHEN 'u' THEN 'CONSTRAINT_UNIQUE'
         WHEN 'c' THEN 'CONSTRAINT_CHECK'
         WHEN 'x' THEN 'CONSTRAINT_EXCLUDE'
         ELSE 'CONSTRAINT' END AS object_type,
       pg_get_userbyid(c.relowner) AS owner,
       '' AS comment,
       NULL AS estimated_rows,
       'table=' || c.relname::text || ';def=' || pg_get_constraintdef(con.oid) AS detail
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = con.connamespace
WHERE con.contype IN ('p','f','u','c')
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY 1, 2;
