SELECT d.column_name, d.column_name_cn
FROM meta.database_object_dictionary d
WHERE d.schema_name = 'audit' AND d.object_name = 'import_batch'
  AND d.object_type = 'column' AND d.enabled = TRUE
ORDER BY d.display_order;
