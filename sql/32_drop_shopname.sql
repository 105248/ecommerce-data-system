-- 删除本次临时新增的 shop_name 冗余物理列（依赖扫描已确认无任何引用）
-- 仅 DROP COLUMN，不 CASCADE，不删除 shop_id
BEGIN;

ALTER TABLE core.douyin_deal_daily     DROP COLUMN IF EXISTS shop_name;
ALTER TABLE core.douyin_carrier_daily  DROP COLUMN IF EXISTS shop_name;
ALTER TABLE core.douyin_account_daily  DROP COLUMN IF EXISTS shop_name;
ALTER TABLE core.douyin_content_daily  DROP COLUMN IF EXISTS shop_name;
ALTER TABLE core.douyin_terminal_daily DROP COLUMN IF EXISTS shop_name;
ALTER TABLE core.douyin_category_daily DROP COLUMN IF EXISTS shop_name;
ALTER TABLE core.douyin_product_daily  DROP COLUMN IF EXISTS shop_name;
ALTER TABLE core.douyin_price_band_daily DROP COLUMN IF EXISTS shop_name;
ALTER TABLE core.douyin_audience_daily DROP COLUMN IF EXISTS shop_name;
ALTER TABLE audit.import_batch         DROP COLUMN IF EXISTS shop_name;

COMMIT;

-- 验证: shop_name 列已全部移除, shop_id 保留
SELECT '残留shop_name列' AS chk, count(*)::text AS val
FROM information_schema.columns
WHERE column_name = 'shop_name' AND table_schema IN ('core','audit');

SELECT 'shop_id保留' AS chk, count(*)::text AS val
FROM information_schema.columns
WHERE column_name = 'shop_id' AND table_schema IN ('core','audit');
