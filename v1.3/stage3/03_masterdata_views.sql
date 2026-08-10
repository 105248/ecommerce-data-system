-- ============================================================================
-- V1.3 阶段3｜跨店商品 / SKU / 品线主数据
-- 03_masterdata_views.sql（解析 View / 未映射 / 冲突）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 商品解析 View（全部映射明细）
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS mart.product_master_resolution;
CREATE VIEW mart.product_master_resolution AS
SELECT
    m.platform_code,
    m.shop_id,
    s.shop_name,
    m.platform_product_id,
    m.platform_product_name_snapshot AS platform_product_name,
    mp.master_product_id,
    mp.master_product_code,
    mp.master_product_name,
    pl.product_line_id,
    pl.product_line_name,
    m.mapping_status,
    m.mapping_source,
    m.confidence_score,
    m.valid_from,
    m.valid_to
FROM meta.platform_product_mapping m
JOIN meta.shop s ON s.shop_id = m.shop_id
JOIN meta.master_product mp ON mp.master_product_id = m.master_product_id
LEFT JOIN meta.product_line pl ON pl.product_line_id = mp.product_line_id;

COMMENT ON VIEW mart.product_master_resolution IS 'V1.3 商品主数据解析（平台商品 → Master Product → 品线 → 状态/来源/有效期）。';

-- ----------------------------------------------------------------------------
-- 2. SKU 解析 View（当前抖音源无 SKU → SKU_SOURCE_NOT_AVAILABLE）
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS mart.sku_master_resolution;
CREATE VIEW mart.sku_master_resolution AS
SELECT
    'SKU_SOURCE_NOT_AVAILABLE' AS sku_source_status,
    '当前抖音正式商品经营事实源不包含 SKU ID/名称维度；已建立 Master SKU 与映射框架，但不伪造平台 SKU（V1.3 文档第三十节）。' AS note
WHERE false;

COMMENT ON VIEW mart.sku_master_resolution IS 'V1.3 SKU 解析：当前抖音源无 SKU 维度，明确返回 SKU_SOURCE_NOT_AVAILABLE（不伪造）。';

-- ----------------------------------------------------------------------------
-- 3. 未映射商品 View（含 30 天成交金额排序，帮助人工优先处理）
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS mart.unmapped_products;
CREATE VIEW mart.unmapped_products AS
WITH product_sales AS (
    SELECT d.shop_id,
           d.product_id,
           d.product_name,
           count(DISTINCT d.biz_date) AS appear_days,
           min(d.biz_date) AS first_date,
           max(d.biz_date) AS last_date,
           sum(d.user_pay_amount) AS gmv_30d
    FROM core.douyin_product_daily d
    WHERE d.carrier_type = '全部'
      AND d.biz_date >= (SELECT max(biz_date) - 29 FROM core.douyin_product_daily)
    GROUP BY d.shop_id, d.product_id, d.product_name
),
mapped AS (
    SELECT DISTINCT shop_id, platform_product_id FROM meta.platform_product_mapping
    WHERE enabled AND mapping_status IN ('CONFIRMED','SUGGESTED')
)
SELECT
    s.shop_name AS 店铺名称,
    ps.product_id AS 商品ID,
    ps.product_name AS 商品名称,
    ps.first_date AS 首次出现日期,
    ps.last_date AS 最近出现日期,
    ps.appear_days AS 出现天数,
    round(ps.gmv_30d, 2) AS 近30天成交金额,
    'UNMAPPED' AS 映射状态
FROM product_sales ps
JOIN meta.shop s ON s.shop_id = ps.shop_id
LEFT JOIN mapped mp ON mp.shop_id = ps.shop_id AND mp.platform_product_id = ps.product_id
WHERE mp.platform_product_id IS NULL
  AND ps.product_id <> ''
  AND ps.product_name <> '其他'
ORDER BY ps.gmv_30d DESC;

COMMENT ON VIEW mart.unmapped_products IS 'V1.3 未映射商品（近30天GMV降序，成交金额仅用于决定处理优先级，不用于自动匹配）。';

-- ----------------------------------------------------------------------------
-- 4. 商品映射冲突 View（文档三十一节）
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS mart.product_mapping_conflicts;
CREATE VIEW mart.product_mapping_conflicts AS
-- 同一平台店铺商品存在多条启用映射（含时间重叠）→ CONFLICT
SELECT
    'MULTI_MAPPING' AS conflict_type,
    m.platform_code AS 平台,
    s.shop_name AS 店铺名称,
    m.platform_product_id AS 平台商品ID,
    m.mapping_id AS 映射ID,
    m.master_product_id AS 公司商品ID,
    mp.master_product_code AS 公司商品编码,
    m.mapping_status AS 映射状态,
    m.valid_from AS 有效开始,
    m.valid_to AS 有效结束
FROM meta.platform_product_mapping m
JOIN meta.shop s ON s.shop_id = m.shop_id
JOIN meta.master_product mp ON mp.master_product_id = m.master_product_id
WHERE m.enabled
  AND EXISTS (
      SELECT 1 FROM meta.platform_product_mapping m2
      WHERE m2.platform_code = m.platform_code AND m2.shop_id = m.shop_id
        AND m2.platform_product_id = m.platform_product_id AND m2.enabled
        AND m2.mapping_id <> m.mapping_id
        AND m2.valid_from < coalesce(m.valid_to, 'infinity'::date)
        AND coalesce(m2.valid_to, 'infinity'::date) > m.valid_from
  );

COMMENT ON VIEW mart.product_mapping_conflicts IS 'V1.3 商品映射冲突（同一平台店铺商品多条启用映射时间重叠）。';

-- ----------------------------------------------------------------------------
-- 5. SKU 映射冲突 View（框架预留）
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS mart.sku_mapping_conflicts;
CREATE VIEW mart.sku_mapping_conflicts AS
SELECT 'SKU_SOURCE_NOT_AVAILABLE' AS conflict_type, '当前抖音源无SKU维度，无SKU映射冲突可检测' AS note
WHERE false;

COMMENT ON VIEW mart.sku_mapping_conflicts IS 'V1.3 SKU 映射冲突（预留；SKU 数据源接入后启用）。';
