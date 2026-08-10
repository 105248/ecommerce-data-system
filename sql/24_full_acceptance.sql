-- 完整验收
-- 1. 数据保真: 中文View行数 = 物理表行数
SELECT '成交日报行数' AS chk, (SELECT count(*) FROM core.douyin_deal_daily)::text || ' = ' ||
       (SELECT count(*) FROM "中文数据"."抖音成交日报") AS val
UNION ALL
SELECT '商品日报行数', (SELECT count(*) FROM core.douyin_product_daily)::text || ' = ' ||
       (SELECT count(*) FROM "中文数据"."抖音商品日报")
UNION ALL
SELECT '载体日报行数', (SELECT count(*) FROM core.douyin_carrier_daily)::text || ' = ' ||
       (SELECT count(*) FROM "中文数据"."抖音载体日报");

-- 2. 指标公式规则中文View
SELECT '指标公式规则中文View' AS chk,
       string_agg(column_name, ',' ORDER BY ordinal_position) AS fields
FROM information_schema.columns
WHERE table_schema = '中文数据' AND table_name = '指标公式规则';

-- 3. 数据库未受影响
SELECT 'core总行数不变' AS chk, (
  (SELECT count(*) FROM core.douyin_deal_daily) + (SELECT count(*) FROM core.douyin_carrier_daily)
)::text AS val;

-- 4. 字典覆盖率
SELECT '字典记录总数' AS chk, count(*)::text FROM meta.database_object_dictionary
UNION ALL
SELECT '字段中文名非空', count(*)::text FROM meta.database_object_dictionary WHERE column_name IS NOT NULL AND column_name_cn IS NOT NULL
UNION ALL
SELECT '无冲突', count(*)::text FROM meta.database_object_dictionary WHERE name_resolution_status = 'conflict_pending';
