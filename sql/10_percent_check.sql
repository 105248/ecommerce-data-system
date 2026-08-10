-- 第五步: 百分比数据库抽查
SELECT '0.1972检查' AS chk,
       click_to_transaction_rate_users AS db_value,
       mart.format_percent_2(click_to_transaction_rate_users) AS display_value
FROM core.douyin_deal_daily
WHERE source_row_number = 2 AND sale_scope = '全部';

SELECT '9.625检查' AS chk,
       click_to_transaction_rate_users AS db_value,
       mart.format_percent_2(click_to_transaction_rate_users) AS display_value
FROM core.douyin_deal_daily
WHERE source_row_number = 8 AND sale_scope = '全部';

SELECT '错误值检查' AS chk, count(*) AS cnt
FROM core.douyin_deal_daily
WHERE click_to_transaction_rate_users IN (0.09625, 962.5);
