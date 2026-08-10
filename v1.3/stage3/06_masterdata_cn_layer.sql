-- ============================================================================
-- V1.3 阶段3｜跨店商品 / SKU / 品线主数据
-- 06_masterdata_cn_layer.sql（中文数据层 9 View）
-- ============================================================================

DROP VIEW IF EXISTS 中文数据.公司商品主档;
CREATE VIEW 中文数据.公司商品主档 AS
SELECT master_product_code    AS 公司商品编码,
       master_product_name    AS 公司商品名称,
       brand_name             AS 品牌,
       (SELECT product_line_name FROM meta.product_line pl WHERE pl.product_line_id = mp.product_line_id) AS 所属品线,
       product_status         AS 商品状态,
       enabled                AS 启用,
       valid_from             AS 有效开始,
       valid_to               AS 有效结束,
       notes                  AS 备注
FROM meta.master_product mp;

DROP VIEW IF EXISTS 中文数据.公司SKU主档;
CREATE VIEW 中文数据.公司SKU主档 AS
SELECT ms.master_sku_code      AS 公司SKU编码,
       ms.master_sku_name      AS 公司SKU名称,
       mp.master_product_code  AS 所属公司商品编码,
       ms.specification        AS 规格,
       ms.net_content          AS 净含量,
       ms.variant_name         AS 变体名称,
       ms.enabled              AS 启用,
       ms.valid_from           AS 有效开始,
       ms.valid_to             AS 有效结束
FROM meta.master_sku ms
JOIN meta.master_product mp ON mp.master_product_id = ms.master_product_id;

DROP VIEW IF EXISTS 中文数据.品线配置;
CREATE VIEW 中文数据.品线配置 AS
SELECT product_line_code    AS 品线编码,
       product_line_name    AS 品线名称,
       enabled              AS 启用,
       display_order        AS 排序,
       valid_from           AS 有效开始,
       valid_to             AS 有效结束,
       notes                AS 备注
FROM meta.product_line;

DROP VIEW IF EXISTS 中文数据.平台商品映射;
CREATE VIEW 中文数据.平台商品映射 AS
SELECT m.platform_code               AS 平台,
       s.shop_name                   AS 店铺名称,
       m.platform_product_id         AS 平台商品ID,
       m.platform_product_name_snapshot AS 平台商品名称,
       mp.master_product_code        AS 公司商品编码,
       mp.master_product_name        AS 公司商品名称,
       (SELECT product_line_name FROM meta.product_line pl WHERE pl.product_line_id = mp.product_line_id) AS 所属品线,
       m.mapping_status              AS 映射状态,
       m.mapping_source              AS 映射来源,
       m.confidence_score            AS 置信度,
       m.valid_from                  AS 有效开始,
       m.valid_to                    AS 有效结束
FROM meta.platform_product_mapping m
JOIN meta.shop s ON s.shop_id = m.shop_id
JOIN meta.master_product mp ON mp.master_product_id = m.master_product_id;

DROP VIEW IF EXISTS 中文数据.平台SKU映射;
CREATE VIEW 中文数据.平台SKU映射 AS
SELECT 'SKU_SOURCE_NOT_AVAILABLE' AS 状态说明,
       '当前抖音正式商品事实源不含SKU维度；Master SKU 与映射框架已建立，不伪造平台SKU' AS 说明
WHERE false;

DROP VIEW IF EXISTS 中文数据.未归属商品;
CREATE VIEW 中文数据.未归属商品 AS
SELECT * FROM mart.unmapped_products;

DROP VIEW IF EXISTS 中文数据.未归属SKU;
CREATE VIEW 中文数据.未归属SKU AS
SELECT 'SKU_SOURCE_NOT_AVAILABLE' AS 状态说明, '当前抖音源无SKU维度' AS 说明 WHERE false;

DROP VIEW IF EXISTS 中文数据.商品映射冲突;
CREATE VIEW 中文数据.商品映射冲突 AS
SELECT * FROM mart.product_mapping_conflicts;

DROP VIEW IF EXISTS 中文数据.SKU映射冲突;
CREATE VIEW 中文数据.SKU映射冲突 AS
SELECT * FROM mart.sku_mapping_conflicts;

COMMENT ON VIEW 中文数据.公司商品主档 IS 'V1.3 公司商品主档（中文）。';
COMMENT ON VIEW 中文数据.公司SKU主档 IS 'V1.3 公司SKU主档（中文）。';
COMMENT ON VIEW 中文数据.品线配置 IS 'V1.3 品线配置（中文）。';
COMMENT ON VIEW 中文数据.平台商品映射 IS 'V1.3 平台商品映射（中文）。';
COMMENT ON VIEW 中文数据.平台SKU映射 IS 'V1.3 平台SKU映射（中文；当前SKU源不可用）。';
COMMENT ON VIEW 中文数据.未归属商品 IS 'V1.3 未归属商品（近30天GMV排序）。';
COMMENT ON VIEW 中文数据.未归属SKU IS 'V1.3 未归属SKU（当前SKU源不可用）。';
COMMENT ON VIEW 中文数据.商品映射冲突 IS 'V1.3 商品映射冲突。';
COMMENT ON VIEW 中文数据.SKU映射冲突 IS 'V1.3 SKU映射冲突（预留）。';
