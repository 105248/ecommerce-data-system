-- 冲突分析: 同一正式字段对应多个不同源中文表头
SELECT target_schema, target_table, target_column_name,
       count(DISTINCT source_sheet_name) AS sheet_cnt,
       count(DISTINCT source_column_name) AS header_cnt,
       string_agg(DISTINCT source_sheet_name || '=' || source_column_name, ' ; ' ORDER BY source_sheet_name || '=' || source_column_name) AS variants
FROM meta.field_mapping
WHERE enabled = TRUE
GROUP BY target_schema, target_table, target_column_name
HAVING count(DISTINCT source_column_name) > 1
ORDER BY header_cnt DESC;
