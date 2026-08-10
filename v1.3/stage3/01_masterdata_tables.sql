-- ============================================================================
-- V1.3 阶段3｜跨店商品 / SKU / 品线主数据
-- 01_masterdata_tables.sql（主数据表 + 审计 + 初始品线）
-- ============================================================================
-- 原则（文档四节）：
--   ID 是主键；名称只是展示和辅助匹配；映射带平台+店铺；历史映射不物理删除；
--   冲突不静默覆盖；自动建议≠自动确认；SKU 优先于 Product；未映射允许存在。
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. 公司级品线
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS meta.product_line CASCADE;
CREATE TABLE meta.product_line (
    product_line_id   serial PRIMARY KEY,
    product_line_code text NOT NULL UNIQUE,
    product_line_name text NOT NULL UNIQUE,
    enabled           boolean NOT NULL DEFAULT true,
    display_order     integer NOT NULL DEFAULT 0,
    valid_from        date,
    valid_to          date,
    notes             text,
    created_at        timestamptz NOT NULL DEFAULT now(),
    updated_at        timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE meta.product_line IS 'V1.3 公司级品线（只初始化品线，不按名称关键词自动归属商品）。';

-- 初始品线（文档五十九节）
INSERT INTO meta.product_line (product_line_code, product_line_name, display_order, notes) VALUES
    ('YIZIJIANG', '鱼子酱品线', 1, '鱼子酱系列'),
    ('RENSHEN',   '人参品线',   2, '人参系列')
ON CONFLICT (product_line_code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. 公司级 Master Product
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS meta.master_product CASCADE;
CREATE TABLE meta.master_product (
    master_product_id          serial PRIMARY KEY,
    master_product_code        text NOT NULL UNIQUE,   -- MP000001 格式（触发器生成）
    master_product_name        text NOT NULL,
    brand_name                 text,
    product_line_id            integer REFERENCES meta.product_line(product_line_id),
    product_status             text NOT NULL DEFAULT 'ACTIVE' CHECK (product_status IN ('ACTIVE','DISCONTINUED','MERGED','TEST')),
    enabled                    boolean NOT NULL DEFAULT true,
    merged_into_master_product_id integer REFERENCES meta.master_product(master_product_id),
    valid_from                 date,
    valid_to                   date,
    notes                      text,
    created_at                 timestamptz NOT NULL DEFAULT now(),
    updated_at                 timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE meta.master_product IS 'V1.3 公司级真实商品主档（master_product_id 代表公司认定的同一真实商品）。';

-- ----------------------------------------------------------------------------
-- 3. 公司级 Master SKU
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS meta.master_sku CASCADE;
CREATE TABLE meta.master_sku (
    master_sku_id    serial PRIMARY KEY,
    master_sku_code  text NOT NULL UNIQUE,   -- MS000001
    master_product_id integer NOT NULL REFERENCES meta.master_product(master_product_id),
    master_sku_name  text NOT NULL,
    specification    text,
    net_content      text,
    variant_name     text,
    enabled          boolean NOT NULL DEFAULT true,
    valid_from       date,
    valid_to         date,
    notes            text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE meta.master_sku IS 'V1.3 公司级 SKU 主档（一个 Master Product 可有多个 SKU）。';

-- ----------------------------------------------------------------------------
-- 4. 平台商品映射（跨店必须带 shop_id；唯一身份 = platform_code+shop_id+platform_product_id）
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS meta.platform_product_mapping CASCADE;
CREATE TABLE meta.platform_product_mapping (
    mapping_id                     serial PRIMARY KEY,
    platform_code                  text NOT NULL,
    shop_id                        bigint NOT NULL REFERENCES meta.shop(shop_id),
    platform_product_id            text NOT NULL,
    platform_product_name_snapshot text,
    master_product_id              integer NOT NULL REFERENCES meta.master_product(master_product_id),
    mapping_status                 text NOT NULL DEFAULT 'SUGGESTED'
        CHECK (mapping_status IN ('CONFIRMED','SUGGESTED','UNMAPPED','CONFLICT','DISABLED')),
    mapping_source                 text NOT NULL DEFAULT 'MANUAL'
        CHECK (mapping_source IN ('MANUAL','EXACT_ID_RULE','EXACT_NAME_SUGGESTION','ALIAS_SUGGESTION','AI_SUGGESTION','IMPORT_FILE')),
    confidence_score               numeric(5,4),
    valid_from                     date NOT NULL DEFAULT '2026-01-01',
    valid_to                       date,
    enabled                        boolean NOT NULL DEFAULT true,
    reviewed_by                    text,
    reviewed_at                    timestamptz,
    notes                          text,
    created_at                     timestamptz NOT NULL DEFAULT now(),
    updated_at                     timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE meta.platform_product_mapping IS 'V1.3 平台商品→Master Product 映射（跨店按 shop_id 隔离；历史不物理删除）。';

-- 同一平台店铺商品在同一有效起始日只能有 1 条启用映射（防重复）
CREATE UNIQUE INDEX uk_ppm_active_from ON meta.platform_product_mapping
    (platform_code, shop_id, platform_product_id, valid_from) WHERE enabled;

-- ----------------------------------------------------------------------------
-- 5. 平台 SKU 映射
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS meta.platform_sku_mapping CASCADE;
CREATE TABLE meta.platform_sku_mapping (
    mapping_id                     serial PRIMARY KEY,
    platform_code                  text NOT NULL,
    shop_id                        bigint NOT NULL REFERENCES meta.shop(shop_id),
    platform_product_id            text NOT NULL,
    platform_sku_id                text NOT NULL,
    platform_product_name_snapshot text,
    platform_sku_name_snapshot     text,
    master_product_id              integer NOT NULL REFERENCES meta.master_product(master_product_id),
    master_sku_id                  integer NOT NULL REFERENCES meta.master_sku(master_sku_id),
    mapping_status                 text NOT NULL DEFAULT 'SUGGESTED'
        CHECK (mapping_status IN ('CONFIRMED','SUGGESTED','UNMAPPED','CONFLICT','DISABLED')),
    mapping_source                 text NOT NULL DEFAULT 'MANUAL'
        CHECK (mapping_source IN ('MANUAL','EXACT_ID_RULE','EXACT_NAME_SUGGESTION','ALIAS_SUGGESTION','AI_SUGGESTION','IMPORT_FILE')),
    confidence_score               numeric(5,4),
    valid_from                     date NOT NULL DEFAULT '2026-01-01',
    valid_to                       date,
    enabled                        boolean NOT NULL DEFAULT true,
    reviewed_by                    text,
    reviewed_at                    timestamptz,
    notes                          text,
    created_at                     timestamptz NOT NULL DEFAULT now(),
    updated_at                     timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE meta.platform_sku_mapping IS 'V1.3 平台 SKU→Master SKU 映射。当前抖音源无 SKU 维度（SKU_SOURCE_NOT_AVAILABLE），本表保留框架，不伪造平台 SKU。';

-- ----------------------------------------------------------------------------
-- 6. 商品 / SKU 别名表（用于候选匹配）
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS meta.master_product_alias CASCADE;
CREATE TABLE meta.master_product_alias (
    alias_id         serial PRIMARY KEY,
    master_product_id integer NOT NULL REFERENCES meta.master_product(master_product_id),
    alias_name       text NOT NULL,
    alias_type       text NOT NULL DEFAULT 'COMMON' CHECK (alias_type IN ('COMMON','SHORT_NAME','OLD_NAME','PLATFORM_SPECIFIC')),
    enabled          boolean NOT NULL DEFAULT true,
    notes            text,
    created_at       timestamptz NOT NULL DEFAULT now(),
    updated_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE meta.master_product_alias IS 'V1.3 公司商品别名（鱼子酱洗发水/鱼子酱洗发露 等，用于候选匹配）。';

DROP TABLE IF EXISTS meta.master_sku_alias CASCADE;
CREATE TABLE meta.master_sku_alias (
    alias_id      serial PRIMARY KEY,
    master_sku_id integer NOT NULL REFERENCES meta.master_sku(master_sku_id),
    alias_name    text NOT NULL,
    alias_type    text NOT NULL DEFAULT 'COMMON' CHECK (alias_type IN ('COMMON','SHORT_NAME','OLD_NAME','PLATFORM_SPECIFIC')),
    enabled       boolean NOT NULL DEFAULT true,
    notes         text,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE meta.master_sku_alias IS 'V1.3 公司 SKU 别名（500ml/500ML/500毫升 等）。';

-- ----------------------------------------------------------------------------
-- 7. 主数据变更审计日志
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS audit.masterdata_change_log CASCADE;
CREATE TABLE audit.masterdata_change_log (
    change_id    serial PRIMARY KEY,
    object_type  text NOT NULL,   -- MASTER_PRODUCT / PLATFORM_PRODUCT_MAPPING / ...
    object_id    text NOT NULL,
    change_type  text NOT NULL,   -- CREATE / UPDATE_NAME / CHANGE_LINE / CREATE_MAPPING / CONFIRM_MAPPING / CLOSE_MAPPING / CHANGE_PERIOD / RESOLVE_CONFLICT
    old_value    jsonb,
    new_value    jsonb,
    changed_by   text NOT NULL DEFAULT 'SYSTEM',
    changed_at   timestamptz NOT NULL DEFAULT now(),
    reason       text
);
COMMENT ON TABLE audit.masterdata_change_log IS 'V1.3 主数据变更审计（历史可追溯，禁止物理删除历史映射）。';

COMMIT;

\echo '=== 品线 ==='
SELECT product_line_code, product_line_name, enabled FROM meta.product_line ORDER BY display_order;
\echo '=== 主数据表清单 ==='
SELECT table_name FROM information_schema.tables WHERE table_schema='meta' AND table_name IN ('product_line','master_product','master_sku','platform_product_mapping','platform_sku_mapping','master_product_alias','master_sku_alias') ORDER BY table_name;
