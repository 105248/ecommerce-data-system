-- ============================================================================
-- V1.1 阶段1｜经营指标诊断基础层
-- 03b_diagnostic_snapshot_carrier_account.sql（_diag_carrier / _diag_account）
-- ============================================================================
-- carrier/account 域：27 指标（排除 4 个效率字段，该两表无效率列）。
-- 对象：carrier=(sale_scope, carrier_type)；account=(sale_scope, account_name)。
-- 排名：域内(scope 内) DENSE_RANK，方向按白名单（refund_rate ASC 其余 DESC）；
--       account 排名排除"更多账号"聚合桶（与 rank_accounts 默认一致）。
-- 贡献：域内占比（分母含聚合桶），denominator_type=domain。
-- ============================================================================

-- ----------------------------------------------------------------------------
-- _diag_carrier
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart._diag_carrier(text,date,date,date,date,text);

CREATE FUNCTION mart._diag_carrier(
    p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text
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
    v_en text; v_scope text;
BEGIN
    SELECT COALESCE(s.shop_name, '平台汇总') INTO v_en FROM meta.shop s WHERE s.shop_name = p_shop_name;
    IF v_en IS NULL THEN v_en := '平台汇总'; END IF;
    IF p_scope_key IS NOT NULL AND NOT EXISTS (SELECT 1 FROM mart.resolve_scope(p_scope_key)) THEN
        RAISE EXCEPTION '未知 Scope: %', p_scope_key;
    END IF;

    RETURN QUERY
    WITH raw AS (
        SELECT
            d.sale_scope AS scp,
            d.carrier_type AS eid,
            d.carrier_type AS ename,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.biz_date END)::int AS p_days,
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
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.total_expense_rate_net_refund_shop_bound * d.settlement_amount END) AS p_total_exp
        FROM core.douyin_carrier_daily d
        JOIN meta.shop s ON s.shop_id = d.shop_id
        WHERE d.biz_date BETWEEN p_ps AND p_ce
          AND d.sale_scope IN ('自营','合作')
          AND d.account_channel NOT IN ('全域投放时段','标准+品牌投放')
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
          AND (p_scope_key IS NULL OR (
                d.sale_scope = (SELECT r.sale_scope FROM mart.resolve_scope(p_scope_key) r)
                AND ((SELECT r.carrier_type FROM mart.resolve_scope(p_scope_key) r) = '全部'
                     OR d.carrier_type = (SELECT r.carrier_type FROM mart.resolve_scope(p_scope_key) r))))
        GROUP BY d.sale_scope, d.carrier_type
    ),
    metrics AS (
        SELECT r.*, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up WHEN 'transaction_amount' THEN r.c_trans
                WHEN 'settlement_amount' THEN r.c_settle WHEN 'transaction_order_count' THEN r.c_ord
                WHEN 'transaction_buyer_count' THEN r.c_buyer WHEN 'transaction_item_count' THEN r.c_items
                WHEN 'avg_customer_amount' THEN r.c_up / NULLIF(r.c_buyer, 0)
                WHEN 'avg_item_amount' THEN r.c_up / NULLIF(r.c_items, 0)
                WHEN 'product_exposure_user_count' THEN r.c_exp_u WHEN 'product_click_user_count' THEN r.c_click_u
                WHEN 'exposure_to_click_rate_users' THEN r.c_click_u / NULLIF(r.c_exp_u, 0)
                WHEN 'click_to_transaction_rate_users' THEN r.c_buyer / NULLIF(r.c_click_u, 0)
                WHEN 'exposure_to_transaction_rate_users' THEN r.c_buyer / NULLIF(r.c_exp_u, 0)
                WHEN 'product_exposure_count' THEN r.c_exp_c WHEN 'product_click_count' THEN r.c_click_c
                WHEN 'exposure_to_click_rate_events' THEN r.c_click_c / NULLIF(r.c_exp_c, 0)
                WHEN 'click_to_transaction_rate_events' THEN r.c_ord / NULLIF(r.c_click_c, 0)
                WHEN 'exposure_to_transaction_rate_events' THEN r.c_ord / NULLIF(r.c_exp_c, 0)
                WHEN 'transaction_refund_amount_pay_time' THEN r.c_trefund
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
                WHEN 'ad_spend_shop_promoted' THEN r.c_ad_promoted WHEN 'ad_spend_shop_bound' THEN r.c_ad_bound
                WHEN 'ad_attributed_transaction_amount' THEN r.c_ad_attrib
                WHEN 'ad_attributed_transaction_share' THEN r.c_ad_attrib / NULLIF(r.c_trans, 0)
                WHEN 'ad_spend_rate_net_refund_shop_bound' THEN r.c_ad_bound / NULLIF(r.c_settle, 0)
                WHEN 'total_expense_rate_net_refund_shop_bound' THEN r.c_total_exp / NULLIF(r.c_settle, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up WHEN 'transaction_amount' THEN r.p_trans
                WHEN 'settlement_amount' THEN r.p_settle WHEN 'transaction_order_count' THEN r.p_ord
                WHEN 'transaction_buyer_count' THEN r.p_buyer WHEN 'transaction_item_count' THEN r.p_items
                WHEN 'avg_customer_amount' THEN r.p_up / NULLIF(r.p_buyer, 0)
                WHEN 'avg_item_amount' THEN r.p_up / NULLIF(r.p_items, 0)
                WHEN 'product_exposure_user_count' THEN r.p_exp_u WHEN 'product_click_user_count' THEN r.p_click_u
                WHEN 'exposure_to_click_rate_users' THEN r.p_click_u / NULLIF(r.p_exp_u, 0)
                WHEN 'click_to_transaction_rate_users' THEN r.p_buyer / NULLIF(r.p_click_u, 0)
                WHEN 'exposure_to_transaction_rate_users' THEN r.p_buyer / NULLIF(r.p_exp_u, 0)
                WHEN 'product_exposure_count' THEN r.p_exp_c WHEN 'product_click_count' THEN r.p_click_c
                WHEN 'exposure_to_click_rate_events' THEN r.p_click_c / NULLIF(r.p_exp_c, 0)
                WHEN 'click_to_transaction_rate_events' THEN r.p_ord / NULLIF(r.p_click_c, 0)
                WHEN 'exposure_to_transaction_rate_events' THEN r.p_ord / NULLIF(r.p_exp_c, 0)
                WHEN 'transaction_refund_amount_pay_time' THEN r.p_trefund
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
                WHEN 'ad_spend_shop_promoted' THEN r.p_ad_promoted WHEN 'ad_spend_shop_bound' THEN r.p_ad_bound
                WHEN 'ad_attributed_transaction_amount' THEN r.p_ad_attrib
                WHEN 'ad_attributed_transaction_share' THEN r.p_ad_attrib / NULLIF(r.p_trans, 0)
                WHEN 'ad_spend_rate_net_refund_shop_bound' THEN r.p_ad_bound / NULLIF(r.p_settle, 0)
                WHEN 'total_expense_rate_net_refund_shop_bound' THEN r.p_total_exp / NULLIF(r.p_settle, 0)
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
            ('total_expense_rate_net_refund_shop_bound','综合费比(剔除退款、店铺绑定)','投放','ratio','0.00%')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        v_en AS shop_name,
        'carrier' AS domain_key,
        '载体' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        m.scp::text AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs AS current_start_date, p_ce AS current_end_date,
        p_ps AS previous_start_date, p_pe AS previous_end_date,
        m.c_val AS current_value, m.p_val AS previous_value,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.metric_key IN ('exposure_to_click_rate_users','click_to_transaction_rate_users',
                    'exposure_to_transaction_rate_users','exposure_to_click_rate_events','click_to_transaction_rate_events',
                    'exposure_to_transaction_rate_events','refund_rate_pay_time','ad_attributed_transaction_share',
                    'ad_spend_rate_net_refund_shop_bound','total_expense_rate_net_refund_shop_bound')
             AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.scp, m2.eid,
                        DENSE_RANK() OVER (PARTITION BY m2.scp ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.scp = m.scp AND t.eid = m.eid)
             ELSE NULL END AS current_rank,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.scp, m2.eid,
                        DENSE_RANK() OVER (PARTITION BY m2.scp ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.scp = m.scp AND t.eid = m.eid)
             ELSE NULL END AS previous_rank,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.scp, m2.eid,
                        DENSE_RANK() OVER (PARTITION BY m2.scp ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.scp = m.scp AND t.eid = m.eid)
                  - (SELECT t.rnk FROM (SELECT m2.scp, m2.eid,
                        DENSE_RANK() OVER (PARTITION BY m2.scp ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.scp = m.scp AND t.eid = m.eid)
             ELSE NULL END AS rank_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time')
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.scp = m.scp), 0)
             ELSE NULL END AS current_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time')
             THEN m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.scp = m.scp), 0)
             ELSE NULL END AS previous_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time') AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.scp = m.scp), 0)
                - m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.scp = m.scp), 0)
             ELSE NULL END AS contribution_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time') THEN 'domain' ELSE NULL END AS contribution_denominator_type,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time')
             THEN (SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.scp = m.scp) ELSE NULL END AS contribution_denominator_value,
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
        '载体快照；排名按 Scope 内' AS notes
    FROM metrics m
    ORDER BY m.scp, m.eid, m.metric_key;
END;
$function$;

COMMENT ON FUNCTION mart._diag_carrier(text,date,date,date,date,text) IS 'V1.1 载体域诊断快照（内部函数，不对外授权）。';

-- ----------------------------------------------------------------------------
-- _diag_account
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart._diag_account(text,date,date,date,date,text);

CREATE FUNCTION mart._diag_account(
    p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text
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
    IF p_scope_key IS NOT NULL AND NOT EXISTS (SELECT 1 FROM mart.resolve_scope(p_scope_key)) THEN
        RAISE EXCEPTION '未知 Scope: %', p_scope_key;
    END IF;

    RETURN QUERY
    WITH raw AS (
        SELECT
            d.sale_scope AS scp,
            d.account_name AS eid,
            d.account_name AS ename,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.biz_date END)::int AS p_days,
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
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.total_expense_rate_net_refund_shop_bound * d.settlement_amount END) AS p_total_exp
        FROM core.douyin_account_daily d
        JOIN meta.shop s ON s.shop_id = d.shop_id
        WHERE d.biz_date BETWEEN p_ps AND p_ce
          AND d.sale_scope IN ('自营','合作')
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
          AND (p_scope_key IS NULL OR d.sale_scope = (SELECT r.sale_scope FROM mart.resolve_scope(p_scope_key) r))
        GROUP BY d.sale_scope, d.account_name
    ),
    metrics AS (
        SELECT r.*, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up WHEN 'transaction_amount' THEN r.c_trans
                WHEN 'settlement_amount' THEN r.c_settle WHEN 'transaction_order_count' THEN r.c_ord
                WHEN 'transaction_buyer_count' THEN r.c_buyer WHEN 'transaction_item_count' THEN r.c_items
                WHEN 'avg_customer_amount' THEN r.c_up / NULLIF(r.c_buyer, 0)
                WHEN 'avg_item_amount' THEN r.c_up / NULLIF(r.c_items, 0)
                WHEN 'product_exposure_user_count' THEN r.c_exp_u WHEN 'product_click_user_count' THEN r.c_click_u
                WHEN 'exposure_to_click_rate_users' THEN r.c_click_u / NULLIF(r.c_exp_u, 0)
                WHEN 'click_to_transaction_rate_users' THEN r.c_buyer / NULLIF(r.c_click_u, 0)
                WHEN 'exposure_to_transaction_rate_users' THEN r.c_buyer / NULLIF(r.c_exp_u, 0)
                WHEN 'product_exposure_count' THEN r.c_exp_c WHEN 'product_click_count' THEN r.c_click_c
                WHEN 'exposure_to_click_rate_events' THEN r.c_click_c / NULLIF(r.c_exp_c, 0)
                WHEN 'click_to_transaction_rate_events' THEN r.c_ord / NULLIF(r.c_click_c, 0)
                WHEN 'exposure_to_transaction_rate_events' THEN r.c_ord / NULLIF(r.c_exp_c, 0)
                WHEN 'transaction_refund_amount_pay_time' THEN r.c_trefund
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
                WHEN 'ad_spend_shop_promoted' THEN r.c_ad_promoted WHEN 'ad_spend_shop_bound' THEN r.c_ad_bound
                WHEN 'ad_attributed_transaction_amount' THEN r.c_ad_attrib
                WHEN 'ad_attributed_transaction_share' THEN r.c_ad_attrib / NULLIF(r.c_trans, 0)
                WHEN 'ad_spend_rate_net_refund_shop_bound' THEN r.c_ad_bound / NULLIF(r.c_settle, 0)
                WHEN 'total_expense_rate_net_refund_shop_bound' THEN r.c_total_exp / NULLIF(r.c_settle, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up WHEN 'transaction_amount' THEN r.p_trans
                WHEN 'settlement_amount' THEN r.p_settle WHEN 'transaction_order_count' THEN r.p_ord
                WHEN 'transaction_buyer_count' THEN r.p_buyer WHEN 'transaction_item_count' THEN r.p_items
                WHEN 'avg_customer_amount' THEN r.p_up / NULLIF(r.p_buyer, 0)
                WHEN 'avg_item_amount' THEN r.p_up / NULLIF(r.p_items, 0)
                WHEN 'product_exposure_user_count' THEN r.p_exp_u WHEN 'product_click_user_count' THEN r.p_click_u
                WHEN 'exposure_to_click_rate_users' THEN r.p_click_u / NULLIF(r.p_exp_u, 0)
                WHEN 'click_to_transaction_rate_users' THEN r.p_buyer / NULLIF(r.p_click_u, 0)
                WHEN 'exposure_to_transaction_rate_users' THEN r.p_buyer / NULLIF(r.p_exp_u, 0)
                WHEN 'product_exposure_count' THEN r.p_exp_c WHEN 'product_click_count' THEN r.p_click_c
                WHEN 'exposure_to_click_rate_events' THEN r.p_click_c / NULLIF(r.p_exp_c, 0)
                WHEN 'click_to_transaction_rate_events' THEN r.p_ord / NULLIF(r.p_click_c, 0)
                WHEN 'exposure_to_transaction_rate_events' THEN r.p_ord / NULLIF(r.p_exp_c, 0)
                WHEN 'transaction_refund_amount_pay_time' THEN r.p_trefund
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
                WHEN 'ad_spend_shop_promoted' THEN r.p_ad_promoted WHEN 'ad_spend_shop_bound' THEN r.p_ad_bound
                WHEN 'ad_attributed_transaction_amount' THEN r.p_ad_attrib
                WHEN 'ad_attributed_transaction_share' THEN r.p_ad_attrib / NULLIF(r.p_trans, 0)
                WHEN 'ad_spend_rate_net_refund_shop_bound' THEN r.p_ad_bound / NULLIF(r.p_settle, 0)
                WHEN 'total_expense_rate_net_refund_shop_bound' THEN r.p_total_exp / NULLIF(r.p_settle, 0)
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
            ('total_expense_rate_net_refund_shop_bound','综合费比(剔除退款、店铺绑定)','投放','ratio','0.00%')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        v_en AS shop_name,
        'account' AS domain_key,
        '账号' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        m.scp::text AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs AS current_start_date, p_ce AS current_end_date,
        p_ps AS previous_start_date, p_pe AS previous_end_date,
        m.c_val AS current_value, m.p_val AS previous_value,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.metric_key IN ('exposure_to_click_rate_users','click_to_transaction_rate_users',
                    'exposure_to_transaction_rate_users','exposure_to_click_rate_events','click_to_transaction_rate_events',
                    'exposure_to_transaction_rate_events','refund_rate_pay_time','ad_attributed_transaction_share',
                    'ad_spend_rate_net_refund_shop_bound','total_expense_rate_net_refund_shop_bound')
             AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','transaction_order_count','transaction_buyer_count',
                    'avg_customer_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.scp, m2.eid,
                        DENSE_RANK() OVER (PARTITION BY m2.scp ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.eid <> '更多账号') t WHERE t.scp = m.scp AND t.eid = m.eid)
             ELSE NULL END AS current_rank,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','transaction_order_count','transaction_buyer_count',
                    'avg_customer_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.scp, m2.eid,
                        DENSE_RANK() OVER (PARTITION BY m2.scp ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.eid <> '更多账号') t WHERE t.scp = m.scp AND t.eid = m.eid)
             ELSE NULL END AS previous_rank,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','transaction_order_count','transaction_buyer_count',
                    'avg_customer_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.scp, m2.eid,
                        DENSE_RANK() OVER (PARTITION BY m2.scp ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.eid <> '更多账号') t WHERE t.scp = m.scp AND t.eid = m.eid)
                  - (SELECT t.rnk FROM (SELECT m2.scp, m2.eid,
                        DENSE_RANK() OVER (PARTITION BY m2.scp ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.eid <> '更多账号') t WHERE t.scp = m.scp AND t.eid = m.eid)
             ELSE NULL END AS rank_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time')
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.scp = m.scp), 0)
             ELSE NULL END AS current_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time')
             THEN m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.scp = m.scp), 0)
             ELSE NULL END AS previous_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time') AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.scp = m.scp), 0)
                - m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.scp = m.scp), 0)
             ELSE NULL END AS contribution_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time') THEN 'domain' ELSE NULL END AS contribution_denominator_type,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time')
             THEN (SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key AND m2.scp = m.scp) ELSE NULL END AS contribution_denominator_value,
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
        '账号快照；排名排除更多账号桶，贡献分母含桶' AS notes
    FROM metrics m
    ORDER BY m.scp, m.eid, m.metric_key;
END;
$function$;

COMMENT ON FUNCTION mart._diag_account(text,date,date,date,date,text) IS 'V1.1 账号域诊断快照（内部函数，不对外授权）。';
