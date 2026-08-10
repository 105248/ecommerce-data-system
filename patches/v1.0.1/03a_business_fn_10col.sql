-- V1.0.1: 重建 get_business_period_summary (+10投放指标列)
DROP FUNCTION IF EXISTS mart.get_business_period_summary(text,date,date,text);
CREATE OR REPLACE FUNCTION mart.get_business_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text)
 RETURNS TABLE(shop_name text, start_date date, end_date date, expected_days integer, coverage_days integer, coverage_complete boolean, scope_key text, sale_scope text, carrier_type text, ad_period text, source_row_count bigint, user_pay_amount numeric, net_user_pay_amount_pay_time numeric, smart_coupon_amount numeric, net_smart_coupon_amount_pay_time numeric, platform_subsidy_amount numeric, transaction_order_count bigint, transaction_buyer_count bigint, avg_customer_amount numeric, transaction_amount numeric, net_transaction_amount numeric, refund_amount_refund_time numeric, transaction_refund_amount_refund_time numeric, refund_order_count_refund_time bigint, refund_rate_pay_time numeric, refund_amount_pay_time numeric, transaction_refund_amount_pay_time numeric, refund_order_count_pay_time bigint, product_exposure_user_count bigint, product_click_user_count bigint, exposure_to_click_rate_users numeric, click_to_transaction_rate_users numeric, exposure_to_transaction_rate_users numeric, user_pay_amount_per_1000_exposures numeric, product_exposure_count bigint, product_click_count bigint, exposure_to_click_rate_events numeric, click_to_transaction_rate_events numeric, exposure_to_transaction_rate_events numeric, shipped_user_pay_amount_ship_time numeric, ship_within_2_days_rate numeric, settlement_amount numeric, settlement_amount_refund_time numeric, settlement_amount_7d numeric, settlement_amount_14d numeric, net_creator_subsidy_amount_pay_time numeric, creator_subsidy_amount numeric, presale_deposit_amount numeric, transaction_item_count bigint, avg_item_amount numeric, net_transaction_order_count bigint, pre_shipment_refund_rate_pay_time numeric, unreceived_refund_rate_pay_time numeric, received_refund_rate_pay_time numeric, received_return_refund_rate_pay_time numeric, one_hour_transaction_refund_amount_pay_time numeric, one_hour_refund_order_count_pay_time bigint, one_hour_refund_rate_pay_time numeric, net_platform_subsidy_amount_pay_time numeric, ad_spend_shop_promoted numeric, ad_spend_shop_bound numeric, ad_attributed_transaction_amount numeric, ad_attributed_transaction_share numeric, ad_spend_rate_net_refund_shop_bound numeric, total_expense_rate_net_refund_shop_bound numeric, ad_efficiency_shop_promoted numeric, ad_efficiency_shop_bound numeric, store_efficiency_shop_promoted numeric, store_efficiency_shop_bound numeric, unrecalculable_metrics text[])
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
AS $function$
DECLARE
    v_scope record;
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);

    SELECT * INTO v_scope FROM mart.period_scope_rule(p_scope_key);
    IF NOT FOUND THEN
        RAISE EXCEPTION '不支持的 scope_key：%。请使用阶段1已确认经营范围。', p_scope_key;
    END IF;

    RETURN QUERY
    SELECT
        s.shop_name::text,
        p_start_date,
        p_end_date,
        (p_end_date - p_start_date + 1)::integer AS expected_days,
        COUNT(DISTINCT d.biz_date)::integer AS coverage_days,
        COUNT(DISTINCT d.biz_date) = (p_end_date - p_start_date + 1)::integer AS coverage_complete,
        v_scope.scope_key::text,
        v_scope.sale_scope::text,
        v_scope.carrier_type::text,
        v_scope.ad_period::text,
        COUNT(*)::bigint,
        SUM(d.user_pay_amount),
        SUM(d.net_user_pay_amount_pay_time),
        SUM(d.smart_coupon_amount),
        SUM(d.net_smart_coupon_amount_pay_time),
        SUM(d.platform_subsidy_amount),
        SUM(d.transaction_order_count)::bigint,
        SUM(d.transaction_buyer_count)::bigint,
        SUM(d.user_pay_amount) / NULLIF(SUM(d.transaction_buyer_count), 0),
        SUM(d.transaction_amount),
        SUM(d.net_transaction_amount),
        SUM(d.refund_amount_refund_time),
        SUM(d.transaction_refund_amount_refund_time),
        SUM(d.refund_order_count_refund_time)::bigint,
        SUM(d.refund_amount_pay_time) / NULLIF(SUM(d.user_pay_amount), 0),
        SUM(d.refund_amount_pay_time),
        SUM(d.transaction_refund_amount_pay_time),
        SUM(d.refund_order_count_pay_time)::bigint,
        SUM(d.product_exposure_user_count)::bigint,
        SUM(d.product_click_user_count)::bigint,
        SUM(d.product_click_user_count) / NULLIF(SUM(d.product_exposure_user_count), 0),
        SUM(d.transaction_buyer_count) / NULLIF(SUM(d.product_click_user_count), 0),
        SUM(d.transaction_buyer_count) / NULLIF(SUM(d.product_exposure_user_count), 0),
        SUM(d.user_pay_amount) / NULLIF(SUM(d.product_exposure_count), 0) * 1000,
        SUM(d.product_exposure_count)::bigint,
        SUM(d.product_click_count)::bigint,
        SUM(d.product_click_count) / NULLIF(SUM(d.product_exposure_count), 0),
        SUM(d.transaction_order_count) / NULLIF(SUM(d.product_click_count), 0),
        SUM(d.transaction_order_count) / NULLIF(SUM(d.product_exposure_count), 0),
        SUM(d.shipped_user_pay_amount_ship_time),
        CASE WHEN p_start_date = p_end_date THEN MAX(d.ship_within_2_days_rate) ELSE NULL END,
        SUM(d.settlement_amount),
        SUM(d.settlement_amount_refund_time),
        SUM(d.settlement_amount_7d),
        SUM(d.settlement_amount_14d),
        SUM(d.net_creator_subsidy_amount_pay_time),
        SUM(d.creator_subsidy_amount),
        SUM(d.presale_deposit_amount),
        SUM(d.transaction_item_count)::bigint,
        SUM(d.user_pay_amount) / NULLIF(SUM(d.transaction_item_count), 0),
        SUM(d.net_transaction_order_count)::bigint,
        CASE WHEN p_start_date = p_end_date THEN MAX(d.pre_shipment_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN MAX(d.unreceived_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN MAX(d.received_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN MAX(d.received_return_refund_rate_pay_time) ELSE NULL END,
        SUM(d.one_hour_transaction_refund_amount_pay_time),
        SUM(d.one_hour_refund_order_count_pay_time)::bigint,
        CASE WHEN p_start_date = p_end_date THEN MAX(d.one_hour_refund_rate_pay_time) ELSE NULL END,
        SUM(d.net_platform_subsidy_amount_pay_time),
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
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[] ELSE ARRAY[
            '两日内发货率',
            '发货前退款率(支付时间)',
            '未收货退款率(支付时间)',
            '已收货退款率(支付时间)',
            '已收货退货退款率(支付时间)',
            '1小时成交退款率(支付时间)'
        ]::text[] END
    FROM core.douyin_deal_daily d
    JOIN meta.shop s ON s.shop_id = d.shop_id
    WHERE d.biz_date BETWEEN p_start_date AND p_end_date
      AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND d.sale_scope = v_scope.sale_scope
      AND d.carrier_type = v_scope.carrier_type
      AND d.ad_period = v_scope.ad_period
    GROUP BY s.shop_name;
END;
$function$

