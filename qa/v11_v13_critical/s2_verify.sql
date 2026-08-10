\pset pager off
\echo '=== 中文数据 schema 的 SKU 相关视图 ==='
SELECT table_name FROM information_schema.views WHERE table_schema='中文数据' AND (table_name LIKE '%SKU%' OR table_name LIKE '%sku%');
\echo '=== get_diagnostic_snapshot 函数体头部 ==='
SELECT left(prosrc, 1200) AS src_head FROM pg_proc WHERE proname='get_diagnostic_snapshot';
