-- 最终验收：店铺名称覆盖
SELECT '== 中文业务View中 店铺名称 覆盖(应9+1=10) ==' AS info;
SELECT table_name FROM information_schema.columns
WHERE table_schema = '中文数据' AND column_name = '店铺名称'
  AND table_name != '店铺信息'
ORDER BY table_name;

SELECT '== 中文业务View中 残留店铺ID(应0) ==' AS info;
SELECT table_name FROM information_schema.columns
WHERE table_schema = '中文数据' AND column_name = '店铺ID'
  AND table_name != '店铺信息'
ORDER BY table_name;

SELECT '== 查询验证: 抖音商品日报 ==' AS info;
SELECT "店铺名称", "日期", "用户支付金额"
FROM "中文数据"."抖音商品日报" LIMIT 3;

SELECT '== 查询验证: 抖音成交日报(比例原值) ==' AS info;
SELECT "店铺名称", "商品点击-成交转化率(人数)"
FROM "中文数据"."抖音成交日报"
WHERE "源文件行号" IN (2, 8) AND "成交范围" = '全部';

SELECT '== core 总行数 ==' AS info;
SELECT (SELECT count(*) FROM core.douyin_deal_daily) +
       (SELECT count(*) FROM core.douyin_carrier_daily) +
       (SELECT count(*) FROM core.douyin_account_daily) +
       (SELECT count(*) FROM core.douyin_content_daily) +
       (SELECT count(*) FROM core.douyin_terminal_daily) +
       (SELECT count(*) FROM core.douyin_category_daily) +
       (SELECT count(*) FROM core.douyin_product_daily) +
       (SELECT count(*) FROM core.douyin_price_band_daily) +
       (SELECT count(*) FROM core.douyin_audience_daily) AS total;

SELECT '== core 仍含 shop_id ==' AS info;
SELECT count(*) FROM information_schema.columns
WHERE column_name = 'shop_id' AND table_schema = 'core';
