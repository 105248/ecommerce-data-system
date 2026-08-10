-- ============================================================================
-- PostgreSQL mart经营分析层 V1.0
-- 阶段2：动态时间区间汇总 Function
-- 版本：Stage2 V1.0
-- 基线：V1.4 指标规则 + 阶段0/0.5真实口径扫描 + 阶段1治理/Scope Resolver/Daily Mart
--
-- 设计原则：
-- 1. 不修改 core / meta / audit 业务数据；本脚本仅创建/替换 mart 层只读函数。
-- 2. 对外统一 shop_name，不返回 shop_id。
-- 3. 可加指标跨期 SUM；非可加指标按 V1.4 分子/分母重算，禁止 AVG(日比例)。
-- 4. source_only / 缺基础字段：单日可返回源值，多日返回 NULL。
-- 5. 平台已存在合法 TOTAL 时优先使用 TOTAL，不用父级+子级重建。
-- 6. get_business_period_summary 只负责经营总览 Scope，不做万能查询函数。
-- ============================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS mart;

-- ----------------------------------------------------------------------------
-- A. 前置条件检查：发现异常立即中止，避免在错误基线上继续开发
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_cnt bigint;
    v_auto bigint;
    v_bad bigint;
BEGIN
    IF to_regclass('meta.metric_formula_rule') IS NULL THEN
        RAISE EXCEPTION '缺少 meta.metric_formula_rule；请先执行 V1.4。';
    END IF;
    IF to_regclass('meta.shop') IS NULL THEN
        RAISE EXCEPTION '缺少 meta.shop。';
    END IF;
    IF to_regclass('core.douyin_deal_daily') IS NULL THEN
        RAISE EXCEPTION '缺少 core.douyin_deal_daily。';
    END IF;
    IF to_regclass('mart.mart_dimension_rule') IS NULL THEN
        RAISE EXCEPTION '缺少阶段1对象 mart.mart_dimension_rule。';
    END IF;

    SELECT COUNT(*) INTO v_cnt
    FROM meta.metric_formula_rule
    WHERE mapping_version = 'V1.4';
    IF v_cnt <> 96 THEN
        RAISE EXCEPTION 'V1.4 指标规则数量异常：实际 %，期望 96。', v_cnt;
    END IF;

    SELECT COUNT(*) INTO v_auto
    FROM meta.metric_formula_rule
    WHERE mapping_version = 'V1.4' AND auto_use_allowed = TRUE;
    IF v_auto <> 79 THEN
        RAISE EXCEPTION 'V1.4 auto_use_allowed 数量异常：实际 %，期望 79。', v_auto;
    END IF;

    SELECT COUNT(*) INTO v_bad
    FROM meta.metric_formula_rule
    WHERE mapping_version = 'V1.4' AND rule_status = '待首轮对账确认';
    IF v_bad <> 0 THEN
        RAISE EXCEPTION '仍存在待首轮对账确认规则：% 条。', v_bad;
    END IF;

    SELECT COUNT(*) INTO v_bad
    FROM meta.metric_formula_rule
    WHERE mapping_version = 'V1.4'
      AND target_column_name IN (
          'ad_spend_rate_net_refund_shop_bound',
          'ad_spend_rate_net_refund_shop_promoted',
          'total_expense_rate_net_refund_shop_bound',
          'total_expense_rate_net_refund_shop_promoted'
      )
      AND denominator_expression <> 'settlement_amount';
    IF v_bad <> 0 THEN
        RAISE EXCEPTION '剔除退款费比仍存在非 settlement_amount 分母：% 条。', v_bad;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- B. 通用日期校验
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.assert_period(
    p_start_date date,
    p_end_date date
)
RETURNS void
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION '开始日期和结束日期不能为空。';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION '开始日期 % 不能晚于结束日期 %。', p_start_date, p_end_date;
    END IF;
END;
$$;

COMMENT ON FUNCTION mart.assert_period(date,date) IS
'阶段2内部校验函数：验证时间区间非空且开始日期不晚于结束日期。';

-- ----------------------------------------------------------------------------
-- C. 阶段1 Scope Resolver 的稳定适配层
--    说明：该函数不替代阶段1治理，只提供阶段2固定输入输出；必须与阶段1扫描结论一致。
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.period_scope_rule(p_scope_key text)
RETURNS TABLE(
    scope_key text,
    sale_scope text,
    carrier_type text,
    ad_period text,
    is_total boolean
)
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT *
    FROM (VALUES
        ('全店',       '全部', '全部',   '不限', TRUE),
        ('自营',       '自营', '全部',   '不限', TRUE),
        ('合作',       '合作', '全部',   '不限', TRUE),
        ('商品卡',     '全部', '商品卡', '不限', TRUE),
        ('短视频',     '全部', '短视频', '不限', TRUE),
        ('直播',       '全部', '直播',   '不限', TRUE),
        ('图文',       '全部', '图文',   '不限', TRUE),
        ('其他',       '全部', '其他',   '不限', TRUE),
        ('自营商品卡', '自营', '商品卡', '不限', TRUE),
        ('合作商品卡', '合作', '商品卡', '不限', TRUE),
        ('自营短视频', '自营', '短视频', '不限', TRUE),
        ('合作短视频', '合作', '短视频', '不限', TRUE),
        ('自营直播',   '自营', '直播',   '不限', TRUE),
        ('合作直播',   '合作', '直播',   '不限', TRUE),
        ('自营图文',   '自营', '图文',   '不限', TRUE),
        ('合作图文',   '合作', '图文',   '不限', TRUE),
        ('自营其他',   '自营', '其他',   '不限', TRUE),
        ('合作其他',   '合作', '其他',   '不限', TRUE)
    ) AS v(scope_key, sale_scope, carrier_type, ad_period, is_total)
    WHERE v.scope_key = p_scope_key;
$$;

COMMENT ON FUNCTION mart.period_scope_rule(text) IS
'阶段2 Scope稳定适配层。规则来自阶段0/0.5真实数据验证；平台TOTAL优先，不通过父子明细重建。';

-- ----------------------------------------------------------------------------
-- D. 高频经营总览：任意日期 + 合法 Scope
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_business_period_summary(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_scope_key text
)
RETURNS TABLE(
    shop_name text,
    start_date date,
    end_date date,
    expected_days integer,
    coverage_days integer,
    coverage_complete boolean,
    scope_key text,
    sale_scope text,
    carrier_type text,
    ad_period text,
    source_row_count bigint,
    user_pay_amount numeric,
    net_user_pay_amount_pay_time numeric,
    smart_coupon_amount numeric,
    net_smart_coupon_amount_pay_time numeric,
    platform_subsidy_amount numeric,
    transaction_order_count bigint,
    transaction_buyer_count bigint,
    avg_customer_amount numeric,
    transaction_amount numeric,
    net_transaction_amount numeric,
    refund_amount_refund_time numeric,
    transaction_refund_amount_refund_time numeric,
    refund_order_count_refund_time bigint,
    refund_rate_pay_time numeric,
    refund_amount_pay_time numeric,
    transaction_refund_amount_pay_time numeric,
    refund_order_count_pay_time bigint,
    product_exposure_user_count bigint,
    product_click_user_count bigint,
    exposure_to_click_rate_users numeric,
    click_to_transaction_rate_users numeric,
    exposure_to_transaction_rate_users numeric,
    user_pay_amount_per_1000_exposures numeric,
    product_exposure_count bigint,
    product_click_count bigint,
    exposure_to_click_rate_events numeric,
    click_to_transaction_rate_events numeric,
    exposure_to_transaction_rate_events numeric,
    shipped_user_pay_amount_ship_time numeric,
    ship_within_2_days_rate numeric,
    settlement_amount numeric,
    settlement_amount_refund_time numeric,
    settlement_amount_7d numeric,
    settlement_amount_14d numeric,
    net_creator_subsidy_amount_pay_time numeric,
    creator_subsidy_amount numeric,
    presale_deposit_amount numeric,
    transaction_item_count bigint,
    avg_item_amount numeric,
    net_transaction_order_count bigint,
    pre_shipment_refund_rate_pay_time numeric,
    unreceived_refund_rate_pay_time numeric,
    received_refund_rate_pay_time numeric,
    received_return_refund_rate_pay_time numeric,
    one_hour_transaction_refund_amount_pay_time numeric,
    one_hour_refund_order_count_pay_time bigint,
    one_hour_refund_rate_pay_time numeric,
    net_platform_subsidy_amount_pay_time numeric,
    unrecalculable_metrics text[]
)
LANGUAGE plpgsql
STABLE
AS $$
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
$$;

COMMENT ON FUNCTION mart.get_business_period_summary(text,date,date,text) IS
'高频经营总览区间汇总：全店/自营/合作/商品卡/短视频等合法Scope。比例按V1.4分子分母重算；source_only多日返回NULL。';

-- ----------------------------------------------------------------------------
-- E. Carrier 域：返回每个 account_channel 的区间表现，不负责全店TOTAL
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_carrier_period_summary(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_sale_scope text DEFAULT NULL,
    p_carrier_type text DEFAULT NULL,
    p_account_channel text DEFAULT NULL
)
RETURNS TABLE(
    shop_name text,
    start_date date,
    end_date date,
    sale_scope text,
    carrier_type text,
    account_channel text,
    douyin_account_id text,
    row_semantic text,
    aggregation_allowed boolean,
    coverage_days integer,
    transaction_amount numeric,
    user_pay_amount numeric,
    settlement_amount numeric,
    refund_amount_pay_time numeric,
    refund_rate_pay_time numeric,
    transaction_order_count bigint,
    transaction_item_count bigint,
    transaction_buyer_count bigint,
    avg_item_amount numeric,
    avg_customer_amount numeric,
    product_exposure_count bigint,
    product_click_count bigint,
    exposure_to_click_rate_events numeric,
    click_to_transaction_rate_events numeric,
    exposure_to_transaction_rate_events numeric,
    product_exposure_user_count bigint,
    product_click_user_count bigint,
    exposure_to_click_rate_users numeric,
    click_to_transaction_rate_users numeric,
    exposure_to_transaction_rate_users numeric,
    user_pay_amount_per_1000_exposures numeric,
    ad_attributed_transaction_amount numeric,
    ad_attributed_transaction_share numeric,
    ad_spend_shop_bound numeric,
    ad_spend_shop_promoted numeric,
    platform_commission_settlement numeric,
    creator_commission_settlement numeric,
    ad_spend_rate_shop_bound numeric,
    ad_spend_rate_shop_promoted numeric,
    ad_spend_rate_net_refund_shop_bound numeric,
    ad_spend_rate_net_refund_shop_promoted numeric,
    total_expense_rate_shop_bound numeric,
    total_expense_rate_shop_promoted numeric,
    total_expense_rate_net_refund_shop_bound numeric,
    total_expense_rate_net_refund_shop_promoted numeric,
    one_hour_refund_rate_pay_time numeric,
    unrecalculable_metrics text[]
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);

    RETURN QUERY
    SELECT
        s.shop_name::text,
        p_start_date,
        p_end_date,
        c.sale_scope::text,
        c.carrier_type::text,
        c.account_channel::text,
        c.douyin_account_id::text,
        CASE
            WHEN c.account_channel = '更多账号' THEN 'aggregate_bucket'
            WHEN c.account_channel IN ('全域投放时段','标准+品牌投放') THEN 'special_overlap'
            WHEN c.account_channel = '其他' THEN 'aggregate_bucket'
            ELSE 'detail'
        END::text,
        (c.account_channel NOT IN ('全域投放时段','标准+品牌投放')),
        COUNT(DISTINCT c.biz_date)::integer,
        SUM(c.transaction_amount),
        SUM(c.user_pay_amount),
        SUM(c.settlement_amount),
        SUM(c.refund_amount_pay_time),
        SUM(c.refund_amount_pay_time) / NULLIF(SUM(c.user_pay_amount), 0),
        SUM(c.transaction_order_count)::bigint,
        SUM(c.transaction_item_count)::bigint,
        SUM(c.transaction_buyer_count)::bigint,
        SUM(c.user_pay_amount) / NULLIF(SUM(c.transaction_item_count), 0),
        SUM(c.user_pay_amount) / NULLIF(SUM(c.transaction_buyer_count), 0),
        SUM(c.product_exposure_count)::bigint,
        SUM(c.product_click_count)::bigint,
        SUM(c.product_click_count) / NULLIF(SUM(c.product_exposure_count), 0),
        SUM(c.transaction_order_count) / NULLIF(SUM(c.product_click_count), 0),
        SUM(c.transaction_order_count) / NULLIF(SUM(c.product_exposure_count), 0),
        SUM(c.product_exposure_user_count)::bigint,
        SUM(c.product_click_user_count)::bigint,
        SUM(c.product_click_user_count) / NULLIF(SUM(c.product_exposure_user_count), 0),
        SUM(c.transaction_buyer_count) / NULLIF(SUM(c.product_click_user_count), 0),
        SUM(c.transaction_buyer_count) / NULLIF(SUM(c.product_exposure_user_count), 0),
        SUM(c.user_pay_amount) / NULLIF(SUM(c.product_exposure_count), 0) * 1000,
        SUM(c.ad_attributed_transaction_amount),
        SUM(c.ad_attributed_transaction_amount) / NULLIF(SUM(c.transaction_amount), 0),
        SUM(c.ad_spend_shop_bound),
        SUM(c.ad_spend_shop_promoted),
        SUM(c.platform_commission_settlement),
        SUM(c.creator_commission_settlement),
        SUM(c.ad_spend_shop_bound) / NULLIF(SUM(c.transaction_amount), 0),
        SUM(c.ad_spend_shop_promoted) / NULLIF(SUM(c.transaction_amount), 0),
        SUM(c.ad_spend_shop_bound) / NULLIF(SUM(c.settlement_amount), 0),
        SUM(c.ad_spend_shop_promoted) / NULLIF(SUM(c.settlement_amount), 0),
        (COALESCE(SUM(c.ad_spend_shop_bound),0) + COALESCE(SUM(c.platform_commission_settlement),0) + COALESCE(SUM(c.creator_commission_settlement),0)) / NULLIF(SUM(c.transaction_amount), 0),
        (COALESCE(SUM(c.ad_spend_shop_promoted),0) + COALESCE(SUM(c.platform_commission_settlement),0) + COALESCE(SUM(c.creator_commission_settlement),0)) / NULLIF(SUM(c.transaction_amount), 0),
        (COALESCE(SUM(c.ad_spend_shop_bound),0) + COALESCE(SUM(c.platform_commission_settlement),0) + COALESCE(SUM(c.creator_commission_settlement),0)) / NULLIF(SUM(c.settlement_amount), 0),
        (COALESCE(SUM(c.ad_spend_shop_promoted),0) + COALESCE(SUM(c.platform_commission_settlement),0) + COALESCE(SUM(c.creator_commission_settlement),0)) / NULLIF(SUM(c.settlement_amount), 0),
        CASE WHEN p_start_date = p_end_date THEN MAX(c.one_hour_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[] ELSE ARRAY['1小时退款率(支付时间)']::text[] END
    FROM core.douyin_carrier_daily c
    JOIN meta.shop s ON s.shop_id = c.shop_id
    WHERE c.biz_date BETWEEN p_start_date AND p_end_date
      AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_sale_scope IS NULL OR c.sale_scope = p_sale_scope)
      AND (p_carrier_type IS NULL OR c.carrier_type = p_carrier_type)
      AND (p_account_channel IS NULL OR c.account_channel = p_account_channel)
    GROUP BY s.shop_name, c.sale_scope, c.carrier_type, c.account_channel, c.douyin_account_id;
END;
$$;

COMMENT ON FUNCTION mart.get_carrier_period_summary(text,date,date,text,text,text) IS
'载体/渠道区间拆分。按account_channel逐桶返回，不承担全店TOTAL；special_overlap行明确禁止与明细混SUM。';

-- ----------------------------------------------------------------------------
-- F. Account 域：账号拆分/单账号区间汇总，不负责全店/自营TOTAL
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_account_period_summary(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_sale_scope text DEFAULT NULL,
    p_account_name text DEFAULT NULL
)
RETURNS TABLE(
    shop_name text,
    start_date date,
    end_date date,
    sale_scope text,
    account_name text,
    account_type text,
    douyin_account_id text,
    row_semantic text,
    coverage_days integer,
    transaction_amount numeric,
    user_pay_amount numeric,
    settlement_amount numeric,
    refund_amount_pay_time numeric,
    refund_rate_pay_time numeric,
    transaction_order_count bigint,
    transaction_item_count bigint,
    transaction_buyer_count bigint,
    avg_item_amount numeric,
    avg_customer_amount numeric,
    product_exposure_count bigint,
    product_click_count bigint,
    exposure_to_click_rate_events numeric,
    click_to_transaction_rate_events numeric,
    exposure_to_transaction_rate_events numeric,
    ad_spend_shop_bound numeric,
    ad_spend_shop_promoted numeric,
    ad_spend_rate_net_refund_shop_bound numeric,
    ad_spend_rate_net_refund_shop_promoted numeric,
    total_expense_rate_net_refund_shop_bound numeric,
    total_expense_rate_net_refund_shop_promoted numeric,
    one_hour_refund_rate_pay_time numeric,
    unrecalculable_metrics text[]
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);

    RETURN QUERY
    SELECT
        s.shop_name::text,
        p_start_date,
        p_end_date,
        a.sale_scope::text,
        a.account_name::text,
        a.account_type::text,
        a.douyin_account_id::text,
        CASE WHEN a.account_name = '更多账号' THEN 'aggregate_bucket' ELSE 'detail' END::text,
        COUNT(DISTINCT a.biz_date)::integer,
        SUM(a.transaction_amount),
        SUM(a.user_pay_amount),
        SUM(a.settlement_amount),
        SUM(a.refund_amount_pay_time),
        SUM(a.refund_amount_pay_time) / NULLIF(SUM(a.user_pay_amount), 0),
        SUM(a.transaction_order_count)::bigint,
        SUM(a.transaction_item_count)::bigint,
        SUM(a.transaction_buyer_count)::bigint,
        SUM(a.user_pay_amount) / NULLIF(SUM(a.transaction_item_count), 0),
        SUM(a.user_pay_amount) / NULLIF(SUM(a.transaction_buyer_count), 0),
        SUM(a.product_exposure_count)::bigint,
        SUM(a.product_click_count)::bigint,
        SUM(a.product_click_count) / NULLIF(SUM(a.product_exposure_count), 0),
        SUM(a.transaction_order_count) / NULLIF(SUM(a.product_click_count), 0),
        SUM(a.transaction_order_count) / NULLIF(SUM(a.product_exposure_count), 0),
        SUM(a.ad_spend_shop_bound),
        SUM(a.ad_spend_shop_promoted),
        SUM(a.ad_spend_shop_bound) / NULLIF(SUM(a.settlement_amount), 0),
        SUM(a.ad_spend_shop_promoted) / NULLIF(SUM(a.settlement_amount), 0),
        (COALESCE(SUM(a.ad_spend_shop_bound),0) + COALESCE(SUM(a.platform_commission_settlement),0) + COALESCE(SUM(a.creator_commission_settlement),0)) / NULLIF(SUM(a.settlement_amount), 0),
        (COALESCE(SUM(a.ad_spend_shop_promoted),0) + COALESCE(SUM(a.platform_commission_settlement),0) + COALESCE(SUM(a.creator_commission_settlement),0)) / NULLIF(SUM(a.settlement_amount), 0),
        CASE WHEN p_start_date = p_end_date THEN MAX(a.one_hour_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[] ELSE ARRAY['1小时退款率(支付时间)']::text[] END
    FROM core.douyin_account_daily a
    JOIN meta.shop s ON s.shop_id = a.shop_id
    WHERE a.biz_date BETWEEN p_start_date AND p_end_date
      AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_sale_scope IS NULL OR a.sale_scope = p_sale_scope)
      AND (p_account_name IS NULL OR a.account_name = p_account_name)
    GROUP BY s.shop_name, a.sale_scope, a.account_name, a.account_type, a.douyin_account_id;
END;
$$;

COMMENT ON FUNCTION mart.get_account_period_summary(text,date,date,text,text) IS
'账号区间汇总，仅用于具体账号/合作剩余桶拆分，不用于重建全店或自营TOTAL。';

-- ----------------------------------------------------------------------------
-- G. Content 域：当前样本仅商品卡，但架构保留 carrier_type
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_content_period_summary(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_selling_type text DEFAULT NULL,
    p_carrier_type text DEFAULT NULL,
    p_content_id text DEFAULT NULL
)
RETURNS TABLE(
    shop_name text,
    start_date date,
    end_date date,
    selling_type text,
    carrier_type text,
    content_id text,
    content_title text,
    coverage_days integer,
    transaction_amount numeric,
    user_pay_amount numeric,
    settlement_amount numeric,
    refund_amount_pay_time numeric,
    refund_rate_pay_time numeric,
    transaction_order_count bigint,
    transaction_item_count bigint,
    transaction_buyer_count bigint,
    avg_item_amount numeric,
    avg_customer_amount numeric,
    product_exposure_count bigint,
    product_click_count bigint,
    exposure_to_click_rate_events numeric,
    click_to_transaction_rate_events numeric,
    exposure_to_transaction_rate_events numeric,
    ad_spend_shop_bound numeric,
    ad_spend_shop_promoted numeric,
    ad_spend_rate_net_refund_shop_bound numeric,
    ad_spend_rate_net_refund_shop_promoted numeric,
    one_hour_refund_rate_pay_time numeric,
    unrecalculable_metrics text[]
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);
    RETURN QUERY
    SELECT
        s.shop_name::text,
        p_start_date,
        p_end_date,
        c.selling_type::text,
        c.carrier_type::text,
        c.content_id::text,
        MAX(c.content_title)::text,
        COUNT(DISTINCT c.biz_date)::integer,
        SUM(c.transaction_amount),
        SUM(c.user_pay_amount),
        SUM(c.settlement_amount),
        SUM(c.refund_amount_pay_time),
        SUM(c.refund_amount_pay_time) / NULLIF(SUM(c.user_pay_amount), 0),
        SUM(c.transaction_order_count)::bigint,
        SUM(c.transaction_item_count)::bigint,
        SUM(c.transaction_buyer_count)::bigint,
        SUM(c.user_pay_amount) / NULLIF(SUM(c.transaction_item_count), 0),
        SUM(c.user_pay_amount) / NULLIF(SUM(c.transaction_buyer_count), 0),
        SUM(c.product_exposure_count)::bigint,
        SUM(c.product_click_count)::bigint,
        SUM(c.product_click_count) / NULLIF(SUM(c.product_exposure_count), 0),
        SUM(c.transaction_order_count) / NULLIF(SUM(c.product_click_count), 0),
        SUM(c.transaction_order_count) / NULLIF(SUM(c.product_exposure_count), 0),
        SUM(c.ad_spend_shop_bound),
        SUM(c.ad_spend_shop_promoted),
        SUM(c.ad_spend_shop_bound) / NULLIF(SUM(c.settlement_amount), 0),
        SUM(c.ad_spend_shop_promoted) / NULLIF(SUM(c.settlement_amount), 0),
        CASE WHEN p_start_date = p_end_date THEN MAX(c.one_hour_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[] ELSE ARRAY['1小时退款率(支付时间)']::text[] END
    FROM core.douyin_content_daily c
    JOIN meta.shop s ON s.shop_id = c.shop_id
    WHERE c.biz_date BETWEEN p_start_date AND p_end_date
      AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_selling_type IS NULL OR c.selling_type = p_selling_type)
      AND (p_carrier_type IS NULL OR c.carrier_type = p_carrier_type)
      AND (p_content_id IS NULL OR c.content_id = p_content_id)
    GROUP BY s.shop_name, c.selling_type, c.carrier_type, c.content_id;
END;
$$;

COMMENT ON FUNCTION mart.get_content_period_summary(text,date,date,text,text,text) IS
'内容区间拆分；当前真实样本仅验证商品卡载体，不伪造短视频/直播内容数据。';

-- ----------------------------------------------------------------------------
-- H. Terminal 域
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_terminal_period_summary(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_terminal_type text DEFAULT NULL,
    p_selling_type text DEFAULT NULL
)
RETURNS TABLE(
    shop_name text,
    start_date date,
    end_date date,
    terminal_type text,
    selling_type text,
    is_total_row boolean,
    coverage_days integer,
    transaction_amount numeric,
    user_pay_amount numeric,
    settlement_amount numeric,
    transaction_order_count bigint,
    refund_amount_pay_time numeric,
    refund_rate_pay_time numeric,
    transaction_item_count bigint,
    avg_item_amount numeric,
    product_exposure_count bigint,
    product_click_count bigint,
    exposure_to_click_rate_events numeric,
    click_to_transaction_rate_events numeric,
    exposure_to_transaction_rate_events numeric,
    user_pay_amount_per_1000_exposures numeric,
    one_hour_refund_rate_pay_time numeric,
    unrecalculable_metrics text[]
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);
    RETURN QUERY
    SELECT
        s.shop_name::text,
        p_start_date,
        p_end_date,
        t.terminal_type::text,
        t.selling_type::text,
        (t.terminal_type = '整体'),
        COUNT(DISTINCT t.biz_date)::integer,
        SUM(t.transaction_amount),
        SUM(t.user_pay_amount),
        SUM(t.settlement_amount),
        SUM(t.transaction_order_count)::bigint,
        SUM(t.refund_amount_pay_time),
        SUM(t.refund_amount_pay_time) / NULLIF(SUM(t.user_pay_amount), 0),
        SUM(t.transaction_item_count)::bigint,
        SUM(t.user_pay_amount) / NULLIF(SUM(t.transaction_item_count), 0),
        SUM(t.product_exposure_count)::bigint,
        SUM(t.product_click_count)::bigint,
        SUM(t.product_click_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_click_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.product_exposure_count), 0) * 1000,
        CASE WHEN p_start_date = p_end_date THEN MAX(t.one_hour_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[] ELSE ARRAY['1小时退款率(支付时间)']::text[] END
    FROM core.douyin_terminal_daily t
    JOIN meta.shop s ON s.shop_id = t.shop_id
    WHERE t.biz_date BETWEEN p_start_date AND p_end_date
      AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_terminal_type IS NULL OR t.terminal_type = p_terminal_type)
      AND (p_selling_type IS NULL OR t.selling_type = p_selling_type)
    GROUP BY s.shop_name, t.terminal_type, t.selling_type;
END;
$$;

COMMENT ON FUNCTION mart.get_terminal_period_summary(text,date,date,text,text) IS
'终端区间汇总；terminal_type=整体为合法TOTAL，调用方不得将整体与明细终端再相加。';

-- ----------------------------------------------------------------------------
-- I. Category 域：按 category_level 隔离父子层级
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_category_period_summary(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_category_level integer DEFAULT 3,
    p_category_l1 text DEFAULT NULL,
    p_category_l2 text DEFAULT NULL,
    p_category_l3 text DEFAULT NULL
)
RETURNS TABLE(
    shop_name text,
    start_date date,
    end_date date,
    category_level integer,
    category_l1 text,
    category_l2 text,
    category_l3 text,
    category_l4 text,
    is_total_row boolean,
    coverage_days integer,
    user_pay_amount numeric,
    refund_amount_pay_time numeric,
    refund_rate_pay_time numeric,
    avg_transaction_order_amount numeric,
    click_to_transaction_rate_events numeric,
    unrecalculable_metrics text[]
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);
    IF p_category_level NOT IN (1,2,3,4) THEN
        RAISE EXCEPTION 'p_category_level 仅允许 1/2/3/4。';
    END IF;

    RETURN QUERY
    WITH x AS (
        SELECT
            c.*,
            CASE
                WHEN c.category_level_2 = '全部' THEN 1
                WHEN c.category_level_3 = '全部' THEN 2
                WHEN c.category_level_4 = '全部' OR c.category_level_4 = '' THEN 3
                ELSE 4
            END AS calc_level
        FROM core.douyin_category_daily c
    )
    SELECT
        s.shop_name::text,
        p_start_date,
        p_end_date,
        x.calc_level::integer,
        x.category_level_1::text,
        x.category_level_2::text,
        x.category_level_3::text,
        x.category_level_4::text,
        (x.calc_level < 4),
        COUNT(DISTINCT x.biz_date)::integer,
        SUM(x.user_pay_amount),
        SUM(x.refund_amount_pay_time),
        SUM(x.refund_amount_pay_time) / NULLIF(SUM(x.user_pay_amount), 0),
        CASE WHEN p_start_date = p_end_date THEN MAX(x.avg_transaction_order_amount) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN MAX(x.click_to_transaction_rate_events) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[] ELSE ARRAY['成交笔单价','商品点击-成交转化率(次数)']::text[] END
    FROM x
    JOIN meta.shop s ON s.shop_id = x.shop_id
    WHERE x.biz_date BETWEEN p_start_date AND p_end_date
      AND x.calc_level = p_category_level
      AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_category_l1 IS NULL OR x.category_level_1 = p_category_l1)
      AND (p_category_l2 IS NULL OR x.category_level_2 = p_category_l2)
      AND (p_category_l3 IS NULL OR x.category_level_3 = p_category_l3)
    GROUP BY s.shop_name, x.calc_level, x.category_level_1, x.category_level_2, x.category_level_3, x.category_level_4;
END;
$$;

COMMENT ON FUNCTION mart.get_category_period_summary(text,date,date,integer,text,text,text) IS
'类目区间汇总，强制按category_level隔离父子层级，禁止不同层级混SUM。成交笔单价/次数转化率缺基础字段，多日返回NULL。';

-- ----------------------------------------------------------------------------
-- J. Product 域：默认 carrier_type=全部，使用平台独立 TOTAL
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_product_period_summary(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_product_id text DEFAULT NULL,
    p_product_name text DEFAULT NULL,
    p_carrier_type text DEFAULT '全部'
)
RETURNS TABLE(
    shop_name text,
    start_date date,
    end_date date,
    product_id text,
    product_name text,
    carrier_type text,
    is_platform_total boolean,
    coverage_days integer,
    user_pay_amount numeric,
    refund_amount_pay_time numeric,
    refund_rate_pay_time numeric,
    smart_coupon_amount numeric,
    platform_subsidy_amount numeric,
    net_smart_coupon_amount_pay_time numeric,
    net_platform_subsidy_amount_pay_time numeric,
    avg_transaction_order_amount numeric,
    click_to_transaction_rate_events numeric,
    unrecalculable_metrics text[]
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);

    IF p_product_id IS NOT NULL AND p_product_name IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1
            FROM core.douyin_product_daily p
            JOIN meta.shop s ON s.shop_id = p.shop_id
            WHERE (p_shop_name IS NULL OR s.shop_name = p_shop_name)
              AND p.product_id = p_product_id
              AND p.product_name = p_product_name
        ) THEN
            RAISE EXCEPTION 'product_id=% 与 product_name=% 未指向同一商品。', p_product_id, p_product_name;
        END IF;
    END IF;

    RETURN QUERY
    SELECT
        s.shop_name::text,
        p_start_date,
        p_end_date,
        p.product_id::text,
        MAX(p.product_name)::text,
        p.carrier_type::text,
        (p.carrier_type = '全部'),
        COUNT(DISTINCT p.biz_date)::integer,
        SUM(p.user_pay_amount),
        SUM(p.refund_amount_pay_time),
        SUM(p.refund_amount_pay_time) / NULLIF(SUM(p.user_pay_amount), 0),
        SUM(p.smart_coupon_amount),
        SUM(p.platform_subsidy_amount),
        SUM(p.net_smart_coupon_amount_pay_time),
        SUM(p.net_platform_subsidy_amount_pay_time),
        CASE WHEN p_start_date = p_end_date THEN MAX(p.avg_transaction_order_amount) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN MAX(p.click_to_transaction_rate_events) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[] ELSE ARRAY['成交笔单价','商品点击-成交转化率(次数)']::text[] END
    FROM core.douyin_product_daily p
    JOIN meta.shop s ON s.shop_id = p.shop_id
    WHERE p.biz_date BETWEEN p_start_date AND p_end_date
      AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_product_id IS NULL OR p.product_id = p_product_id)
      AND (p_product_name IS NULL OR p.product_name = p_product_name)
      AND (p_carrier_type IS NULL OR p.carrier_type = p_carrier_type)
    GROUP BY s.shop_name, p.product_id, p.carrier_type;
END;
$$;

COMMENT ON FUNCTION mart.get_product_period_summary(text,date,date,text,text,text) IS
'商品区间汇总。默认carrier_type=全部，直接使用平台独立TOTAL；禁止用商品卡/图文/直播/短视频明细重建全部。';

-- ----------------------------------------------------------------------------
-- K. Price Band 域：6个价格带互斥，可安全求和
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_price_band_period_summary(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_price_band text DEFAULT NULL
)
RETURNS TABLE(
    shop_name text,
    start_date date,
    end_date date,
    price_band text,
    coverage_days integer,
    user_pay_amount numeric,
    avg_transaction_order_amount numeric,
    click_to_transaction_rate_events numeric,
    can_sum_to_store_total boolean,
    unrecalculable_metrics text[]
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);
    RETURN QUERY
    SELECT
        s.shop_name::text,
        p_start_date,
        p_end_date,
        p.price_band::text,
        COUNT(DISTINCT p.biz_date)::integer,
        SUM(p.user_pay_amount),
        CASE WHEN p_start_date = p_end_date THEN MAX(p.avg_transaction_order_amount) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN MAX(p.click_to_transaction_rate_events) ELSE NULL END,
        TRUE,
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[] ELSE ARRAY['成交笔单价','商品点击-成交转化率(次数)']::text[] END
    FROM core.douyin_price_band_daily p
    JOIN meta.shop s ON s.shop_id = p.shop_id
    WHERE p.biz_date BETWEEN p_start_date AND p_end_date
      AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_price_band IS NULL OR p.price_band = p_price_band)
    GROUP BY s.shop_name, p.price_band;
END;
$$;

COMMENT ON FUNCTION mart.get_price_band_period_summary(text,date,date,text) IS
'价格带区间汇总。6个价格带经阶段0.5验证为互斥分桶，可安全SUM重建店铺用户支付金额。';

-- ----------------------------------------------------------------------------
-- L. Audience 域：默认 carrier_type=全部 合法TOTAL
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_audience_period_summary(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_audience_type text DEFAULT NULL,
    p_carrier_type text DEFAULT '全部'
)
RETURNS TABLE(
    shop_name text,
    start_date date,
    end_date date,
    audience_type text,
    carrier_type text,
    is_total_row boolean,
    coverage_days integer,
    user_pay_amount numeric,
    transaction_buyer_count bigint,
    avg_customer_amount numeric,
    transaction_order_count bigint,
    repeat_user_repeat_rate numeric,
    unrecalculable_metrics text[]
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    PERFORM mart.assert_period(p_start_date, p_end_date);
    RETURN QUERY
    SELECT
        s.shop_name::text,
        p_start_date,
        p_end_date,
        a.audience_type::text,
        a.carrier_type::text,
        (a.carrier_type = '全部'),
        COUNT(DISTINCT a.biz_date)::integer,
        SUM(a.user_pay_amount),
        SUM(a.transaction_buyer_count)::bigint,
        SUM(a.user_pay_amount) / NULLIF(SUM(a.transaction_buyer_count), 0),
        SUM(a.transaction_order_count)::bigint,
        CASE WHEN p_start_date = p_end_date THEN MAX(a.repeat_user_repeat_rate) ELSE NULL END,
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[] ELSE ARRAY['复购用户复购率']::text[] END
    FROM core.douyin_audience_daily a
    JOIN meta.shop s ON s.shop_id = a.shop_id
    WHERE a.biz_date BETWEEN p_start_date AND p_end_date
      AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_audience_type IS NULL OR a.audience_type = p_audience_type)
      AND (p_carrier_type IS NULL OR a.carrier_type = p_carrier_type)
    GROUP BY s.shop_name, a.audience_type, a.carrier_type;
END;
$$;

COMMENT ON FUNCTION mart.get_audience_period_summary(text,date,date,text,text) IS
'人群区间汇总。默认carrier_type=全部（阶段0.5已验证60/60匹配合法TOTAL）；复购用户复购率缺基础字段，多日返回NULL。';

-- ----------------------------------------------------------------------------
-- M. 辅助：V1.4规则只读目录，供后续MCP/验收查看
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW mart.metric_rule_v14 AS
SELECT
    target_schema,
    target_table,
    target_column_name_cn,
    target_column_name,
    metric_category,
    calculation_mode,
    formula_cn,
    numerator_expression,
    denominator_expression,
    multiplier,
    period_formula_sql,
    cross_period_recalculable,
    auto_use_allowed,
    rule_status,
    display_format,
    mapping_version,
    verification_method,
    verification_period,
    verification_result
FROM meta.metric_formula_rule
WHERE mapping_version = 'V1.4';

COMMENT ON VIEW mart.metric_rule_v14 IS
'V1.4非可加指标规则只读目录。阶段2函数公式必须与此目录保持一致。';

COMMIT;

-- ============================================================================
-- N. 验收查询（只读；可单独执行）
-- ============================================================================

-- N1. 核心数据不应被修改；当前单店6月基线应为18809行。
SELECT
    (SELECT COUNT(*) FROM core.douyin_deal_daily) +
    (SELECT COUNT(*) FROM core.douyin_carrier_daily) +
    (SELECT COUNT(*) FROM core.douyin_account_daily) +
    (SELECT COUNT(*) FROM core.douyin_content_daily) +
    (SELECT COUNT(*) FROM core.douyin_terminal_daily) +
    (SELECT COUNT(*) FROM core.douyin_category_daily) +
    (SELECT COUNT(*) FROM core.douyin_product_daily) +
    (SELECT COUNT(*) FROM core.douyin_price_band_daily) +
    (SELECT COUNT(*) FROM core.douyin_audience_daily) AS core_total_rows;

-- N2. 高频Scope 30天汇总。
SELECT scope_key, user_pay_amount, transaction_amount, refund_rate_pay_time, coverage_days, coverage_complete
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

SELECT scope_key, user_pay_amount, transaction_amount, refund_rate_pay_time
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','商品卡');

SELECT scope_key, user_pay_amount, transaction_amount, refund_rate_pay_time
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','合作短视频');

-- N3. 证明退款率不是 AVG(日退款率)。
WITH daily AS (
    SELECT refund_rate_pay_time, refund_amount_pay_time, user_pay_amount
    FROM core.douyin_deal_daily d
    JOIN meta.shop s ON s.shop_id=d.shop_id
    WHERE s.shop_name='弹动官方旗舰店'
      AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30'
      AND d.sale_scope='全部' AND d.carrier_type='全部' AND d.ad_period='不限'
)
SELECT
    SUM(refund_amount_pay_time)/NULLIF(SUM(user_pay_amount),0) AS weighted_correct,
    AVG(refund_rate_pay_time) AS avg_daily_wrong,
    SUM(refund_amount_pay_time)/NULLIF(SUM(user_pay_amount),0) - AVG(refund_rate_pay_time) AS difference
FROM daily;

-- N4. source_only 单日有值，多日应为NULL。
SELECT start_date,end_date,ship_within_2_days_rate,one_hour_refund_rate_pay_time,unrecalculable_metrics
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-01','全店');

SELECT start_date,end_date,ship_within_2_days_rate,one_hour_refund_rate_pay_time,unrecalculable_metrics
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');

-- N5. 商品默认使用 carrier=全部 独立TOTAL。
SELECT product_id,product_name,carrier_type,user_pay_amount,refund_rate_pay_time
FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',NULL,NULL,'全部')
ORDER BY user_pay_amount DESC NULLS LAST
LIMIT 20;

-- N6. 类目只取同一层级，禁止混层。
SELECT category_level,category_l1,category_l2,category_l3,user_pay_amount
FROM mart.get_category_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',3,NULL,NULL,NULL)
ORDER BY user_pay_amount DESC NULLS LAST;

-- N7. 价格带可安全求和，与全店TOTAL用户支付金额核对。
WITH pb AS (
    SELECT SUM(user_pay_amount) AS v
    FROM mart.get_price_band_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',NULL)
), st AS (
    SELECT user_pay_amount AS v
    FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店')
)
SELECT pb.v AS price_band_sum, st.v AS store_total, pb.v-st.v AS diff
FROM pb CROSS JOIN st;

-- N8. 人群默认carrier=全部；不把TOTAL和明细一起SUM。
SELECT audience_type,carrier_type,user_pay_amount,avg_customer_amount,repeat_user_repeat_rate
FROM mart.get_audience_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',NULL,'全部');
