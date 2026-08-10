-- ============================================================
-- mart V1.0 阶段2 | 业务域 Period Function (Part1)
-- carrier / account / content / terminal
-- 指标表达式逐条对应 V1.4 meta.metric_formula_rule
-- ============================================================

-- ############################################################
-- 1. get_carrier_period_summary: 载体/渠道拆分
-- 规则: 不提供全店TOTAL; special_overlap(全域投放时段/标准+品牌投放)
--       不得与其明细同时SUM; 合作域(具体账号+更多账号)互斥可SUM
-- ############################################################
CREATE OR REPLACE FUNCTION mart.get_carrier_period_summary(
    p_shop_name       text DEFAULT NULL,
    p_start_date      date DEFAULT NULL,
    p_end_date        date DEFAULT NULL,
    p_sale_scope      text DEFAULT NULL,
    p_carrier_type    text DEFAULT NULL,
    p_account_channel text DEFAULT NULL
) RETURNS TABLE(
    shop_name character varying,
    start_date date,
    end_date date,
    day_count integer,
    sale_scope character varying,
    carrier_type character varying,
    account_channel character varying,
    -- SUM
    transaction_amount numeric, user_pay_amount numeric, settlement_amount numeric,
    transaction_refund_amount_pay_time numeric, refund_amount_pay_time numeric,
    ad_attributed_transaction_amount numeric,
    transaction_order_count numeric, transaction_item_count numeric, transaction_buyer_count numeric,
    net_transaction_amount numeric,
    ad_spend_shop_promoted numeric, ad_spend_shop_bound numeric,
    platform_commission_settlement numeric, creator_commission_settlement numeric,
    -- ratio (V1.4)
    refund_rate_pay_time numeric,               -- 17
    ad_attributed_transaction_share numeric,    -- 18
    ad_spend_rate_net_refund_shop_promoted numeric, -- 19 分母=settlement_amount
    exposure_to_click_rate_users numeric,       -- 20
    click_to_transaction_rate_users numeric,    -- 21
    avg_item_amount numeric,                    -- 22
    avg_customer_amount numeric,                -- 23
    ad_attributed_refund_rate_pay_time numeric, -- 25
    exposure_to_click_rate_events numeric,      -- 26
    click_to_transaction_rate_events numeric,   -- 27
    exposure_to_transaction_rate_events numeric,-- 28
    exposure_to_transaction_rate_users numeric, -- 29
    user_pay_amount_per_1000_exposures numeric, -- 30
    ad_spend_rate_shop_bound numeric,           -- 31
    ad_spend_rate_shop_promoted numeric,        -- 32
    ad_spend_rate_net_refund_shop_bound numeric,-- 33 分母=settlement_amount
    total_expense_rate_shop_bound numeric,      -- 34 ratio_expr
    total_expense_rate_shop_promoted numeric,   -- 35 ratio_expr
    total_expense_rate_net_refund_shop_bound numeric, -- 36 ratio_expr 分母=settlement_amount
    total_expense_rate_net_refund_shop_promoted numeric, -- 37 ratio_expr 分母=settlement_amount
    -- source_only
    one_hour_refund_rate_pay_time numeric,      -- 24 待平台口径确认
    source_only_note text
) AS $$
DECLARE v_single_day boolean;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION '参数错误: p_start_date 和 p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION '参数错误: p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    v_single_day := (p_start_date = p_end_date);

    RETURN QUERY
    SELECT
        s.shop_name, p_start_date, p_end_date,
        (p_end_date - p_start_date + 1)::int,
        t.sale_scope::varchar, t.carrier_type::varchar, t.account_channel::varchar,
        SUM(t.transaction_amount), SUM(t.user_pay_amount), SUM(t.settlement_amount),
        SUM(t.transaction_refund_amount_pay_time), SUM(t.refund_amount_pay_time),
        SUM(t.ad_attributed_transaction_amount),
        SUM(t.transaction_order_count), SUM(t.transaction_item_count), SUM(t.transaction_buyer_count),
        SUM(t.net_transaction_amount),
        SUM(t.ad_spend_shop_promoted), SUM(t.ad_spend_shop_bound),
        SUM(t.platform_commission_settlement), SUM(t.creator_commission_settlement),
        SUM(t.refund_amount_pay_time) / NULLIF(SUM(t.user_pay_amount), 0),
        SUM(t.ad_attributed_transaction_amount) / NULLIF(SUM(t.transaction_amount), 0),
        SUM(t.ad_spend_shop_promoted) / NULLIF(SUM(t.settlement_amount), 0),
        SUM(t.product_click_user_count) / NULLIF(SUM(t.product_exposure_user_count), 0),
        SUM(t.transaction_buyer_count) / NULLIF(SUM(t.product_click_user_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.transaction_item_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.transaction_buyer_count), 0),
        SUM(t.ad_attributed_transaction_refund_amount_pay_time) / NULLIF(SUM(t.ad_attributed_transaction_amount), 0),
        SUM(t.product_click_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_click_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.transaction_buyer_count) / NULLIF(SUM(t.product_exposure_user_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.product_exposure_count), 0) * 1000,
        SUM(t.ad_spend_shop_bound) / NULLIF(SUM(t.transaction_amount), 0),
        SUM(t.ad_spend_shop_promoted) / NULLIF(SUM(t.transaction_amount), 0),
        SUM(t.ad_spend_shop_bound) / NULLIF(SUM(t.settlement_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_bound),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.transaction_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_promoted),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.transaction_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_bound),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.settlement_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_promoted),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.settlement_amount), 0),
        CASE WHEN v_single_day THEN MAX(t.one_hour_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN v_single_day THEN '单日: source_only返回当天源值'
             ELSE '多日: one_hour_refund_rate(待平台口径确认)不可跨期重算, 返回NULL' END
    FROM core.douyin_carrier_daily t
    JOIN meta.shop s ON t.shop_id = s.shop_id
    WHERE (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_sale_scope IS NULL OR t.sale_scope = p_sale_scope)
      AND (p_carrier_type IS NULL OR t.carrier_type = p_carrier_type)
      AND (p_account_channel IS NULL OR t.account_channel = p_account_channel)
      AND t.biz_date BETWEEN p_start_date AND p_end_date
    GROUP BY s.shop_name, t.sale_scope, t.carrier_type, t.account_channel;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mart.get_carrier_period_summary(text,date,date,text,text,text) IS
'载体/渠道动态区间汇总(拆分/排名用, 不提供全店TOTAL)。special_overlap行(全域投放时段/标准+品牌投放)禁止与其明细同时SUM; 合作域 具体账号+更多账号 互斥可SUM。';

-- ############################################################
-- 2. get_account_period_summary: 账号拆分
-- 规则: 弹动官方旗舰店=具体账号非TOTAL; 更多账号=合作聚合桶;
--       不回答全店/自营总成交(回get_business_period_summary)
-- ############################################################
CREATE OR REPLACE FUNCTION mart.get_account_period_summary(
    p_shop_name   text DEFAULT NULL,
    p_start_date  date DEFAULT NULL,
    p_end_date    date DEFAULT NULL,
    p_sale_scope  text DEFAULT NULL,
    p_account_name text DEFAULT NULL
) RETURNS TABLE(
    shop_name character varying,
    start_date date,
    end_date date,
    day_count integer,
    sale_scope character varying,
    account_name character varying,
    account_type character varying,
    -- SUM
    transaction_amount numeric, user_pay_amount numeric, settlement_amount numeric,
    transaction_refund_amount_pay_time numeric, refund_amount_pay_time numeric,
    ad_attributed_transaction_amount numeric,
    transaction_order_count numeric, transaction_item_count numeric, transaction_buyer_count numeric,
    net_transaction_amount numeric,
    ad_spend_shop_promoted numeric, ad_spend_shop_bound numeric,
    platform_commission_settlement numeric, creator_commission_settlement numeric,
    -- ratio (V1.4)
    refund_rate_pay_time numeric,               -- 38
    ad_attributed_transaction_share numeric,    -- 39
    ad_spend_rate_net_refund_shop_promoted numeric, -- 40 分母=settlement_amount
    exposure_to_click_rate_users numeric,       -- 41
    click_to_transaction_rate_users numeric,    -- 42
    avg_item_amount numeric,                    -- 43
    avg_customer_amount numeric,                -- 44
    ad_attributed_refund_rate_pay_time numeric, -- 46
    exposure_to_click_rate_events numeric,      -- 47
    click_to_transaction_rate_events numeric,   -- 48
    exposure_to_transaction_rate_events numeric,-- 49
    exposure_to_transaction_rate_users numeric, -- 50
    user_pay_amount_per_1000_exposures numeric, -- 51
    ad_spend_rate_shop_bound numeric,           -- 52
    ad_spend_rate_shop_promoted numeric,        -- 53
    ad_spend_rate_net_refund_shop_bound numeric,-- 54 分母=settlement_amount
    total_expense_rate_shop_bound numeric,      -- 55 ratio_expr
    total_expense_rate_shop_promoted numeric,   -- 56 ratio_expr
    total_expense_rate_net_refund_shop_bound numeric, -- 57 ratio_expr 分母=settlement_amount
    total_expense_rate_net_refund_shop_promoted numeric, -- 58 ratio_expr 分母=settlement_amount
    -- source_only
    one_hour_refund_rate_pay_time numeric,      -- 45 待平台口径确认
    source_only_note text
) AS $$
DECLARE v_single_day boolean;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION '参数错误: p_start_date 和 p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION '参数错误: p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    v_single_day := (p_start_date = p_end_date);

    RETURN QUERY
    SELECT
        s.shop_name, p_start_date, p_end_date,
        (p_end_date - p_start_date + 1)::int,
        t.sale_scope::varchar, t.account_name::varchar, t.account_type::varchar,
        SUM(t.transaction_amount), SUM(t.user_pay_amount), SUM(t.settlement_amount),
        SUM(t.transaction_refund_amount_pay_time), SUM(t.refund_amount_pay_time),
        SUM(t.ad_attributed_transaction_amount),
        SUM(t.transaction_order_count), SUM(t.transaction_item_count), SUM(t.transaction_buyer_count),
        SUM(t.net_transaction_amount),
        SUM(t.ad_spend_shop_promoted), SUM(t.ad_spend_shop_bound),
        SUM(t.platform_commission_settlement), SUM(t.creator_commission_settlement),
        SUM(t.refund_amount_pay_time) / NULLIF(SUM(t.user_pay_amount), 0),
        SUM(t.ad_attributed_transaction_amount) / NULLIF(SUM(t.transaction_amount), 0),
        SUM(t.ad_spend_shop_promoted) / NULLIF(SUM(t.settlement_amount), 0),
        SUM(t.product_click_user_count) / NULLIF(SUM(t.product_exposure_user_count), 0),
        SUM(t.transaction_buyer_count) / NULLIF(SUM(t.product_click_user_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.transaction_item_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.transaction_buyer_count), 0),
        SUM(t.ad_attributed_transaction_refund_amount_pay_time) / NULLIF(SUM(t.ad_attributed_transaction_amount), 0),
        SUM(t.product_click_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_click_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.transaction_buyer_count) / NULLIF(SUM(t.product_exposure_user_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.product_exposure_count), 0) * 1000,
        SUM(t.ad_spend_shop_bound) / NULLIF(SUM(t.transaction_amount), 0),
        SUM(t.ad_spend_shop_promoted) / NULLIF(SUM(t.transaction_amount), 0),
        SUM(t.ad_spend_shop_bound) / NULLIF(SUM(t.settlement_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_bound),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.transaction_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_promoted),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.transaction_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_bound),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.settlement_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_promoted),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.settlement_amount), 0),
        CASE WHEN v_single_day THEN MAX(t.one_hour_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN v_single_day THEN '单日: source_only返回当天源值'
             ELSE '多日: one_hour_refund_rate(待平台口径确认)不可跨期重算, 返回NULL' END
    FROM core.douyin_account_daily t
    JOIN meta.shop s ON t.shop_id = s.shop_id
    WHERE (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_sale_scope IS NULL OR t.sale_scope = p_sale_scope)
      AND (p_account_name IS NULL OR t.account_name = p_account_name)
      AND t.biz_date BETWEEN p_start_date AND p_end_date
    GROUP BY s.shop_name, t.sale_scope, t.account_name, t.account_type;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mart.get_account_period_summary(text,date,date,text,text) IS
'账号动态区间汇总(单账号/账号拆分/TOP账号)。弹动官方旗舰店=具体账号; 更多账号=合作聚合桶; 不回答全店/自营总成交。';

-- ############################################################
-- 3. get_content_period_summary: 内容(当前仅商品卡载体)
-- ############################################################
CREATE OR REPLACE FUNCTION mart.get_content_period_summary(
    p_shop_name    text DEFAULT NULL,
    p_start_date   date DEFAULT NULL,
    p_end_date     date DEFAULT NULL,
    p_selling_type text DEFAULT NULL,
    p_carrier_type text DEFAULT NULL,
    p_content_id   text DEFAULT NULL
) RETURNS TABLE(
    shop_name character varying,
    start_date date,
    end_date date,
    day_count integer,
    selling_type character varying,
    carrier_type character varying,
    content_id character varying,
    content_title text,
    -- SUM
    transaction_amount numeric, user_pay_amount numeric, settlement_amount numeric,
    transaction_refund_amount_pay_time numeric, refund_amount_pay_time numeric,
    ad_attributed_transaction_amount numeric,
    transaction_order_count numeric, transaction_item_count numeric, transaction_buyer_count numeric,
    net_transaction_amount numeric,
    ad_spend_shop_promoted numeric, ad_spend_shop_bound numeric,
    platform_commission_settlement numeric, creator_commission_settlement numeric,
    -- ratio (V1.4)
    refund_rate_pay_time numeric,               -- 59
    ad_attributed_transaction_share numeric,    -- 60
    ad_spend_rate_net_refund_shop_promoted numeric, -- 61 分母=settlement_amount
    exposure_to_click_rate_users numeric,       -- 62
    click_to_transaction_rate_users numeric,    -- 63
    avg_item_amount numeric,                    -- 64
    avg_customer_amount numeric,                -- 65
    ad_attributed_refund_rate_pay_time numeric, -- 67
    exposure_to_click_rate_events numeric,      -- 68
    click_to_transaction_rate_events numeric,   -- 69
    exposure_to_transaction_rate_events numeric,-- 70
    exposure_to_transaction_rate_users numeric, -- 71
    user_pay_amount_per_1000_exposures numeric, -- 72
    ad_spend_rate_shop_bound numeric,           -- 73
    ad_spend_rate_shop_promoted numeric,        -- 74
    ad_spend_rate_net_refund_shop_bound numeric,-- 75 分母=settlement_amount
    total_expense_rate_shop_bound numeric,      -- 76 ratio_expr
    total_expense_rate_shop_promoted numeric,   -- 77 ratio_expr
    total_expense_rate_net_refund_shop_bound numeric, -- 78 ratio_expr 分母=settlement_amount
    total_expense_rate_net_refund_shop_promoted numeric, -- 79 ratio_expr 分母=settlement_amount
    -- source_only
    one_hour_refund_rate_pay_time numeric,      -- 66 待平台口径确认
    source_only_note text
) AS $$
DECLARE v_single_day boolean;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION '参数错误: p_start_date 和 p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION '参数错误: p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    v_single_day := (p_start_date = p_end_date);

    RETURN QUERY
    SELECT
        s.shop_name, p_start_date, p_end_date,
        (p_end_date - p_start_date + 1)::int,
        t.selling_type::varchar, t.carrier_type::varchar, t.content_id::varchar, t.content_title,
        SUM(t.transaction_amount), SUM(t.user_pay_amount), SUM(t.settlement_amount),
        SUM(t.transaction_refund_amount_pay_time), SUM(t.refund_amount_pay_time),
        SUM(t.ad_attributed_transaction_amount),
        SUM(t.transaction_order_count), SUM(t.transaction_item_count), SUM(t.transaction_buyer_count),
        SUM(t.net_transaction_amount),
        SUM(t.ad_spend_shop_promoted), SUM(t.ad_spend_shop_bound),
        SUM(t.platform_commission_settlement), SUM(t.creator_commission_settlement),
        SUM(t.refund_amount_pay_time) / NULLIF(SUM(t.user_pay_amount), 0),
        SUM(t.ad_attributed_transaction_amount) / NULLIF(SUM(t.transaction_amount), 0),
        SUM(t.ad_spend_shop_promoted) / NULLIF(SUM(t.settlement_amount), 0),
        SUM(t.product_click_user_count) / NULLIF(SUM(t.product_exposure_user_count), 0),
        SUM(t.transaction_buyer_count) / NULLIF(SUM(t.product_click_user_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.transaction_item_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.transaction_buyer_count), 0),
        SUM(t.ad_attributed_transaction_refund_amount_pay_time) / NULLIF(SUM(t.ad_attributed_transaction_amount), 0),
        SUM(t.product_click_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_click_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.transaction_buyer_count) / NULLIF(SUM(t.product_exposure_user_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.product_exposure_count), 0) * 1000,
        SUM(t.ad_spend_shop_bound) / NULLIF(SUM(t.transaction_amount), 0),
        SUM(t.ad_spend_shop_promoted) / NULLIF(SUM(t.transaction_amount), 0),
        SUM(t.ad_spend_shop_bound) / NULLIF(SUM(t.settlement_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_bound),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.transaction_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_promoted),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.transaction_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_bound),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.settlement_amount), 0),
        (COALESCE(SUM(t.ad_spend_shop_promoted),0) + COALESCE(SUM(t.platform_commission_settlement),0) + COALESCE(SUM(t.creator_commission_settlement),0)) / NULLIF(SUM(t.settlement_amount), 0),
        CASE WHEN v_single_day THEN MAX(t.one_hour_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN v_single_day THEN '单日: source_only返回当天源值'
             ELSE '多日: one_hour_refund_rate(待平台口径确认)不可跨期重算, 返回NULL' END
    FROM core.douyin_content_daily t
    JOIN meta.shop s ON t.shop_id = s.shop_id
    WHERE (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_selling_type IS NULL OR t.selling_type = p_selling_type)
      AND (p_carrier_type IS NULL OR t.carrier_type = p_carrier_type)
      AND (p_content_id IS NULL OR t.content_id = p_content_id)
      AND t.biz_date BETWEEN p_start_date AND p_end_date
    GROUP BY s.shop_name, t.selling_type, t.carrier_type, t.content_id, t.content_title;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mart.get_content_period_summary(text,date,date,text,text,text) IS
'内容动态区间汇总(当前真实数据仅商品卡载体; 不伪造短视频/直播内容)。';

-- ############################################################
-- 4. get_terminal_period_summary: 终端拆分
-- 规则: terminal_type=整体 为合法TOTAL; 拆分只取具体终端;
--       禁止 整体+明细 同时SUM
-- ############################################################
CREATE OR REPLACE FUNCTION mart.get_terminal_period_summary(
    p_shop_name    text DEFAULT NULL,
    p_start_date   date DEFAULT NULL,
    p_end_date     date DEFAULT NULL,
    p_terminal_type text DEFAULT NULL,
    p_selling_type text DEFAULT NULL
) RETURNS TABLE(
    shop_name character varying,
    start_date date,
    end_date date,
    day_count integer,
    terminal_type character varying,
    selling_type character varying,
    -- SUM
    transaction_amount numeric, user_pay_amount numeric, settlement_amount numeric,
    transaction_order_count numeric, transaction_refund_amount_pay_time numeric,
    refund_amount_pay_time numeric, transaction_item_count numeric,
    product_exposure_count numeric, product_click_count numeric,
    -- ratio (V1.4)
    refund_rate_pay_time numeric,               -- 80
    exposure_to_click_rate_events numeric,      -- 81
    click_to_transaction_rate_events numeric,   -- 82
    avg_item_amount numeric,                    -- 83
    exposure_to_transaction_rate_events numeric,-- 85
    user_pay_amount_per_1000_exposures numeric, -- 86
    -- source_only
    one_hour_refund_rate_pay_time numeric,      -- 84 待平台口径确认
    source_only_note text
) AS $$
DECLARE v_single_day boolean;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION '参数错误: p_start_date 和 p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION '参数错误: p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    v_single_day := (p_start_date = p_end_date);

    RETURN QUERY
    SELECT
        s.shop_name, p_start_date, p_end_date,
        (p_end_date - p_start_date + 1)::int,
        t.terminal_type::varchar, t.selling_type::varchar,
        SUM(t.transaction_amount), SUM(t.user_pay_amount), SUM(t.settlement_amount),
        SUM(t.transaction_order_count), SUM(t.transaction_refund_amount_pay_time),
        SUM(t.refund_amount_pay_time), SUM(t.transaction_item_count),
        SUM(t.product_exposure_count), SUM(t.product_click_count),
        SUM(t.refund_amount_pay_time) / NULLIF(SUM(t.user_pay_amount), 0),
        SUM(t.product_click_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_click_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.transaction_item_count), 0),
        SUM(t.transaction_order_count) / NULLIF(SUM(t.product_exposure_count), 0),
        SUM(t.user_pay_amount) / NULLIF(SUM(t.product_exposure_count), 0) * 1000,
        CASE WHEN v_single_day THEN MAX(t.one_hour_refund_rate_pay_time) ELSE NULL END,
        CASE WHEN v_single_day THEN '单日: source_only返回当天源值'
             ELSE '多日: one_hour_refund_rate(待平台口径确认)不可跨期重算, 返回NULL' END
    FROM core.douyin_terminal_daily t
    JOIN meta.shop s ON t.shop_id = s.shop_id
    WHERE (p_shop_name IS NULL OR s.shop_name = p_shop_name)
      AND (p_terminal_type IS NULL OR t.terminal_type = p_terminal_type)
      AND (p_selling_type IS NULL OR t.selling_type = p_selling_type)
      AND t.biz_date BETWEEN p_start_date AND p_end_date
    GROUP BY s.shop_name, t.terminal_type, t.selling_type;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mart.get_terminal_period_summary(text,date,date,text,text) IS
'终端动态区间汇总。terminal_type=整体为平台TOTAL(总览优先取); 拆分只取具体终端; 禁止整体+明细同时SUM。';
