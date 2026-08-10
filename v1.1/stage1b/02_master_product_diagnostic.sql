-- ============================================================================
-- V1.1 阶段1补充｜多店兼容补充检查
-- 02_master_product_diagnostic.sql（Master Product / Product Line / 平台快照整合 + 支持矩阵）
-- ============================================================================
-- 原则：master_product/product_line 仅用 CONFIRMED 映射成员；shop_product=原 product 域；
-- 不支持指标返回 UNSUPPORTED_DOMAIN_METRIC；mapping coverage 附 notes。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. 支持矩阵扩展（master_product / product_line / shop_product = product 3 指标）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_diagnostic_entity_metrics(text);
CREATE FUNCTION mart.get_diagnostic_entity_metrics(p_domain_key text)
RETURNS TABLE (
    domain_key text, metric_key text, metric_name_cn text,
    metric_group text, metric_type text, display_format text,
    diagnostic_enabled boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
    WITH domain_support AS (
        SELECT 'shop' AS dk, metric_key FROM mart.diagnostic_metric_rule WHERE diagnostic_enabled
        UNION ALL SELECT 'scope', metric_key FROM mart.diagnostic_metric_rule WHERE diagnostic_enabled
        UNION ALL SELECT 'platform', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','transaction_amount','settlement_amount','refund_amount_pay_time','refund_rate_pay_time',
                                 'transaction_order_count','transaction_buyer_count','transaction_item_count',
                                 'ad_spend_shop_promoted','ad_spend_shop_bound','ad_attributed_transaction_amount',
                                 'ad_attributed_transaction_share','ad_spend_rate_net_refund_shop_bound',
                                 'total_expense_rate_net_refund_shop_bound','ad_efficiency_shop_promoted','store_efficiency_shop_promoted')
        UNION ALL SELECT 'product', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
        UNION ALL SELECT 'shop_product', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
        UNION ALL SELECT 'master_product', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
        UNION ALL SELECT 'product_line', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
        UNION ALL SELECT 'carrier', metric_key FROM mart.diagnostic_metric_rule WHERE diagnostic_enabled
            AND metric_key NOT IN ('ad_efficiency_shop_promoted','ad_efficiency_shop_bound',
                                   'store_efficiency_shop_promoted','store_efficiency_shop_bound')
        UNION ALL SELECT 'account', metric_key FROM mart.diagnostic_metric_rule WHERE diagnostic_enabled
            AND metric_key NOT IN ('ad_efficiency_shop_promoted','ad_efficiency_shop_bound',
                                   'store_efficiency_shop_promoted','store_efficiency_shop_bound')
        UNION ALL SELECT 'category', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
    )
    SELECT ds.dk AS domain_key, m.metric_key, m.metric_name_cn, m.metric_group,
           m.metric_type, m.display_format, m.diagnostic_enabled
    FROM domain_support ds
    JOIN mart.diagnostic_metric_rule m ON m.metric_key = ds.metric_key
    WHERE ds.dk = p_domain_key
    ORDER BY m.metric_group, m.metric_key;
$function$;

-- ----------------------------------------------------------------------------
-- 2. _diag_master_product：Master Product 诊断快照（仅 CONFIRMED 成员）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart._diag_master_product(text,date,date,date,date,text,text);
CREATE FUNCTION mart._diag_master_product(
    p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date,
    p_entity_id text, p_entity_name text
) RETURNS TABLE (
    shop_name text, domain_key text, domain_name_cn text,
    entity_id text, entity_name text, scope_key text,
    metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text,
    current_start_date date, current_end_date date,
    previous_start_date date, previous_end_date date,
    current_value numeric, previous_value numeric,
    absolute_change numeric, relative_change numeric, percentage_point_change numeric,
    current_rank bigint, previous_rank bigint, rank_change bigint,
    current_contribution numeric, previous_contribution numeric, contribution_change numeric,
    contribution_denominator_type text, contribution_denominator_value numeric,
    current_coverage_days integer, expected_current_days integer,
    previous_coverage_days integer, expected_previous_days integer,
    current_coverage_complete boolean, previous_coverage_complete boolean,
    calculation_status text, data_status text, notes text
)
LANGUAGE plpgsql
STABLE
AS $function$
BEGIN
    RETURN QUERY
    WITH mp_list AS (
        SELECT mp.master_product_id::text AS eid, mp.master_product_name AS ename
        FROM meta.master_product mp
        WHERE mp.enabled
          AND EXISTS (SELECT 1 FROM meta.platform_product_mapping m
                      WHERE m.master_product_id = mp.master_product_id AND m.enabled AND m.mapping_status='CONFIRMED')
          AND (p_entity_id IS NULL OR mp.master_product_id = p_entity_id::bigint)
          AND (p_entity_name IS NULL OR mp.master_product_name = p_entity_name)
    ),
    members AS (
        SELECT m.master_product_id, m.shop_id, m.platform_product_id
        FROM meta.platform_product_mapping m
        WHERE m.enabled AND m.mapping_status = 'CONFIRMED'
    ),
    raw AS (
        SELECT
            ml.eid, ml.ename,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.biz_date END)::int AS p_days,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.user_pay_amount END) AS c_up,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.user_pay_amount END) AS p_up,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.refund_amount_pay_time END) AS p_refund,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN mem.shop_id END)::int AS c_mapped_shops
        FROM mp_list ml
        JOIN members mem ON mem.master_product_id = ml.eid::bigint
        LEFT JOIN core.douyin_product_daily d
          ON d.shop_id = mem.shop_id AND d.product_id = mem.platform_product_id
         AND d.biz_date BETWEEN p_ps AND p_ce AND d.carrier_type = '全部'
        GROUP BY ml.eid, ml.ename
    ),
    metrics AS (
        SELECT r.*, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
            END AS p_val
        FROM raw r
        CROSS JOIN LATERAL (VALUES
            ('user_pay_amount','用户支付金额','成交','amount','金额'),
            ('refund_amount_pay_time','退款金额(支付时间)','售后','amount','金额'),
            ('refund_rate_pay_time','退款率(支付时间)','售后','ratio','0.00%')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        COALESCE((SELECT s.shop_name::text FROM meta.shop s WHERE s.shop_name = p_shop_name), '平台汇总') AS shop_name,
        'master_product' AS domain_key,
        '公司商品' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        NULL::text AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs, p_ce, p_ps, p_pe,
        m.c_val, m.p_val,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        (SELECT t.rnk FROM (SELECT m2.eid,
             DENSE_RANK() OVER (ORDER BY CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                                           CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                                           m2.eid) AS rnk
             FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid) AS current_rank,
        (SELECT t.rnk FROM (SELECT m2.eid,
             DENSE_RANK() OVER (ORDER BY CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                                           CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                                           m2.eid) AS rnk
             FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid) AS previous_rank,
        NULL::bigint AS rank_change,
        m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0) AS current_contribution,
        m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0) AS previous_contribution,
        NULL::numeric AS contribution_change,
        'domain' AS contribution_denominator_type,
        (SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key) AS contribution_denominator_value,
        m.c_days, (p_ce - p_cs + 1)::int,
        m.p_days, (p_pe - p_ps + 1)::int,
        (m.c_days >= (p_ce - p_cs + 1)::int) AS current_coverage_complete,
        (m.p_days >= (p_pe - p_ps + 1)::int) AS previous_coverage_complete,
        CASE WHEN m.p_val IS NOT NULL AND m.p_val = 0 THEN 'PREVIOUS_ZERO' ELSE 'CALCULATED' END AS calculation_status,
        CASE WHEN m.c_days = 0 THEN 'NO_CURRENT_DATA'
             WHEN m.p_days = 0 THEN 'NO_PREVIOUS_DATA'
             WHEN m.c_days < (p_ce - p_cs + 1)::int AND m.p_days < (p_pe - p_ps + 1)::int THEN 'BOTH_INCOMPLETE'
             WHEN m.c_days < (p_ce - p_cs + 1)::int THEN 'CURRENT_INCOMPLETE'
             WHEN m.p_days < (p_pe - p_ps + 1)::int THEN 'PREVIOUS_INCOMPLETE'
             ELSE 'OK' END AS data_status,
        'Master Product（仅CONFIRMED成员）；mapping_coverage附: mapped_shops=' || m.c_mapped_shops || '/2' AS notes
    FROM metrics m
    ORDER BY m.eid, m.metric_key;
END;
$function$;

-- ----------------------------------------------------------------------------
-- 3. _diag_product_line：品线诊断快照（品线 → CONFIRMED Master Product 成员）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart._diag_product_line(text,date,date,date,date,text);
CREATE FUNCTION mart._diag_product_line(
    p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_name text
) RETURNS TABLE (
    shop_name text, domain_key text, domain_name_cn text,
    entity_id text, entity_name text, scope_key text,
    metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text,
    current_start_date date, current_end_date date,
    previous_start_date date, previous_end_date date,
    current_value numeric, previous_value numeric,
    absolute_change numeric, relative_change numeric, percentage_point_change numeric,
    current_rank bigint, previous_rank bigint, rank_change bigint,
    current_contribution numeric, previous_contribution numeric, contribution_change numeric,
    contribution_denominator_type text, contribution_denominator_value numeric,
    current_coverage_days integer, expected_current_days integer,
    previous_coverage_days integer, expected_previous_days integer,
    current_coverage_complete boolean, previous_coverage_complete boolean,
    calculation_status text, data_status text, notes text
)
LANGUAGE plpgsql
STABLE
AS $function$
BEGIN
    RETURN QUERY
    WITH pl_list AS (
        SELECT pl.product_line_id::text AS eid, pl.product_line_name AS ename
        FROM meta.product_line pl
        WHERE (p_entity_name IS NULL OR pl.product_line_name = p_entity_name)
          AND EXISTS (SELECT 1 FROM meta.master_product mp
                      WHERE mp.product_line_id = pl.product_line_id AND mp.enabled
                        AND EXISTS (SELECT 1 FROM meta.platform_product_mapping m
                                    WHERE m.master_product_id = mp.master_product_id AND m.enabled AND m.mapping_status='CONFIRMED'))
    ),
    members AS (
        SELECT m.master_product_id, m.shop_id, m.platform_product_id
        FROM meta.platform_product_mapping m
        JOIN meta.master_product mp ON mp.master_product_id = m.master_product_id
        WHERE m.enabled AND m.mapping_status = 'CONFIRMED'
          AND mp.product_line_id IN (SELECT eid::integer FROM pl_list)
    ),
    raw AS (
        SELECT
            pll.eid, pll.ename,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.biz_date END)::int AS p_days,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.user_pay_amount END) AS c_up,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.user_pay_amount END) AS p_up,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.refund_amount_pay_time END) AS p_refund,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN mem.shop_id END)::int AS c_mapped_shops
        FROM pl_list pll
        JOIN meta.master_product mpl ON mpl.product_line_id = pll.eid::integer
        JOIN members mem ON mem.master_product_id = mpl.master_product_id
        LEFT JOIN core.douyin_product_daily d
          ON d.shop_id = mem.shop_id AND d.product_id = mem.platform_product_id
         AND d.biz_date BETWEEN p_ps AND p_ce AND d.carrier_type = '全部'
        GROUP BY pll.eid, pll.ename
    ),
    metrics AS (
        SELECT r.*, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
            END AS p_val
        FROM raw r
        CROSS JOIN LATERAL (VALUES
            ('user_pay_amount','用户支付金额','成交','amount','金额'),
            ('refund_amount_pay_time','退款金额(支付时间)','售后','amount','金额'),
            ('refund_rate_pay_time','退款率(支付时间)','售后','ratio','0.00%')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        COALESCE((SELECT s.shop_name::text FROM meta.shop s WHERE s.shop_name = p_shop_name), '平台汇总') AS shop_name,
        'product_line' AS domain_key,
        '品线' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        NULL::text AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs, p_ce, p_ps, p_pe,
        m.c_val, m.p_val,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        (SELECT t.rnk FROM (SELECT m2.eid,
             DENSE_RANK() OVER (ORDER BY CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                                           CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                                           m2.eid) AS rnk
             FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid) AS current_rank,
        (SELECT t.rnk FROM (SELECT m2.eid,
             DENSE_RANK() OVER (ORDER BY CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                                           CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                                           m2.eid) AS rnk
             FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid) AS previous_rank,
        NULL::bigint AS rank_change,
        m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0) AS current_contribution,
        m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0) AS previous_contribution,
        NULL::numeric AS contribution_change,
        'domain' AS contribution_denominator_type,
        (SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key) AS contribution_denominator_value,
        m.c_days, (p_ce - p_cs + 1)::int,
        m.p_days, (p_pe - p_ps + 1)::int,
        (m.c_days >= (p_ce - p_cs + 1)::int) AS current_coverage_complete,
        (m.p_days >= (p_pe - p_ps + 1)::int) AS previous_coverage_complete,
        CASE WHEN m.p_val IS NOT NULL AND m.p_val = 0 THEN 'PREVIOUS_ZERO' ELSE 'CALCULATED' END AS calculation_status,
        CASE WHEN m.c_days = 0 THEN 'NO_CURRENT_DATA'
             WHEN m.p_days = 0 THEN 'NO_PREVIOUS_DATA'
             WHEN m.c_days < (p_ce - p_cs + 1)::int AND m.p_days < (p_pe - p_ps + 1)::int THEN 'BOTH_INCOMPLETE'
             WHEN m.c_days < (p_ce - p_cs + 1)::int THEN 'CURRENT_INCOMPLETE'
             WHEN m.p_days < (p_pe - p_ps + 1)::int THEN 'PREVIOUS_INCOMPLETE'
             ELSE 'OK' END AS data_status,
        '品线（仅已确认Master Product成员）；mapped_shops=' || m.c_mapped_shops || '/2' AS notes
    FROM metrics m
    ORDER BY m.eid, m.metric_key;
END;
$function$;
