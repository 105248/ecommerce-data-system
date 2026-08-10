-- ============================================================
-- mart V1.0 阶段2 | get_business_period_summary
-- 店铺/经营范围 动态时间区间汇总（唯一核心总览 Function）
-- 指标表达式逐条对应 V1.4 meta.metric_formula_rule 已验证公式
-- ============================================================
CREATE OR REPLACE FUNCTION mart.get_business_period_summary(
    p_shop_name   text DEFAULT NULL,   -- NULL=全部店铺
    p_start_date  date DEFAULT NULL,   -- 必填(函数内校验)
    p_end_date    date DEFAULT NULL,   -- 必填(函数内校验)
    p_scope_key   text DEFAULT '全店'  -- 必须为 Scope Resolver 已确认语义
) RETURNS TABLE(
    shop_name    character varying,
    start_date   date,
    end_date     date,
    day_count    integer,
    scope_key    character varying,
    sale_scope   character varying,
    carrier_type character varying,
    ad_period    character varying,
    -- 可加指标(SUM)
    user_pay_amount              numeric,
    net_user_pay_amount_pay_time numeric,
    smart_coupon_amount          numeric,
    platform_subsidy_amount      numeric,
    transaction_order_count      numeric,
    transaction_buyer_count      numeric,
    transaction_item_count       numeric,
    transaction_amount           numeric,
    net_transaction_amount       numeric,
    refund_amount_pay_time       numeric,
    transaction_refund_amount_pay_time numeric,
    refund_order_count_pay_time  numeric,
    settlement_amount            numeric,
    creator_subsidy_amount       numeric,
    presale_deposit_amount       numeric,
    product_exposure_user_count  numeric,
    product_click_user_count     numeric,
    product_exposure_count       numeric,
    product_click_count          numeric,
    -- ratio/均值(SUM分子/SUM分母, 规则来源见COMMENT)
    avg_customer_amount                  numeric,  -- rule1  客单价
    avg_item_amount                      numeric,  -- rule11 件单价
    refund_rate_pay_time                 numeric,  -- rule2  退款率
    exposure_to_click_rate_users         numeric,  -- rule3
    click_to_transaction_rate_users      numeric,  -- rule4
    exposure_to_transaction_rate_users   numeric,  -- rule5
    user_pay_amount_per_1000_exposures   numeric,  -- rule6
    exposure_to_click_rate_events        numeric,  -- rule7
    click_to_transaction_rate_events     numeric,  -- rule8
    exposure_to_transaction_rate_events  numeric,  -- rule9
    -- source_only(单日源值/多日NULL)
    ship_within_2_days_rate              numeric,  -- rule10 待平台口径确认
    one_hour_refund_rate_pay_time        numeric,  -- rule16 待平台口径确认
    pre_shipment_refund_rate_pay_time    numeric,  -- rule12 缺基础字段
    unreceived_refund_rate_pay_time      numeric,  -- rule13 缺基础字段
    received_refund_rate_pay_time        numeric,  -- rule14 缺基础字段
    received_return_refund_rate_pay_time numeric,  -- rule15 缺基础字段
    source_only_note text
) AS $$
DECLARE
    v_sale varchar; v_carrier varchar; v_period varchar; v_total boolean;
    v_single_day boolean;
BEGIN
    -- 日期校验
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION '参数错误: p_start_date 和 p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION '参数错误: p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    v_single_day := (p_start_date = p_end_date);

    -- 经营范围必须走 Scope Resolver, 不自行猜测
    SELECT r.sale_scope, r.carrier_type, r.ad_period, r.is_total
      INTO v_sale, v_carrier, v_period, v_total
      FROM mart.resolve_scope(p_scope_key) r;

    RETURN QUERY
    SELECT
        s.shop_name,
        p_start_date,
        p_end_date,
        (p_end_date - p_start_date + 1)::int,
        p_scope_key::varchar,
        v_sale, v_carrier, v_period,
        -- SUM类
        SUM(t.user_pay_amount),
        SUM(t.net_user_pay_amount_pay_time),
        SUM(t.smart_coupon_amount),
        SUM(t.platform_subsidy_amount),
        SUM(t.transaction_order_count),
        SUM(t.transaction_buyer_count),
        SUM(t.transaction_item_count),
        SUM(t.transaction_amount),
        SUM(t.net_transaction_amount),
        SUM(t.refund_amount_pay_time),
        SUM(t.transaction_refund_amount_pay_time),
        SUM(t.refund_order_count_pay_time),
        SUM(t.settlement_amount),
        SUM(t.creator_subsidy_amount),
        SUM(t.presale_deposit_amount),
        SUM(t.product_exposure_user_count),
        SUM(t.product_click_user_count),
        SUM(t.product_exposure_count),
        SUM(t.product_click_count),
        -- ratio 类(V1.4 period_formula_sql 原文)
        SUM(t.user_pay_amount) / NULLIF(SUM(t.transaction_buyer_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.transaction_item_count), 0),
        SUM(t.refund_amount_pay_time) / NULLIF(SUM(t.user_pay_amount), 0),
        SUM(t.product_click_user_count) / NULLIF(SUM(t.product_exposure_user_count), 0),
        SUM(t.transaction_buyer_count) / NULLIF(SUM(t.product_click_user_count), 0),
        SUM(t.transaction_buyer_count) / NULLIF(SUM(t.product_exposure_user_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.product_exposure_count), 0) * 1000,
        SUM(t.product_click_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_click_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_exposure_count), 0),
        -- source_only
        CASE WHEN v_single_day THEN MAX(t.ship_within_2_days_rate) ELSE NULL END,
        CASE WHEN v_single_day THEN MAX(t.one_hour_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN v_single_day THEN MAX(t.pre_shipment_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN v_single_day THEN MAX(t.unreceived_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN v_single_day THEN MAX(t.received_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN v_single_day THEN MAX(t.received_return_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN v_single_day THEN '单日查询: source_only 指标返回当天源值'
             ELSE '多日查询: 6个source_only指标(发货率/细分退款率等)不可精确跨期重算, 返回NULL' END
    FROM core.douyin_deal_daily t
    JOIN meta.shop s ON t.shop_id = s.shop_id
    WHERE (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND t.sale_scope = v_sale
      AND t.carrier_type = v_carrier
      AND t.ad_period = v_period
      AND t.biz_date BETWEEN p_start_date AND p_end_date
    GROUP BY s.shop_name;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mart.get_business_period_summary(text,date,date,text) IS
'经营总览动态区间汇总。仅处理经营范围语义(全店/自营/合作/载体/组合), 业务域筛选请用独立Function。';
