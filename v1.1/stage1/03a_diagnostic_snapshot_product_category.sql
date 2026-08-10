-- ============================================================================
-- V1.1 阶段1｜经营指标诊断基础层
-- 03a_diagnostic_snapshot_product_category.sql（_diag_product / _diag_category）
-- ============================================================================
-- product 域：product_daily carrier=全部（独立 TOTAL），未指定对象时当前期 TOP100。
-- category 域：默认 L3 粒度。
-- 排名 = 内联 DENSE_RANK（与 rank_* 口径一致：全量排名→筛选，方向按白名单）。
-- 贡献 = 域内占比（denominator_type=domain），notes 附全店占比（双分母语义保留）。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- _diag_product
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart._diag_product(text,date,date,date,date,text,text);

CREATE FUNCTION mart._diag_product(
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
DECLARE
    v_en text;
BEGIN
    SELECT COALESCE(s.shop_name, '平台汇总') INTO v_en FROM meta.shop s WHERE s.shop_name = p_shop_name;
    IF v_en IS NULL THEN v_en := '平台汇总'; END IF;

    RETURN QUERY
    WITH top100 AS (
        SELECT p.product_id
        FROM core.douyin_product_daily p
        JOIN meta.shop s ON s.shop_id = p.shop_id
        WHERE p.biz_date BETWEEN p_cs AND p_ce
          AND p.carrier_type = '全部'
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
        GROUP BY p.product_id
        ORDER BY sum(p.user_pay_amount) DESC NULLS LAST, p.product_id
        LIMIT 100
    ),
    all_raw AS (
        -- 全量对象聚合（排名/贡献分母用；不受 entity 过滤与 TOP100 限制）
        SELECT
            p.product_id AS eid,
            p.product_name AS ename,
            sum(CASE WHEN p.biz_date BETWEEN p_cs AND p_ce THEN p.user_pay_amount END) AS c_up,
            sum(CASE WHEN p.biz_date BETWEEN p_ps AND p_pe THEN p.user_pay_amount END) AS p_up,
            sum(CASE WHEN p.biz_date BETWEEN p_cs AND p_ce THEN p.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN p.biz_date BETWEEN p_ps AND p_pe THEN p.refund_amount_pay_time END) AS p_refund
        FROM core.douyin_product_daily p
        JOIN meta.shop s ON s.shop_id = p.shop_id
        WHERE p.biz_date BETWEEN p_ps AND p_ce
          AND p.carrier_type = '全部'
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
        GROUP BY p.product_id, p.product_name
    ),
    raw AS (
        SELECT
            p.product_id AS eid,
            p.product_name AS ename,
            count(DISTINCT CASE WHEN p.biz_date BETWEEN p_cs AND p_ce THEN p.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN p.biz_date BETWEEN p_ps AND p_pe THEN p.biz_date END)::int AS p_days,
            sum(CASE WHEN p.biz_date BETWEEN p_cs AND p_ce THEN p.user_pay_amount END) AS c_up,
            sum(CASE WHEN p.biz_date BETWEEN p_ps AND p_pe THEN p.user_pay_amount END) AS p_up,
            sum(CASE WHEN p.biz_date BETWEEN p_cs AND p_ce THEN p.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN p.biz_date BETWEEN p_ps AND p_pe THEN p.refund_amount_pay_time END) AS p_refund
        FROM core.douyin_product_daily p
        JOIN meta.shop s ON s.shop_id = p.shop_id
        WHERE p.biz_date BETWEEN p_ps AND p_ce
          AND p.carrier_type = '全部'
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
          AND (p_entity_id IS NULL OR p.product_id = p_entity_id)
          AND (p_entity_name IS NULL OR p.product_name = p_entity_name)
          AND (p_entity_id IS NOT NULL OR p_entity_name IS NOT NULL OR p.product_id IN (SELECT product_id FROM top100))
        GROUP BY p.product_id, p.product_name
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
    ),
    all_metrics AS (
        -- 全量对象指标（排名/贡献分母用，不受 entity 过滤影响）
        SELECT r.eid, r.ename, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
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
        FROM all_raw r
        CROSS JOIN LATERAL (VALUES
            ('user_pay_amount','用户支付金额','成交','amount','金额'),
            ('refund_amount_pay_time','退款金额(支付时间)','售后','amount','金额'),
            ('refund_rate_pay_time','退款率(支付时间)','售后','ratio','0.00%')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    ),
    full_rank AS (
        -- 全量对象排名（全体排名 → 再筛选；方向：退款率 ASC 其余 DESC）
        SELECT am.eid,
            am.metric_key,
            DENSE_RANK() OVER (PARTITION BY am.metric_key ORDER BY
                CASE WHEN am.metric_key='refund_rate_pay_time' THEN am.c_val END ASC NULLS LAST,
                CASE WHEN am.metric_key<>'refund_rate_pay_time' THEN am.c_val END DESC NULLS LAST,
                am.eid) AS cur_rnk,
            DENSE_RANK() OVER (PARTITION BY am.metric_key ORDER BY
                CASE WHEN am.metric_key='refund_rate_pay_time' THEN am.p_val END ASC NULLS LAST,
                CASE WHEN am.metric_key<>'refund_rate_pay_time' THEN am.p_val END DESC NULLS LAST,
                am.eid) AS prev_rnk
        FROM all_metrics am
    )
    SELECT
        v_en AS shop_name,
        'product' AS domain_key,
        '商品' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        NULL::text AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs AS current_start_date, p_ce AS current_end_date,
        p_ps AS previous_start_date, p_pe AS previous_end_date,
        m.c_val AS current_value, m.p_val AS previous_value,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        fr.cur_rnk AS current_rank,
        fr.prev_rnk AS previous_rank,
        (fr.prev_rnk - fr.cur_rnk) AS rank_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM all_metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS current_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN m.p_val / NULLIF((SELECT sum(m2.p_val) FROM all_metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS previous_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time') AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM all_metrics m2 WHERE m2.metric_key = m.metric_key), 0)
                - m.p_val / NULLIF((SELECT sum(m2.p_val) FROM all_metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS contribution_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time') THEN 'domain' ELSE NULL END AS contribution_denominator_type,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN (SELECT sum(m2.c_val) FROM all_metrics m2 WHERE m2.metric_key = m.metric_key) ELSE NULL END AS contribution_denominator_value,
        m.c_days AS current_coverage_days, (p_ce - p_cs + 1)::int AS expected_current_days,
        m.p_days AS previous_coverage_days, (p_pe - p_ps + 1)::int AS expected_previous_days,
        (m.c_days >= (p_ce - p_cs + 1)::int) AS current_coverage_complete,
        (m.p_days >= (p_pe - p_ps + 1)::int) AS previous_coverage_complete,
        CASE WHEN m.p_val IS NOT NULL AND m.p_val = 0 THEN 'PREVIOUS_ZERO' ELSE 'CALCULATED' END AS calculation_status,
        CASE WHEN m.c_days = 0 THEN 'NO_CURRENT_DATA'
             WHEN m.p_days = 0 THEN 'NO_PREVIOUS_DATA'
             WHEN m.c_days < (p_ce - p_cs + 1)::int AND m.p_days < (p_pe - p_ps + 1)::int THEN 'BOTH_INCOMPLETE'
             WHEN m.c_days < (p_ce - p_cs + 1)::int THEN 'CURRENT_INCOMPLETE'
             WHEN m.p_days < (p_pe - p_ps + 1)::int THEN 'PREVIOUS_INCOMPLETE'
             ELSE 'OK' END AS data_status,
        '商品快照（carrier=全部 独立TOTAL）；贡献=域内占比' AS notes
    FROM metrics m
    LEFT JOIN full_rank fr ON fr.eid = m.eid AND fr.metric_key = m.metric_key
    ORDER BY m.eid, m.metric_key;
END;
$function$;

COMMENT ON FUNCTION mart._diag_product(text,date,date,date,date,text,text) IS 'V1.1 商品域诊断快照（内部函数，不对外授权）。';

-- ----------------------------------------------------------------------------
-- _diag_category（默认 L3）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart._diag_category(text,date,date,date,date,integer);

CREATE FUNCTION mart._diag_category(
    p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_category_level integer
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
DECLARE
    v_en text;
    v_level int;
BEGIN
    SELECT COALESCE(s.shop_name, '平台汇总') INTO v_en FROM meta.shop s WHERE s.shop_name = p_shop_name;
    IF v_en IS NULL THEN v_en := '平台汇总'; END IF;
    v_level := COALESCE(p_category_level, 3);

    RETURN QUERY
    WITH raw AS (
        SELECT
            c.category_level_3 AS eid,
            c.category_level_3 AS ename,
            count(DISTINCT CASE WHEN c.biz_date BETWEEN p_cs AND p_ce THEN c.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN c.biz_date BETWEEN p_ps AND p_pe THEN c.biz_date END)::int AS p_days,
            sum(CASE WHEN c.biz_date BETWEEN p_cs AND p_ce THEN c.user_pay_amount END) AS c_up,
            sum(CASE WHEN c.biz_date BETWEEN p_ps AND p_pe THEN c.user_pay_amount END) AS p_up,
            sum(CASE WHEN c.biz_date BETWEEN p_cs AND p_ce THEN c.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN c.biz_date BETWEEN p_ps AND p_pe THEN c.refund_amount_pay_time END) AS p_refund
        FROM core.douyin_category_daily c
        JOIN meta.shop s ON s.shop_id = c.shop_id
        WHERE c.biz_date BETWEEN p_ps AND p_ce
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
          AND c.category_level_3 IS NOT NULL AND c.category_level_3 <> '' AND c.category_level_3 <> '全部'
          AND (v_level = 3 OR c.category_level_1 IS NOT NULL AND c.category_level_1 <> '')
        GROUP BY c.category_level_3
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
        v_en AS shop_name,
        'category' AS domain_key,
        '类目' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        NULL::text AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs AS current_start_date, p_ce AS current_end_date,
        p_ps AS previous_start_date, p_pe AS previous_end_date,
        m.c_val AS current_value, m.p_val AS previous_value,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.eid,
                        DENSE_RANK() OVER (ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid)
             ELSE NULL END AS current_rank,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.eid,
                        DENSE_RANK() OVER (ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid)
             ELSE NULL END AS previous_rank,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.eid,
                        DENSE_RANK() OVER (ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid)
                  - (SELECT t.rnk FROM (SELECT m2.eid,
                        DENSE_RANK() OVER (ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid)
             ELSE NULL END AS rank_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS current_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS previous_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time') AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0)
                - m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS contribution_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time') THEN 'domain' ELSE NULL END AS contribution_denominator_type,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN (SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key) ELSE NULL END AS contribution_denominator_value,
        m.c_days AS current_coverage_days, (p_ce - p_cs + 1)::int AS expected_current_days,
        m.p_days AS previous_coverage_days, (p_pe - p_ps + 1)::int AS expected_previous_days,
        (m.c_days >= (p_ce - p_cs + 1)::int) AS current_coverage_complete,
        (m.p_days >= (p_pe - p_ps + 1)::int) AS previous_coverage_complete,
        CASE WHEN m.p_val IS NOT NULL AND m.p_val = 0 THEN 'PREVIOUS_ZERO' ELSE 'CALCULATED' END AS calculation_status,
        CASE WHEN m.c_days = 0 THEN 'NO_CURRENT_DATA'
             WHEN m.p_days = 0 THEN 'NO_PREVIOUS_DATA'
             WHEN m.c_days < (p_ce - p_cs + 1)::int AND m.p_days < (p_pe - p_ps + 1)::int THEN 'BOTH_INCOMPLETE'
             WHEN m.c_days < (p_ce - p_cs + 1)::int THEN 'CURRENT_INCOMPLETE'
             WHEN m.p_days < (p_pe - p_ps + 1)::int THEN 'PREVIOUS_INCOMPLETE'
             ELSE 'OK' END AS data_status,
        '类目快照（L' || v_level || ' 粒度）' AS notes
    FROM metrics m
    ORDER BY m.eid, m.metric_key;
END;
$function$;

COMMENT ON FUNCTION mart._diag_category(text,date,date,date,date,integer) IS 'V1.1 类目域诊断快照（内部函数，不对外授权）。';
