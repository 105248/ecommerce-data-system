-- 覆盖重导: 清空6月数据 + 标记旧批次 (事务)
BEGIN;

-- 1. 标记旧批次为 superseded (保留审计记录)
UPDATE audit.import_batch SET import_status = 'superseded'
WHERE batch_id = 7 AND import_status = 'success';

-- 2. 清空 9 张 core 表 6月数据
DELETE FROM core.douyin_deal_daily      WHERE shop_id = 1 AND biz_date BETWEEN '2026-06-01' AND '2026-06-30';
DELETE FROM core.douyin_carrier_daily   WHERE shop_id = 1 AND biz_date BETWEEN '2026-06-01' AND '2026-06-30';
DELETE FROM core.douyin_account_daily   WHERE shop_id = 1 AND biz_date BETWEEN '2026-06-01' AND '2026-06-30';
DELETE FROM core.douyin_content_daily   WHERE shop_id = 1 AND biz_date BETWEEN '2026-06-01' AND '2026-06-30';
DELETE FROM core.douyin_terminal_daily  WHERE shop_id = 1 AND biz_date BETWEEN '2026-06-01' AND '2026-06-30';
DELETE FROM core.douyin_category_daily  WHERE shop_id = 1 AND biz_date BETWEEN '2026-06-01' AND '2026-06-30';
DELETE FROM core.douyin_product_daily   WHERE shop_id = 1 AND biz_date BETWEEN '2026-06-01' AND '2026-06-30';
DELETE FROM core.douyin_price_band_daily WHERE shop_id = 1 AND biz_date BETWEEN '2026-06-01' AND '2026-06-30';
DELETE FROM core.douyin_audience_daily  WHERE shop_id = 1 AND biz_date BETWEEN '2026-06-01' AND '2026-06-30';

-- 3. 验证清空
SELECT 'deal' AS tbl, count(*) AS cnt FROM core.douyin_deal_daily
UNION ALL SELECT 'carrier', count(*) FROM core.douyin_carrier_daily
UNION ALL SELECT 'account', count(*) FROM core.douyin_account_daily
UNION ALL SELECT 'content', count(*) FROM core.douyin_content_daily
UNION ALL SELECT 'terminal', count(*) FROM core.douyin_terminal_daily
UNION ALL SELECT 'category', count(*) FROM core.douyin_category_daily
UNION ALL SELECT 'product', count(*) FROM core.douyin_product_daily
UNION ALL SELECT 'price_band', count(*) FROM core.douyin_price_band_daily
UNION ALL SELECT 'audience', count(*) FROM core.douyin_audience_daily;

COMMIT;
