-- ============================================================================
-- V1.3 阶段2｜抖音多店统一经营层
-- 02_platform_business_summary.sql
--   mart.get_platform_business_period_summary  平台整体经营汇总（含 coverage）
--   mart.compare_platform_business             平台环比
-- ============================================================================
-- 原则（文档八~十七节）：
--   汇总范围 = enabled=true AND platform_code=douyin 店铺
--   可加指标 = 两店 SUM；成交人数 = sum_of_shop_transaction_users（跨店不去重）
--   比例 = 汇总分子 / 汇总分母（禁 AVG）；效率 = 投放消耗加权
--   coverage = enabled_shop_count / covered_shop_count / missing / complete + 日期按店检查
--   平台整体只存在于 mart 语义，不建 shop_id=0
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 平台整体经营汇总
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.get_platform_business_period_summary(text,date,date,text);

CREATE FUNCTION mart.get_platform_business_period_summary(
    p_platform_code text,
    p_start_date    date,
    p_end_date      date,
    p_scope_key     text DEFAULT '全店'
) RETURNS TABLE (
    platform_code text, platform_name text,
    start_date date, end_date date, scope_key text,
    enabled_shop_count integer, covered_shop_count integer,
    missing_shop_count integer, missing_shops text,
    coverage_complete boolean,
    coverage_days integer, expected_days integer,
    user_pay_amount numeric, transaction_amount numeric, settlement_amount numeric,
    refund_amount_pay_time numeric, refund_rate_pay_time numeric,
    transaction_order_count bigint, transaction_buyer_count bigint, transaction_item_count bigint,
    avg_customer_amount numeric, avg_item_amount numeric,
    product_exposure_count bigint, product_click_count bigint,
    exposure_to_click_rate_events numeric, click_to_transaction_rate_events numeric, exposure_to_transaction_rate_events numeric,
    exposure_to_click_rate_users numeric, click_to_transaction_rate_users numeric, exposure_to_transaction_rate_users numeric,
    ad_spend_shop_promoted numeric, ad_spend_shop_bound numeric,
    ad_attributed_transaction_amount numeric, ad_attributed_transaction_share numeric,
    ad_spend_rate_net_refund_shop_bound numeric, total_expense_rate_net_refund_shop_bound numeric,
    ad_efficiency_shop_promoted numeric, ad_efficiency_shop_bound numeric,
    store_efficiency_shop_promoted numeric, store_efficiency_shop_bound numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_enabled_count int;
    v_missing_shops text;
    v_scope_sale text; v_scope_carrier text; v_scope_period text;
    v_expected_days int;
BEGIN
    -- 平台校验
    IF NOT EXISTS (SELECT 1 FROM meta.platform p WHERE p.platform_code = p_platform_code AND p.enabled) THEN
        RAISE EXCEPTION '未知/未启用平台: %', p_platform_code;
    END IF;
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RAISE EXCEPTION '非法日期区间: % ~ %', p_start_date, p_end_date;
    END IF;
    -- Scope 解析
    SELECT sale_scope, carrier_type, ad_period INTO v_scope_sale, v_scope_carrier, v_scope_period
    FROM mart.resolve_scope(p_scope_key);
    IF v_scope_sale IS NULL THEN
        RAISE EXCEPTION '未知经营语义: %', p_scope_key;
    END IF;
    v_expected_days := (p_end_date - p_start_date) + 1;

    RETURN QUERY
    WITH enabled_shops AS (
        SELECT s.shop_id, s.shop_name FROM meta.shop s
        WHERE s.platform_code = p_platform_code AND s.enabled
    ),
    shop_days AS (
        -- 每店在该区间有数据的天数（合法 TOTAL 口径）
        SELECT d.shop_id,
               count(DISTINCT d.biz_date)::int AS covered_days
        FROM core.douyin_deal_daily d
        JOIN enabled_shops es ON es.shop_id = d.shop_id
        WHERE d.biz_date BETWEEN p_start_date AND p_end_date
          AND d.sale_scope = v_scope_sale AND d.carrier_type = v_scope_carrier AND d.ad_period = v_scope_period
        GROUP BY d.shop_id
    ),
    agg AS (
        SELECT
            count(DISTINCT es.shop_id)::int AS enabled_cnt,
            count(DISTINCT sd.shop_id)::int AS covered_cnt,
            coalesce(sum(sd.covered_days), 0)::int AS total_covered_days,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.user_pay_amount END) AS c_up,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.transaction_amount END) AS c_trans,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.settlement_amount END) AS c_settle,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.transaction_order_count END)::bigint AS c_ord,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.transaction_buyer_count END)::bigint AS c_buyer,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.transaction_item_count END)::bigint AS c_items,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.product_exposure_count END) AS c_exp_c,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.product_click_count END) AS c_click_c,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.product_exposure_user_count END) AS c_exp_u,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.product_click_user_count END) AS c_click_u,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.ad_spend_shop_promoted END) AS c_ad_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.ad_spend_shop_bound END) AS c_ad_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.ad_attributed_transaction_amount END) AS c_ad_attrib,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.total_expense_rate_net_refund_shop_bound * d.settlement_amount END) AS c_total_exp,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.ad_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS c_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.ad_efficiency_shop_bound * d.ad_spend_shop_bound END) AS c_eff_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.store_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS c_st_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.store_efficiency_shop_bound * d.ad_spend_shop_bound END) AS c_st_eff_bound
        FROM enabled_shops es
        LEFT JOIN core.douyin_deal_daily d
          ON d.shop_id = es.shop_id
         AND d.biz_date BETWEEN p_start_date AND p_end_date
         AND d.sale_scope = v_scope_sale AND d.carrier_type = v_scope_carrier AND d.ad_period = v_scope_period
        LEFT JOIN shop_days sd ON sd.shop_id = es.shop_id
    )
    SELECT
        p_platform_code AS platform_code,
        (SELECT p.platform_name FROM meta.platform p WHERE p.platform_code = p_platform_code) AS platform_name,
        p_start_date, p_end_date, p_scope_key,
        a.enabled_cnt AS enabled_shop_count,
        a.covered_cnt AS covered_shop_count,
        (a.enabled_cnt - a.covered_cnt) AS missing_shop_count,
        (SELECT string_agg(es.shop_name, '、' ORDER BY es.shop_name)
           FROM enabled_shops es LEFT JOIN shop_days sd ON sd.shop_id = es.shop_id
          WHERE sd.shop_id IS NULL) AS missing_shops,
        (a.covered_cnt = a.enabled_cnt
         AND NOT EXISTS (SELECT 1 FROM shop_days sd2 JOIN enabled_shops es2 ON es2.shop_id=sd2.shop_id WHERE sd2.covered_days < v_expected_days)
        ) AS coverage_complete,
        a.total_covered_days AS coverage_days,
        (a.enabled_cnt * v_expected_days) AS expected_days,
        round(a.c_up, 2), round(a.c_trans, 2), round(a.c_settle, 2),
        round(a.c_refund, 2),
        round(a.c_refund / NULLIF(a.c_up, 0), 10),
        a.c_ord, a.c_buyer, a.c_items,
        round(a.c_up / NULLIF(a.c_buyer, 0), 4),
        round(a.c_up / NULLIF(a.c_items, 0), 4),
        a.c_exp_c::bigint, a.c_click_c::bigint,
        round(a.c_click_c / NULLIF(a.c_exp_c, 0), 10),
        round(a.c_ord / NULLIF(a.c_click_c, 0), 10),
        round(a.c_ord / NULLIF(a.c_exp_c, 0), 10),
        round(a.c_click_u / NULLIF(a.c_exp_u, 0), 10),
        round(a.c_buyer / NULLIF(a.c_click_u, 0), 10),
        round(a.c_buyer / NULLIF(a.c_exp_u, 0), 10),
        round(a.c_ad_promoted, 2), round(a.c_ad_bound, 2),
        round(a.c_ad_attrib, 2),
        round(a.c_ad_attrib / NULLIF(a.c_trans, 0), 10),
        round(a.c_ad_bound / NULLIF(a.c_settle, 0), 10),
        round(a.c_total_exp / NULLIF(a.c_settle, 0), 10),
        round(a.c_eff_promoted / NULLIF(a.c_ad_promoted, 0), 10),
        round(a.c_eff_bound / NULLIF(a.c_ad_bound, 0), 10),
        round(a.c_st_eff_promoted / NULLIF(a.c_ad_promoted, 0), 10),
        round(a.c_st_eff_bound / NULLIF(a.c_ad_bound, 0), 10)
    FROM agg a;
END;
$function$;

COMMENT ON FUNCTION mart.get_platform_business_period_summary(text,date,date,text) IS
'V1.3 平台整体经营汇总：范围=enabled且platform_code匹配的店铺；可加指标SUM、比例分子/分母重算、效率加权；coverage含启用/覆盖/缺失店铺数与日期完整性。成交人数=各店之和（跨店不去重）。';

-- ----------------------------------------------------------------------------
-- 平台环比（本期 vs 等长上期）
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS mart.compare_platform_business(text,date,date,text,text);

CREATE FUNCTION mart.compare_platform_business(
    p_platform_code text,
    p_start_date    date,
    p_end_date      date,
    p_scope_key     text DEFAULT '全店',
    p_metric_key    text DEFAULT 'user_pay_amount'
) RETURNS TABLE (
    platform_code text, platform_name text, scope_key text,
    metric_key text, metric_name_cn text, value_type text,
    current_start_date date, current_end_date date,
    previous_start_date date, previous_end_date date,
    current_value numeric, previous_value numeric,
    absolute_change numeric, relative_change numeric,
    percentage_point_change numeric,
    enabled_shop_count integer, covered_shop_count integer,
    current_coverage_complete boolean, previous_coverage_complete boolean,
    comparison_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
DECLARE
    v_ps date; v_pe date; v_days int;
    v_name text; v_type text;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RAISE EXCEPTION '非法日期区间: % ~ %', p_start_date, p_end_date;
    END IF;
    SELECT w.metric_name_cn, w.value_type INTO v_name, v_type
    FROM mart.analysis_metric_whitelist w WHERE w.domain_key='business' AND w.metric_key = p_metric_key;
    IF v_name IS NULL THEN
        RAISE EXCEPTION 'business 域不支持指标: %', p_metric_key;
    END IF;
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);

    RETURN QUERY
    SELECT
        p_platform_code,
        (SELECT p.platform_name FROM meta.platform p WHERE p.platform_code = p_platform_code),
        p_scope_key,
        p_metric_key, v_name, v_type,
        p_start_date, p_end_date, v_ps, v_pe,
        c.val AS current_value,
        p_.val AS previous_value,
        (c.val - p_.val) AS absolute_change,
        CASE WHEN p_.val IS NULL THEN NULL WHEN p_.val = 0 THEN NULL
             ELSE (c.val - p_.val) / abs(p_.val) END AS relative_change,
        CASE WHEN v_type = 'ratio' AND c.val IS NOT NULL AND p_.val IS NOT NULL
             THEN c.val - p_.val ELSE NULL END AS percentage_point_change,
        c.enabled_shop_count, c.covered_shop_count,
        c.coverage_complete, p_.coverage_complete,
        CASE WHEN c.val IS NOT NULL AND p_.val IS NOT NULL THEN 'COMPARABLE' ELSE 'INCOMPLETE' END AS comparison_status
    FROM (SELECT *, CASE p_metric_key
                      WHEN 'user_pay_amount' THEN user_pay_amount
                      WHEN 'transaction_amount' THEN transaction_amount
                      WHEN 'settlement_amount' THEN settlement_amount
                      WHEN 'refund_amount_pay_time' THEN refund_amount_pay_time
                      WHEN 'refund_rate_pay_time' THEN refund_rate_pay_time
                      WHEN 'transaction_order_count' THEN transaction_order_count
                      WHEN 'transaction_buyer_count' THEN transaction_buyer_count
                      WHEN 'transaction_item_count' THEN transaction_item_count
                      WHEN 'ad_spend_shop_promoted' THEN ad_spend_shop_promoted
                      WHEN 'ad_spend_shop_bound' THEN ad_spend_shop_bound
                      WHEN 'ad_attributed_transaction_amount' THEN ad_attributed_transaction_amount
                      WHEN 'ad_spend_rate_net_refund_shop_bound' THEN ad_spend_rate_net_refund_shop_bound
                    END AS val
          FROM mart.get_platform_business_period_summary(p_platform_code, p_start_date, p_end_date, p_scope_key)) c
    CROSS JOIN (SELECT *, CASE p_metric_key
                      WHEN 'user_pay_amount' THEN user_pay_amount
                      WHEN 'transaction_amount' THEN transaction_amount
                      WHEN 'settlement_amount' THEN settlement_amount
                      WHEN 'refund_amount_pay_time' THEN refund_amount_pay_time
                      WHEN 'refund_rate_pay_time' THEN refund_rate_pay_time
                      WHEN 'transaction_order_count' THEN transaction_order_count
                      WHEN 'transaction_buyer_count' THEN transaction_buyer_count
                      WHEN 'transaction_item_count' THEN transaction_item_count
                      WHEN 'ad_spend_shop_promoted' THEN ad_spend_shop_promoted
                      WHEN 'ad_spend_shop_bound' THEN ad_spend_shop_bound
                      WHEN 'ad_attributed_transaction_amount' THEN ad_attributed_transaction_amount
                      WHEN 'ad_spend_rate_net_refund_shop_bound' THEN ad_spend_rate_net_refund_shop_bound
                    END AS val
                FROM mart.get_platform_business_period_summary(p_platform_code, v_ps, v_pe, p_scope_key)) p_;
END;
$function$;

COMMENT ON FUNCTION mart.compare_platform_business(text,date,date,text,text) IS 'V1.3 平台环比：本期 vs 等长上期（金额/计数可比较；比例返回百分点+相对变化）。';
