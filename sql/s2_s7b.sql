-- S7复查: 定位 0.1972 / 9.625 真实位置
\echo ==== 全core表扫描 0.1972 ====
SELECT 'deal' AS tbl, count(*) FILTER (WHERE exposure_to_click_rate_users = 0.1972) AS exp_click_users
FROM core.douyin_deal_daily;
SELECT 'carrier' AS tbl, count(*) FILTER (WHERE exposure_to_click_rate_users = 0.1972) AS exp_click_users
FROM core.douyin_carrier_daily;
SELECT 'account' AS tbl, count(*) FILTER (WHERE exposure_to_click_rate_users = 0.1972) AS exp_click_users
FROM core.douyin_account_daily;
SELECT 'content' AS tbl, count(*) FILTER (WHERE exposure_to_click_rate_users = 0.1972) AS exp_click_users
FROM core.douyin_content_daily;

\echo ==== 全core表扫描 9.625 ====
SELECT 'deal' AS tbl, count(*) FILTER (WHERE click_to_transaction_rate_events = 9.625) AS ctr_events
FROM core.douyin_deal_daily;
SELECT 'carrier' AS tbl, count(*) FILTER (WHERE click_to_transaction_rate_events = 9.625) AS ctr_events
FROM core.douyin_carrier_daily;
SELECT 'account' AS tbl, count(*) FILTER (WHERE click_to_transaction_rate_events = 9.625) AS ctr_events
FROM core.douyin_account_daily;
SELECT 'content' AS tbl, count(*) FILTER (WHERE click_to_transaction_rate_events = 9.625) AS ctr_events
FROM core.douyin_content_daily;
