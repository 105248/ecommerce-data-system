-- 最后确认
-- 1. 账号构成 account_name 的汇总值
SELECT '账号 account_name 汇总值' AS info;
SELECT account_name, count(*) AS cnt FROM core.douyin_account_daily
WHERE account_name IN ('全部','更多账号','其他','弹动官方旗舰店','全域投放时段')
GROUP BY account_name;

-- 2. 账号构成 account_type 汇总值(空值含义)
SELECT '账号 account_type 明细' AS info;
SELECT sale_scope, account_type, count(*) AS cnt
FROM core.douyin_account_daily WHERE account_type = '' GROUP BY sale_scope, account_type;

-- 3. 品类构成: 二级/三级类目 distinct
SELECT '品类 distinct' AS info;
SELECT count(DISTINCT category_level_2) AS l2, count(DISTINCT category_level_3) AS l3,
       count(DISTINCT category_level_4) AS l4 FROM core.douyin_category_daily;

-- 4. 品类 每日组合数
SELECT '品类 每日组合数' AS info;
SELECT biz_date, count(*) AS combos FROM core.douyin_category_daily GROUP BY biz_date ORDER BY biz_date LIMIT 3;

-- 5. 价格带 每日组合
SELECT '价格带 每日组合' AS info;
SELECT biz_date, count(*) AS combos FROM core.douyin_price_band_daily GROUP BY biz_date ORDER BY biz_date LIMIT 3;

-- 6. 人群 每日组合
SELECT '人群 每日组合' AS info;
SELECT biz_date, count(*) AS combos FROM core.douyin_audience_daily GROUP BY biz_date ORDER BY biz_date LIMIT 3;

-- 7. 终端 每日组合
SELECT '终端 每日组合' AS info;
SELECT biz_date, count(*) AS combos FROM core.douyin_terminal_daily GROUP BY biz_date ORDER BY biz_date LIMIT 3;

-- 8. 单载体 selling_type 是'自营/合作'而非'全部'?
SELECT '单载体 是否有全部' AS info;
SELECT count(*) AS cnt FROM core.douyin_content_daily WHERE selling_type = '全部';
