-- 第三项: 正式导入后核对
-- 1. 9张core表总行数
SELECT '9表总行数' AS chk, (SELECT count(*) FROM core.douyin_deal_daily)
    + (SELECT count(*) FROM core.douyin_carrier_daily)
    + (SELECT count(*) FROM core.douyin_account_daily)
    + (SELECT count(*) FROM core.douyin_content_daily)
    + (SELECT count(*) FROM core.douyin_terminal_daily)
    + (SELECT count(*) FROM core.douyin_category_daily)
    + (SELECT count(*) FROM core.douyin_product_daily)
    + (SELECT count(*) FROM core.douyin_price_band_daily)
    + (SELECT count(*) FROM core.douyin_audience_daily)::text AS val;

-- 2. 日期范围
SELECT '日期范围' AS chk, min(biz_date)::text || ' ~ ' || max(biz_date)::text AS val
FROM core.douyin_deal_daily;

-- 3. 比例原值 0.1972 和 9.625
SELECT '比例0.1972' AS chk, click_to_transaction_rate_users::text AS val
FROM core.douyin_deal_daily WHERE source_row_number = 2 AND sale_scope = '全部';
SELECT '比例9.625' AS chk, click_to_transaction_rate_users::text AS val
FROM core.douyin_deal_daily WHERE source_row_number = 8 AND sale_scope = '全部';

-- 4. import_batch 最终状态
SELECT 'batch状态' AS chk, count(*)::text || '条success' AS val
FROM audit.import_batch WHERE import_status = 'success';
