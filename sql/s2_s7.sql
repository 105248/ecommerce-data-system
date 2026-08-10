-- S7复查: 比例原值 0.1972 / 9.625 保护
\echo ===== 查找 0.1972 所在表行 =====
SELECT 'deal_daily' AS tbl, exposure_to_click_rate_users::text AS v FROM core.douyin_deal_daily WHERE exposure_to_click_rate_users = 0.1972 LIMIT 1
UNION ALL
SELECT 'carrier_daily', exposure_to_click_rate_users::text FROM core.douyin_carrier_daily WHERE exposure_to_click_rate_users = 0.1972 LIMIT 1
UNION ALL
SELECT 'account_daily', exposure_to_click_rate_users::text FROM core.douyin_account_daily WHERE exposure_to_click_rate_users = 0.1972 LIMIT 1
UNION ALL
SELECT 'content_daily', exposure_to_click_rate_users::text FROM core.douyin_content_daily WHERE exposure_to_click_rate_users = 0.1972 LIMIT 1;

\echo ===== 查找 9.625 所在表行 =====
SELECT 'deal_daily' AS tbl, click_to_transaction_rate_events::text AS v FROM core.douyin_deal_daily WHERE click_to_transaction_rate_events = 9.625 LIMIT 1
UNION ALL
SELECT 'carrier_daily', click_to_transaction_rate_events::text FROM core.douyin_carrier_daily WHERE click_to_transaction_rate_events = 9.625 LIMIT 1
UNION ALL
SELECT 'account_daily', click_to_transaction_rate_events::text FROM core.douyin_account_daily WHERE click_to_transaction_rate_events = 9.625 LIMIT 1
UNION ALL
SELECT 'content_daily', click_to_transaction_rate_events::text FROM core.douyin_content_daily WHERE click_to_transaction_rate_events = 9.625 LIMIT 1;

\echo ===== 中文View中比例原值抽查 =====
SELECT "商品曝光-点击转化率(人数)" AS v1 FROM "中文数据"."抖音成交日报" WHERE "商品曝光-点击转化率(人数)" = 0.1972 LIMIT 1;
SELECT "商品点击-成交转化率(次数)" AS v2 FROM "中文数据"."抖音成交日报" WHERE "商品点击-成交转化率(次数)" = 9.625 LIMIT 1;
