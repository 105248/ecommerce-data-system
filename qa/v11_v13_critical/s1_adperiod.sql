\pset pager off
\echo '=== deal_daily ad_period 实际取值 ==='
SELECT ad_period, count(*) n, round(SUM(user_pay_amount)::numeric,2) gmv
FROM core.douyin_deal_daily GROUP BY 1 ORDER BY 2 DESC;
\echo '=== carrier_daily account_channel 取值（投放拆分维度） ==='
SELECT account_channel, count(*) n, round(SUM(user_pay_amount)::numeric,2) gmv
FROM core.douyin_carrier_daily GROUP BY 1 ORDER BY 2 DESC;
\echo '=== deal_daily 中 ad_period=不限 的行数占比 ==='
SELECT count(*) FILTER (WHERE ad_period='不限') unlimited_rows, count(*) total FROM core.douyin_deal_daily;
