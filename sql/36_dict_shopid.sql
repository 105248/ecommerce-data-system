-- 检查字典中 shop_id 状态
SELECT schema_name, object_name, column_name, column_name_cn,
       chinese_name_source, name_resolution_status
FROM meta.database_object_dictionary
WHERE column_name = 'shop_id' AND object_type = 'column' AND schema_name IN ('core','audit')
ORDER BY schema_name, object_name LIMIT 12;
