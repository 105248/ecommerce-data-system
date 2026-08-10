-- ============================================================================
-- V1.3 阶段2｜抖音多店统一经营层
-- 03_shop_contribution.sql
--   mart.get_shop_contribution             店铺贡献度（占平台比重）
--   mart.decompose_platform_change_by_shop 平台变化按店铺拆解（负向/正向/净额）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 店铺贡献度
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_shop_contribution(text,date,date,text,text);

CREATE FUNCTION mart.get_shop_contribution(
    p_platform_code text,
    p_start_date    date,
    p_end_date      date,
    p_scope_key     text DEFAULT '全店',
    p_metric_key    text DEFAULT 'user_pay_amount'
) RETURNS TABLE (
    platform_code text, platform_name text,
    start_date date, end_date date, scope_key text, metric_key text,
    shop_name text,
    current_value numeric,
    platform_total numeric,
    contribution numeric,
    previous_value numeric,
    previous_contribution numeric,
    contribution_change numeric,
    coverage_complete boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_scope_sale text; v_scope_carrier text; v_scope_period text;
    v_ps date; v_pe date; v_days int;
BEGIN
    SELECT sale_scope, carrier_type, ad_period INTO v_scope_sale, v_scope_carrier, v_scope_period
    FROM mart.resolve_scope(p_scope_key);
    IF v_scope_sale IS NULL THEN RAISE EXCEPTION '未知经营语义: %', p_scope_key; END IF;
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);

    RETURN QUERY
    WITH enabled_shops AS (
        SELECT s.shop_id, s.shop_name FROM meta.shop s
        WHERE s.platform_code = p_platform_code AND s.enabled
    ),
    shop_vals AS (
        SELECT es.shop_name,
               sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.user_pay_amount END) AS c_val,
               sum(CASE WHEN d.biz_date BETWEEN v_ps AND v_pe THEN d.user_pay_amount END) AS p_val
        FROM enabled_shops es
        LEFT JOIN core.douyin_deal_daily d
          ON d.shop_id = es.shop_id
         AND d.biz_date BETWEEN v_ps AND p_end_date
         AND d.sale_scope = v_scope_sale AND d.carrier_type = v_scope_carrier AND d.ad_period = v_scope_period
        GROUP BY es.shop_name
    ),
    totals AS (
        SELECT sum(c_val) AS c_tot, sum(p_val) AS p_tot FROM shop_vals
    )
    SELECT
        p_platform_code,
        (SELECT p.platform_name FROM meta.platform p WHERE p.platform_code = p_platform_code),
        p_start_date, p_end_date, p_scope_key, p_metric_key,
        sv.shop_name::text,
        sv.c_val AS current_value,
        t.c_tot AS platform_total,
        CASE WHEN t.c_tot IS NULL OR t.c_tot = 0 THEN NULL ELSE sv.c_val / t.c_tot END AS contribution,
        sv.p_val AS previous_value,
        CASE WHEN t.p_tot IS NULL OR t.p_tot = 0 THEN NULL ELSE sv.p_val / t.p_tot END AS previous_contribution,
        CASE WHEN t.c_tot IS NULL OR t.c_tot = 0 OR t.p_tot IS NULL OR t.p_tot = 0 THEN NULL
             ELSE (sv.c_val / t.c_tot) - (sv.p_val / t.p_tot) END AS contribution_change,
        (SELECT count(*) FROM enabled_shops) > 0 AND
        (SELECT bool_and(sd.cnt >= (p_end_date - p_start_date) + 1)
           FROM (SELECT es2.shop_id, count(DISTINCT d2.biz_date) AS cnt
                 FROM enabled_shops es2 LEFT JOIN core.douyin_deal_daily d2
                   ON d2.shop_id = es2.shop_id
                  AND d2.biz_date BETWEEN p_start_date AND p_end_date
                  AND d2.sale_scope = v_scope_sale AND d2.carrier_type = v_scope_carrier AND d2.ad_period = v_scope_period
                 GROUP BY es2.shop_id) sd) AS coverage_complete
    FROM shop_vals sv
    CROSS JOIN totals t
    ORDER BY contribution DESC NULLS LAST, sv.shop_name;
END;
$function$;

COMMENT ON FUNCTION mart.get_shop_contribution(text,date,date,text,text) IS 'V1.3 店铺贡献度：单店值/平台总额/贡献占比（本期+上期+变化）。仅支持可加指标（默认 user_pay_amount）。';

-- ----------------------------------------------------------------------------
-- 平台变化按店铺拆解
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.decompose_platform_change_by_shop(text,date,date,text,text);

CREATE FUNCTION mart.decompose_platform_change_by_shop(
    p_platform_code text,
    p_start_date    date,
    p_end_date      date,
    p_scope_key     text DEFAULT '全店',
    p_metric_key    text DEFAULT 'user_pay_amount'
) RETURNS TABLE (
    platform_code text, platform_name text,
    current_start_date date, current_end_date date,
    previous_start_date date, previous_end_date date,
    scope_key text, metric_key text,
    shop_name text,
    current_value numeric, previous_value numeric,
    absolute_change numeric, relative_change numeric,
    net_change numeric,
    gross_negative_impact numeric,
    gross_positive_offset numeric,
    negative_impact_share numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_scope_sale text; v_scope_carrier text; v_scope_period text;
    v_ps date; v_pe date; v_days int;
BEGIN
    SELECT sale_scope, carrier_type, ad_period INTO v_scope_sale, v_scope_carrier, v_scope_period
    FROM mart.resolve_scope(p_scope_key);
    IF v_scope_sale IS NULL THEN RAISE EXCEPTION '未知经营语义: %', p_scope_key; END IF;
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);

    RETURN QUERY
    WITH enabled_shops AS (
        SELECT s.shop_id, s.shop_name FROM meta.shop s
        WHERE s.platform_code = p_platform_code AND s.enabled
    ),
    shop_chg AS (
        SELECT es.shop_name,
               sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.user_pay_amount END) AS c_val,
               sum(CASE WHEN d.biz_date BETWEEN v_ps AND v_pe THEN d.user_pay_amount END) AS p_val
        FROM enabled_shops es
        LEFT JOIN core.douyin_deal_daily d
          ON d.shop_id = es.shop_id
         AND d.biz_date BETWEEN v_ps AND p_end_date
         AND d.sale_scope = v_scope_sale AND d.carrier_type = v_scope_carrier AND d.ad_period = v_scope_period
        GROUP BY es.shop_name
    ),
    totals AS (
        SELECT
            sum(c_val - p_val) AS net_chg,
            sum(CASE WHEN (c_val - p_val) < 0 THEN abs(c_val - p_val) ELSE 0 END) AS gross_neg,
            sum(CASE WHEN (c_val - p_val) > 0 THEN (c_val - p_val) ELSE 0 END) AS gross_pos
        FROM shop_chg
    )
    SELECT
        p_platform_code,
        (SELECT p.platform_name FROM meta.platform p WHERE p.platform_code = p_platform_code),
        p_start_date, p_end_date, v_ps, v_pe,
        p_scope_key, p_metric_key,
        sc.shop_name::text,
        sc.c_val AS current_value, sc.p_val AS previous_value,
        (sc.c_val - sc.p_val) AS absolute_change,
        CASE WHEN sc.p_val IS NULL THEN NULL WHEN sc.p_val = 0 THEN NULL
             ELSE (sc.c_val - sc.p_val) / abs(sc.p_val) END AS relative_change,
        t.net_chg AS net_change,
        t.gross_neg AS gross_negative_impact,
        t.gross_pos AS gross_positive_offset,
        CASE WHEN t.gross_neg IS NULL OR t.gross_neg = 0 THEN NULL
             ELSE abs(sc.c_val - sc.p_val) / t.gross_neg END AS negative_impact_share
    FROM shop_chg sc
    CROSS JOIN totals t
    ORDER BY absolute_change ASC;
END;
$function$;

COMMENT ON FUNCTION mart.decompose_platform_change_by_shop(text,date,date,text,text) IS
'V1.3 平台变化按店铺拆解：net_change=Σ单店变化；gross_negative_impact=Σ负向绝对值；gross_positive_offset=Σ正向；
negative_impact_share=单店负向绝对值/全部负向绝对值（文档二十二节：不除以净下降额）。';
