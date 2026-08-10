-- ============================================================================
-- V1.1 阶段1补充｜多店兼容补充检查
-- 01_entity_extension.sql（诊断实体扩展 + 支持矩阵）
-- ============================================================================
-- 新增实体：platform / master_product / shop_product / product_line
-- 不改变既有：指标公式 / 18 Scope / 快照核心算法 / source_only / ratio 重算
-- ============================================================================

BEGIN;

-- 新增诊断实体（document 第三节）
INSERT INTO mart.diagnostic_entity_rule
    (domain_key, domain_name_cn, enabled, entity_id_field, entity_name_field,
     supports_rank, supports_contribution, supports_scope, source_object, notes)
VALUES
    ('platform',        '抖音平台整体', true, 'platform_code', 'platform_name', false, true,  true,  'meta.platform + 两店合法汇总', '平台模式=p_platform_code=douyin且p_shop_name=NULL；覆盖=enabled/covered/missing店铺'),
    ('master_product',  '公司商品',     true, 'master_product_id', 'master_product_name', true, true, false, 'meta.master_product + CONFIRMED映射', '仅使用CONFIRMED映射成员；mapping coverage 必带'),
    ('shop_product',    '店铺商品',     true, 'product_id', 'product_name', true, true, false, 'core.douyin_product_daily', '=原 product 域（shop_name+platform_product_id），保留店铺商品身份'),
    ('product_line',    '品线',         true, 'product_line_id', 'product_line_name', true, true, false, 'meta.product_line + 已确认Master Product', '仅对真实可计算指标启用')
ON CONFLICT (domain_key) DO UPDATE SET
    domain_name_cn = EXCLUDED.domain_name_cn, enabled = EXCLUDED.enabled,
    notes = EXCLUDED.notes;

COMMIT;

\echo '=== 诊断实体（9 域） ==='
SELECT domain_key, domain_name_cn, enabled FROM mart.diagnostic_entity_rule ORDER BY domain_key;
