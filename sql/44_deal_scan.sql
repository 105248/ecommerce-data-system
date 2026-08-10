-- 阶段0 核心：deal_daily 三个关键维度真实值扫描
-- 1. sale_scope 分布
SELECT 'sale_scope 分布' AS info;
SELECT sale_scope, count(*) AS cnt, count(DISTINCT biz_date) AS days
FROM core.douyin_deal_daily
GROUP BY sale_scope ORDER BY sale_scope;

-- 2. carrier_type 分布（全scope）
SELECT 'carrier_type 分布' AS info;
SELECT carrier_type, count(*) AS cnt, count(DISTINCT biz_date) AS days
FROM core.douyin_deal_daily
GROUP BY carrier_type ORDER BY carrier_type;

-- 3. ad_period 分布
SELECT 'ad_period 分布' AS info;
SELECT ad_period, count(*) AS cnt, count(DISTINCT biz_date) AS days
FROM core.douyin_deal_daily
GROUP BY ad_period ORDER BY ad_period;

-- 4. sale_scope × carrier_type 交叉
SELECT 'sale_scope × carrier_type' AS info;
SELECT sale_scope, carrier_type, count(*) AS cnt
FROM core.douyin_deal_daily
GROUP BY sale_scope, carrier_type ORDER BY sale_scope, carrier_type;

-- 5. sale_scope × ad_period 交叉
SELECT 'sale_scope × ad_period' AS info;
SELECT sale_scope, ad_period, count(*) AS cnt
FROM core.douyin_deal_daily
GROUP BY sale_scope, ad_period ORDER BY sale_scope, ad_period;
