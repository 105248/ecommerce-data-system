-- mart 阶段0 扫描：9张core表的维度字段识别
SELECT target_table,
       string_agg(target_column_name, '|' ORDER BY source_column_order) AS dim_columns
FROM meta.field_mapping
WHERE field_category = '维度字段'
  AND target_schema = 'core'
  AND enabled = TRUE
GROUP BY target_table
ORDER BY target_table;
