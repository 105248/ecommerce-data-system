-- 核心验收
-- 1. 比例原值保真: 中文View中 0.1972 / 9.625 必须保持
SELECT '0.1972保真' AS chk, "商品点击-成交转化率(人数)"::text AS val
FROM "中文数据"."抖音成交日报" WHERE "源文件行号" = 2 AND "成交范围" = '全部';

SELECT '9.625保真' AS chk, "商品点击-成交转化率(人数)"::text AS val
FROM "中文数据"."抖音成交日报" WHERE "源文件行号" = 8 AND "成交范围" = '全部';

-- 2. 字段覆盖率: 物理表字段数 vs 中文View字段数 对比
SELECT '核心表字段覆盖对比' AS chk,
    (SELECT count(*) FROM information_schema.columns WHERE table_schema='core' AND table_name='douyin_deal_daily') AS 物理,
    (SELECT count(*) FROM information_schema.columns WHERE table_schema='中文数据' AND table_name='抖音成交日报') AS 中文;

-- 3. 中文View字段名 = 源表头验证(抽查3个)
SELECT '源表头还原' AS chk, "商品点击-成交转化率(次数)"::text AS val
FROM "中文数据"."抖音载体日报" LIMIT 1;

-- 4. 字典溯源统计
SELECT chinese_name_source, name_resolution_status, count(*)
FROM meta.database_object_dictionary
GROUP BY chinese_name_source, name_resolution_status ORDER BY 3 DESC;
