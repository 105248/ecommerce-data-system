-- ============================================================================
-- V1.3 阶段3｜跨店商品 / SKU / 品线主数据
-- 02_masterdata_functions.sql（code 生成 / 审计 / 解析 / 成员 / 冲突检测）
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Master Product Code 生成触发器（MP000001）
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION meta.gen_master_product_code() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF NEW.master_product_code IS NULL THEN
        NEW.master_product_code := 'MP' || lpad(NEW.master_product_id::text, 6, '0');
    END IF;
    RETURN NEW;
END; $f$;

DROP TRIGGER IF EXISTS trg_master_product_code ON meta.master_product;
CREATE TRIGGER trg_master_product_code
    BEFORE INSERT ON meta.master_product
    FOR EACH ROW EXECUTE FUNCTION meta.gen_master_product_code();

-- Master SKU Code 生成（MS000001）
CREATE OR REPLACE FUNCTION meta.gen_master_sku_code() RETURNS trigger
LANGUAGE plpgsql AS $f$
BEGIN
    IF NEW.master_sku_code IS NULL THEN
        NEW.master_sku_code := 'MS' || lpad(NEW.master_sku_id::text, 6, '0');
    END IF;
    RETURN NEW;
END; $f$;

DROP TRIGGER IF EXISTS trg_master_sku_code ON meta.master_sku;
CREATE TRIGGER trg_master_sku_code
    BEFORE INSERT ON meta.master_sku
    FOR EACH ROW EXECUTE FUNCTION meta.gen_master_sku_code();

-- ----------------------------------------------------------------------------
-- 2. 审计触发器（主数据变更可追溯，文档八十节）
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION meta.audit_masterdata() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE
    v_obj text;
BEGIN
    v_obj := TG_TABLE_NAME;
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit.masterdata_change_log (object_type, object_id, change_type, old_value, new_value, changed_by)
        VALUES (upper(v_obj), NEW.master_product_id::text, 'CREATE', NULL, to_jsonb(NEW), 'SYSTEM');
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit.masterdata_change_log (object_type, object_id, change_type, old_value, new_value, changed_by)
        VALUES (upper(v_obj), NEW.master_product_id::text, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), 'SYSTEM');
    END IF;
    RETURN NULL;
END; $f$;

DROP TRIGGER IF EXISTS trg_audit_master_product ON meta.master_product;
CREATE TRIGGER trg_audit_master_product
    AFTER INSERT OR UPDATE ON meta.master_product
    FOR EACH ROW EXECUTE FUNCTION meta.audit_masterdata();

CREATE OR REPLACE FUNCTION meta.audit_mapping() RETURNS trigger
LANGUAGE plpgsql AS $f$
DECLARE
    v_obj text; v_id text; v_act text;
BEGIN
    v_obj := TG_TABLE_NAME;
    IF TG_OP = 'INSERT' THEN
        v_act := 'CREATE_MAPPING'; v_id := NEW.mapping_id::text;
        INSERT INTO audit.masterdata_change_log (object_type, object_id, change_type, old_value, new_value, changed_by)
        VALUES (upper(v_obj), v_id, v_act, NULL, to_jsonb(NEW), coalesce(NEW.reviewed_by, 'SYSTEM'));
    ELSIF TG_OP = 'UPDATE' THEN
        v_act := 'UPDATE_MAPPING'; v_id := NEW.mapping_id::text;
        IF OLD.mapping_status = 'SUGGESTED' AND NEW.mapping_status = 'CONFIRMED' THEN v_act := 'CONFIRM_MAPPING'; END IF;
        IF OLD.enabled AND NOT NEW.enabled THEN v_act := 'CLOSE_MAPPING'; END IF;
        INSERT INTO audit.masterdata_change_log (object_type, object_id, change_type, old_value, new_value, changed_by)
        VALUES (upper(v_obj), v_id, v_act, to_jsonb(OLD), to_jsonb(NEW), coalesce(NEW.reviewed_by, 'SYSTEM'));
    END IF;
    RETURN NULL;
END; $f$;

DROP TRIGGER IF EXISTS trg_audit_ppm ON meta.platform_product_mapping;
CREATE TRIGGER trg_audit_ppm
    AFTER INSERT OR UPDATE ON meta.platform_product_mapping
    FOR EACH ROW EXECUTE FUNCTION meta.audit_mapping();

DROP TRIGGER IF EXISTS trg_audit_psm ON meta.platform_sku_mapping;
CREATE TRIGGER trg_audit_psm
    AFTER INSERT OR UPDATE ON meta.platform_sku_mapping
    FOR EACH ROW EXECUTE FUNCTION meta.audit_mapping();

-- ----------------------------------------------------------------------------
-- 3. 时间区间重叠冲突检测（文档二十二/二十三节）
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.check_mapping_period_conflict(
    p_platform_code text, p_shop_id bigint, p_platform_product_id text,
    p_valid_from date, p_valid_to date, p_exclude_mapping_id bigint DEFAULT NULL
) RETURNS TABLE (conflict_mapping_id bigint, master_product_id integer, valid_from date, valid_to date)
LANGUAGE plpgsql
STABLE
AS $f$
BEGIN
    RETURN QUERY
    SELECT m.mapping_id, m.master_product_id, m.valid_from, m.valid_to
    FROM meta.platform_product_mapping m
    WHERE m.platform_code = p_platform_code AND m.shop_id = p_shop_id
      AND m.platform_product_id = p_platform_product_id AND m.enabled
      AND (p_exclude_mapping_id IS NULL OR m.mapping_id <> p_exclude_mapping_id)
      AND m.valid_from < coalesce(p_valid_to, 'infinity'::date)
      AND coalesce(m.valid_to, 'infinity'::date) > p_valid_from;
END; $f$;

COMMENT ON FUNCTION mart.check_mapping_period_conflict(text,bigint,text,date,date,bigint) IS
'V1.3 映射时间区间重叠检测：同一平台店铺商品在重叠有效期内存在多条启用映射 → CONFLICT（不静默覆盖）。';

-- ----------------------------------------------------------------------------
-- 4. 查商品归属（resolve，支持业务日期；SKU 优先——当前无 SKU 源则走 Product）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.resolve_master_product(text,text,text,date);
CREATE FUNCTION mart.resolve_master_product(
    p_platform_code      text,
    p_shop_name          text,
    p_platform_product_id text,
    p_biz_date           date DEFAULT CURRENT_DATE
) RETURNS TABLE (
    platform_code text, shop_name text, platform_product_id text,
    platform_product_name text,
    master_product_id integer, master_product_code text, master_product_name text,
    product_line_id integer, product_line_name text,
    mapping_status text, mapping_source text, confidence_score numeric,
    valid_from date, valid_to date,
    sku_source_status text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT
        m.platform_code,
        s.shop_name,
        m.platform_product_id,
        m.platform_product_name_snapshot,
        mp.master_product_id,
        mp.master_product_code,
        mp.master_product_name,
        pl.product_line_id,
        pl.product_line_name,
        m.mapping_status, m.mapping_source, m.confidence_score,
        m.valid_from, m.valid_to,
        'SKU_SOURCE_NOT_AVAILABLE'::text AS sku_source_status
    FROM meta.platform_product_mapping m
    JOIN meta.shop s ON s.shop_id = m.shop_id
    JOIN meta.master_product mp ON mp.master_product_id = m.master_product_id
    LEFT JOIN meta.product_line pl ON pl.product_line_id = mp.product_line_id
    WHERE m.platform_code = p_platform_code
      AND s.shop_name = p_shop_name
      AND m.platform_product_id = p_platform_product_id
      AND m.enabled
      AND m.valid_from <= p_biz_date
      AND (m.valid_to IS NULL OR m.valid_to >= p_biz_date)
      AND NOT EXISTS (
          -- 同期间多条启用映射（时间重叠）→ CONFLICT，不返回
          SELECT 1 FROM meta.platform_product_mapping m2
          WHERE m2.platform_code = m.platform_code AND m2.shop_id = m.shop_id
            AND m2.platform_product_id = m.platform_product_id AND m2.enabled
            AND m2.mapping_id <> m.mapping_id
            AND m2.valid_from < coalesce(m.valid_to, 'infinity'::date)
            AND coalesce(m2.valid_to, 'infinity'::date) > m.valid_from
      )
    ORDER BY m.mapping_status = 'CONFIRMED' DESC, m.mapping_id
    LIMIT 1;
$f$;

COMMENT ON FUNCTION mart.resolve_master_product(text,text,text,date) IS
'V1.3 查商品归属：平台+店铺+平台商品ID+业务日期 → Master Product/品线/状态。
当前抖音源无 SKU 维度（SKU_SOURCE_NOT_AVAILABLE），SKU 优先规则在真实 SKU 数据接入后启用。';

-- ----------------------------------------------------------------------------
-- 5. 跨店成员（Master Product 在两店的平台商品）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_master_product_members(bigint);
CREATE FUNCTION mart.get_master_product_members(p_master_product_id bigint)
RETURNS TABLE (
    platform_code text, shop_id bigint, shop_name text,
    platform_product_id text, platform_product_name text,
    mapping_status text, mapping_source text, confidence_score numeric,
    valid_from date, valid_to date
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT m.platform_code, m.shop_id, s.shop_name,
           m.platform_product_id, m.platform_product_name_snapshot,
           m.mapping_status, m.mapping_source, m.confidence_score,
           m.valid_from, m.valid_to
    FROM meta.platform_product_mapping m
    JOIN meta.shop s ON s.shop_id = m.shop_id
    WHERE m.master_product_id = p_master_product_id AND m.enabled
    ORDER BY s.shop_id, m.platform_product_id;
$f$;

COMMENT ON FUNCTION mart.get_master_product_members(bigint) IS 'V1.3 Master Product 跨店成员（平台/店铺/平台商品ID/状态/有效期）。';

-- ----------------------------------------------------------------------------
-- 6. 品线成员
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_product_line_members(text);
CREATE FUNCTION mart.get_product_line_members(p_product_line_name text)
RETURNS TABLE (
    product_line_id integer, product_line_name text,
    master_product_id integer, master_product_code text, master_product_name text,
    mapping_count bigint, covered_shop_count bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
    SELECT pl.product_line_id, pl.product_line_name,
           mp.master_product_id, mp.master_product_code, mp.master_product_name,
           count(m.mapping_id) AS mapping_count,
           count(DISTINCT m.shop_id) AS covered_shop_count
    FROM meta.product_line pl
    JOIN meta.master_product mp ON mp.product_line_id = pl.product_line_id AND mp.enabled
    LEFT JOIN meta.platform_product_mapping m ON m.master_product_id = mp.master_product_id AND m.enabled AND m.mapping_status = 'CONFIRMED'
    WHERE pl.product_line_name = p_product_line_name
    GROUP BY pl.product_line_id, pl.product_line_name, mp.master_product_id, mp.master_product_code, mp.master_product_name
    ORDER BY mp.master_product_id;
$f$;

COMMENT ON FUNCTION mart.get_product_line_members(text) IS 'V1.3 品线成员：品线 → Master Product → 已确认映射数/店铺覆盖。';

COMMIT;
