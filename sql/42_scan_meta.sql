-- mart 阶段0 扫描：每张表的基础信息
SELECT table_name,
       count(*) AS row_count
FROM information_schema.columns
WHERE table_schema = 'core'
GROUP BY table_name ORDER BY table_name;
