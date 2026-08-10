-- ============================================================================
-- V1.3 阶段2｜抖音多店统一经营层
-- 04_platform_daily_and_diagnostic.sql
--   mart.douyin_platform_daily            平台日表 View（platform×date×scope）
--   mart.get_platform_diagnostic_snapshot 平台整体诊断快照（V1.1 Stage1 平台模式）
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 平台日表（全店 TOTAL 口径，平台×日期）
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS mart.douyin_platform_daily;
CREATE VIEW mart.douyin_platform_daily AS
SELECT
    'douyin' AS platform_code,
    d.biz_date,
    '全店' AS scope_key,
    sum(d.user_pay_amount) AS user_pay_amount,
    sum(d.transaction_amount) AS transaction_amount,
    sum(d.settlement_amount) AS settlement_amount,
    sum(d.refund_amount_pay_time) AS refund_amount_pay_time,
    sum(d.transaction_order_count) AS transaction_order_count,
    sum(d.transaction_buyer_count) AS transaction_buyer_count,
    sum(d.transaction_item_count) AS transaction_item_count,
    sum(d.product_exposure_count) AS product_exposure_count,
    sum(d.product_click_count) AS product_click_count,
    sum(d.ad_spend_shop_promoted) AS ad_spend_shop_promoted,
    sum(d.ad_spend_shop_bound) AS ad_spend_shop_bound,
    sum(d.ad_attributed_transaction_amount) AS ad_attributed_transaction_amount
FROM core.douyin_deal_daily d
JOIN meta.shop s ON s.shop_id = d.shop_id
WHERE s.platform_code = 'douyin' AND s.enabled
  AND d.sale_scope = '全部' AND d.carrier_type = '全部' AND d.ad_period = '不限'
GROUP BY d.biz_date;

COMMENT ON VIEW mart.douyin_platform_daily IS 'V1.3 平台日表（全店TOTAL口径）：platform×date，两店合计。平台整体只存在于 mart 语义，不建 shop_id=0。';

-- ----------------------------------------------------------------------------
-- 平台整体诊断快照（V1.1 Stage1 平台模式）
-- 对象=抖音整体，指标=平台汇总口径；带 shop coverage。
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_platform_diagnostic_snapshot(text,date,date,text);

CREATE FUNCTION mart.get_platform_diagnostic_snapshot(
    p_platform_code text,
    p_start_date    date,
    p_end_date      date,
    p_scope_key     text DEFAULT '全店'
) RETURNS TABLE (
    platform_code text, platform_name text, scope_key text,
    entity_id text, entity_name text,
    metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text,
    current_start_date date, current_end_date date,
    previous_start_date date, previous_end_date date,
    current_value numeric, previous_value numeric,
    absolute_change numeric, relative_change numeric, percentage_point_change numeric,
    enabled_shop_count integer, covered_shop_count integer,
    current_coverage_complete boolean, previous_coverage_complete boolean,
    data_status text
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
    WITH m AS (
        SELECT * FROM mart.get_platform_business_period_summary(p_platform_code, p_start_date, p_end_date, p_scope_key)
    ),
    mp AS (
        SELECT * FROM mart.get_platform_business_period_summary(p_platform_code, v_ps, v_pe, p_scope_key)
    ),
    metrics AS (
        SELECT vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN m.user_pay_amount
                WHEN 'transaction_amount' THEN m.transaction_amount
                WHEN 'settlement_amount' THEN m.settlement_amount
                WHEN 'refund_amount_pay_time' THEN m.refund_amount_pay_time
                WHEN 'refund_rate_pay_time' THEN m.refund_rate_pay_time
                WHEN 'transaction_order_count' THEN m.transaction_order_count
                WHEN 'transaction_buyer_count' THEN m.transaction_buyer_count
                WHEN 'transaction_item_count' THEN m.transaction_item_count
                WHEN 'avg_customer_amount' THEN m.avg_customer_amount
                WHEN 'avg_item_amount' THEN m.avg_item_amount
                WHEN 'ad_spend_shop_promoted' THEN m.ad_spend_shop_promoted
                WHEN 'ad_spend_shop_bound' THEN m.ad_spend_shop_bound
                WHEN 'ad_attributed_transaction_amount' THEN m.ad_attributed_transaction_amount
                WHEN 'ad_attributed_transaction_share' THEN m.ad_attributed_transaction_share
                WHEN 'ad_spend_rate_net_refund_shop_bound' THEN m.ad_spend_rate_net_refund_shop_bound
                WHEN 'total_expense_rate_net_refund_shop_bound' THEN m.total_expense_rate_net_refund_shop_bound
                WHEN 'ad_efficiency_shop_promoted' THEN m.ad_efficiency_shop_promoted
                WHEN 'store_efficiency_shop_promoted' THEN m.store_efficiency_shop_promoted
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN mp.user_pay_amount
                WHEN 'transaction_amount' THEN mp.transaction_amount
                WHEN 'settlement_amount' THEN mp.settlement_amount
                WHEN 'refund_amount_pay_time' THEN mp.refund_amount_pay_time
                WHEN 'refund_rate_pay_time' THEN mp.refund_rate_pay_time
                WHEN 'transaction_order_count' THEN mp.transaction_order_count
                WHEN 'transaction_buyer_count' THEN mp.transaction_buyer_count
                WHEN 'transaction_item_count' THEN mp.transaction_item_count
                WHEN 'avg_customer_amount' THEN mp.avg_customer_amount
                WHEN 'avg_item_amount' THEN mp.avg_item_amount
                WHEN 'ad_spend_shop_promoted' THEN mp.ad_spend_shop_promoted
                WHEN 'ad_spend_shop_bound' THEN mp.ad_spend_shop_bound
                WHEN 'ad_attributed_transaction_amount' THEN mp.ad_attributed_transaction_amount
                WHEN 'ad_attributed_transaction_share' THEN mp.ad_attributed_transaction_share
                WHEN 'ad_spend_rate_net_refund_shop_bound' THEN mp.ad_spend_rate_net_refund_shop_bound
                WHEN 'total_expense_rate_net_refund_shop_bound' THEN mp.total_expense_rate_net_refund_shop_bound
                WHEN 'ad_efficiency_shop_promoted' THEN mp.ad_efficiency_shop_promoted
                WHEN 'store_efficiency_shop_promoted' THEN mp.store_efficiency_shop_promoted
            END AS p_val
        FROM m, mp
        CROSS JOIN LATERAL (VALUES
            ('user_pay_amount','用户支付金额','成交','amount','金额'),
            ('transaction_amount','成交金额','成交','amount','金额'),
            ('settlement_amount','结算金额','成交','amount','金额'),
            ('transaction_order_count','成交订单数','成交','count','整数'),
            ('transaction_buyer_count','成交人数','成交','count','整数'),
            ('transaction_item_count','成交件数','成交','count','整数'),
            ('avg_customer_amount','客单价','成交','average','0.00'),
            ('avg_item_amount','件单价','成交','average','0.00'),
            ('refund_amount_pay_time','退款金额(支付时间)','售后','amount','金额'),
            ('refund_rate_pay_time','退款率(支付时间)','售后','ratio','0.00%'),
            ('ad_spend_shop_promoted','投放消耗(店铺被投)','投放','amount','金额'),
            ('ad_spend_shop_bound','投放消耗(店铺绑定)','投放','amount','金额'),
            ('ad_attributed_transaction_amount','投放贡献成交金额','投放','amount','金额'),
            ('ad_attributed_transaction_share','投放贡献成交占比','投放','ratio','0.00%'),
            ('ad_spend_rate_net_refund_shop_bound','投放费比(剔除退款、店铺绑定)','投放','ratio','0.00%'),
            ('total_expense_rate_net_refund_shop_bound','综合费比(剔除退款、店铺绑定)','投放','ratio','0.00%'),
            ('ad_efficiency_shop_promoted','投放效率(店铺被投)','投放','efficiency','0.00'),
            ('store_efficiency_shop_promoted','全店效率(店铺被投)','投放','efficiency','0.00')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        p_platform_code,
        (SELECT p.platform_name FROM meta.platform p WHERE p.platform_code = p_platform_code),
        p_scope_key,
        'platform' AS entity_id,
        '抖音整体' AS entity_name,
        mt.metric_key, mt.name_cn AS metric_name_cn, mt.grp AS metric_group, mt.typ AS metric_type, mt.fmt AS display_format,
        p_start_date, p_end_date, v_ps, v_pe,
        mt.c_val AS current_value, mt.p_val AS previous_value,
        (mt.c_val - mt.p_val) AS absolute_change,
        CASE WHEN mt.p_val IS NULL THEN NULL WHEN mt.p_val = 0 THEN NULL
             ELSE (mt.c_val - mt.p_val) / abs(mt.p_val) END AS relative_change,
        CASE WHEN mt.typ = 'ratio' AND mt.c_val IS NOT NULL AND mt.p_val IS NOT NULL
             THEN mt.c_val - mt.p_val ELSE NULL END AS percentage_point_change,
        m.enabled_shop_count, m.covered_shop_count,
        m.coverage_complete, mp.coverage_complete,
        CASE WHEN m.coverage_complete AND mp.coverage_complete THEN 'OK'
             WHEN NOT m.coverage_complete AND NOT mp.coverage_complete THEN 'BOTH_INCOMPLETE'
             WHEN NOT m.coverage_complete THEN 'CURRENT_INCOMPLETE'
             ELSE 'PREVIOUS_INCOMPLETE' END AS data_status
    FROM metrics mt, m, mp
    ORDER BY mt.metric_key;
END;
$function$;

COMMENT ON FUNCTION mart.get_platform_diagnostic_snapshot(text,date,date,text) IS
'V1.3 平台整体诊断快照：对象=抖音整体，指标=平台汇总口径（18项），带 shop coverage 与数据状态。';
