-- 查看 抖音商品日报 的实际视图定义
SELECT view_definition FROM information_schema.views
WHERE table_schema = '中文数据' AND table_name = '抖音商品日报';
