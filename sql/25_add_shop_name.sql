-- 为所有含 shop_id 的表增加 shop_name 冗余列并回填店铺名称
BEGIN;

-- core 9 张表加列 + 回填
ALTER TABLE core.douyin_deal_daily     ADD COLUMN IF NOT EXISTS shop_name VARCHAR(100);
ALTER TABLE core.douyin_carrier_daily  ADD COLUMN IF NOT EXISTS shop_name VARCHAR(100);
ALTER TABLE core.douyin_account_daily  ADD COLUMN IF NOT EXISTS shop_name VARCHAR(100);
ALTER TABLE core.douyin_content_daily  ADD COLUMN IF NOT EXISTS shop_name VARCHAR(100);
ALTER TABLE core.douyin_terminal_daily ADD COLUMN IF NOT EXISTS shop_name VARCHAR(100);
ALTER TABLE core.douyin_category_daily ADD COLUMN IF NOT EXISTS shop_name VARCHAR(100);
ALTER TABLE core.douyin_product_daily  ADD COLUMN IF NOT EXISTS shop_name VARCHAR(100);
ALTER TABLE core.douyin_price_band_daily ADD COLUMN IF NOT EXISTS shop_name VARCHAR(100);
ALTER TABLE core.douyin_audience_daily ADD COLUMN IF NOT EXISTS shop_name VARCHAR(100);

-- audit.import_batch 加列
ALTER TABLE audit.import_batch ADD COLUMN IF NOT EXISTS shop_name VARCHAR(100);

-- 回填（JOIN meta.shop）
UPDATE core.douyin_deal_daily d SET shop_name = s.shop_name FROM meta.shop s WHERE d.shop_id = s.shop_id;
UPDATE core.douyin_carrier_daily d SET shop_name = s.shop_name FROM meta.shop s WHERE d.shop_id = s.shop_id;
UPDATE core.douyin_account_daily d SET shop_name = s.shop_name FROM meta.shop s WHERE d.shop_id = s.shop_id;
UPDATE core.douyin_content_daily d SET shop_name = s.shop_name FROM meta.shop s WHERE d.shop_id = s.shop_id;
UPDATE core.douyin_terminal_daily d SET shop_name = s.shop_name FROM meta.shop s WHERE d.shop_id = s.shop_id;
UPDATE core.douyin_category_daily d SET shop_name = s.shop_name FROM meta.shop s WHERE d.shop_id = s.shop_id;
UPDATE core.douyin_product_daily d SET shop_name = s.shop_name FROM meta.shop s WHERE d.shop_id = s.shop_id;
UPDATE core.douyin_price_band_daily d SET shop_name = s.shop_name FROM meta.shop s WHERE d.shop_id = s.shop_id;
UPDATE core.douyin_audience_daily d SET shop_name = s.shop_name FROM meta.shop s WHERE d.shop_id = s.shop_id;
UPDATE audit.import_batch b SET shop_name = s.shop_name FROM meta.shop s WHERE b.shop_id = s.shop_id;

COMMIT;

-- 验证
SELECT '核心表shop_name回填' AS chk,
       (SELECT count(*) FROM core.douyin_deal_daily WHERE shop_name = '弹动官方旗舰店')::text AS val
UNION ALL
SELECT 'import_batch', (SELECT count(*) FROM audit.import_batch WHERE shop_name = '弹动官方旗舰店')::text;
