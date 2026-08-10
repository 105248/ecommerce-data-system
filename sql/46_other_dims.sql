-- 阶段0：其余8张表的维度值扫描 + 汇总值检测
-- 载体构成
SELECT '载体构成 维度' AS info;
SELECT sale_scope, count(*) AS cnt, count(DISTINCT biz_date) AS days FROM core.douyin_carrier_daily GROUP BY sale_scope ORDER BY 1;
SELECT '载体构成 carrier_type' AS info;
SELECT carrier_type, count(*) AS cnt, count(DISTINCT biz_date) AS days FROM core.douyin_carrier_daily GROUP BY carrier_type ORDER BY 1;
SELECT '载体构成 account_channel' AS info;
SELECT account_channel, count(*) AS cnt FROM core.douyin_carrier_daily GROUP BY account_channel ORDER BY 1;

-- 账号构成
SELECT '账号构成 sale_scope' AS info;
SELECT sale_scope, count(*) AS cnt, count(DISTINCT biz_date) AS days FROM core.douyin_account_daily GROUP BY sale_scope ORDER BY 1;
SELECT '账号构成 account_type' AS info;
SELECT account_type, count(*) AS cnt FROM core.douyin_account_daily GROUP BY account_type ORDER BY 1;

-- 单载体构成
SELECT '单载体构成 selling_type' AS info;
SELECT selling_type, count(*) AS cnt, count(DISTINCT biz_date) AS days FROM core.douyin_content_daily GROUP BY selling_type ORDER BY 1;
SELECT '单载体构成 carrier_type' AS info;
SELECT carrier_type, count(*) AS cnt FROM core.douyin_content_daily GROUP BY carrier_type ORDER BY 1;

-- 终端构成
SELECT '终端构成 terminal_type' AS info;
SELECT terminal_type, count(*) AS cnt, count(DISTINCT biz_date) AS days FROM core.douyin_terminal_daily GROUP BY terminal_type ORDER BY 1;
SELECT '终端构成 selling_type' AS info;
SELECT selling_type, count(*) AS cnt FROM core.douyin_terminal_daily GROUP BY selling_type ORDER BY 1;

-- 品类构成
SELECT '品类构成 一级类目' AS info;
SELECT category_level_1, count(*) AS cnt, count(DISTINCT biz_date) AS days FROM core.douyin_category_daily GROUP BY category_level_1 ORDER BY 1;

-- 商品构成
SELECT '商品构成 carrier_type' AS info;
SELECT carrier_type, count(*) AS cnt FROM core.douyin_product_daily GROUP BY carrier_type ORDER BY 1;

-- 价格带构成
SELECT '价格带构成 price_band' AS info;
SELECT price_band, count(*) AS cnt FROM core.douyin_price_band_daily GROUP BY price_band ORDER BY 1;

-- 人群构成
SELECT '人群构成 audience_type' AS info;
SELECT audience_type, count(*) AS cnt, count(DISTINCT biz_date) AS days FROM core.douyin_audience_daily GROUP BY audience_type ORDER BY 1;
SELECT '人群构成 carrier_type' AS info;
SELECT carrier_type, count(*) AS cnt FROM core.douyin_audience_daily GROUP BY carrier_type ORDER BY 1;
