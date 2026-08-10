-- ============================================================================
-- V1.1 阶段3｜问题定位与漏斗诊断（多店兼容修订版）
-- 02_diagnostic_functions.sql（实体诊断 / 拆解 / 漏斗 / 投放诊断）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. master_product → shop_product 拆解（定位哪家店商品拖累）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.decompose_master_product_by_shop_product(bigint,date,date);
CREATE FUNCTION mart.decompose_master_product_by_shop_product(
    p_master_product_id bigint,
    p_start_date date,
    p_end_date   date
) RETURNS TABLE (
    master_product_id integer, master_product_name text,
    shop_name text, platform_product_id text, platform_product_name text,
    current_value numeric, previous_value numeric,
    absolute_change numeric, relative_change numeric,
    net_change numeric, gross_negative_impact numeric, gross_positive_offset numeric,
    negative_impact_share numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_ps date; v_pe date; v_days int;
BEGIN
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);
    RETURN QUERY
    WITH members AS (
        SELECT m.shop_id, m.platform_product_id
        FROM meta.platform_product_mapping m
        WHERE m.master_product_id = p_master_product_id AND m.enabled AND m.mapping_status='CONFIRMED'
    ),
    member_chg AS (
        SELECT mem.shop_id, mem.platform_product_id,
               sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.user_pay_amount END) AS c_val,
               sum(CASE WHEN d.biz_date BETWEEN v_ps AND v_pe THEN d.user_pay_amount END) AS p_val
        FROM members mem
        LEFT JOIN core.douyin_product_daily d
          ON d.shop_id = mem.shop_id AND d.product_id = mem.platform_product_id
         AND d.biz_date BETWEEN v_ps AND p_end_date AND d.carrier_type='全部'
        GROUP BY mem.shop_id, mem.platform_product_id
    ),
    totals AS (
        SELECT sum(c_val - p_val) AS net_chg,
               sum(CASE WHEN (c_val - p_val) < 0 THEN abs(c_val - p_val) ELSE 0 END) AS gross_neg,
               sum(CASE WHEN (c_val - p_val) > 0 THEN (c_val - p_val) ELSE 0 END) AS gross_pos
        FROM member_chg
    )
    SELECT
        p_master_product_id::integer,
        (SELECT mpp.master_product_name FROM meta.master_product mpp WHERE mpp.master_product_id = p_master_product_id),
        s.shop_name::text,
        mc.platform_product_id,
        (SELECT m2.platform_product_name_snapshot FROM meta.platform_product_mapping m2
         WHERE m2.master_product_id = p_master_product_id AND m2.shop_id = mc.shop_id AND m2.platform_product_id = mc.platform_product_id
           AND m2.enabled LIMIT 1),
        mc.c_val, mc.p_val,
        (mc.c_val - mc.p_val) AS absolute_change,
        CASE WHEN mc.p_val IS NULL THEN NULL WHEN mc.p_val = 0 THEN NULL
             ELSE (mc.c_val - mc.p_val) / abs(mc.p_val) END AS relative_change,
        t.net_chg, t.gross_neg, t.gross_pos,
        CASE WHEN t.gross_neg IS NULL OR t.gross_neg = 0 THEN NULL
             ELSE abs(mc.c_val - mc.p_val) / t.gross_neg END AS negative_impact_share
    FROM member_chg mc
    JOIN meta.shop s ON s.shop_id = mc.shop_id
    CROSS JOIN totals t
    ORDER BY absolute_change ASC NULLS LAST;
END;
$function$;

COMMENT ON FUNCTION mart.decompose_master_product_by_shop_product(bigint,date,date) IS
'V1.3/V1.1 Master Product → 店铺商品拆解：定位哪家店商品拖累（negative_impact_share=单店商品负向/全部负向）。';

-- ----------------------------------------------------------------------------
-- 2. 漏斗诊断（曝光→点击→成交→退款；缺字段跳过该分支）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_funnel_diagnosis(text,text,date,date,text,text);
CREATE FUNCTION mart.get_funnel_diagnosis(
    p_domain_key  text,
    p_entity_name text,
    p_start_date  date,
    p_end_date    date,
    p_shop_name   text DEFAULT NULL,
    p_scope_key   text DEFAULT NULL
) RETURNS TABLE (
    stage text, metric_key text, metric_name_cn text,
    current_value numeric, previous_value numeric,
    absolute_change numeric, relative_change numeric,
    contribution_share numeric,
    primary_stage text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_ps date; v_pe date; v_days int;
BEGIN
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);
    RETURN QUERY
    WITH snap AS (
        SELECT s.entity_id, s.entity_name, s.metric_key, s.current_value, s.previous_value,
               s.relative_change, s.data_status
        FROM mart.get_diagnostic_snapshot(p_shop_name, p_start_date, p_end_date, p_domain_key, p_scope_key,
                                          CASE WHEN p_domain_key='product_line' THEN NULL ELSE p_entity_name END,
                                          CASE WHEN p_domain_key='product_line' THEN p_entity_name ELSE NULL END,
                                          NULL) s
    ),
    sel AS (
        SELECT * FROM snap WHERE entity_name = p_entity_name OR entity_id = p_entity_name
    )
    SELECT
        CASE m.metric_key
            WHEN 'product_exposure_user_count' THEN 'traffic'
            WHEN 'product_click_user_count' THEN 'click'
            WHEN 'transaction_buyer_count' THEN 'conversion'
            WHEN 'refund_rate_pay_time' THEN 'refund'
            ELSE 'other' END AS stage,
        m.metric_key, r.metric_name_cn,
        m.current_value, m.previous_value,
        (m.current_value - m.previous_value) AS absolute_change,
        m.relative_change,
        CASE WHEN m.metric_key='product_exposure_user_count' THEN 1.0
             WHEN m.metric_key='product_click_user_count' THEN
                (SELECT c.current_value FROM sel c WHERE c.metric_key='product_click_user_count')
                / NULLIF((SELECT e.current_value FROM sel e WHERE e.metric_key='product_exposure_user_count'), 0)
             WHEN m.metric_key='transaction_buyer_count' THEN
                (SELECT c.current_value FROM sel c WHERE c.metric_key='transaction_buyer_count')
                / NULLIF((SELECT e.current_value FROM sel e WHERE e.metric_key='product_exposure_user_count'), 0)
             WHEN m.metric_key='refund_rate_pay_time' THEN m.current_value
             ELSE NULL END AS contribution_share,
        NULL::text AS primary_stage
    FROM sel m
    JOIN mart.diagnostic_metric_rule r ON r.metric_key = m.metric_key
    WHERE m.metric_key IN ('product_exposure_user_count','product_click_user_count','transaction_buyer_count','refund_rate_pay_time')
    ORDER BY CASE m.metric_key
        WHEN 'product_exposure_user_count' THEN 1 WHEN 'product_click_user_count' THEN 2
        WHEN 'transaction_buyer_count' THEN 3 WHEN 'refund_rate_pay_time' THEN 4 END;
END;
$function$;

COMMENT ON FUNCTION mart.get_funnel_diagnosis(text,text,date,date,text,text) IS
'V1.1 漏斗诊断：曝光→点击→成交→退款 各环节变化（缺字段跳过，不跨domain补数）。';

-- ----------------------------------------------------------------------------
-- 3. 投放诊断（复用 V1.0.1 正式投放函数）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_advertising_diagnosis(text,text,date,date,text);
CREATE FUNCTION mart.get_advertising_diagnosis(
    p_domain_key  text,
    p_entity_name text,
    p_start_date  date,
    p_end_date    date,
    p_shop_name   text DEFAULT NULL
) RETURNS TABLE (
    metric_key text, metric_name_cn text,
    current_value numeric, previous_value numeric,
    absolute_change numeric, relative_change numeric,
    diagnostic_note text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_ps date; v_pe date; v_days int;
BEGIN
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);
    RETURN QUERY
    WITH snap AS (
        SELECT s.entity_id, s.entity_name, s.metric_key, s.current_value, s.previous_value, s.relative_change
        FROM mart.get_diagnostic_snapshot(p_shop_name, p_start_date, p_end_date, p_domain_key, NULL, NULL, p_entity_name, NULL) s
    )
    SELECT m.metric_key, r.metric_name_cn,
           m.current_value, m.previous_value,
           (m.current_value - m.previous_value) AS absolute_change,
           m.relative_change,
           CASE WHEN m.metric_key='ad_efficiency_shop_promoted' THEN '效率倍数，非百分比'
                WHEN m.metric_key='ad_spend_rate_net_refund_shop_bound' THEN '费比（剔除退款、店铺绑定）'
                ELSE '' END AS diagnostic_note
    FROM snap m
    JOIN mart.diagnostic_metric_rule r ON r.metric_key = m.metric_key
    WHERE m.metric_key IN ('ad_spend_shop_promoted','ad_spend_shop_bound','ad_attributed_transaction_amount',
                           'ad_attributed_transaction_share','ad_spend_rate_net_refund_shop_bound',
                           'total_expense_rate_net_refund_shop_bound','ad_efficiency_shop_promoted',
                           'store_efficiency_shop_promoted')
    ORDER BY m.metric_key;
END;
$function$;

COMMENT ON FUNCTION mart.get_advertising_diagnosis(text,text,date,date,text) IS
'V1.1 投放诊断（复用快照投放指标；平台=跨店加权，单店=原口径）。';
