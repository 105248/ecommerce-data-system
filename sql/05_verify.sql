-- 验收检查脚本
SELECT shop_id AS shop_id, platform_code AS platform_code, shop_code AS shop_code, shop_name AS shop_name, enabled AS enabled
FROM meta.shop;

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema IN ('meta','audit','stg','core','mart')
ORDER BY table_schema, table_name;
