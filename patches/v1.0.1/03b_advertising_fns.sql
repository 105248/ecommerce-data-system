-- V1.0.1: 新增 mart.get_advertising_period_summary 投放汇总函数
DROP FUNCTION IF EXISTS mart.get_advertising_period_summary(text,date,date,text);

CREATE OR REPLACE FUNCTION mart.get_advertising_period_summary(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_scope_key text
)
RETURNS TABLE(
    shop_name text,
    period_start date,
    period_end date,
    scope_key text,
    ad_spend_shop_promoted numeric,
    ad_spend_shop_bound numeric,
    ad_attributed_transaction_amount numeric,
    ad_attributed_transaction_share numeric,
    ad_spend_rate_net_refund_shop_bound numeric,
    total_expense_rate_net_refund_shop_bound numeric,
    ad_efficiency_shop_promoted numeric,
    ad_efficiency_shop_bound numeric,
    store_efficiency_shop_promoted numeric,
    store_efficiency_shop_bound numeric,
    expected_days integer,
    coverage_days integer,
    coverage_complete boolean,
    calculation_notes text
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
AS $function$
DECLARE
    v_scope record;
    v_notes text;
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);

    SELECT * INTO v_scope FROM mart.period_scope_rule(p_scope_key);
    IF NOT FOUND THEN
        RAISE EXCEPTION '不支持的 scope_key：%。请使用阶段1已确认经营范围。', p_scope_key;
    END IF;

    v_notes := '3项金额=SUM; 投放贡献占比=SUM贡献/SUM成交; 投放费比=SUM消耗绑定/SUM结算(剔除退款); 综合费比与4效率=按结算/消耗加权源比率(weighted_source_ratio, 非AVG); 仅ad_period=不限参与汇总';

    RETURN QUERY
    SELECT
        s.shop_name::text,
        p_start_date,
        p_end_date,
        v_scope.scope_key::text,
        SUM(d.ad_spend_shop_promoted),
        SUM(d.ad_spend_shop_bound),
        SUM(d.ad_attributed_transaction_amount),
        SUM(d.ad_attributed_transaction_amount) / NULLIF(SUM(d.transaction_amount), 0),
        SUM(d.ad_spend_shop_bound) / NULLIF(SUM(d.settlement_amount), 0),
        SUM(d.total_expense_rate_net_refund_shop_bound * d.settlement_amount) / NULLIF(SUM(d.settlement_amount), 0),
        SUM(d.ad_efficiency_shop_promoted * d.ad_spend_shop_promoted) / NULLIF(SUM(d.ad_spend_shop_promoted), 0),
        SUM(d.ad_efficiency_shop_bound * d.ad_spend_shop_bound) / NULLIF(SUM(d.ad_spend_shop_bound), 0),
        SUM(d.store_efficiency_shop_promoted * d.ad_spend_shop_promoted) / NULLIF(SUM(d.ad_spend_shop_promoted), 0),
        SUM(d.store_efficiency_shop_bound * d.ad_spend_shop_bound) / NULLIF(SUM(d.ad_spend_shop_bound), 0),
        (p_end_date - p_start_date + 1)::integer,
        COUNT(DISTINCT d.biz_date)::integer,
        COUNT(DISTINCT d.biz_date) = (p_end_date - p_start_date + 1)::integer,
        v_notes
    FROM core.douyin_deal_daily d
    JOIN meta.shop s ON s.shop_id = d.shop_id
    WHERE d.biz_date BETWEEN p_start_date AND p_end_date
      AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND d.sale_scope = v_scope.sale_scope
      AND d.carrier_type = v_scope.carrier_type
      AND d.ad_period = v_scope.ad_period
    GROUP BY s.shop_name;
END;
$function$;

COMMENT ON FUNCTION mart.get_advertising_period_summary(text,date,date,text) IS
'V1.0.1 投放经营汇总：一次返回10项投放指标+coverage。仅ad_period=不限参与；综合费比/效率为加权源比率，禁止AVG。';

-- V1.0.1: 新增 mart.compare_advertising_period 投放环比函数
DROP FUNCTION IF EXISTS mart.compare_advertising_period(text,date,date,text);

CREATE OR REPLACE FUNCTION mart.compare_advertising_period(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_scope_key text
)
RETURNS TABLE(
    metric_key text,
    metric_name_cn text,
    value_type text,
    current_value numeric,
    previous_value numeric,
    absolute_change numeric,
    relative_change numeric,
    percentage_point_change numeric
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
AS $function$
DECLARE
    v_prev_start date;
    v_prev_end date;
    r record;
    c record;
    p record;
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);
    SELECT pp.previous_start_date, pp.previous_end_date INTO v_prev_start, v_prev_end
    FROM mart.previous_period(p_start_date, p_end_date) pp;

    SELECT * INTO c FROM mart.get_advertising_period_summary(p_shop_name, p_start_date, p_end_date, p_scope_key);
    IF NOT FOUND THEN
        RAISE EXCEPTION '本期无数据: % ~ %', p_start_date, p_end_date;
    END IF;
    SELECT * INTO p FROM mart.get_advertising_period_summary(p_shop_name, v_prev_start, v_prev_end, p_scope_key);
    IF NOT FOUND THEN
        RAISE EXCEPTION '上期无数据: % ~ %', v_prev_start, v_prev_end;
    END IF;

    FOR r IN SELECT 1 LOOP
        RETURN QUERY
        SELECT 'ad_spend_shop_promoted', '投放消耗(店铺被投)', 'amount',
               c.ad_spend_shop_promoted, p.ad_spend_shop_promoted,
               c.ad_spend_shop_promoted - p.ad_spend_shop_promoted,
               CASE WHEN p.ad_spend_shop_promoted IS NULL OR p.ad_spend_shop_promoted = 0 THEN NULL
                    ELSE (c.ad_spend_shop_promoted - p.ad_spend_shop_promoted) / abs(p.ad_spend_shop_promoted) END,
               NULL::numeric
        UNION ALL SELECT 'ad_spend_shop_bound', '投放消耗(店铺绑定)', 'amount',
               c.ad_spend_shop_bound, p.ad_spend_shop_bound,
               c.ad_spend_shop_bound - p.ad_spend_shop_bound,
               CASE WHEN p.ad_spend_shop_bound IS NULL OR p.ad_spend_shop_bound = 0 THEN NULL
                    ELSE (c.ad_spend_shop_bound - p.ad_spend_shop_bound) / abs(p.ad_spend_shop_bound) END,
               NULL::numeric
        UNION ALL SELECT 'ad_attributed_transaction_amount', '投放贡献成交金额', 'amount',
               c.ad_attributed_transaction_amount, p.ad_attributed_transaction_amount,
               c.ad_attributed_transaction_amount - p.ad_attributed_transaction_amount,
               CASE WHEN p.ad_attributed_transaction_amount IS NULL OR p.ad_attributed_transaction_amount = 0 THEN NULL
                    ELSE (c.ad_attributed_transaction_amount - p.ad_attributed_transaction_amount) / abs(p.ad_attributed_transaction_amount) END,
               NULL::numeric
        UNION ALL SELECT 'ad_attributed_transaction_share', '投放贡献成交占比', 'ratio',
               c.ad_attributed_transaction_share, p.ad_attributed_transaction_share,
               c.ad_attributed_transaction_share - p.ad_attributed_transaction_share,
               CASE WHEN p.ad_attributed_transaction_share IS NULL OR p.ad_attributed_transaction_share = 0 THEN NULL
                    ELSE (c.ad_attributed_transaction_share - p.ad_attributed_transaction_share) / abs(p.ad_attributed_transaction_share) END,
               c.ad_attributed_transaction_share - p.ad_attributed_transaction_share
        UNION ALL SELECT 'ad_spend_rate_net_refund_shop_bound', '投放费比(剔除退款、店铺绑定)', 'ratio',
               c.ad_spend_rate_net_refund_shop_bound, p.ad_spend_rate_net_refund_shop_bound,
               c.ad_spend_rate_net_refund_shop_bound - p.ad_spend_rate_net_refund_shop_bound,
               CASE WHEN p.ad_spend_rate_net_refund_shop_bound IS NULL OR p.ad_spend_rate_net_refund_shop_bound = 0 THEN NULL
                    ELSE (c.ad_spend_rate_net_refund_shop_bound - p.ad_spend_rate_net_refund_shop_bound) / abs(p.ad_spend_rate_net_refund_shop_bound) END,
               c.ad_spend_rate_net_refund_shop_bound - p.ad_spend_rate_net_refund_shop_bound
        UNION ALL SELECT 'total_expense_rate_net_refund_shop_bound', '综合费比(剔除退款、店铺绑定)', 'ratio',
               c.total_expense_rate_net_refund_shop_bound, p.total_expense_rate_net_refund_shop_bound,
               c.total_expense_rate_net_refund_shop_bound - p.total_expense_rate_net_refund_shop_bound,
               CASE WHEN p.total_expense_rate_net_refund_shop_bound IS NULL OR p.total_expense_rate_net_refund_shop_bound = 0 THEN NULL
                    ELSE (c.total_expense_rate_net_refund_shop_bound - p.total_expense_rate_net_refund_shop_bound) / abs(p.total_expense_rate_net_refund_shop_bound) END,
               c.total_expense_rate_net_refund_shop_bound - p.total_expense_rate_net_refund_shop_bound
        UNION ALL SELECT 'ad_efficiency_shop_promoted', '投放效率(店铺被投)', 'efficiency',
               c.ad_efficiency_shop_promoted, p.ad_efficiency_shop_promoted,
               c.ad_efficiency_shop_promoted - p.ad_efficiency_shop_promoted,
               CASE WHEN p.ad_efficiency_shop_promoted IS NULL OR p.ad_efficiency_shop_promoted = 0 THEN NULL
                    ELSE (c.ad_efficiency_shop_promoted - p.ad_efficiency_shop_promoted) / abs(p.ad_efficiency_shop_promoted) END,
               NULL::numeric
        UNION ALL SELECT 'ad_efficiency_shop_bound', '投放效率(店铺绑定)', 'efficiency',
               c.ad_efficiency_shop_bound, p.ad_efficiency_shop_bound,
               c.ad_efficiency_shop_bound - p.ad_efficiency_shop_bound,
               CASE WHEN p.ad_efficiency_shop_bound IS NULL OR p.ad_efficiency_shop_bound = 0 THEN NULL
                    ELSE (c.ad_efficiency_shop_bound - p.ad_efficiency_shop_bound) / abs(p.ad_efficiency_shop_bound) END,
               NULL::numeric
        UNION ALL SELECT 'store_efficiency_shop_promoted', '全店效率(店铺被投)', 'efficiency',
               c.store_efficiency_shop_promoted, p.store_efficiency_shop_promoted,
               c.store_efficiency_shop_promoted - p.store_efficiency_shop_promoted,
               CASE WHEN p.store_efficiency_shop_promoted IS NULL OR p.store_efficiency_shop_promoted = 0 THEN NULL
                    ELSE (c.store_efficiency_shop_promoted - p.store_efficiency_shop_promoted) / abs(p.store_efficiency_shop_promoted) END,
               NULL::numeric
        UNION ALL SELECT 'store_efficiency_shop_bound', '全店效率(店铺绑定)', 'efficiency',
               c.store_efficiency_shop_bound, p.store_efficiency_shop_bound,
               c.store_efficiency_shop_bound - p.store_efficiency_shop_bound,
               CASE WHEN p.store_efficiency_shop_bound IS NULL OR p.store_efficiency_shop_bound = 0 THEN NULL
                    ELSE (c.store_efficiency_shop_bound - p.store_efficiency_shop_bound) / abs(p.store_efficiency_shop_bound) END,
               NULL::numeric;
    END LOOP;
END;
$function$;

COMMENT ON FUNCTION mart.compare_advertising_period(text,date,date,text) IS
'V1.0.1 投放环比：本期N天 vs 紧邻前N天；比例输出百分点+相对，效率只输出绝对+相对（不输出百分点）。';

REVOKE ALL ON FUNCTION mart.get_advertising_period_summary(text,date,date,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION mart.compare_advertising_period(text,date,date,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mart.get_advertising_period_summary(text,date,date,text) TO agent_readonly;
GRANT EXECUTE ON FUNCTION mart.compare_advertising_period(text,date,date,text) TO agent_readonly;
