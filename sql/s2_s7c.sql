-- S7确认: 比例原值精确值
\echo ==== 0.1972 ====
SELECT 'carrier.exposure_to_transaction_rate_events' AS loc, exposure_to_transaction_rate_events::text AS v
FROM core.douyin_carrier_daily WHERE exposure_to_transaction_rate_events = 0.1972 LIMIT 1;
SELECT 'deal.refund_rate_pay_time' AS loc, refund_rate_pay_time::text AS v
FROM core.douyin_deal_daily WHERE refund_rate_pay_time = 0.1972 LIMIT 1;
SELECT 'deal.click_to_transaction_rate_users' AS loc, click_to_transaction_rate_users::text AS v
FROM core.douyin_deal_daily WHERE click_to_transaction_rate_users = 0.1972 LIMIT 1;

\echo ==== 9.625 ====
SELECT 'deal.click_to_transaction_rate_users' AS loc, click_to_transaction_rate_users::text AS v
FROM core.douyin_deal_daily WHERE click_to_transaction_rate_users = 9.625 LIMIT 1;
SELECT 'carrier.exposure_to_transaction_rate_events' AS loc, exposure_to_transaction_rate_events::text AS v
FROM core.douyin_carrier_daily WHERE exposure_to_transaction_rate_events = 9.625 LIMIT 1;
