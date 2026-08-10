SELECT column_name || '|' || column_name_cn
FROM meta.database_object_dictionary
WHERE schema_name = 'core' AND object_name = 'douyin_deal_daily'
  AND object_type = 'column' AND enabled = TRUE
ORDER BY display_order;
