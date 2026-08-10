-- ============================================================
-- s03_triggers_sequences.sql  触发器/序列/索引/约束盘点
-- 输出列: schema_name|object_name|object_type|owner|comment|detail
-- ============================================================
\pset format unaligned
\pset tuples_only on
\pset fieldsep '|'

-- 触发器
SELECT n.nspname AS schema_name,
       t.tgname  AS object_name,
       'TRIGGER' AS object_type,
       pg_get_userbyid(c.relowner) AS owner,
       '' AS comment,
       'table=' || c.relname || ';event=' || t.tgtype::int AS detail
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE NOT t.tgisinternal
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY 1, 2;

-- 序列
SELECT n.nspname AS schema_name,
       c.relname AS object_name,
       'SEQUENCE' AS object_type,
       pg_get_userbyid(c.relowner) AS owner,
       COALESCE(obj_description(c.oid,'pg_class'),'') AS comment,
       '' AS detail
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'S'
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY 1, 2;

-- 索引（仅用户索引）
SELECT n.nspname AS schema_name,
       ic.relname AS object_name,
       'INDEX' AS object_type,
       pg_get_userbyid(ic.relowner) AS owner,
       '' AS comment,
       'table=' || t.relname || ';unique=' || ix.indisunique || ';primary=' || ix.indisprimary || ';definition=' || pg_get_indexdef(i.indexrelid) AS detail
FROM pg_index ix
JOIN pg_class ic ON ic.oid = ix.indexrelid
JOIN pg_class t ON t.oid = ix.indrelid
JOIN pg_namespace n ON n.oid = ic.relnamespace
WHERE n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND ix.indisprimary = false
ORDER BY 1, 2;

-- 约束（PK/FK/UNIQUE/CHECK）
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
       'table=' || c.relname || ';definition=' || pg_get_constraintdef(con.oid) AS detail
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = con.connamespace
WHERE con.contype IN ('p','f','u','c')
  AND n.nspname NOT IN ('pg_catalog','information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
ORDER BY 1, 2;
