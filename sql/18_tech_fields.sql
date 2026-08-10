-- 技术字段(无源表头)与mart检查
SELECT '== 无源映射的core技术字段 ==' AS info;
SELECT c.table_name, c.column_name, c.ordinal_position
FROM information_schema.columns c
WHERE c.table_schema = 'core'
  AND NOT EXISTS (SELECT 1 FROM meta.field_mapping fm
                  WHERE fm.target_table = c.table_name AND fm.target_column_name = c.column_name AND fm.enabled = TRUE)
ORDER BY c.table_name, c.ordinal_position;

SELECT '== mart schema 对象 ==' AS info;
SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = 'mart';

SELECT '== meta/audit 需中文化的表 ==' AS info;
SELECT table_schema, table_name FROM information_schema.tables
WHERE table_schema IN ('meta','audit') AND table_type = 'BASE TABLE' ORDER BY table_schema, table_name;
