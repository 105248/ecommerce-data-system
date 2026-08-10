-- 找出中文名为空的字段（用于修复28）
SELECT d.schema_name, d.object_name, d.column_name, d.column_name_cn
FROM meta.database_object_dictionary d
WHERE d.object_type = 'column' AND d.enabled = TRUE
  AND (d.column_name_cn IS NULL OR d.column_name_cn = '')
  AND d.schema_name IN ('core', 'audit');
