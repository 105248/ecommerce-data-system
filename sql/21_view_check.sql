-- 中文数据 View 验证
SELECT table_name FROM information_schema.views
WHERE table_schema = '中文数据' ORDER BY table_name;

SELECT table_name, count(*) AS column_count
FROM information_schema.columns
WHERE table_schema = '中文数据'
GROUP BY table_name ORDER BY table_name;
