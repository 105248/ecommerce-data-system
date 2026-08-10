-- ============================================================================
-- V1.3 阶段2｜抖音多店统一经营层
-- 01_platform_meta.sql（平台维度 + 平台→店铺关系）
-- ============================================================================
BEGIN;

-- 平台维度表（如不存在）
CREATE TABLE IF NOT EXISTS meta.platform (
    platform_code text PRIMARY KEY,
    platform_name text NOT NULL,
    enabled       boolean NOT NULL DEFAULT true,
    notes         text,
    created_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE meta.platform IS 'V1.3 平台维度：platform_code 为聚合范围语义，平台整体只存在于 mart 查询层，不进 core。';

INSERT INTO meta.platform (platform_code, platform_name, enabled, notes)
VALUES ('douyin', '抖音', true, 'V1.3 抖音多店统一经营平台')
ON CONFLICT (platform_code) DO UPDATE SET platform_name = EXCLUDED.platform_name, enabled = true;

COMMIT;

\echo '=== meta.platform ==='
SELECT platform_code, platform_name, enabled FROM meta.platform;
\echo '=== 平台→店铺关系（enabled + douyin） ==='
SELECT shop_id, shop_code, shop_name FROM meta.shop WHERE platform_code='douyin' AND enabled ORDER BY shop_id;
