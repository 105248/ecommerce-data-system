-- ============================================================================
-- V1.3 阶段1｜第二抖音店铺接入
-- 01_second_shop_meta.sql（第二店注册与命名统一）
-- ============================================================================
-- 说明：第二店（shop_id=2）已于 V1.0.1 batch10 导入（20551 行）。
-- 本阶段将其正式名统一为「弹动个人护理旗舰店」（与官方店命名风格一致，
-- 原为「抖音个人护理旗舰店」）；目录 raw_files/douyin/弹动个人护理旗舰店/ 同步。
-- 本脚本记录该变更，可重放。

BEGIN;

-- 第二店记录（如不存在则插入；已存在则改名）
INSERT INTO meta.shop (platform_code, shop_code, shop_name, enabled)
SELECT 'douyin', 'DY_GERENHULI_OFFICIAL', '弹动个人护理旗舰店', true
WHERE NOT EXISTS (SELECT 1 FROM meta.shop WHERE shop_code = 'DY_GERENHULI_OFFICIAL');

UPDATE meta.shop
SET shop_name = '弹动个人护理旗舰店'
WHERE shop_id = 2 AND shop_code = 'DY_GERENHULI_OFFICIAL';

COMMIT;

\echo '=== meta.shop（两店） ==='
SELECT shop_id, platform_code, shop_code, shop_name, enabled FROM meta.shop ORDER BY shop_id;
