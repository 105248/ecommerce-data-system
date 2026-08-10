-- 验证所有中文业务 View 的店铺列
SELECT '== 含店铺名称的View ==' AS info;
SELECT table_name
FROM information_schema.columns
WHERE table_schema = '中文数据' AND column_name = '店铺名称'
ORDER BY table_name;

SELECT '== 仍含店铺ID的View(应只剩店铺信息) ==' AS info;
SELECT table_name
FROM information_schema.columns
WHERE table_schema = '中文数据' AND column_name = '店铺ID'
ORDER BY table_name;

SELECT '== 店铺名称查询验证 ==' AS info;
SELECT "店铺名称", "日期", "用户支付金额"
FROM "中文数据"."抖音商品日报" LIMIT 3;

SELECT '== 导入批次记录 ==' AS info;
SELECT "店铺名称", "导入批次ID", "导入状态"
FROM "中文数据"."导入批次记录";
