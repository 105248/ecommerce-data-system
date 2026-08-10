-- 阶段0 进一步确认
-- 1. 载体构成: account_channel 的时段类值 与 carrier_type 交叉(判断是否为ad_period误入)
SELECT '载体 时段类值 × carrier_type' AS info;
SELECT carrier_type, account_channel, sale_scope, count(*) AS cnt
FROM core.douyin_carrier_daily
WHERE account_channel IN ('全域投放时段','标准+品牌投放','非投放时段','不限')
GROUP BY carrier_type, account_channel, sale_scope ORDER BY carrier_type, account_channel;

-- 2. 载体构成: 每 carrier_type 下 account_channel 的 distinct 数
SELECT '载体 各carrier下channel数' AS info;
SELECT carrier_type, count(DISTINCT account_channel) AS channels, count(*) AS rows_cnt
FROM core.douyin_carrier_daily GROUP BY carrier_type ORDER BY carrier_type;

-- 3. 载体构成: 每日组合数
SELECT '载体 每日组合数' AS info;
SELECT biz_date, count(*) AS combos FROM core.douyin_carrier_daily
GROUP BY biz_date ORDER BY biz_date LIMIT 3;

-- 4. 账号构成: account_name distinct
SELECT '账号构成 account_name distinct' AS info;
SELECT count(DISTINCT account_name) AS cnt FROM core.douyin_account_daily;
SELECT '账号构成 每日组合数' AS info;
SELECT biz_date, count(*) AS combos FROM core.douyin_account_daily GROUP BY biz_date ORDER BY biz_date LIMIT 3;

-- 5. 单载体构成: content_title distinct + 每日组合
SELECT '单载体 content_title distinct' AS info;
SELECT count(DISTINCT content_title) AS cnt FROM core.douyin_content_daily;
SELECT '单载体 每日组合数' AS info;
SELECT biz_date, count(*) AS combos FROM core.douyin_content_daily GROUP BY biz_date ORDER BY biz_date LIMIT 3;

-- 6. 商品构成: product distinct + 每日组合
SELECT '商品 product_id distinct' AS info;
SELECT count(DISTINCT product_id) AS cnt FROM core.douyin_product_daily;
SELECT '商品 每日组合数' AS info;
SELECT biz_date, count(*) AS combos FROM core.douyin_product_daily GROUP BY biz_date ORDER BY biz_date LIMIT 3;
