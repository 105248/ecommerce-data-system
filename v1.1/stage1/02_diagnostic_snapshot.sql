-- ============================================================================
-- V1.1 阶段1｜经营指标诊断基础层
-- 02_diagnostic_snapshot.sql（主函数 + shop / scope 域）
-- ============================================================================
-- 架构：主函数 get_diagnostic_snapshot = SECURITY DEFINER，CASE 分发 6 个内部函数；
-- 内部函数 _diag_* 普通权限（不授权给 agent_readonly，仅由主函数调用）。
-- 快照口径与现有 mart/Period/Rank/Contribution 完全一致（数值由 Stage1 一致性验收证明）。
-- 值/变化/覆盖/排名/贡献全部为固定 SQL + 内联窗口，零动态 SQL。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 主函数
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_diagnostic_snapshot(text,date,date,text,text,text,text,integer);

CREATE FUNCTION mart.get_diagnostic_snapshot(
    p_shop_name      text,
    p_start_date     date,
    p_end_date       date,
    p_domain_key     text,
    p_scope_key      text DEFAULT NULL,
    p_entity_id      text DEFAULT NULL,
    p_entity_name    text DEFAULT NULL,
    p_category_level integer DEFAULT NULL
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
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_domain_name text; v_enabled boolean;
    v_cs date; v_ce date; v_ps date; v_pe date; v_days integer;
BEGIN
    -- 店铺校验
    IF p_shop_name IS NOT NULL AND NOT EXISTS (SELECT 1 FROM meta.shop s WHERE s.shop_name = p_shop_name) THEN
        RAISE EXCEPTION '未知店铺: %', p_shop_name;
    END IF;
    -- 日期校验
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RAISE EXCEPTION '非法日期区间: % ~ %', p_start_date, p_end_date;
    END IF;
    -- 域校验
    SELECT r.domain_name_cn, r.enabled INTO v_domain_name, v_enabled
    FROM mart.diagnostic_entity_rule r WHERE r.domain_key = p_domain_key;
    IF v_domain_name IS NULL THEN RAISE EXCEPTION '未知诊断域: %', p_domain_key; END IF;
    IF NOT v_enabled THEN RAISE EXCEPTION '诊断域 % 未启用', p_domain_key; END IF;
    -- 周期（等长前置）
    v_ce := p_end_date; v_cs := p_start_date;
    v_days := (v_ce - v_cs) + 1;
    v_pe := v_cs - 1;
    v_ps := v_pe - (v_days - 1);

    IF p_domain_key = 'shop' THEN
        RETURN QUERY SELECT * FROM mart._diag_shop(p_shop_name, v_cs, v_ce, v_ps, v_pe);
    ELSIF p_domain_key = 'scope' THEN
        RETURN QUERY SELECT * FROM mart._diag_scope(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_scope_key);
    ELSIF p_domain_key IN ('product','shop_product') THEN
        RETURN QUERY SELECT * FROM mart._diag_product(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_entity_id, p_entity_name);
    ELSIF p_domain_key = 'master_product' THEN
        RETURN QUERY SELECT * FROM mart._diag_master_product(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_entity_id, p_entity_name);
    ELSIF p_domain_key = 'product_line' THEN
        RETURN QUERY SELECT * FROM mart._diag_product_line(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_entity_name);
    ELSIF p_domain_key = 'carrier' THEN
        RETURN QUERY SELECT * FROM mart._diag_carrier(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_scope_key);
    ELSIF p_domain_key = 'account' THEN
        RETURN QUERY SELECT * FROM mart._diag_account(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_scope_key);
    ELSIF p_domain_key = 'category' THEN
        RETURN QUERY SELECT * FROM mart._diag_category(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_category_level);
    ELSE
        RAISE EXCEPTION '诊断域 % 不支持', p_domain_key;
    END IF;
END;
$function$;

COMMENT ON FUNCTION mart.get_diagnostic_snapshot(text,date,date,text,text,text,text,integer) IS
'V1.1 统一诊断快照：一行 = 一个对象×一个指标×当前期×上期。含值/变化/排名/贡献/覆盖/数据状态。零动态 SQL，复用现有口径。';

-- ----------------------------------------------------------------------------
-- _diag_shop：店铺整体域（deal_daily 全店 TOTAL，单对象）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart._diag_shop(text,date,date,date,date);

CREATE FUNCTION mart._diag_shop(
    p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date
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
    WITH raw AS (
        SELECT
            s.shop_id::text AS eid,
            s.shop_name AS ename,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.biz_date END)::int AS p_days,
            -- 双期原始量（金额/计数/加权分子分母）
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.user_pay_amount END) AS c_up,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.user_pay_amount END) AS p_up,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.transaction_amount END) AS c_trans,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.transaction_amount END) AS p_trans,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.settlement_amount END) AS c_settle,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.settlement_amount END) AS p_settle,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.transaction_order_count END) AS c_ord,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.transaction_order_count END) AS p_ord,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.transaction_buyer_count END) AS c_buyer,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.transaction_buyer_count END) AS p_buyer,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.transaction_item_count END) AS c_items,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.transaction_item_count END) AS p_items,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.product_exposure_user_count END) AS c_exp_u,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.product_exposure_user_count END) AS p_exp_u,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.product_click_user_count END) AS c_click_u,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.product_click_user_count END) AS p_click_u,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.product_exposure_count END) AS c_exp_c,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.product_exposure_count END) AS p_exp_c,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.product_click_count END) AS c_click_c,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.product_click_count END) AS p_click_c,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.transaction_refund_amount_pay_time END) AS c_trefund,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.transaction_refund_amount_pay_time END) AS p_trefund,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.refund_amount_pay_time END) AS p_refund,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.ad_spend_shop_promoted END) AS c_ad_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.ad_spend_shop_promoted END) AS p_ad_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.ad_spend_shop_bound END) AS c_ad_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.ad_spend_shop_bound END) AS p_ad_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.ad_attributed_transaction_amount END) AS c_ad_attrib,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.ad_attributed_transaction_amount END) AS p_ad_attrib,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.total_expense_rate_net_refund_shop_bound * d.settlement_amount END) AS c_total_exp,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.total_expense_rate_net_refund_shop_bound * d.settlement_amount END) AS p_total_exp,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.ad_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS c_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.ad_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS p_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.ad_efficiency_shop_bound * d.ad_spend_shop_bound END) AS c_eff_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.ad_efficiency_shop_bound * d.ad_spend_shop_bound END) AS p_eff_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.store_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS c_st_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.store_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS p_st_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.store_efficiency_shop_bound * d.ad_spend_shop_bound END) AS c_st_eff_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.store_efficiency_shop_bound * d.ad_spend_shop_bound END) AS p_st_eff_bound
        FROM core.douyin_deal_daily d
        JOIN meta.shop s ON s.shop_id = d.shop_id
        WHERE d.biz_date BETWEEN p_ps AND p_ce
          AND d.sale_scope = '全部' AND d.carrier_type = '全部' AND d.ad_period = '不限'
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
        GROUP BY s.shop_id, s.shop_name
    ),
    metrics AS (
        SELECT r.*, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up
                WHEN 'transaction_amount' THEN r.c_trans
                WHEN 'settlement_amount' THEN r.c_settle
                WHEN 'transaction_order_count' THEN r.c_ord
                WHEN 'transaction_buyer_count' THEN r.c_buyer
                WHEN 'transaction_item_count' THEN r.c_items
                WHEN 'avg_customer_amount' THEN r.c_up / NULLIF(r.c_buyer, 0)
                WHEN 'avg_item_amount' THEN r.c_up / NULLIF(r.c_items, 0)
                WHEN 'product_exposure_user_count' THEN r.c_exp_u
                WHEN 'product_click_user_count' THEN r.c_click_u
                WHEN 'exposure_to_click_rate_users' THEN r.c_click_u / NULLIF(r.c_exp_u, 0)
                WHEN 'click_to_transaction_rate_users' THEN r.c_buyer / NULLIF(r.c_click_u, 0)
                WHEN 'exposure_to_transaction_rate_users' THEN r.c_buyer / NULLIF(r.c_exp_u, 0)
                WHEN 'product_exposure_count' THEN r.c_exp_c
                WHEN 'product_click_count' THEN r.c_click_c
                WHEN 'exposure_to_click_rate_events' THEN r.c_click_c / NULLIF(r.c_exp_c, 0)
                WHEN 'click_to_transaction_rate_events' THEN r.c_ord / NULLIF(r.c_click_c, 0)
                WHEN 'exposure_to_transaction_rate_events' THEN r.c_ord / NULLIF(r.c_exp_c, 0)
                WHEN 'transaction_refund_amount_pay_time' THEN r.c_trefund
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
                WHEN 'ad_spend_shop_promoted' THEN r.c_ad_promoted
                WHEN 'ad_spend_shop_bound' THEN r.c_ad_bound
                WHEN 'ad_attributed_transaction_amount' THEN r.c_ad_attrib
                WHEN 'ad_attributed_transaction_share' THEN r.c_ad_attrib / NULLIF(r.c_trans, 0)
                WHEN 'ad_spend_rate_net_refund_shop_bound' THEN r.c_ad_bound / NULLIF(r.c_settle, 0)
                WHEN 'total_expense_rate_net_refund_shop_bound' THEN r.c_total_exp / NULLIF(r.c_settle, 0)
                WHEN 'ad_efficiency_shop_promoted' THEN r.c_eff_promoted / NULLIF(r.c_ad_promoted, 0)
                WHEN 'ad_efficiency_shop_bound' THEN r.c_eff_bound / NULLIF(r.c_ad_bound, 0)
                WHEN 'store_efficiency_shop_promoted' THEN r.c_st_eff_promoted / NULLIF(r.c_ad_promoted, 0)
                WHEN 'store_efficiency_shop_bound' THEN r.c_st_eff_bound / NULLIF(r.c_ad_bound, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up
                WHEN 'transaction_amount' THEN r.p_trans
                WHEN 'settlement_amount' THEN r.p_settle
                WHEN 'transaction_order_count' THEN r.p_ord
                WHEN 'transaction_buyer_count' THEN r.p_buyer
                WHEN 'transaction_item_count' THEN r.p_items
                WHEN 'avg_customer_amount' THEN r.p_up / NULLIF(r.p_buyer, 0)
                WHEN 'avg_item_amount' THEN r.p_up / NULLIF(r.p_items, 0)
                WHEN 'product_exposure_user_count' THEN r.p_exp_u
                WHEN 'product_click_user_count' THEN r.p_click_u
                WHEN 'exposure_to_click_rate_users' THEN r.p_click_u / NULLIF(r.p_exp_u, 0)
                WHEN 'click_to_transaction_rate_users' THEN r.p_buyer / NULLIF(r.p_click_u, 0)
                WHEN 'exposure_to_transaction_rate_users' THEN r.p_buyer / NULLIF(r.p_exp_u, 0)
                WHEN 'product_exposure_count' THEN r.p_exp_c
                WHEN 'product_click_count' THEN r.p_click_c
                WHEN 'exposure_to_click_rate_events' THEN r.p_click_c / NULLIF(r.p_exp_c, 0)
                WHEN 'click_to_transaction_rate_events' THEN r.p_ord / NULLIF(r.p_click_c, 0)
                WHEN 'exposure_to_transaction_rate_events' THEN r.p_ord / NULLIF(r.p_exp_c, 0)
                WHEN 'transaction_refund_amount_pay_time' THEN r.p_trefund
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
                WHEN 'ad_spend_shop_promoted' THEN r.p_ad_promoted
                WHEN 'ad_spend_shop_bound' THEN r.p_ad_bound
                WHEN 'ad_attributed_transaction_amount' THEN r.p_ad_attrib
                WHEN 'ad_attributed_transaction_share' THEN r.p_ad_attrib / NULLIF(r.p_trans, 0)
                WHEN 'ad_spend_rate_net_refund_shop_bound' THEN r.p_ad_bound / NULLIF(r.p_settle, 0)
                WHEN 'total_expense_rate_net_refund_shop_bound' THEN r.p_total_exp / NULLIF(r.p_settle, 0)
                WHEN 'ad_efficiency_shop_promoted' THEN r.p_eff_promoted / NULLIF(r.p_ad_promoted, 0)
                WHEN 'ad_efficiency_shop_bound' THEN r.p_eff_bound / NULLIF(r.p_ad_bound, 0)
                WHEN 'store_efficiency_shop_promoted' THEN r.p_st_eff_promoted / NULLIF(r.p_ad_promoted, 0)
                WHEN 'store_efficiency_shop_bound' THEN r.p_st_eff_bound / NULLIF(r.p_ad_bound, 0)
            END AS p_val
        FROM raw r
        CROSS JOIN LATERAL (VALUES
            ('user_pay_amount','用户支付金额','成交','amount','金额'),
            ('transaction_amount','成交金额','成交','amount','金额'),
            ('settlement_amount','结算金额','成交','amount','金额'),
            ('transaction_order_count','成交订单数','成交','count','整数'),
            ('transaction_buyer_count','成交人数','成交','count','整数'),
            ('transaction_item_count','成交件数','成交','count','整数'),
            ('avg_customer_amount','客单价','成交','average','0.00'),
            ('avg_item_amount','件单价','成交','average','0.00'),
            ('product_exposure_user_count','商品曝光人数','流量','count','整数'),
            ('product_click_user_count','商品点击人数','流量','count','整数'),
            ('exposure_to_click_rate_users','商品曝光-点击转化率(人数)','流量','ratio','0.00%'),
            ('click_to_transaction_rate_users','商品点击-成交转化率(人数)','流量','ratio','0.00%'),
            ('exposure_to_transaction_rate_users','商品曝光-成交转化率(人数)','流量','ratio','0.00%'),
            ('product_exposure_count','商品曝光次数','流量','count','整数'),
            ('product_click_count','商品点击次数','流量','count','整数'),
            ('exposure_to_click_rate_events','商品曝光-点击转化率(次数)','流量','ratio','0.00%'),
            ('click_to_transaction_rate_events','商品点击-成交转化率(次数)','流量','ratio','0.00%'),
            ('exposure_to_transaction_rate_events','商品曝光-成交转化率(次数)','流量','ratio','0.00%'),
            ('transaction_refund_amount_pay_time','成交退款金额(支付时间)','售后','amount','金额'),
            ('refund_amount_pay_time','退款金额(支付时间)','售后','amount','金额'),
            ('refund_rate_pay_time','退款率(支付时间)','售后','ratio','0.00%'),
            ('ad_spend_shop_promoted','投放消耗(店铺被投)','投放','amount','金额'),
            ('ad_spend_shop_bound','投放消耗(店铺绑定)','投放','amount','金额'),
            ('ad_attributed_transaction_amount','投放贡献成交金额','投放','amount','金额'),
            ('ad_attributed_transaction_share','投放贡献成交占比','投放','ratio','0.00%'),
            ('ad_spend_rate_net_refund_shop_bound','投放费比(剔除退款、店铺绑定)','投放','ratio','0.00%'),
            ('total_expense_rate_net_refund_shop_bound','综合费比(剔除退款、店铺绑定)','投放','ratio','0.00%'),
            ('ad_efficiency_shop_promoted','投放效率(店铺被投)','投放','efficiency','0.00'),
            ('ad_efficiency_shop_bound','投放效率(店铺绑定)','投放','efficiency','0.00'),
            ('store_efficiency_shop_promoted','全店效率(店铺被投)','投放','efficiency','0.00'),
            ('store_efficiency_shop_bound','全店效率(店铺绑定)','投放','efficiency','0.00')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        m.ename::text AS shop_name,
        'shop' AS domain_key,
        '店铺整体' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        '全店' AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs AS current_start_date, p_ce AS current_end_date,
        p_ps AS previous_start_date, p_pe AS previous_end_date,
        m.c_val AS current_value, m.p_val AS previous_value,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL
             WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.metric_key IN ('exposure_to_click_rate_users','click_to_transaction_rate_users',
                    'exposure_to_transaction_rate_users','exposure_to_click_rate_events','click_to_transaction_rate_events',
                    'exposure_to_transaction_rate_events','refund_rate_pay_time','ad_attributed_transaction_share',
                    'ad_spend_rate_net_refund_shop_bound','total_expense_rate_net_refund_shop_bound')
             AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        NULL::bigint AS current_rank, NULL::bigint AS previous_rank, NULL::bigint AS rank_change,
        NULL::numeric AS current_contribution, NULL::numeric AS previous_contribution, NULL::numeric AS contribution_change,
        NULL::text AS contribution_denominator_type, NULL::numeric AS contribution_denominator_value,
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
        '店铺整体快照' AS notes
    FROM metrics m
    ORDER BY m.grp, m.metric_key;
END;
$function$;

COMMENT ON FUNCTION mart._diag_shop(text,date,date,date,date) IS 'V1.1 店铺整体域诊断快照（内部函数，不对外授权）。';
