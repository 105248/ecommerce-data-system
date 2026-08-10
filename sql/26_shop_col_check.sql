SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = '中文数据'
  AND (column_name LIKE '%店铺%' OR column_name LIKE '%shop%')
ORDER BY table_name, ordinal_position;
