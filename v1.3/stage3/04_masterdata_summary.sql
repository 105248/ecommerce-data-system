-- ============================================================================
-- V1.3 阶段3｜跨店商品 / SKU / 品线主数据
-- 04_masterdata_summary.sql（跨店 Master Product 汇总 / 品线汇总 / 排名 / 质量指标）
-- ============================================================================
-- 原则（文档三十八/三十九/四十三节）：
--   跨店汇总仅使用 CONFIRMED 映射成员；未确认候选不得并入；返回 mapping coverage。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 跨店 Master Product 经营汇总（仅 CONFIRMED 成员）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_master_product_period_summary(bigint,date,date,text);
CREATE FUNCTION mart.get_master_product_period_summary(
    p_master_product_id bigint,
    p_start_date date,
    p_end_date   date,
    p_shop_name  text DEFAULT NULL
) RETURNS TABLE (
    master_product_id integer, master_product_code text, master_product_name text,
    product_line_id integer, product_line_name text,
    start_date date, end_date date,
    mapped_shop_count bigint, unmapped_member_count bigint, mapping_complete boolean,
    user_pay_amount numeric,
    refund_amount_pay_time numeric, refund_rate_pay_time numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
BEGIN
    RETURN QUERY
    WITH mp AS (
        SELECT m.master_product_id, m.master_product_code, m.master_product_name,
               m.product_line_id FROM meta.master_product m WHERE m.master_product_id = p_master_product_id
    ),
    members AS (
        SELECT m.shop_id, m.platform_product_id
        FROM meta.platform_product_mapping m
        WHERE m.master_product_id = p_master_product_id AND m.enabled AND m.mapping_status = 'CONFIRMED'
          AND (p_shop_name IS NULL OR m.shop_id = (SELECT shop_id FROM meta.shop WHERE shop_name = p_shop_name))
    ),
    agg AS (
        SELECT
            count(DISTINCT d.shop_id)::bigint AS mapped_shop_count,
            sum(d.user_pay_amount) AS up,
            sum(d.refund_amount_pay_time) AS refund
        FROM members mem
        JOIN core.douyin_product_daily d
          ON d.shop_id = mem.shop_id AND d.product_id = mem.platform_product_id
         AND d.biz_date BETWEEN p_start_date AND p_end_date AND d.carrier_type = '全部'
    )
    SELECT
        mp.master_product_id, mp.master_product_code, mp.master_product_name,
        mp.product_line_id,
        (SELECT l.product_line_name FROM meta.product_line l WHERE l.product_line_id = mp.product_line_id),
        p_start_date, p_end_date,
        a.mapped_shop_count,
        ((SELECT count(DISTINCT shop_id) FROM meta.shop WHERE platform_code='douyin' AND enabled) - a.mapped_shop_count)::bigint AS unmapped_member_count,
        (a.mapped_shop_count >= (SELECT count(*) FROM meta.shop WHERE platform_code='douyin' AND enabled)) AS mapping_complete,
        round(a.up, 2), round(a.refund, 2),
        round(a.refund / NULLIF(a.up, 0), 10)
    FROM mp, agg a;
END; $f$;

COMMENT ON FUNCTION mart.get_master_product_period_summary(bigint,date,date,text) IS
'V1.3 跨店 Master Product 经营汇总（仅 CONFIRMED 成员；返回 mapped_shop_count/unmapped_member_count/mapping_complete）。';

-- ----------------------------------------------------------------------------
-- 2. 品线跨店汇总（品线 → CONFIRMED Master Product 成员）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_product_line_period_summary(text,date,date);
CREATE FUNCTION mart.get_product_line_period_summary(
    p_product_line_name text,
    p_start_date date,
    p_end_date   date
) RETURNS TABLE (
    product_line_id integer, product_line_name text,
    start_date date, end_date date,
    expected_member_count bigint, mapped_member_count bigint, unmapped_member_count bigint,
    enabled_shop_count bigint, covered_shop_count bigint,
    mapping_complete boolean, data_coverage_complete boolean,
    user_pay_amount numeric, refund_amount_pay_time numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
BEGIN
    RETURN QUERY
    WITH pl AS (
        SELECT l.product_line_id, l.product_line_name FROM meta.product_line l WHERE l.product_line_name = p_product_line_name
    ),
    mp_list AS (
        SELECT m.master_product_id FROM meta.master_product m
        JOIN pl ON pl.product_line_id = m.product_line_id
        WHERE m.enabled
    ),
    mapped_mp AS (
        SELECT DISTINCT m.master_product_id FROM meta.platform_product_mapping m
        JOIN mp_list ml ON ml.master_product_id = m.master_product_id
        WHERE m.enabled AND m.mapping_status = 'CONFIRMED'
    ),
    agg AS (
        SELECT
            count(DISTINCT mp_list.master_product_id)::bigint AS expected,
            count(DISTINCT mm.master_product_id)::bigint AS mapped,
            sum(d.user_pay_amount) AS up,
            sum(d.refund_amount_pay_time) AS refund,
            count(DISTINCT d.shop_id)::bigint AS covered_shop
        FROM mp_list
        LEFT JOIN mapped_mp mm ON mm.master_product_id = mp_list.master_product_id
        LEFT JOIN meta.platform_product_mapping m
          ON m.master_product_id = mp_list.master_product_id AND m.enabled AND m.mapping_status='CONFIRMED'
        LEFT JOIN core.douyin_product_daily d
          ON d.shop_id = m.shop_id AND d.product_id = m.platform_product_id
         AND d.biz_date BETWEEN p_start_date AND p_end_date AND d.carrier_type='全部'
    )
    SELECT
        pl.product_line_id, pl.product_line_name, p_start_date, p_end_date,
        a.expected, a.mapped, (a.expected - a.mapped) AS unmapped,
        (SELECT count(*)::bigint FROM meta.shop WHERE platform_code='douyin' AND enabled) AS enabled_shop,
        a.covered_shop,
        (a.mapped = a.expected) AS mapping_complete,
        (a.covered_shop >= (SELECT count(*) FROM meta.shop WHERE platform_code='douyin' AND enabled)) AS data_coverage_complete,
        round(a.up, 2), round(a.refund, 2)
    FROM pl, agg a;
END; $f$;

COMMENT ON FUNCTION mart.get_product_line_period_summary(text,date,date) IS
'V1.3 品线跨店汇总（expected/mapped/unmapped 成员数 + 店铺覆盖 + mapping_complete/data_coverage_complete）。';

-- ----------------------------------------------------------------------------
-- 3. Master Product 跨店排名（与 rank_products 店铺内排名并存，文档四十/四十一节）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.rank_master_products(date,date,text,text,text,integer);
CREATE FUNCTION mart.rank_master_products(
    p_start_date date,
    p_end_date   date,
    p_metric_key text DEFAULT 'user_pay_amount',
    p_sort_by    text DEFAULT 'current_value',
    p_sort_direction text DEFAULT 'DESC',
    p_limit      integer DEFAULT 20
) RETURNS TABLE (
    master_product_id integer, master_product_code text, master_product_name text,
    product_line_name text,
    metric_key text, current_value numeric,
    mapped_shop_count bigint, mapping_complete boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
BEGIN
    RETURN QUERY
    SELECT
        mp.master_product_id, mp.master_product_code, mp.master_product_name,
        (SELECT l.product_line_name FROM meta.product_line l WHERE l.product_line_id = mp.product_line_id),
        p_metric_key,
        round(sum(d.user_pay_amount), 2) AS current_value,
        count(DISTINCT m.shop_id)::bigint AS mapped_shop_count,
        (count(DISTINCT m.shop_id) >= (SELECT count(*) FROM meta.shop WHERE platform_code='douyin' AND enabled)) AS mapping_complete
    FROM meta.master_product mp
    JOIN meta.platform_product_mapping m
      ON m.master_product_id = mp.master_product_id AND m.enabled AND m.mapping_status = 'CONFIRMED'
    LEFT JOIN core.douyin_product_daily d
      ON d.shop_id = m.shop_id AND d.product_id = m.platform_product_id
     AND d.biz_date BETWEEN p_start_date AND p_end_date AND d.carrier_type = '全部'
    GROUP BY mp.master_product_id, mp.master_product_code, mp.master_product_name
    ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN sum(d.user_pay_amount) END DESC NULLS LAST,
             CASE WHEN upper(p_sort_direction)='ASC' THEN sum(d.user_pay_amount) END ASC NULLS LAST,
             mp.master_product_id
    LIMIT p_limit;
END; $f$;

COMMENT ON FUNCTION mart.rank_master_products(date,date,text,text,text,integer) IS
'V1.3 Master Product 跨店排名（仅 CONFIRMED 成员；与店铺内 rank_products 并存）。';

-- ----------------------------------------------------------------------------
-- 4. 主数据质量指标（文档六十/六十一节）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_masterdata_quality(date,date);
CREATE FUNCTION mart.get_masterdata_quality(
    p_start_date date,
    p_end_date   date
) RETURNS TABLE (
    metric_key text, metric_name_cn text, metric_value numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $f$
BEGIN
    RETURN QUERY
    WITH sales AS (
        SELECT d.shop_id, d.product_id, sum(d.user_pay_amount) AS gmv
        FROM core.douyin_product_daily d
        WHERE d.carrier_type = '全部' AND d.biz_date BETWEEN p_start_date AND p_end_date
        GROUP BY d.shop_id, d.product_id
    ),
    mapped_sales AS (
        SELECT s.gmv FROM sales s
        JOIN meta.platform_product_mapping m
          ON m.shop_id = s.shop_id AND m.platform_product_id = s.product_id
         AND m.enabled AND m.mapping_status = 'CONFIRMED'
    )
    SELECT
        'product_mapping_rate_by_gmv' AS metric_key,
        '已确认映射商品成交金额覆盖率(GMV)' AS metric_name_cn,
        round((SELECT sum(gmv) FROM mapped_sales) / NULLIF((SELECT sum(gmv) FROM sales), 0), 6) AS metric_value
    UNION ALL SELECT
        'product_mapping_rate_by_product_count',
        '已确认映射商品数量覆盖率',
        round((SELECT count(*)::numeric FROM mapped_sales) / NULLIF((SELECT count(*)::numeric FROM sales), 0), 6)
    UNION ALL SELECT
        'product_line_assignment_rate',
        'Master Product 品线归属率(已启用)',
        round((SELECT count(*)::numeric FROM meta.master_product WHERE enabled AND product_line_id IS NOT NULL)
              / NULLIF((SELECT count(*)::numeric FROM meta.master_product WHERE enabled), 0), 6)
    UNION ALL SELECT
        'conflict_count',
        '商品映射冲突数',
        (SELECT count(*)::numeric FROM mart.product_mapping_conflicts)
    UNION ALL SELECT
        'unmapped_high_value_count',
        '近30天高价值未映射商品数(GMV>10000)',
        (SELECT count(*)::numeric FROM mart.unmapped_products WHERE 近30天成交金额 > 10000)
    UNION ALL SELECT
        'sku_mapping_rate',
        'SKU映射覆盖率',
        NULL::numeric  -- SKU 源不可用，无法计算
    ;
END; $f$;

COMMENT ON FUNCTION mart.get_masterdata_quality(date,date) IS 'V1.3 主数据质量指标（GMV覆盖率/数量覆盖率/品线归属率/冲突数/高价值未映射数）。';
