-- ============================================================================
-- V1.3 阶段3｜跨店商品 / SKU / 品线主数据
-- 05_masterdata_security.sql（角色 + 权限隔离）
-- ============================================================================
-- 原则（文档四十八/四十九/七十六节）：
--   agent_readonly：主数据只读（读取 PASS / 写入 DENIED）
--   ecommerce_masterdata_admin：允许 meta 主数据 CRUD；禁止 core 经营事实写入
-- ============================================================================

-- 1. 主数据管理角色
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ecommerce_masterdata_admin') THEN
        CREATE ROLE ecommerce_masterdata_admin NOLOGIN;
    END IF;
END $$;

-- 2. agent_readonly：meta 主数据 SELECT 授权
GRANT USAGE ON SCHEMA meta TO agent_readonly;
GRANT SELECT ON meta.product_line, meta.master_product, meta.master_sku,
    meta.platform_product_mapping, meta.platform_sku_mapping,
    meta.master_product_alias, meta.master_sku_alias, meta.platform TO agent_readonly;
GRANT SELECT ON audit.masterdata_change_log TO agent_readonly;

-- 3. agent_readonly：批准执行主数据只读函数
GRANT EXECUTE ON FUNCTION mart.resolve_master_product(text,text,text,date) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_master_product_members(bigint) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_product_line_members(text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_master_product_period_summary(bigint,date,date,text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_product_line_period_summary(text,date,date) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.rank_master_products(date,date,text,text,text,integer) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.get_masterdata_quality(date,date) TO agent_readonly;
GRANT SELECT ON mart.product_master_resolution, mart.sku_master_resolution,
    mart.unmapped_products, mart.product_mapping_conflicts, mart.sku_mapping_conflicts TO agent_readonly;

-- 4. 主数据管理员：meta 主数据读写（序列 + 表 CRUD）
GRANT USAGE ON SCHEMA meta TO ecommerce_masterdata_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA meta TO ecommerce_masterdata_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON meta.product_line, meta.master_product, meta.master_sku,
    meta.platform_product_mapping, meta.platform_sku_mapping,
    meta.master_product_alias, meta.master_sku_alias TO ecommerce_masterdata_admin;
GRANT SELECT ON meta.shop, meta.platform TO ecommerce_masterdata_admin;
GRANT SELECT, INSERT ON audit.masterdata_change_log TO ecommerce_masterdata_admin;
-- 审计序列
GRANT USAGE ON SEQUENCE audit.masterdata_change_log_change_id_seq TO ecommerce_masterdata_admin;

-- 5. 主数据管理员：禁止 core 写入（仅 SELECT）
GRANT USAGE ON SCHEMA core TO ecommerce_masterdata_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO ecommerce_masterdata_admin;
-- 显式无 DML（未授予 INSERT/UPDATE/DELETE 即禁止）

-- 6. 收回 PUBLIC 默认（函数 EXECUTE 收紧）
REVOKE ALL ON FUNCTION mart.resolve_master_product(text,text,text,date) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_master_product_members(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_product_line_members(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_master_product_period_summary(bigint,date,date,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_product_line_period_summary(text,date,date) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.rank_master_products(date,date,text,text,text,integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.get_masterdata_quality(date,date) FROM PUBLIC;

COMMENT ON ROLE ecommerce_masterdata_admin IS 'V1.3 主数据管理角色：meta 主数据 CRUD + audit 日志；禁止 core 经营事实写入。';
