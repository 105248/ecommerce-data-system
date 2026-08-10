--
-- PostgreSQL database dump
--

-- Dumped from database version 16.6
-- Dumped by pg_dump version 16.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: mart; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA mart;


ALTER SCHEMA mart OWNER TO postgres;

--
-- Name: SCHEMA mart; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA mart IS '经营分析层：由core标准化日报组织为稳定可组合的经营查询接口。';


--
-- Name: assert_period(date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.assert_period(p_start_date date, p_end_date date) RETURNS void
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.assert_period(p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: FUNCTION assert_period(p_start_date date, p_end_date date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.assert_period(p_start_date date, p_end_date date) IS '阶段2内部校验函数：验证时间区间非空且开始日期不晚于结束日期。';


--
-- Name: assert_rank_args(text, text, text, text, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.assert_rank_args(p_domain_key text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) RETURNS void
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM mart.analysis_metric_whitelist w
        WHERE w.domain_key=p_domain_key AND w.metric_key=p_metric_key AND w.rank_allowed
    ) THEN
        RAISE EXCEPTION '域%不允许按指标%排名。请使用 mart.analysis_metric_whitelist。', p_domain_key,p_metric_key;
    END IF;
    IF p_sort_by NOT IN ('current_value','absolute_change','relative_change','rank_change') THEN
        RAISE EXCEPTION 'p_sort_by仅允许 current_value/absolute_change/relative_change/rank_change。';
    END IF;
    IF upper(p_sort_direction) NOT IN ('ASC','DESC') THEN
        RAISE EXCEPTION 'p_sort_direction仅允许 ASC/DESC。';
    END IF;
    IF p_limit IS NULL OR p_limit < 1 OR p_limit > 500 THEN
        RAISE EXCEPTION 'p_limit仅允许1~500。';
    END IF;
END;
$$;


ALTER FUNCTION mart.assert_rank_args(p_domain_key text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) OWNER TO postgres;

--
-- Name: compare_business_period(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.compare_business_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text DEFAULT 'user_pay_amount'::text) RETURNS TABLE(shop_name text, scope_key text, metric_key text, metric_name_cn text, value_type text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_coverage_complete boolean, previous_coverage_complete boolean, comparison_status text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_prev_start date;
    v_prev_end date;
    v_cur record;
    v_prev record;
    v_cur_found boolean := false;
    v_prev_found boolean := false;
    v_type text;
    v_name text;
    v_cur_value numeric;
    v_prev_value numeric;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date);
    SELECT pp.previous_start_date,pp.previous_end_date INTO v_prev_start,v_prev_end
    FROM mart.previous_period(p_start_date,p_end_date) pp;

    SELECT w.metric_name_cn,w.value_type INTO v_name,v_type
    FROM mart.analysis_metric_whitelist w
    WHERE w.domain_key='business' AND w.metric_key=p_metric_key AND w.rank_allowed;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'business域不支持指标%。',p_metric_key;
    END IF;

    SELECT * INTO v_cur FROM mart.get_business_period_summary(p_shop_name,p_start_date,p_end_date,p_scope_key);
    v_cur_found := FOUND;
    SELECT * INTO v_prev FROM mart.get_business_period_summary(p_shop_name,v_prev_start,v_prev_end,p_scope_key);
    v_prev_found := FOUND;

    IF NOT v_cur_found THEN
        RAISE EXCEPTION '本期无可用数据：% ~ %，scope=%。',p_start_date,p_end_date,p_scope_key;
    END IF;

    v_cur_value := CASE p_metric_key
        WHEN 'user_pay_amount' THEN v_cur.user_pay_amount
        WHEN 'transaction_amount' THEN v_cur.transaction_amount
        WHEN 'refund_amount_pay_time' THEN v_cur.refund_amount_pay_time
        WHEN 'settlement_amount' THEN v_cur.settlement_amount
        WHEN 'transaction_order_count' THEN v_cur.transaction_order_count
        WHEN 'transaction_buyer_count' THEN v_cur.transaction_buyer_count
        WHEN 'transaction_item_count' THEN v_cur.transaction_item_count
        WHEN 'avg_customer_amount' THEN v_cur.avg_customer_amount
        WHEN 'avg_item_amount' THEN v_cur.avg_item_amount
        WHEN 'refund_rate_pay_time' THEN v_cur.refund_rate_pay_time
        WHEN 'exposure_to_click_rate_users' THEN v_cur.exposure_to_click_rate_users
        WHEN 'click_to_transaction_rate_users' THEN v_cur.click_to_transaction_rate_users
        WHEN 'exposure_to_transaction_rate_users' THEN v_cur.exposure_to_transaction_rate_users
        WHEN 'exposure_to_click_rate_events' THEN v_cur.exposure_to_click_rate_events
        WHEN 'click_to_transaction_rate_events' THEN v_cur.click_to_transaction_rate_events
        WHEN 'exposure_to_transaction_rate_events' THEN v_cur.exposure_to_transaction_rate_events
        WHEN 'user_pay_amount_per_1000_exposures' THEN v_cur.user_pay_amount_per_1000_exposures
    END;

    IF v_prev_found THEN
        v_prev_value := CASE p_metric_key
            WHEN 'user_pay_amount' THEN v_prev.user_pay_amount
            WHEN 'transaction_amount' THEN v_prev.transaction_amount
            WHEN 'refund_amount_pay_time' THEN v_prev.refund_amount_pay_time
            WHEN 'settlement_amount' THEN v_prev.settlement_amount
            WHEN 'transaction_order_count' THEN v_prev.transaction_order_count
            WHEN 'transaction_buyer_count' THEN v_prev.transaction_buyer_count
            WHEN 'transaction_item_count' THEN v_prev.transaction_item_count
            WHEN 'avg_customer_amount' THEN v_prev.avg_customer_amount
            WHEN 'avg_item_amount' THEN v_prev.avg_item_amount
            WHEN 'refund_rate_pay_time' THEN v_prev.refund_rate_pay_time
            WHEN 'exposure_to_click_rate_users' THEN v_prev.exposure_to_click_rate_users
            WHEN 'click_to_transaction_rate_users' THEN v_prev.click_to_transaction_rate_users
            WHEN 'exposure_to_transaction_rate_users' THEN v_prev.exposure_to_transaction_rate_users
            WHEN 'exposure_to_click_rate_events' THEN v_prev.exposure_to_click_rate_events
            WHEN 'click_to_transaction_rate_events' THEN v_prev.click_to_transaction_rate_events
            WHEN 'exposure_to_transaction_rate_events' THEN v_prev.exposure_to_transaction_rate_events
            WHEN 'user_pay_amount_per_1000_exposures' THEN v_prev.user_pay_amount_per_1000_exposures
        END;
    END IF;

    RETURN QUERY SELECT
        v_cur.shop_name::text,
        p_scope_key,
        p_metric_key,
        v_name,
        v_type,
        p_start_date,p_end_date,v_prev_start,v_prev_end,
        v_cur_value,
        v_prev_value,
        CASE WHEN v_prev_value IS NULL THEN NULL ELSE v_cur_value-v_prev_value END,
        CASE WHEN v_prev_value IS NULL OR v_prev_value=0 THEN NULL ELSE (v_cur_value-v_prev_value)/v_prev_value END,
        CASE WHEN v_type='ratio' AND v_prev_value IS NOT NULL THEN v_cur_value-v_prev_value ELSE NULL END,
        v_cur.coverage_complete,
        CASE WHEN v_prev_found THEN v_prev.coverage_complete ELSE FALSE END,
        CASE
            WHEN NOT v_prev_found THEN '上期无数据'
            WHEN NOT v_cur.coverage_complete AND NOT v_prev.coverage_complete THEN '本期与上期数据均不完整'
            WHEN NOT v_cur.coverage_complete THEN '本期数据不完整'
            WHEN NOT v_prev.coverage_complete THEN '上期数据不完整'
            WHEN v_cur_value IS NULL OR v_prev_value IS NULL THEN '指标不可比较/无值'
            ELSE '可比较'
        END::text;
END;
$$;


ALTER FUNCTION mart.compare_business_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) OWNER TO postgres;

--
-- Name: FUNCTION compare_business_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.compare_business_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) IS '阶段3A经营环比：固定N天vs紧邻前N天；ratio同时返回percentage_point_change（原始比率差，如0.02=2个百分点）。';


--
-- Name: format_percent_2(numeric); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.format_percent_2(value_decimal numeric) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
    SELECT CASE
        WHEN value_decimal IS NULL THEN NULL
        ELSE TO_CHAR(value_decimal * 100, 'FM999999999990.00') || '%'
    END;
$$;


ALTER FUNCTION mart.format_percent_2(value_decimal numeric) OWNER TO postgres;

--
-- Name: FUNCTION format_percent_2(value_decimal numeric); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.format_percent_2(value_decimal numeric) IS '将比率原始数值格式化为两位小数百分比，输入值可大于1。例如0.1972返回19.72%，9.625返回962.50%。仅用于展示，不用于后续数学计算。';


--
-- Name: get_account_contribution(text, date, date, text, text, text, boolean, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_account_contribution(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text DEFAULT 'user_pay_amount'::text, p_account_name text DEFAULT NULL::text, p_include_aggregate_bucket boolean DEFAULT true, p_limit integer DEFAULT 100) RETURNS TABLE(shop_name text, sale_scope text, account_name text, row_semantic text, metric_key text, metric_name_cn text, numerator_value numeric, scope_total numeric, contribution_to_scope numeric, store_total numeric, contribution_to_store numeric, coverage_note text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE v_name text;v_scope record;v_store record;v_scope_val numeric;v_store_val numeric;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date);
    IF p_sale_scope NOT IN ('自营','合作') THEN RAISE EXCEPTION '账号贡献度p_sale_scope仅允许自营/合作。'; END IF;
    IF p_limit<1 OR p_limit>1000 THEN RAISE EXCEPTION 'p_limit仅允许1~1000。'; END IF;
    SELECT w.metric_name_cn INTO v_name FROM mart.analysis_metric_whitelist w WHERE w.domain_key='account' AND w.metric_key=p_metric_key AND w.contribution_allowed;
    IF NOT FOUND THEN RAISE EXCEPTION 'account贡献度不支持指标%。',p_metric_key; END IF;
    SELECT * INTO v_scope FROM mart.get_business_period_summary(p_shop_name,p_start_date,p_end_date,p_sale_scope);
    SELECT * INTO v_store FROM mart.get_business_period_summary(p_shop_name,p_start_date,p_end_date,'全店');
    v_scope_val := CASE p_metric_key WHEN 'user_pay_amount' THEN v_scope.user_pay_amount WHEN 'transaction_amount' THEN v_scope.transaction_amount WHEN 'refund_amount_pay_time' THEN v_scope.refund_amount_pay_time END;
    v_store_val := CASE p_metric_key WHEN 'user_pay_amount' THEN v_store.user_pay_amount WHEN 'transaction_amount' THEN v_store.transaction_amount WHEN 'refund_amount_pay_time' THEN v_store.refund_amount_pay_time END;
    RETURN QUERY
    SELECT a.shop_name,a.sale_scope,a.account_name,a.row_semantic,p_metric_key,v_name,
           CASE p_metric_key WHEN 'user_pay_amount' THEN a.user_pay_amount WHEN 'transaction_amount' THEN a.transaction_amount WHEN 'refund_amount_pay_time' THEN a.refund_amount_pay_time END::numeric,
           v_scope_val,
           CASE p_metric_key WHEN 'user_pay_amount' THEN a.user_pay_amount WHEN 'transaction_amount' THEN a.transaction_amount WHEN 'refund_amount_pay_time' THEN a.refund_amount_pay_time END::numeric/NULLIF(v_scope_val,0),
           v_store_val,
           CASE p_metric_key WHEN 'user_pay_amount' THEN a.user_pay_amount WHEN 'transaction_amount' THEN a.transaction_amount WHEN 'refund_amount_pay_time' THEN a.refund_amount_pay_time END::numeric/NULLIF(v_store_val,0),
           CASE WHEN p_sale_scope='合作' THEN '合作账号明细+更多账号已验证可重建合作TOTAL；贡献度分母使用deal合作TOTAL' ELSE '自营account_daily存在未列出成交；贡献度分母使用deal自营TOTAL，账号贡献之和可能小于100%' END::text
    FROM mart.get_account_period_summary(p_shop_name,p_start_date,p_end_date,p_sale_scope,NULL) a
    WHERE (p_include_aggregate_bucket OR a.row_semantic<>'aggregate_bucket') AND (p_account_name IS NULL OR a.account_name=p_account_name)
    ORDER BY 7 DESC NULLS LAST LIMIT p_limit;
END; $$;


ALTER FUNCTION mart.get_account_contribution(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_account_name text, p_include_aggregate_bucket boolean, p_limit integer) OWNER TO postgres;

--
-- Name: FUNCTION get_account_contribution(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_account_name text, p_include_aggregate_bucket boolean, p_limit integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_account_contribution(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_account_name text, p_include_aggregate_bucket boolean, p_limit integer) IS '账号贡献度；分母使用deal权威scope TOTAL，自营覆盖缺口明确提示。';


--
-- Name: get_account_period_summary(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_account_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text DEFAULT NULL::text, p_account_name text DEFAULT NULL::text) RETURNS TABLE(shop_name text, start_date date, end_date date, sale_scope text, account_name text, account_type text, douyin_account_id text, row_semantic text, coverage_days integer, transaction_amount numeric, user_pay_amount numeric, settlement_amount numeric, refund_amount_pay_time numeric, refund_rate_pay_time numeric, transaction_order_count bigint, transaction_item_count bigint, transaction_buyer_count bigint, avg_item_amount numeric, avg_customer_amount numeric, product_exposure_count bigint, product_click_count bigint, exposure_to_click_rate_events numeric, click_to_transaction_rate_events numeric, exposure_to_transaction_rate_events numeric, ad_spend_shop_bound numeric, ad_spend_shop_promoted numeric, ad_spend_rate_net_refund_shop_bound numeric, ad_spend_rate_net_refund_shop_promoted numeric, total_expense_rate_net_refund_shop_bound numeric, total_expense_rate_net_refund_shop_promoted numeric, one_hour_refund_rate_pay_time numeric, unrecalculable_metrics text[])
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.get_account_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_account_name text) OWNER TO postgres;

--
-- Name: FUNCTION get_account_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_account_name text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_account_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_account_name text) IS '账号区间汇总，仅用于具体账号/合作剩余桶拆分，不用于重建全店或自营TOTAL。';


--
-- Name: get_audience_period_summary(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_audience_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_audience_type text DEFAULT NULL::text, p_carrier_type text DEFAULT '全部'::text) RETURNS TABLE(shop_name text, start_date date, end_date date, audience_type text, carrier_type text, is_total_row boolean, coverage_days integer, user_pay_amount numeric, transaction_buyer_count bigint, avg_customer_amount numeric, transaction_order_count bigint, repeat_user_repeat_rate numeric, unrecalculable_metrics text[])
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.get_audience_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_audience_type text, p_carrier_type text) OWNER TO postgres;

--
-- Name: FUNCTION get_audience_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_audience_type text, p_carrier_type text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_audience_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_audience_type text, p_carrier_type text) IS '人群区间汇总。默认carrier_type=全部（阶段0.5已验证60/60匹配合法TOTAL）；复购用户复购率缺基础字段，多日返回NULL。';


--
-- Name: get_business_contribution(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_business_contribution(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text DEFAULT 'user_pay_amount'::text) RETURNS TABLE(shop_name text, scope_key text, metric_key text, metric_name_cn text, numerator_value numeric, denominator_value numeric, denominator_source text, contribution_rate numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE v_num record;v_den record;v_name text;v_num_val numeric;v_den_val numeric;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date);
    SELECT w.metric_name_cn INTO v_name FROM mart.analysis_metric_whitelist w WHERE w.domain_key='business' AND w.metric_key=p_metric_key AND w.contribution_allowed;
    IF NOT FOUND THEN RAISE EXCEPTION 'business贡献度不支持指标%。',p_metric_key; END IF;
    SELECT * INTO v_num FROM mart.get_business_period_summary(p_shop_name,p_start_date,p_end_date,p_scope_key);
    SELECT * INTO v_den FROM mart.get_business_period_summary(p_shop_name,p_start_date,p_end_date,'全店');
    IF NOT FOUND THEN RAISE EXCEPTION '全店权威TOTAL无数据。'; END IF;
    v_num_val := CASE p_metric_key WHEN 'user_pay_amount' THEN v_num.user_pay_amount WHEN 'transaction_amount' THEN v_num.transaction_amount WHEN 'refund_amount_pay_time' THEN v_num.refund_amount_pay_time END;
    v_den_val := CASE p_metric_key WHEN 'user_pay_amount' THEN v_den.user_pay_amount WHEN 'transaction_amount' THEN v_den.transaction_amount WHEN 'refund_amount_pay_time' THEN v_den.refund_amount_pay_time END;
    RETURN QUERY SELECT v_num.shop_name::text,p_scope_key,p_metric_key,v_name,v_num_val,v_den_val,'deal全店合法TOTAL'::text,v_num_val/NULLIF(v_den_val,0);
END; $$;


ALTER FUNCTION mart.get_business_contribution(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) OWNER TO postgres;

--
-- Name: FUNCTION get_business_contribution(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_business_contribution(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) IS '经营范围贡献度；分母固定deal全店权威TOTAL。';


--
-- Name: get_business_period_summary(text, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_business_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) RETURNS TABLE(shop_name text, start_date date, end_date date, expected_days integer, coverage_days integer, coverage_complete boolean, scope_key text, sale_scope text, carrier_type text, ad_period text, source_row_count bigint, user_pay_amount numeric, net_user_pay_amount_pay_time numeric, smart_coupon_amount numeric, net_smart_coupon_amount_pay_time numeric, platform_subsidy_amount numeric, transaction_order_count bigint, transaction_buyer_count bigint, avg_customer_amount numeric, transaction_amount numeric, net_transaction_amount numeric, refund_amount_refund_time numeric, transaction_refund_amount_refund_time numeric, refund_order_count_refund_time bigint, refund_rate_pay_time numeric, refund_amount_pay_time numeric, transaction_refund_amount_pay_time numeric, refund_order_count_pay_time bigint, product_exposure_user_count bigint, product_click_user_count bigint, exposure_to_click_rate_users numeric, click_to_transaction_rate_users numeric, exposure_to_transaction_rate_users numeric, user_pay_amount_per_1000_exposures numeric, product_exposure_count bigint, product_click_count bigint, exposure_to_click_rate_events numeric, click_to_transaction_rate_events numeric, exposure_to_transaction_rate_events numeric, shipped_user_pay_amount_ship_time numeric, ship_within_2_days_rate numeric, settlement_amount numeric, settlement_amount_refund_time numeric, settlement_amount_7d numeric, settlement_amount_14d numeric, net_creator_subsidy_amount_pay_time numeric, creator_subsidy_amount numeric, presale_deposit_amount numeric, transaction_item_count bigint, avg_item_amount numeric, net_transaction_order_count bigint, pre_shipment_refund_rate_pay_time numeric, unreceived_refund_rate_pay_time numeric, received_refund_rate_pay_time numeric, received_return_refund_rate_pay_time numeric, one_hour_transaction_refund_amount_pay_time numeric, one_hour_refund_order_count_pay_time bigint, one_hour_refund_rate_pay_time numeric, net_platform_subsidy_amount_pay_time numeric, unrecalculable_metrics text[])
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.get_business_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) OWNER TO postgres;

--
-- Name: FUNCTION get_business_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_business_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) IS '高频经营总览区间汇总：全店/自营/合作/商品卡/短视频等合法Scope。比例按V1.4分子分母重算；source_only多日返回NULL。';


--
-- Name: get_carrier_period_summary(text, date, date, text, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_carrier_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text DEFAULT NULL::text, p_carrier_type text DEFAULT NULL::text, p_account_channel text DEFAULT NULL::text) RETURNS TABLE(shop_name text, start_date date, end_date date, sale_scope text, carrier_type text, account_channel text, douyin_account_id text, row_semantic text, aggregation_allowed boolean, coverage_days integer, transaction_amount numeric, user_pay_amount numeric, settlement_amount numeric, refund_amount_pay_time numeric, refund_rate_pay_time numeric, transaction_order_count bigint, transaction_item_count bigint, transaction_buyer_count bigint, avg_item_amount numeric, avg_customer_amount numeric, product_exposure_count bigint, product_click_count bigint, exposure_to_click_rate_events numeric, click_to_transaction_rate_events numeric, exposure_to_transaction_rate_events numeric, product_exposure_user_count bigint, product_click_user_count bigint, exposure_to_click_rate_users numeric, click_to_transaction_rate_users numeric, exposure_to_transaction_rate_users numeric, user_pay_amount_per_1000_exposures numeric, ad_attributed_transaction_amount numeric, ad_attributed_transaction_share numeric, ad_spend_shop_bound numeric, ad_spend_shop_promoted numeric, platform_commission_settlement numeric, creator_commission_settlement numeric, ad_spend_rate_shop_bound numeric, ad_spend_rate_shop_promoted numeric, ad_spend_rate_net_refund_shop_bound numeric, ad_spend_rate_net_refund_shop_promoted numeric, total_expense_rate_shop_bound numeric, total_expense_rate_shop_promoted numeric, total_expense_rate_net_refund_shop_bound numeric, total_expense_rate_net_refund_shop_promoted numeric, one_hour_refund_rate_pay_time numeric, unrecalculable_metrics text[])
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.get_carrier_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_carrier_type text, p_account_channel text) OWNER TO postgres;

--
-- Name: FUNCTION get_carrier_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_carrier_type text, p_account_channel text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_carrier_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_carrier_type text, p_account_channel text) IS '载体/渠道区间拆分。按account_channel逐桶返回，不承担全店TOTAL；special_overlap行明确禁止与明细混SUM。';


--
-- Name: get_category_contribution(text, date, date, integer, text, text, text, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_category_contribution(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer DEFAULT 3, p_category_l1 text DEFAULT NULL::text, p_category_l2 text DEFAULT NULL::text, p_metric_key text DEFAULT 'user_pay_amount'::text, p_limit integer DEFAULT 100) RETURNS TABLE(shop_name text, category_level integer, category_l1 text, category_l2 text, category_l3 text, category_l4 text, metric_key text, metric_name_cn text, numerator_value numeric, category_level_total numeric, contribution_to_category_level numeric, store_total numeric, contribution_to_store numeric, denominator_note text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE v_name text;v_store record;v_store_val numeric;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date);
    IF p_limit<1 OR p_limit>1000 THEN RAISE EXCEPTION 'p_limit仅允许1~1000。'; END IF;
    SELECT w.metric_name_cn INTO v_name FROM mart.analysis_metric_whitelist w WHERE w.domain_key='category' AND w.metric_key=p_metric_key AND w.contribution_allowed;
    IF NOT FOUND THEN RAISE EXCEPTION 'category贡献度不支持指标%。',p_metric_key; END IF;
    SELECT * INTO v_store FROM mart.get_business_period_summary(p_shop_name,p_start_date,p_end_date,'全店');
    v_store_val := CASE p_metric_key WHEN 'user_pay_amount' THEN v_store.user_pay_amount WHEN 'refund_amount_pay_time' THEN v_store.refund_amount_pay_time END;
    RETURN QUERY
    WITH allc AS (
      SELECT c.*,CASE p_metric_key WHEN 'user_pay_amount' THEN c.user_pay_amount WHEN 'refund_amount_pay_time' THEN c.refund_amount_pay_time END::numeric val
      FROM mart.get_category_period_summary(p_shop_name,p_start_date,p_end_date,p_category_level,p_category_l1,p_category_l2,NULL) c
    ), x AS (SELECT a.*,SUM(a.val) OVER() lvl_total FROM allc a)
    SELECT x.shop_name,x.category_level,x.category_l1,x.category_l2,x.category_l3,x.category_l4,p_metric_key,v_name,x.val,x.lvl_total,x.val/NULLIF(x.lvl_total,0),v_store_val,x.val/NULLIF(v_store_val,0),
           '类目域分母=同一category_level合法层级总量；全店分母=deal全店TOTAL。阶段2已确认类目域与deal可存在平台口径差异，禁止强行校平。'::text
    FROM x ORDER BY x.val DESC NULLS LAST LIMIT p_limit;
END; $$;


ALTER FUNCTION mart.get_category_contribution(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_limit integer) OWNER TO postgres;

--
-- Name: FUNCTION get_category_contribution(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_limit integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_category_contribution(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_limit integer) IS '类目贡献度；类目层级域分母与deal全店分母同时返回，不强行统一平台口径。';


--
-- Name: get_category_period_summary(text, date, date, integer, text, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_category_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer DEFAULT 3, p_category_l1 text DEFAULT NULL::text, p_category_l2 text DEFAULT NULL::text, p_category_l3 text DEFAULT NULL::text) RETURNS TABLE(shop_name text, start_date date, end_date date, category_level integer, category_l1 text, category_l2 text, category_l3 text, category_l4 text, is_total_row boolean, coverage_days integer, user_pay_amount numeric, refund_amount_pay_time numeric, refund_rate_pay_time numeric, avg_transaction_order_amount numeric, click_to_transaction_rate_events numeric, unrecalculable_metrics text[])
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.get_category_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_category_l3 text) OWNER TO postgres;

--
-- Name: FUNCTION get_category_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_category_l3 text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_category_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_category_l3 text) IS '类目区间汇总，强制按category_level隔离父子层级，禁止不同层级混SUM。成交笔单价/次数转化率缺基础字段，多日返回NULL。';


--
-- Name: get_content_period_summary(text, date, date, text, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_content_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_selling_type text DEFAULT NULL::text, p_carrier_type text DEFAULT NULL::text, p_content_id text DEFAULT NULL::text) RETURNS TABLE(shop_name text, start_date date, end_date date, selling_type text, carrier_type text, content_id text, content_title text, coverage_days integer, transaction_amount numeric, user_pay_amount numeric, settlement_amount numeric, refund_amount_pay_time numeric, refund_rate_pay_time numeric, transaction_order_count bigint, transaction_item_count bigint, transaction_buyer_count bigint, avg_item_amount numeric, avg_customer_amount numeric, product_exposure_count bigint, product_click_count bigint, exposure_to_click_rate_events numeric, click_to_transaction_rate_events numeric, exposure_to_transaction_rate_events numeric, ad_spend_shop_bound numeric, ad_spend_shop_promoted numeric, ad_spend_rate_net_refund_shop_bound numeric, ad_spend_rate_net_refund_shop_promoted numeric, one_hour_refund_rate_pay_time numeric, unrecalculable_metrics text[])
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.get_content_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_selling_type text, p_carrier_type text, p_content_id text) OWNER TO postgres;

--
-- Name: FUNCTION get_content_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_selling_type text, p_carrier_type text, p_content_id text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_content_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_selling_type text, p_carrier_type text, p_content_id text) IS '内容区间拆分；当前真实样本仅验证商品卡载体，不伪造短视频/直播内容数据。';


--
-- Name: get_data_coverage(text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_data_coverage(p_shop_name text DEFAULT NULL::text) RETURNS TABLE(shop_name text, min_date date, max_date date, day_count bigint, row_count bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT s.shop_name::text,
           MIN(d.biz_date)::date,
           MAX(d.biz_date)::date,
           COUNT(DISTINCT d.biz_date)::bigint,
           COUNT(*)::bigint
    FROM core.douyin_deal_daily d
    JOIN meta.shop s ON s.shop_id = d.shop_id
    WHERE (p_shop_name IS NULL OR s.shop_name = p_shop_name)
    GROUP BY s.shop_name
    ORDER BY s.shop_name;
$$;


ALTER FUNCTION mart.get_data_coverage(p_shop_name text) OWNER TO postgres;

--
-- Name: get_price_band_period_summary(text, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_price_band_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_price_band text DEFAULT NULL::text) RETURNS TABLE(shop_name text, start_date date, end_date date, price_band text, coverage_days integer, user_pay_amount numeric, avg_transaction_order_amount numeric, click_to_transaction_rate_events numeric, can_sum_to_store_total boolean, unrecalculable_metrics text[])
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.get_price_band_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_price_band text) OWNER TO postgres;

--
-- Name: FUNCTION get_price_band_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_price_band text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_price_band_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_price_band text) IS '价格带区间汇总。6个价格带经阶段0.5验证为互斥分桶，可安全SUM重建店铺用户支付金额。';


--
-- Name: get_product_contribution(text, date, date, text, text, text, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_product_contribution(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text DEFAULT 'user_pay_amount'::text, p_product_id text DEFAULT NULL::text, p_product_name text DEFAULT NULL::text, p_limit integer DEFAULT 100) RETURNS TABLE(shop_name text, product_id text, product_name text, metric_key text, metric_name_cn text, numerator_value numeric, product_domain_total numeric, contribution_to_product_domain numeric, store_total numeric, contribution_to_store numeric, denominator_note text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE v_name text;v_store record;v_store_val numeric;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date);
    IF p_limit<1 OR p_limit>1000 THEN RAISE EXCEPTION 'p_limit仅允许1~1000。'; END IF;
    SELECT w.metric_name_cn INTO v_name FROM mart.analysis_metric_whitelist w WHERE w.domain_key='product' AND w.metric_key=p_metric_key AND w.contribution_allowed;
    IF NOT FOUND THEN RAISE EXCEPTION 'product贡献度不支持指标%。',p_metric_key; END IF;
    SELECT * INTO v_store FROM mart.get_business_period_summary(p_shop_name,p_start_date,p_end_date,'全店');
    v_store_val := CASE p_metric_key WHEN 'user_pay_amount' THEN v_store.user_pay_amount WHEN 'refund_amount_pay_time' THEN v_store.refund_amount_pay_time END;
    RETURN QUERY
    WITH allp AS (
      SELECT p.shop_name,p.product_id,p.product_name,CASE p_metric_key WHEN 'user_pay_amount' THEN p.user_pay_amount WHEN 'refund_amount_pay_time' THEN p.refund_amount_pay_time END::numeric val
      FROM mart.get_product_period_summary(p_shop_name,p_start_date,p_end_date,NULL,NULL,'全部') p
    ), x AS (SELECT a.*,SUM(a.val) OVER() domain_total FROM allp a)
    SELECT x.shop_name,x.product_id,x.product_name,p_metric_key,v_name,x.val,x.domain_total,x.val/NULLIF(x.domain_total,0),v_store_val,x.val/NULLIF(v_store_val,0),
           'product域分母=各商品carrier=全部的平台独立TOTAL之和；全店分母=deal全店TOTAL，两者允许存在平台口径差异'::text
    FROM x WHERE (p_product_id IS NULL OR x.product_id=p_product_id) AND (p_product_name IS NULL OR x.product_name=p_product_name)
    ORDER BY x.val DESC NULLS LAST LIMIT p_limit;
END; $$;


ALTER FUNCTION mart.get_product_contribution(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_product_id text, p_product_name text, p_limit integer) OWNER TO postgres;

--
-- Name: FUNCTION get_product_contribution(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_product_id text, p_product_name text, p_limit integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_product_contribution(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_product_id text, p_product_name text, p_limit integer) IS '商品贡献度；同时返回product域占比与全店占比，明确分母口径。';


--
-- Name: get_product_period_summary(text, date, date, text, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_product_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_product_id text DEFAULT NULL::text, p_product_name text DEFAULT NULL::text, p_carrier_type text DEFAULT '全部'::text) RETURNS TABLE(shop_name text, start_date date, end_date date, product_id text, product_name text, carrier_type text, is_platform_total boolean, coverage_days integer, user_pay_amount numeric, refund_amount_pay_time numeric, refund_rate_pay_time numeric, smart_coupon_amount numeric, platform_subsidy_amount numeric, net_smart_coupon_amount_pay_time numeric, net_platform_subsidy_amount_pay_time numeric, avg_transaction_order_amount numeric, click_to_transaction_rate_events numeric, unrecalculable_metrics text[])
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.get_product_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_product_id text, p_product_name text, p_carrier_type text) OWNER TO postgres;

--
-- Name: FUNCTION get_product_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_product_id text, p_product_name text, p_carrier_type text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_product_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_product_id text, p_product_name text, p_carrier_type text) IS '商品区间汇总。默认carrier_type=全部，直接使用平台独立TOTAL；禁止用商品卡/图文/直播/短视频明细重建全部。';


--
-- Name: get_terminal_period_summary(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_terminal_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_terminal_type text DEFAULT NULL::text, p_selling_type text DEFAULT NULL::text) RETURNS TABLE(shop_name text, start_date date, end_date date, terminal_type text, selling_type text, is_total_row boolean, coverage_days integer, transaction_amount numeric, user_pay_amount numeric, settlement_amount numeric, transaction_order_count bigint, refund_amount_pay_time numeric, refund_rate_pay_time numeric, transaction_item_count bigint, avg_item_amount numeric, product_exposure_count bigint, product_click_count bigint, exposure_to_click_rate_events numeric, click_to_transaction_rate_events numeric, exposure_to_transaction_rate_events numeric, user_pay_amount_per_1000_exposures numeric, one_hour_refund_rate_pay_time numeric, unrecalculable_metrics text[])
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.get_terminal_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_terminal_type text, p_selling_type text) OWNER TO postgres;

--
-- Name: FUNCTION get_terminal_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_terminal_type text, p_selling_type text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_terminal_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_terminal_type text, p_selling_type text) IS '终端区间汇总；terminal_type=整体为合法TOTAL，调用方不得将整体与明细终端再相加。';


--
-- Name: period_scope_rule(text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.period_scope_rule(p_scope_key text) RETURNS TABLE(scope_key text, sale_scope text, carrier_type text, ad_period text, is_total boolean)
    LANGUAGE sql IMMUTABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
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


ALTER FUNCTION mart.period_scope_rule(p_scope_key text) OWNER TO postgres;

--
-- Name: FUNCTION period_scope_rule(p_scope_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.period_scope_rule(p_scope_key text) IS '阶段2 Scope稳定适配层。规则来自阶段0/0.5真实数据验证；平台TOTAL优先，不通过父子明细重建。';


--
-- Name: previous_period(date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.previous_period(p_start_date date, p_end_date date) RETURNS TABLE(current_start_date date, current_end_date date, day_count integer, previous_start_date date, previous_end_date date)
    LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_days integer;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date);
    v_days := (p_end_date - p_start_date + 1)::integer;
    RETURN QUERY SELECT
        p_start_date,
        p_end_date,
        v_days,
        (p_start_date - v_days)::date,
        (p_start_date - 1)::date;
END;
$$;


ALTER FUNCTION mart.previous_period(p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: FUNCTION previous_period(p_start_date date, p_end_date date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.previous_period(p_start_date date, p_end_date date) IS '阶段3固定环比窗口：本期N天，对比紧邻之前N天。';


--
-- Name: rank_accounts(text, date, date, text, text, text, text, integer, boolean, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.rank_accounts(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text DEFAULT NULL::text, p_metric_key text DEFAULT 'user_pay_amount'::text, p_sort_by text DEFAULT 'current_value'::text, p_sort_direction text DEFAULT 'DESC'::text, p_limit integer DEFAULT 20, p_include_aggregate_bucket boolean DEFAULT false, p_account_name text DEFAULT NULL::text) RETURNS TABLE(shop_name text, sale_scope text, account_name text, account_type text, douyin_account_id text, row_semantic text, metric_key text, metric_name_cn text, value_type text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE v_prev_start date; v_prev_end date; v_type text; v_name text;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date);
    PERFORM mart.assert_rank_args('account',p_metric_key,p_sort_by,p_sort_direction,p_limit);
    SELECT w.metric_name_cn,w.value_type INTO v_name,v_type FROM mart.analysis_metric_whitelist w WHERE w.domain_key='account' AND w.metric_key=p_metric_key;
    SELECT pp.previous_start_date,pp.previous_end_date INTO v_prev_start,v_prev_end FROM mart.previous_period(p_start_date,p_end_date) pp;

    RETURN QUERY
    WITH cur0 AS (SELECT * FROM mart.get_account_period_summary(p_shop_name,p_start_date,p_end_date,p_sale_scope,NULL)),
    prev0 AS (SELECT * FROM mart.get_account_period_summary(p_shop_name,v_prev_start,v_prev_end,p_sale_scope,NULL)),
    cur AS (
      SELECT c.*,CASE p_metric_key WHEN 'user_pay_amount' THEN c.user_pay_amount WHEN 'transaction_amount' THEN c.transaction_amount WHEN 'refund_amount_pay_time' THEN c.refund_amount_pay_time WHEN 'refund_rate_pay_time' THEN c.refund_rate_pay_time WHEN 'transaction_order_count' THEN c.transaction_order_count WHEN 'transaction_buyer_count' THEN c.transaction_buyer_count WHEN 'avg_customer_amount' THEN c.avg_customer_amount END::numeric val
      FROM cur0 c WHERE p_include_aggregate_bucket OR c.row_semantic<>'aggregate_bucket'
    ), prev AS (
      SELECT p.*,CASE p_metric_key WHEN 'user_pay_amount' THEN p.user_pay_amount WHEN 'transaction_amount' THEN p.transaction_amount WHEN 'refund_amount_pay_time' THEN p.refund_amount_pay_time WHEN 'refund_rate_pay_time' THEN p.refund_rate_pay_time WHEN 'transaction_order_count' THEN p.transaction_order_count WHEN 'transaction_buyer_count' THEN p.transaction_buyer_count WHEN 'avg_customer_amount' THEN p.avg_customer_amount END::numeric val
      FROM prev0 p WHERE p_include_aggregate_bucket OR p.row_semantic<>'aggregate_bucket'
    ), cr AS (
      SELECT c.*,DENSE_RANK() OVER (ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN c.val END DESC NULLS LAST,CASE WHEN upper(p_sort_direction)='ASC' THEN c.val END ASC NULLS LAST,c.sale_scope,c.account_name) rnk FROM cur c
    ), pr AS (
      SELECT p.*,DENSE_RANK() OVER (ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN p.val END DESC NULLS LAST,CASE WHEN upper(p_sort_direction)='ASC' THEN p.val END ASC NULLS LAST,p.sale_scope,p.account_name) rnk FROM prev p
    ), j AS (
      SELECT COALESCE(cr.shop_name,pr.shop_name) shop_name,COALESCE(cr.sale_scope,pr.sale_scope) sale_scope,COALESCE(cr.account_name,pr.account_name) account_name,
             COALESCE(cr.account_type,pr.account_type) account_type,COALESCE(cr.douyin_account_id,pr.douyin_account_id) douyin_account_id,COALESCE(cr.row_semantic,pr.row_semantic) row_semantic,
             cr.val cur_val,pr.val prev_val,cr.rnk cur_rank,pr.rnk prev_rank
      FROM cr FULL JOIN pr ON cr.sale_scope=pr.sale_scope AND COALESCE(cr.douyin_account_id,cr.account_name)=COALESCE(pr.douyin_account_id,pr.account_name)
    ), s AS (
      SELECT j.*,CASE WHEN prev_val IS NULL THEN NULL ELSE cur_val-prev_val END abs_chg,CASE WHEN prev_val IS NULL OR prev_val=0 THEN NULL ELSE (cur_val-prev_val)/prev_val END rel_chg,
             CASE WHEN v_type='ratio' AND prev_val IS NOT NULL THEN cur_val-prev_val ELSE NULL END pp_chg,CASE WHEN cur_rank IS NULL OR prev_rank IS NULL THEN NULL ELSE prev_rank-cur_rank END rank_chg FROM j
    )
    SELECT s.shop_name,s.sale_scope,s.account_name,s.account_type,s.douyin_account_id,s.row_semantic,p_metric_key,v_name,v_type,p_start_date,p_end_date,v_prev_start,v_prev_end,
           s.cur_val,s.prev_val,s.abs_chg,s.rel_chg,s.pp_chg,s.cur_rank,s.prev_rank,s.rank_chg
    FROM s WHERE (p_account_name IS NULL OR s.account_name=p_account_name)
    ORDER BY
      CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='DESC' THEN s.cur_val END DESC NULLS LAST,
      CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='ASC' THEN s.cur_val END ASC NULLS LAST,
      CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='DESC' THEN s.abs_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='ASC' THEN s.abs_chg END ASC NULLS LAST,
      CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='DESC' THEN s.rel_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='ASC' THEN s.rel_chg END ASC NULLS LAST,
      CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='DESC' THEN s.rank_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='ASC' THEN s.rank_chg END ASC NULLS LAST,
      s.sale_scope,s.account_name
    LIMIT p_limit;
END; $$;


ALTER FUNCTION mart.rank_accounts(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_include_aggregate_bucket boolean, p_account_name text) OWNER TO postgres;

--
-- Name: FUNCTION rank_accounts(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_include_aggregate_bucket boolean, p_account_name text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.rank_accounts(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_include_aggregate_bucket boolean, p_account_name text) IS '账号排名；默认排除aggregate_bucket，避免把更多账号聚合桶当具体账号。';


--
-- Name: rank_audiences(text, date, date, text, text, text, text, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.rank_audiences(p_shop_name text, p_start_date date, p_end_date date, p_carrier_type text DEFAULT '全部'::text, p_metric_key text DEFAULT 'user_pay_amount'::text, p_sort_by text DEFAULT 'current_value'::text, p_sort_direction text DEFAULT 'DESC'::text, p_limit integer DEFAULT 20) RETURNS TABLE(shop_name text, audience_type text, carrier_type text, metric_key text, metric_name_cn text, value_type text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE v_prev_start date;v_prev_end date;v_type text;v_name text;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date); PERFORM mart.assert_rank_args('audience',p_metric_key,p_sort_by,p_sort_direction,p_limit);
    SELECT w.metric_name_cn,w.value_type INTO v_name,v_type FROM mart.analysis_metric_whitelist w WHERE w.domain_key='audience' AND w.metric_key=p_metric_key;
    SELECT pp.previous_start_date,pp.previous_end_date INTO v_prev_start,v_prev_end FROM mart.previous_period(p_start_date,p_end_date) pp;
    RETURN QUERY
    WITH cur0 AS (SELECT * FROM mart.get_audience_period_summary(p_shop_name,p_start_date,p_end_date,NULL,p_carrier_type)),prev0 AS (SELECT * FROM mart.get_audience_period_summary(p_shop_name,v_prev_start,v_prev_end,NULL,p_carrier_type)),
    cur AS (SELECT c.*,CASE p_metric_key WHEN 'user_pay_amount' THEN c.user_pay_amount WHEN 'transaction_buyer_count' THEN c.transaction_buyer_count WHEN 'transaction_order_count' THEN c.transaction_order_count WHEN 'avg_customer_amount' THEN c.avg_customer_amount END::numeric val FROM cur0 c),
    prev AS (SELECT p.*,CASE p_metric_key WHEN 'user_pay_amount' THEN p.user_pay_amount WHEN 'transaction_buyer_count' THEN p.transaction_buyer_count WHEN 'transaction_order_count' THEN p.transaction_order_count WHEN 'avg_customer_amount' THEN p.avg_customer_amount END::numeric val FROM prev0 p),
    cr AS (SELECT c.*,DENSE_RANK() OVER(ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN c.val END DESC,CASE WHEN upper(p_sort_direction)='ASC' THEN c.val END ASC,c.audience_type) rnk FROM cur c),
    pr AS (SELECT p.*,DENSE_RANK() OVER(ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN p.val END DESC,CASE WHEN upper(p_sort_direction)='ASC' THEN p.val END ASC,p.audience_type) rnk FROM prev p),
    j AS (SELECT COALESCE(cr.shop_name,pr.shop_name) shop_name,COALESCE(cr.audience_type,pr.audience_type) audience_type,COALESCE(cr.carrier_type,pr.carrier_type) carrier_type,cr.val cur_val,pr.val prev_val,cr.rnk cur_rank,pr.rnk prev_rank FROM cr FULL JOIN pr USING(audience_type,carrier_type)),
    s AS (SELECT j.*,CASE WHEN prev_val IS NULL THEN NULL ELSE cur_val-prev_val END abs_chg,CASE WHEN prev_val IS NULL OR prev_val=0 THEN NULL ELSE (cur_val-prev_val)/prev_val END rel_chg,CASE WHEN v_type='ratio' AND prev_val IS NOT NULL THEN cur_val-prev_val ELSE NULL END pp_chg,CASE WHEN cur_rank IS NULL OR prev_rank IS NULL THEN NULL ELSE prev_rank-cur_rank END rank_chg FROM j)
    SELECT s.shop_name,s.audience_type,s.carrier_type,p_metric_key,v_name,v_type,p_start_date,p_end_date,v_prev_start,v_prev_end,s.cur_val,s.prev_val,s.abs_chg,s.rel_chg,s.pp_chg,s.cur_rank,s.prev_rank,s.rank_chg FROM s
    ORDER BY CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='DESC' THEN s.cur_val END DESC NULLS LAST,CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='ASC' THEN s.cur_val END ASC NULLS LAST,CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='DESC' THEN s.abs_chg END DESC NULLS LAST,CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='ASC' THEN s.abs_chg END ASC NULLS LAST,CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='DESC' THEN s.rel_chg END DESC NULLS LAST,CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='ASC' THEN s.rel_chg END ASC NULLS LAST,CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='DESC' THEN s.rank_chg END DESC NULLS LAST,CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='ASC' THEN s.rank_chg END ASC NULLS LAST,s.audience_type LIMIT p_limit;
END; $$;


ALTER FUNCTION mart.rank_audiences(p_shop_name text, p_start_date date, p_end_date date, p_carrier_type text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) OWNER TO postgres;

--
-- Name: FUNCTION rank_audiences(p_shop_name text, p_start_date date, p_end_date date, p_carrier_type text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.rank_audiences(p_shop_name text, p_start_date date, p_end_date date, p_carrier_type text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) IS '人群排名；默认carrier=全部合法TOTAL。';


--
-- Name: rank_carriers(text, date, date, text, text, text, text, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.rank_carriers(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text DEFAULT '全部'::text, p_metric_key text DEFAULT 'user_pay_amount'::text, p_sort_by text DEFAULT 'current_value'::text, p_sort_direction text DEFAULT 'DESC'::text, p_limit integer DEFAULT 20) RETURNS TABLE(shop_name text, sale_scope text, carrier_type text, metric_key text, metric_name_cn text, value_type text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE v_prev_start date; v_prev_end date; v_type text; v_name text;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date);
    IF p_sale_scope NOT IN ('全部','自营','合作') THEN RAISE EXCEPTION 'p_sale_scope仅允许 全部/自营/合作。'; END IF;
    PERFORM mart.assert_rank_args('carrier',p_metric_key,p_sort_by,p_sort_direction,p_limit);
    SELECT w.metric_name_cn,w.value_type INTO v_name,v_type FROM mart.analysis_metric_whitelist w WHERE w.domain_key='carrier' AND w.metric_key=p_metric_key;
    SELECT pp.previous_start_date,pp.previous_end_date INTO v_prev_start,v_prev_end FROM mart.previous_period(p_start_date,p_end_date) pp;

    RETURN QUERY
    WITH carriers AS (SELECT * FROM (VALUES('商品卡'),('短视频'),('直播'),('图文'),('其他')) v(carrier_type)),
    cur0 AS (
      SELECT c.carrier_type, b.shop_name, b.user_pay_amount, b.transaction_amount, b.refund_amount_pay_time, b.refund_rate_pay_time
      FROM carriers c CROSS JOIN LATERAL mart.get_business_period_summary(p_shop_name,p_start_date,p_end_date,CASE WHEN p_sale_scope='全部' THEN c.carrier_type ELSE p_sale_scope||c.carrier_type END) b
    ), prev0 AS (
      SELECT c.carrier_type, b.shop_name, b.user_pay_amount, b.transaction_amount, b.refund_amount_pay_time, b.refund_rate_pay_time
      FROM carriers c CROSS JOIN LATERAL mart.get_business_period_summary(p_shop_name,v_prev_start,v_prev_end,CASE WHEN p_sale_scope='全部' THEN c.carrier_type ELSE p_sale_scope||c.carrier_type END) b
    ), cur AS (
      SELECT c.shop_name,c.carrier_type,CASE p_metric_key WHEN 'user_pay_amount' THEN c.user_pay_amount WHEN 'transaction_amount' THEN c.transaction_amount WHEN 'refund_amount_pay_time' THEN c.refund_amount_pay_time WHEN 'refund_rate_pay_time' THEN c.refund_rate_pay_time END::numeric val FROM cur0 c
    ), prev AS (
      SELECT p.shop_name,p.carrier_type,CASE p_metric_key WHEN 'user_pay_amount' THEN p.user_pay_amount WHEN 'transaction_amount' THEN p.transaction_amount WHEN 'refund_amount_pay_time' THEN p.refund_amount_pay_time WHEN 'refund_rate_pay_time' THEN p.refund_rate_pay_time END::numeric val FROM prev0 p
    ), cr AS (SELECT c.*,DENSE_RANK() OVER(ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN c.val END DESC NULLS LAST,CASE WHEN upper(p_sort_direction)='ASC' THEN c.val END ASC NULLS LAST,c.carrier_type) rnk FROM cur c),
    pr AS (SELECT p.*,DENSE_RANK() OVER(ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN p.val END DESC NULLS LAST,CASE WHEN upper(p_sort_direction)='ASC' THEN p.val END ASC NULLS LAST,p.carrier_type) rnk FROM prev p),
    j AS (SELECT COALESCE(cr.shop_name,pr.shop_name) shop_name,COALESCE(cr.carrier_type,pr.carrier_type) carrier_type,cr.val cur_val,pr.val prev_val,cr.rnk cur_rank,pr.rnk prev_rank FROM cr FULL JOIN pr USING(carrier_type)),
    s AS (SELECT j.*,CASE WHEN prev_val IS NULL THEN NULL ELSE cur_val-prev_val END abs_chg,CASE WHEN prev_val IS NULL OR prev_val=0 THEN NULL ELSE (cur_val-prev_val)/prev_val END rel_chg,CASE WHEN v_type='ratio' AND prev_val IS NOT NULL THEN cur_val-prev_val ELSE NULL END pp_chg,CASE WHEN cur_rank IS NULL OR prev_rank IS NULL THEN NULL ELSE prev_rank-cur_rank END rank_chg FROM j)
    SELECT s.shop_name,p_sale_scope,s.carrier_type,p_metric_key,v_name,v_type,p_start_date,p_end_date,v_prev_start,v_prev_end,s.cur_val,s.prev_val,s.abs_chg,s.rel_chg,s.pp_chg,s.cur_rank,s.prev_rank,s.rank_chg
    FROM s ORDER BY
      CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='DESC' THEN s.cur_val END DESC NULLS LAST,
      CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='ASC' THEN s.cur_val END ASC NULLS LAST,
      CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='DESC' THEN s.abs_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='ASC' THEN s.abs_chg END ASC NULLS LAST,
      CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='DESC' THEN s.rel_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='ASC' THEN s.rel_chg END ASC NULLS LAST,
      CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='DESC' THEN s.rank_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='ASC' THEN s.rank_chg END ASC NULLS LAST,
      s.carrier_type LIMIT p_limit;
END; $$;


ALTER FUNCTION mart.rank_carriers(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) OWNER TO postgres;

--
-- Name: FUNCTION rank_carriers(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.rank_carriers(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) IS '载体排名；使用deal合法TOTAL Scope，避免carrier_daily层级重叠。';


--
-- Name: rank_categories(text, date, date, integer, text, text, text, text, text, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.rank_categories(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer DEFAULT 3, p_category_l1 text DEFAULT NULL::text, p_category_l2 text DEFAULT NULL::text, p_metric_key text DEFAULT 'user_pay_amount'::text, p_sort_by text DEFAULT 'current_value'::text, p_sort_direction text DEFAULT 'DESC'::text, p_limit integer DEFAULT 20) RETURNS TABLE(shop_name text, category_level integer, category_l1 text, category_l2 text, category_l3 text, category_l4 text, metric_key text, metric_name_cn text, value_type text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE v_prev_start date;v_prev_end date;v_type text;v_name text;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date);
    PERFORM mart.assert_rank_args('category',p_metric_key,p_sort_by,p_sort_direction,p_limit);
    SELECT w.metric_name_cn,w.value_type INTO v_name,v_type FROM mart.analysis_metric_whitelist w WHERE w.domain_key='category' AND w.metric_key=p_metric_key;
    SELECT pp.previous_start_date,pp.previous_end_date INTO v_prev_start,v_prev_end FROM mart.previous_period(p_start_date,p_end_date) pp;
    RETURN QUERY
    WITH cur0 AS (SELECT * FROM mart.get_category_period_summary(p_shop_name,p_start_date,p_end_date,p_category_level,p_category_l1,p_category_l2,NULL)),
    prev0 AS (SELECT * FROM mart.get_category_period_summary(p_shop_name,v_prev_start,v_prev_end,p_category_level,p_category_l1,p_category_l2,NULL)),
    cur AS (SELECT c.*,CASE p_metric_key WHEN 'user_pay_amount' THEN c.user_pay_amount WHEN 'refund_amount_pay_time' THEN c.refund_amount_pay_time WHEN 'refund_rate_pay_time' THEN c.refund_rate_pay_time END::numeric val FROM cur0 c),
    prev AS (SELECT p.*,CASE p_metric_key WHEN 'user_pay_amount' THEN p.user_pay_amount WHEN 'refund_amount_pay_time' THEN p.refund_amount_pay_time WHEN 'refund_rate_pay_time' THEN p.refund_rate_pay_time END::numeric val FROM prev0 p),
    cr AS (SELECT c.*,DENSE_RANK() OVER(ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN c.val END DESC NULLS LAST,CASE WHEN upper(p_sort_direction)='ASC' THEN c.val END ASC NULLS LAST,c.category_l1,c.category_l2,c.category_l3) rnk FROM cur c),
    pr AS (SELECT p.*,DENSE_RANK() OVER(ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN p.val END DESC NULLS LAST,CASE WHEN upper(p_sort_direction)='ASC' THEN p.val END ASC NULLS LAST,p.category_l1,p.category_l2,p.category_l3) rnk FROM prev p),
    j AS (SELECT COALESCE(cr.shop_name,pr.shop_name) shop_name,COALESCE(cr.category_level,pr.category_level) category_level,COALESCE(cr.category_l1,pr.category_l1) category_l1,COALESCE(cr.category_l2,pr.category_l2) category_l2,COALESCE(cr.category_l3,pr.category_l3) category_l3,COALESCE(cr.category_l4,pr.category_l4) category_l4,cr.val cur_val,pr.val prev_val,cr.rnk cur_rank,pr.rnk prev_rank FROM cr FULL JOIN pr ON cr.category_level=pr.category_level AND cr.category_l1=pr.category_l1 AND cr.category_l2=pr.category_l2 AND cr.category_l3=pr.category_l3 AND cr.category_l4=pr.category_l4),
    s AS (SELECT j.*,CASE WHEN prev_val IS NULL THEN NULL ELSE cur_val-prev_val END abs_chg,CASE WHEN prev_val IS NULL OR prev_val=0 THEN NULL ELSE (cur_val-prev_val)/prev_val END rel_chg,CASE WHEN v_type='ratio' AND prev_val IS NOT NULL THEN cur_val-prev_val ELSE NULL END pp_chg,CASE WHEN cur_rank IS NULL OR prev_rank IS NULL THEN NULL ELSE prev_rank-cur_rank END rank_chg FROM j)
    SELECT s.shop_name,s.category_level,s.category_l1,s.category_l2,s.category_l3,s.category_l4,p_metric_key,v_name,v_type,p_start_date,p_end_date,v_prev_start,v_prev_end,s.cur_val,s.prev_val,s.abs_chg,s.rel_chg,s.pp_chg,s.cur_rank,s.prev_rank,s.rank_chg FROM s
    ORDER BY
      CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='DESC' THEN s.cur_val END DESC NULLS LAST,
      CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='ASC' THEN s.cur_val END ASC NULLS LAST,
      CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='DESC' THEN s.abs_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='ASC' THEN s.abs_chg END ASC NULLS LAST,
      CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='DESC' THEN s.rel_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='ASC' THEN s.rel_chg END ASC NULLS LAST,
      CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='DESC' THEN s.rank_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='ASC' THEN s.rank_chg END ASC NULLS LAST,
      s.category_l1,s.category_l2,s.category_l3 LIMIT p_limit;
END; $$;


ALTER FUNCTION mart.rank_categories(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) OWNER TO postgres;

--
-- Name: FUNCTION rank_categories(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.rank_categories(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) IS '类目排名；强制同一category_level内比较，父子层级不混排。';


--
-- Name: rank_price_bands(text, date, date, text, text, text, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.rank_price_bands(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text DEFAULT 'user_pay_amount'::text, p_sort_by text DEFAULT 'current_value'::text, p_sort_direction text DEFAULT 'DESC'::text, p_limit integer DEFAULT 20) RETURNS TABLE(shop_name text, price_band text, metric_key text, metric_name_cn text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE v_prev_start date;v_prev_end date;v_name text;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date); PERFORM mart.assert_rank_args('price_band',p_metric_key,p_sort_by,p_sort_direction,p_limit);
    SELECT w.metric_name_cn INTO v_name FROM mart.analysis_metric_whitelist w WHERE w.domain_key='price_band' AND w.metric_key=p_metric_key;
    SELECT pp.previous_start_date,pp.previous_end_date INTO v_prev_start,v_prev_end FROM mart.previous_period(p_start_date,p_end_date) pp;
    RETURN QUERY
    WITH cur AS (SELECT p.shop_name,p.price_band,p.user_pay_amount::numeric val FROM mart.get_price_band_period_summary(p_shop_name,p_start_date,p_end_date,NULL) p),
         prev AS (SELECT p.shop_name,p.price_band,p.user_pay_amount::numeric val FROM mart.get_price_band_period_summary(p_shop_name,v_prev_start,v_prev_end,NULL) p),
         cr AS (SELECT c.*,DENSE_RANK() OVER(ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN c.val END DESC,CASE WHEN upper(p_sort_direction)='ASC' THEN c.val END ASC,c.price_band) rnk FROM cur c),
         pr AS (SELECT p.*,DENSE_RANK() OVER(ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN p.val END DESC,CASE WHEN upper(p_sort_direction)='ASC' THEN p.val END ASC,p.price_band) rnk FROM prev p),
         j AS (SELECT COALESCE(cr.shop_name,pr.shop_name) shop_name,COALESCE(cr.price_band,pr.price_band) price_band,cr.val cur_val,pr.val prev_val,cr.rnk cur_rank,pr.rnk prev_rank FROM cr FULL JOIN pr USING(price_band)),
         s AS (SELECT j.*,CASE WHEN prev_val IS NULL THEN NULL ELSE cur_val-prev_val END abs_chg,CASE WHEN prev_val IS NULL OR prev_val=0 THEN NULL ELSE (cur_val-prev_val)/prev_val END rel_chg,CASE WHEN cur_rank IS NULL OR prev_rank IS NULL THEN NULL ELSE prev_rank-cur_rank END rank_chg FROM j)
    SELECT s.shop_name,s.price_band,p_metric_key,v_name,p_start_date,p_end_date,v_prev_start,v_prev_end,s.cur_val,s.prev_val,s.abs_chg,s.rel_chg,s.cur_rank,s.prev_rank,s.rank_chg FROM s
    ORDER BY CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='DESC' THEN s.cur_val END DESC NULLS LAST,CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='ASC' THEN s.cur_val END ASC NULLS LAST,CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='DESC' THEN s.abs_chg END DESC NULLS LAST,CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='ASC' THEN s.abs_chg END ASC NULLS LAST,CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='DESC' THEN s.rel_chg END DESC NULLS LAST,CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='ASC' THEN s.rel_chg END ASC NULLS LAST,CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='DESC' THEN s.rank_chg END DESC NULLS LAST,CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='ASC' THEN s.rank_chg END ASC NULLS LAST,s.price_band LIMIT p_limit;
END; $$;


ALTER FUNCTION mart.rank_price_bands(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) OWNER TO postgres;

--
-- Name: FUNCTION rank_price_bands(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.rank_price_bands(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) IS '价格带排名；6个价格带已验证互斥。';


--
-- Name: rank_products(text, date, date, text, text, text, integer, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.rank_products(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text DEFAULT 'user_pay_amount'::text, p_sort_by text DEFAULT 'current_value'::text, p_sort_direction text DEFAULT 'DESC'::text, p_limit integer DEFAULT 20, p_product_id text DEFAULT NULL::text, p_product_name text DEFAULT NULL::text) RETURNS TABLE(shop_name text, product_id text, product_name text, metric_key text, metric_name_cn text, value_type text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_prev_start date; v_prev_end date; v_type text; v_name text;
BEGIN
    PERFORM mart.assert_period(p_start_date,p_end_date);
    PERFORM mart.assert_rank_args('product',p_metric_key,p_sort_by,p_sort_direction,p_limit);
    SELECT w.metric_name_cn,w.value_type INTO v_name,v_type FROM mart.analysis_metric_whitelist w WHERE w.domain_key='product' AND w.metric_key=p_metric_key;
    SELECT pp.previous_start_date,pp.previous_end_date INTO v_prev_start,v_prev_end FROM mart.previous_period(p_start_date,p_end_date) pp;

    IF p_product_id IS NOT NULL AND p_product_name IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM core.douyin_product_daily p JOIN meta.shop s ON s.shop_id=p.shop_id
        WHERE (p_shop_name IS NULL OR s.shop_name=p_shop_name) AND p.product_id=p_product_id AND p.product_name=p_product_name
    ) THEN
        RAISE EXCEPTION 'product_id=% 与 product_name=% 未指向同一商品。',p_product_id,p_product_name;
    END IF;

    RETURN QUERY
    WITH cur0 AS (
        SELECT * FROM mart.get_product_period_summary(p_shop_name,p_start_date,p_end_date,NULL,NULL,'全部')
    ), cur AS (
        SELECT c.shop_name,c.product_id,c.product_name,
               CASE p_metric_key WHEN 'user_pay_amount' THEN c.user_pay_amount WHEN 'refund_amount_pay_time' THEN c.refund_amount_pay_time WHEN 'refund_rate_pay_time' THEN c.refund_rate_pay_time END::numeric AS val
        FROM cur0 c
    ), prev0 AS (
        SELECT * FROM mart.get_product_period_summary(p_shop_name,v_prev_start,v_prev_end,NULL,NULL,'全部')
    ), prev AS (
        SELECT p.shop_name,p.product_id,p.product_name,
               CASE p_metric_key WHEN 'user_pay_amount' THEN p.user_pay_amount WHEN 'refund_amount_pay_time' THEN p.refund_amount_pay_time WHEN 'refund_rate_pay_time' THEN p.refund_rate_pay_time END::numeric AS val
        FROM prev0 p
    ), cr AS (
        SELECT c.*,DENSE_RANK() OVER (ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN c.val END DESC NULLS LAST,CASE WHEN upper(p_sort_direction)='ASC' THEN c.val END ASC NULLS LAST,c.product_id) AS rnk FROM cur c
    ), pr AS (
        SELECT p.*,DENSE_RANK() OVER (ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN p.val END DESC NULLS LAST,CASE WHEN upper(p_sort_direction)='ASC' THEN p.val END ASC NULLS LAST,p.product_id) AS rnk FROM prev p
    ), j AS (
        SELECT COALESCE(cr.shop_name,pr.shop_name) shop_name,COALESCE(cr.product_id,pr.product_id) product_id,COALESCE(cr.product_name,pr.product_name) product_name,
               cr.val cur_val,pr.val prev_val,cr.rnk cur_rank,pr.rnk prev_rank
        FROM cr FULL JOIN pr USING(product_id)
    ), s AS (
        SELECT j.*,
               CASE WHEN prev_val IS NULL THEN NULL ELSE cur_val-prev_val END abs_chg,
               CASE WHEN prev_val IS NULL OR prev_val=0 THEN NULL ELSE (cur_val-prev_val)/prev_val END rel_chg,
               CASE WHEN v_type='ratio' AND prev_val IS NOT NULL THEN cur_val-prev_val ELSE NULL END pp_chg,
               CASE WHEN cur_rank IS NULL OR prev_rank IS NULL THEN NULL ELSE prev_rank-cur_rank END rank_chg
        FROM j
    )
    SELECT s.shop_name,s.product_id,s.product_name,p_metric_key,v_name,v_type,p_start_date,p_end_date,v_prev_start,v_prev_end,
           s.cur_val,s.prev_val,s.abs_chg,s.rel_chg,s.pp_chg,s.cur_rank,s.prev_rank,s.rank_chg
    FROM s
    WHERE (p_product_id IS NULL OR s.product_id=p_product_id) AND (p_product_name IS NULL OR s.product_name=p_product_name)
    ORDER BY
      CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='DESC' THEN s.cur_val END DESC NULLS LAST,
      CASE WHEN p_sort_by='current_value' AND upper(p_sort_direction)='ASC' THEN s.cur_val END ASC NULLS LAST,
      CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='DESC' THEN s.abs_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='absolute_change' AND upper(p_sort_direction)='ASC' THEN s.abs_chg END ASC NULLS LAST,
      CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='DESC' THEN s.rel_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='relative_change' AND upper(p_sort_direction)='ASC' THEN s.rel_chg END ASC NULLS LAST,
      CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='DESC' THEN s.rank_chg END DESC NULLS LAST,
      CASE WHEN p_sort_by='rank_change' AND upper(p_sort_direction)='ASC' THEN s.rank_chg END ASC NULLS LAST,
      s.product_id
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION mart.rank_products(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_product_id text, p_product_name text) OWNER TO postgres;

--
-- Name: FUNCTION rank_products(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_product_id text, p_product_name text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.rank_products(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_product_id text, p_product_name text) IS '商品排名/增长/下降/排名变化；默认carrier=全部的平台独立TOTAL；过滤商品时先全量排名再过滤，保留真实名次。';


--
-- Name: resolve_scope(character varying); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.resolve_scope(p_scope character varying) RETURNS TABLE(scope_semantic character varying, sale_scope character varying, carrier_type character varying, ad_period character varying, is_total boolean, rule_note text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_sale VARCHAR := NULL;
    v_carrier VARCHAR := NULL;
    v_period VARCHAR := '不限';
    v_total BOOLEAN := FALSE;
    v_note TEXT := '';
BEGIN
    p_scope := NULLIF(TRIM(p_scope), '');
    IF p_scope IS NULL OR p_scope = '全店' THEN
        v_sale := '全部'; v_carrier := '全部'; v_total := TRUE;
        v_note := '平台合法TOTAL：sale_scope=全部, carrier=全部, ad_period=不限';
    ELSIF p_scope = '自营' THEN
        v_sale := '自营'; v_carrier := '全部';
        v_note := '自营总览：carrier=全部(平台TOTAL)';
    ELSIF p_scope = '合作' THEN
        v_sale := '合作'; v_carrier := '全部';
        v_note := '合作总览：carrier=全部(平台TOTAL)';
    ELSIF p_scope = '商品卡' THEN
        v_sale := '全部'; v_carrier := '商品卡';
        v_note := '全部商品卡：sale_scope=全部, carrier=商品卡';
    ELSIF p_scope = '短视频' THEN
        v_sale := '全部'; v_carrier := '短视频';
        v_note := '全部短视频：sale_scope=全部, carrier=短视频';
    ELSIF p_scope = '直播' THEN
        v_sale := '全部'; v_carrier := '直播';
        v_note := '全部直播：sale_scope=全部, carrier=直播';
    ELSIF p_scope = '图文' THEN
        v_sale := '全部'; v_carrier := '图文';
        v_note := '全部图文：sale_scope=全部, carrier=图文';
    ELSIF p_scope = '其他' THEN
        v_sale := '全部'; v_carrier := '其他';
        v_note := '全部其他：sale_scope=全部, carrier=其他';
    ELSIF p_scope = '自营商品卡' THEN
        v_sale := '自营'; v_carrier := '商品卡';
        v_note := '自营×商品卡组合';
    ELSIF p_scope = '合作商品卡' THEN
        v_sale := '合作'; v_carrier := '商品卡';
        v_note := '合作×商品卡组合';
    ELSIF p_scope = '自营短视频' THEN
        v_sale := '自营'; v_carrier := '短视频';
        v_note := '自营×短视频组合';
    ELSIF p_scope = '合作短视频' THEN
        v_sale := '合作'; v_carrier := '短视频';
        v_note := '合作×短视频组合';
    ELSIF p_scope = '自营直播' THEN
        v_sale := '自营'; v_carrier := '直播';
        v_note := '自营×直播组合';
    ELSIF p_scope = '合作直播' THEN
        v_sale := '合作'; v_carrier := '直播';
        v_note := '合作×直播组合';
    ELSIF p_scope = '自营图文' THEN
        v_sale := '自营'; v_carrier := '图文';
        v_note := '自营×图文组合';
    ELSIF p_scope = '合作图文' THEN
        v_sale := '合作'; v_carrier := '图文';
        v_note := '合作×图文组合';
    ELSIF p_scope = '自营其他' THEN
        v_sale := '自营'; v_carrier := '其他';
        v_note := '自营×其他组合';
    ELSIF p_scope = '合作其他' THEN
        v_sale := '合作'; v_carrier := '其他';
        v_note := '合作×其他组合';
    ELSE
        RAISE EXCEPTION '未识别经营语义: %', p_scope;
    END IF;

    RETURN QUERY SELECT p_scope, v_sale, v_carrier, v_period, v_total, v_note;
END;
$$;


ALTER FUNCTION mart.resolve_scope(p_scope character varying) OWNER TO postgres;

--
-- Name: FUNCTION resolve_scope(p_scope character varying); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.resolve_scope(p_scope character varying) IS 'Scope Resolver：将经营语义（全店/自营/合作/载体/组合）解析为真实过滤条件；TOTAL优先平台合法口径，禁止父级+子级SUM。';


--
-- Name: scope_daily(character varying, date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.scope_daily(p_scope character varying, p_date_from date, p_date_to date) RETURNS TABLE(shop_name character varying, biz_date date, sale_scope character varying, carrier_type character varying, ad_period character varying, user_pay_amount numeric, transaction_amount numeric)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_sale VARCHAR;
    v_carrier VARCHAR;
    v_period VARCHAR;
    v_total BOOLEAN;
BEGIN
    SELECT r.sale_scope, r.carrier_type, r.ad_period, r.is_total
    INTO v_sale, v_carrier, v_period, v_total
    FROM mart.resolve_scope(p_scope) r;

    RETURN QUERY
    SELECT s.shop_name, d.biz_date, d.sale_scope, d.carrier_type, d.ad_period,
           d.user_pay_amount, d.transaction_amount
    FROM core.douyin_deal_daily d
    JOIN meta.shop s ON d.shop_id = s.shop_id
    WHERE d.sale_scope = v_sale
      AND d.carrier_type = v_carrier
      AND d.ad_period = v_period
      AND d.biz_date BETWEEN p_date_from AND p_date_to
    ORDER BY d.biz_date;
END;
$$;


ALTER FUNCTION mart.scope_daily(p_scope character varying, p_date_from date, p_date_to date) OWNER TO postgres;

--
-- Name: FUNCTION scope_daily(p_scope character varying, p_date_from date, p_date_to date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.scope_daily(p_scope character varying, p_date_from date, p_date_to date) IS '按经营语义查询每日数据（使用deal_daily合法TOTAL/明细口径）。';


--
-- Name: account_daily; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.account_daily AS
 SELECT s.shop_name,
    a.biz_date,
    a.sale_scope,
    a.account_name,
    a.account_type,
    a.transaction_amount,
    a.user_pay_amount,
    a.settlement_amount,
    a.transaction_refund_amount_pay_time,
    a.refund_amount_pay_time,
    a.refund_rate_pay_time,
    a.transaction_order_count,
    a.transaction_item_count,
    a.transaction_buyer_count,
    a.net_transaction_amount
   FROM (core.douyin_account_daily a
     JOIN meta.shop s ON ((a.shop_id = s.shop_id)));


ALTER VIEW mart.account_daily OWNER TO postgres;

--
-- Name: VIEW account_daily; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.account_daily IS '账号拆分/排名（单账号、TOP账号、合作账号拆分；不提供全部账号/自营总/全店总量，总量回deal_daily）。';


--
-- Name: COLUMN account_daily.account_name; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.account_daily.account_name IS '账号名称。更多账号=aggregate_bucket(合作剩余桶)；弹动官方旗舰店=自营具体账号';


--
-- Name: COLUMN account_daily.refund_rate_pay_time; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.account_daily.refund_rate_pay_time IS '退款率(支付时间)。非可加';


--
-- Name: analysis_metric_whitelist; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.analysis_metric_whitelist AS
 SELECT domain_key,
    metric_key,
    metric_name_cn,
    value_type,
    rank_allowed,
    contribution_allowed,
    default_rank_direction
   FROM ( VALUES ('business'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('business'::text,'transaction_amount'::text,'成交金额'::text,'additive'::text,true,true,'DESC'::text), ('business'::text,'refund_amount_pay_time'::text,'退款金额(支付时间)'::text,'additive'::text,true,true,'DESC'::text), ('business'::text,'settlement_amount'::text,'结算金额'::text,'additive'::text,true,false,'DESC'::text), ('business'::text,'transaction_order_count'::text,'成交订单数'::text,'additive'::text,true,false,'DESC'::text), ('business'::text,'transaction_buyer_count'::text,'成交人数'::text,'additive'::text,true,false,'DESC'::text), ('business'::text,'transaction_item_count'::text,'成交件数'::text,'additive'::text,true,false,'DESC'::text), ('business'::text,'avg_customer_amount'::text,'客单价'::text,'average'::text,true,false,'DESC'::text), ('business'::text,'avg_item_amount'::text,'件单价'::text,'average'::text,true,false,'DESC'::text), ('business'::text,'refund_rate_pay_time'::text,'退款率(支付时间)'::text,'ratio'::text,true,false,'ASC'::text), ('business'::text,'exposure_to_click_rate_users'::text,'商品曝光-点击转化率(人数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'click_to_transaction_rate_users'::text,'商品点击-成交转化率(人数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'exposure_to_transaction_rate_users'::text,'商品曝光-成交转化率(人数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'exposure_to_click_rate_events'::text,'商品曝光-点击转化率(次数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'click_to_transaction_rate_events'::text,'商品点击-成交转化率(次数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'exposure_to_transaction_rate_events'::text,'商品曝光-成交转化率(次数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'user_pay_amount_per_1000_exposures'::text,'千次曝光用户支付金额'::text,'average'::text,true,false,'DESC'::text), ('product'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('product'::text,'refund_amount_pay_time'::text,'退款金额(支付时间)'::text,'additive'::text,true,true,'DESC'::text), ('product'::text,'refund_rate_pay_time'::text,'退款率(支付时间)'::text,'ratio'::text,true,false,'ASC'::text), ('account'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('account'::text,'transaction_amount'::text,'成交金额'::text,'additive'::text,true,true,'DESC'::text), ('account'::text,'refund_amount_pay_time'::text,'退款金额(支付时间)'::text,'additive'::text,true,true,'DESC'::text), ('account'::text,'refund_rate_pay_time'::text,'退款率(支付时间)'::text,'ratio'::text,true,false,'ASC'::text), ('account'::text,'transaction_order_count'::text,'成交订单数'::text,'additive'::text,true,false,'DESC'::text), ('account'::text,'transaction_buyer_count'::text,'成交人数'::text,'additive'::text,true,false,'DESC'::text), ('account'::text,'avg_customer_amount'::text,'客单价'::text,'average'::text,true,false,'DESC'::text), ('carrier'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('carrier'::text,'transaction_amount'::text,'成交金额'::text,'additive'::text,true,true,'DESC'::text), ('carrier'::text,'refund_amount_pay_time'::text,'退款金额(支付时间)'::text,'additive'::text,true,true,'DESC'::text), ('carrier'::text,'refund_rate_pay_time'::text,'退款率(支付时间)'::text,'ratio'::text,true,false,'ASC'::text), ('category'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('category'::text,'refund_amount_pay_time'::text,'退款金额(支付时间)'::text,'additive'::text,true,true,'DESC'::text), ('category'::text,'refund_rate_pay_time'::text,'退款率(支付时间)'::text,'ratio'::text,true,false,'ASC'::text), ('price_band'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('audience'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('audience'::text,'transaction_buyer_count'::text,'成交人数'::text,'additive'::text,true,true,'DESC'::text), ('audience'::text,'transaction_order_count'::text,'成交订单数'::text,'additive'::text,true,true,'DESC'::text), ('audience'::text,'avg_customer_amount'::text,'客单价'::text,'average'::text,true,false,'DESC'::text)) v(domain_key, metric_key, metric_name_cn, value_type, rank_allowed, contribution_allowed, default_rank_direction);


ALTER VIEW mart.analysis_metric_whitelist OWNER TO postgres;

--
-- Name: VIEW analysis_metric_whitelist; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.analysis_metric_whitelist IS '阶段3分析指标白名单。排名/贡献/环比禁止接受任意字段名；value_type=ratio时可计算百分点变化。';


--
-- Name: audience_daily; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.audience_daily AS
 SELECT s.shop_name,
    a.biz_date,
    a.audience_type,
    a.carrier_type,
    a.user_pay_amount,
    a.transaction_buyer_count,
    a.avg_customer_amount,
    a.transaction_order_count,
    a.repeat_user_repeat_rate
   FROM (core.douyin_audience_daily a
     JOIN meta.shop s ON ((a.shop_id = s.shop_id)));


ALTER VIEW mart.audience_daily OWNER TO postgres;

--
-- Name: VIEW audience_daily; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.audience_daily IS '人群拆分（carrier_type=全部为合法TOTAL 60/60天验证；总览用全部，拆分用5载体明细，禁止TOTAL+DETAIL一起SUM）。';


--
-- Name: COLUMN audience_daily.avg_customer_amount; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.audience_daily.avg_customer_amount IS '客单价。非可加';


--
-- Name: COLUMN audience_daily.repeat_user_repeat_rate; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.audience_daily.repeat_user_repeat_rate IS '复购用户复购率。非可加';


--
-- Name: carrier_daily; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.carrier_daily AS
 SELECT s.shop_name,
    c.biz_date,
    c.sale_scope,
    c.carrier_type,
    c.account_channel,
    c.douyin_account_id,
    c.transaction_amount,
    c.user_pay_amount,
    c.settlement_amount,
    c.transaction_refund_amount_pay_time,
    c.refund_amount_pay_time,
    c.refund_rate_pay_time,
    c.ad_attributed_transaction_amount,
    c.ad_attributed_transaction_share,
    c.transaction_order_count,
    c.transaction_item_count,
    c.transaction_buyer_count,
    c.net_transaction_amount
   FROM (core.douyin_carrier_daily c
     JOIN meta.shop s ON ((c.shop_id = s.shop_id)));


ALTER VIEW mart.carrier_daily OWNER TO postgres;

--
-- Name: VIEW carrier_daily; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.carrier_daily IS '载体/渠道拆分与排名（不提供全店TOTAL；合作域明细+更多账号可SUM；全域投放时段/标准+品牌投放为special_overlap禁止与明细SUM）。';


--
-- Name: COLUMN carrier_daily.account_channel; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.carrier_daily.account_channel IS '账号/渠道。更多账号=aggregate_bucket(合作剩余桶)；全域投放时段/标准+品牌投放=special_overlap(禁与明细SUM)；自营更多账号=待确认';


--
-- Name: COLUMN carrier_daily.ad_attributed_transaction_share; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.carrier_daily.ad_attributed_transaction_share IS '投放贡献成交占比。非可加';


--
-- Name: category_daily; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.category_daily AS
 SELECT s.shop_name,
    c.biz_date,
    c.category_level_1 AS category_l1,
    c.category_level_2 AS category_l2,
    c.category_level_3 AS category_l3,
    c.category_level_4 AS category_l4,
        CASE
            WHEN ((c.category_level_4 IS NULL) OR ((c.category_level_4)::text = ''::text) OR ((c.category_level_4)::text = '全部'::text)) THEN
            CASE
                WHEN ((c.category_level_3 IS NULL) OR ((c.category_level_3)::text = ''::text) OR ((c.category_level_3)::text = '全部'::text)) THEN
                CASE
                    WHEN ((c.category_level_2 IS NULL) OR ((c.category_level_2)::text = ''::text) OR ((c.category_level_2)::text = '全部'::text)) THEN 1
                    ELSE 2
                END
                ELSE 3
            END
            ELSE 4
        END AS category_level,
    (((c.category_level_4)::text = '全部'::text) OR ((c.category_level_4)::text = ''::text) OR (c.category_level_4 IS NULL)) AS is_total_row,
    c.user_pay_amount,
    c.avg_transaction_order_amount,
    c.click_to_transaction_rate_events,
    c.refund_amount_pay_time,
    c.refund_rate_pay_time
   FROM (core.douyin_category_daily c
     JOIN meta.shop s ON ((c.shop_id = s.shop_id)));


ALTER VIEW mart.category_daily OWNER TO postgres;

--
-- Name: VIEW category_daily; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.category_daily IS '类目拆分（含层级识别：category_level 1/2/3/4；is_total_row=是否父级占位行；不同层级禁止混SUM）。';


--
-- Name: COLUMN category_daily.category_level; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.category_daily.category_level IS '类目层级：1=L1汇总行 2=L2 3=L3 4=L4明细。系统人工字典';


--
-- Name: COLUMN category_daily.is_total_row; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.category_daily.is_total_row IS '是否汇总行：由"全部"占位识别，为TRUE时是父级TOTAL。系统人工字典';


--
-- Name: COLUMN category_daily.avg_transaction_order_amount; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.category_daily.avg_transaction_order_amount IS '成交笔单价。非可加';


--
-- Name: COLUMN category_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.category_daily.click_to_transaction_rate_events IS '商品点击-成交转化率(次数)。非可加';


--
-- Name: COLUMN category_daily.refund_rate_pay_time; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.category_daily.refund_rate_pay_time IS '退款率(支付时间)。非可加';


--
-- Name: content_daily; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.content_daily AS
 SELECT s.shop_name,
    c.biz_date,
    c.selling_type,
    c.carrier_type,
    c.content_id,
    c.content_title,
    c.transaction_amount,
    c.user_pay_amount,
    c.settlement_amount,
    c.transaction_refund_amount_pay_time,
    c.refund_amount_pay_time,
    c.refund_rate_pay_time,
    c.transaction_order_count,
    c.transaction_item_count,
    c.transaction_buyer_count,
    c.net_transaction_amount
   FROM (core.douyin_content_daily c
     JOIN meta.shop s ON ((c.shop_id = s.shop_id)));


ALTER VIEW mart.content_daily OWNER TO postgres;

--
-- Name: VIEW content_daily; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.content_daily IS '单内容(直播间/短视频/图文)拆分；当前真实样本仅商品卡载体(自营/合作)，为其他载体预留不制造数据。';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: mart_dimension_rule; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.mart_dimension_rule (
    rule_id bigint NOT NULL,
    source_schema character varying(50) DEFAULT 'core'::character varying NOT NULL,
    source_table character varying(100) NOT NULL,
    dimension_name character varying(100) NOT NULL,
    dimension_value character varying(200) NOT NULL,
    rule_type character varying(30) NOT NULL,
    parent_dimension character varying(100),
    parent_value character varying(200),
    aggregation_allowed boolean DEFAULT true NOT NULL,
    preferred_total boolean DEFAULT false NOT NULL,
    scope_role character varying(30) DEFAULT 'detail'::character varying NOT NULL,
    rule_status character varying(30) DEFAULT '已确认'::character varying NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE mart.mart_dimension_rule OWNER TO postgres;

--
-- Name: TABLE mart_dimension_rule; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON TABLE mart.mart_dimension_rule IS 'mart维度治理表：登记TOTAL/DETAIL/独立口径/禁止汇总规则，供Scope Resolver和Daily Mart使用。';


--
-- Name: mart_dimension_rule_rule_id_seq; Type: SEQUENCE; Schema: mart; Owner: postgres
--

CREATE SEQUENCE mart.mart_dimension_rule_rule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE mart.mart_dimension_rule_rule_id_seq OWNER TO postgres;

--
-- Name: mart_dimension_rule_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: mart; Owner: postgres
--

ALTER SEQUENCE mart.mart_dimension_rule_rule_id_seq OWNED BY mart.mart_dimension_rule.rule_id;


--
-- Name: metric_rule_v14; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.metric_rule_v14 AS
 SELECT target_schema,
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
  WHERE ((mapping_version)::text = 'V1.4'::text);


ALTER VIEW mart.metric_rule_v14 OWNER TO postgres;

--
-- Name: VIEW metric_rule_v14; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.metric_rule_v14 IS 'V1.4非可加指标规则只读目录。阶段2函数公式必须与此目录保持一致。';


--
-- Name: price_band_daily; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.price_band_daily AS
 SELECT s.shop_name,
    p.biz_date,
    p.price_band,
    p.user_pay_amount,
    p.avg_transaction_order_amount,
    p.click_to_transaction_rate_events
   FROM (core.douyin_price_band_daily p
     JOIN meta.shop s ON ((p.shop_id = s.shop_id)));


ALTER VIEW mart.price_band_daily OWNER TO postgres;

--
-- Name: VIEW price_band_daily; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.price_band_daily IS '价格带拆分（6个价格带已验证互斥，可安全SUM重建店铺总量diff=0.00）。';


--
-- Name: COLUMN price_band_daily.avg_transaction_order_amount; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.price_band_daily.avg_transaction_order_amount IS '成交笔单价。非可加';


--
-- Name: COLUMN price_band_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.price_band_daily.click_to_transaction_rate_events IS '商品点击-成交转化率(次数)。非可加';


--
-- Name: product_daily; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.product_daily AS
 SELECT s.shop_name,
    p.biz_date,
    p.product_id,
    p.product_name,
    p.carrier_type,
    p.user_pay_amount,
    p.avg_transaction_order_amount,
    p.click_to_transaction_rate_events,
    p.refund_amount_pay_time,
    p.refund_rate_pay_time,
    p.smart_coupon_amount,
    p.platform_subsidy_amount
   FROM (core.douyin_product_daily p
     JOIN meta.shop s ON ((p.shop_id = s.shop_id)));


ALTER VIEW mart.product_daily OWNER TO postgres;

--
-- Name: VIEW product_daily; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.product_daily IS '商品拆分（carrier_type=全部为平台独立总口径，商品总览优先读取；商品卡+图文+直播+短视频禁止重建全部）。';


--
-- Name: COLUMN product_daily.product_id; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.product_daily.product_id IS '商品编号(ID类按文本)';


--
-- Name: COLUMN product_daily.avg_transaction_order_amount; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.product_daily.avg_transaction_order_amount IS '成交笔单价。非可加';


--
-- Name: COLUMN product_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.product_daily.click_to_transaction_rate_events IS '商品点击-成交转化率(次数)。非可加';


--
-- Name: COLUMN product_daily.refund_rate_pay_time; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.product_daily.refund_rate_pay_time IS '退款率(支付时间)。非可加';


--
-- Name: shop_daily; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.shop_daily AS
 SELECT s.shop_name,
    d.biz_date,
    d.user_pay_amount,
    d.net_user_pay_amount_pay_time,
    d.smart_coupon_amount,
    d.platform_subsidy_amount,
    d.transaction_order_count,
    d.transaction_buyer_count,
    d.avg_customer_amount,
    d.transaction_amount,
    d.net_transaction_amount,
    d.refund_amount_pay_time,
    d.refund_rate_pay_time,
    d.settlement_amount,
    d.creator_subsidy_amount,
    d.transaction_item_count,
    d.avg_item_amount
   FROM (core.douyin_deal_daily d
     JOIN meta.shop s ON ((d.shop_id = s.shop_id)))
  WHERE (((d.sale_scope)::text = '全部'::text) AND ((d.carrier_type)::text = '全部'::text) AND ((d.ad_period)::text = '不限'::text));


ALTER VIEW mart.shop_daily OWNER TO postgres;

--
-- Name: VIEW shop_daily; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.shop_daily IS '店铺每日总览：全店合法TOTAL口径(sale_scope=全部+carrier=全部+ad_period=不限)，粒度店铺×日期，每天唯一1行。';


--
-- Name: COLUMN shop_daily.shop_name; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.shop_daily.shop_name IS '店铺名称(对外统一显示，来源meta.shop)';


--
-- Name: COLUMN shop_daily.user_pay_amount; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.shop_daily.user_pay_amount IS '用户支付金额。SUM';


--
-- Name: COLUMN shop_daily.avg_customer_amount; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.shop_daily.avg_customer_amount IS '客单价。非可加(不可直接求和或平均)';


--
-- Name: COLUMN shop_daily.refund_rate_pay_time; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.shop_daily.refund_rate_pay_time IS '退款率(支付时间)。非可加(比率原值0-1外可>1)';


--
-- Name: COLUMN shop_daily.avg_item_amount; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON COLUMN mart.shop_daily.avg_item_amount IS '件单价。非可加';


--
-- Name: stage3_expected_scope_map; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.stage3_expected_scope_map AS
 SELECT scope_key,
    sale_scope,
    carrier_type,
    ad_period
   FROM ( VALUES ('全店'::text,'全部'::text,'全部'::text,'不限'::text), ('自营'::text,'自营'::text,'全部'::text,'不限'::text), ('合作'::text,'合作'::text,'全部'::text,'不限'::text), ('商品卡'::text,'全部'::text,'商品卡'::text,'不限'::text), ('短视频'::text,'全部'::text,'短视频'::text,'不限'::text), ('直播'::text,'全部'::text,'直播'::text,'不限'::text), ('图文'::text,'全部'::text,'图文'::text,'不限'::text), ('其他'::text,'全部'::text,'其他'::text,'不限'::text), ('自营商品卡'::text,'自营'::text,'商品卡'::text,'不限'::text), ('合作商品卡'::text,'合作'::text,'商品卡'::text,'不限'::text), ('自营短视频'::text,'自营'::text,'短视频'::text,'不限'::text), ('合作短视频'::text,'合作'::text,'短视频'::text,'不限'::text), ('自营直播'::text,'自营'::text,'直播'::text,'不限'::text), ('合作直播'::text,'合作'::text,'直播'::text,'不限'::text), ('自营图文'::text,'自营'::text,'图文'::text,'不限'::text), ('合作图文'::text,'合作'::text,'图文'::text,'不限'::text), ('自营其他'::text,'自营'::text,'其他'::text,'不限'::text), ('合作其他'::text,'合作'::text,'其他'::text,'不限'::text)) v(scope_key, sale_scope, carrier_type, ad_period);


ALTER VIEW mart.stage3_expected_scope_map OWNER TO postgres;

--
-- Name: VIEW stage3_expected_scope_map; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.stage3_expected_scope_map IS '阶段3固定Scope基线。WorkBuddy执行时须按本机阶段1 resolve_scope真实签名，将其与period_scope_rule逐条对比18/18一致；本脚本不猜测阶段1函数签名。';


--
-- Name: terminal_daily; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.terminal_daily AS
 SELECT s.shop_name,
    t.biz_date,
    t.terminal_type,
    t.selling_type,
    t.transaction_amount,
    t.user_pay_amount,
    t.settlement_amount,
    t.transaction_order_count,
    t.transaction_refund_amount_pay_time,
    t.refund_amount_pay_time,
    t.refund_rate_pay_time,
    t.transaction_item_count,
    t.transaction_refund_amount_refund_time
   FROM (core.douyin_terminal_daily t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW mart.terminal_daily OWNER TO postgres;

--
-- Name: VIEW terminal_daily; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.terminal_daily IS '终端拆分（terminal_type=整体为合法TOTAL优先用于总览；拆分时只取明细终端，禁止整体+明细一起SUM）。';


--
-- Name: mart_dimension_rule rule_id; Type: DEFAULT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.mart_dimension_rule ALTER COLUMN rule_id SET DEFAULT nextval('mart.mart_dimension_rule_rule_id_seq'::regclass);


--
-- Data for Name: mart_dimension_rule; Type: TABLE DATA; Schema: mart; Owner: postgres
--

COPY mart.mart_dimension_rule (rule_id, source_schema, source_table, dimension_name, dimension_value, rule_type, parent_dimension, parent_value, aggregation_allowed, preferred_total, scope_role, rule_status, notes, created_at) FROM stdin;
1	core	douyin_deal_daily	sale_scope	全部	total	\N	\N	t	t	total	已确认	合法TOTAL：=自营+合作(diff=0.00)	2026-08-07 18:09:27.903281+08
2	core	douyin_deal_daily	sale_scope	自营	detail	sale_scope	全部	t	f	detail	已确认	明细层级	2026-08-07 18:09:27.903281+08
3	core	douyin_deal_daily	sale_scope	合作	detail	sale_scope	全部	t	f	detail	已确认	明细层级	2026-08-07 18:09:27.903281+08
4	core	douyin_deal_daily	carrier_type	全部	total	\N	\N	t	t	total	已确认	合法TOTAL：=5载体之和(diff=0.00)	2026-08-07 18:09:27.903281+08
5	core	douyin_deal_daily	carrier_type	商品卡	detail	carrier_type	全部	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
6	core	douyin_deal_daily	carrier_type	直播	detail	carrier_type	全部	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
7	core	douyin_deal_daily	carrier_type	短视频	detail	carrier_type	全部	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
8	core	douyin_deal_daily	carrier_type	图文	detail	carrier_type	全部	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
9	core	douyin_deal_daily	carrier_type	其他	detail	carrier_type	全部	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
10	core	douyin_deal_daily	ad_period	不限	total	\N	\N	t	t	total	已确认	合法TOTAL：=3时段之和(diff=0.00)	2026-08-07 18:09:27.903281+08
12	core	douyin_deal_daily	ad_period	标准+品牌投放	detail	ad_period	不限	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
13	core	douyin_deal_daily	ad_period	非投放时段	detail	ad_period	不限	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
14	core	douyin_terminal_daily	terminal_type	整体	total	\N	\N	t	t	total	已确认	合法TOTAL：=4终端之和(diff=0.00)	2026-08-07 18:09:27.903281+08
15	core	douyin_terminal_daily	terminal_type	抖音	detail	terminal_type	整体	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
16	core	douyin_terminal_daily	terminal_type	抖音极速版	detail	terminal_type	整体	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
17	core	douyin_terminal_daily	terminal_type	红果短剧	detail	terminal_type	整体	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
18	core	douyin_terminal_daily	terminal_type	其他	detail	terminal_type	整体	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
19	core	douyin_product_daily	carrier_type	全部	independent_total	\N	\N	t	t	total	已确认	独立TOTAL：≠明细之和(约1万/日差)，禁止明细重建	2026-08-07 18:09:27.903281+08
20	core	douyin_product_daily	carrier_type	商品卡	detail	carrier_type	全部	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
21	core	douyin_product_daily	carrier_type	图文	detail	carrier_type	全部	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
22	core	douyin_product_daily	carrier_type	直播	detail	carrier_type	全部	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
23	core	douyin_product_daily	carrier_type	短视频	detail	carrier_type	全部	t	f	detail	已确认	明细	2026-08-07 18:09:27.903281+08
24	core	douyin_audience_daily	carrier_type	全部	total	\N	\N	t	t	total	已确认	合法TOTAL：60/60天匹配diff=0	2026-08-07 18:09:27.903281+08
25	core	douyin_account_daily	account_name	更多账号	aggregate_bucket	\N	\N	t	f	detail	已确认	合作剩余桶：明细+更多账号=合作总额(diff=0.00)	2026-08-07 18:09:27.903281+08
26	core	douyin_account_daily	account_name	弹动官方旗舰店	detail	\N	\N	t	f	detail	已确认	自营官方账号：具体账号，非total	2026-08-07 18:09:27.903281+08
27	core	douyin_carrier_daily	account_channel	更多账号	aggregate_bucket	\N	\N	t	f	detail	已确认	合作剩余桶：明细+更多账号=deal对应总额(diff=0.00)	2026-08-07 18:09:27.903281+08
29	core	douyin_carrier_daily	account_channel	标准+品牌投放	special_overlap	carrier_type	商品卡	f	f	special	已确认	TOTAL行(自营×商品卡)：禁止与其明细同时SUM	2026-08-07 18:09:27.903281+08
30	core	douyin_carrier_daily	account_channel	其他	aggregate_bucket	\N	\N	t	f	detail	已确认	独立剩余桶(自营×商品卡30行)	2026-08-07 18:09:27.903281+08
31	core	douyin_carrier_daily	account_name	更多账号	aggregate_bucket	\N	\N	t	f	detail	待确认	自营更多账号语义未最终确认，不自动汇总	2026-08-07 18:09:27.903281+08
11	core	douyin_deal_daily	ad_period	全域+乘方投放时段	detail	ad_period	不限	t	f	detail	已确认	明细 | 2026-08-08 平台导出口径更新: 全域投放时段改名全域+乘方投放时段	2026-08-07 18:09:27.903281+08
28	core	douyin_carrier_daily	account_channel	全域+乘方投放时段	special_overlap	carrier_type	商品卡	f	f	special	已确认	TOTAL行(自营×商品卡305万)：禁止与其明细同时SUM | 2026-08-08 平台导出口径更新: 全域投放时段改名全域+乘方投放时段	2026-08-07 18:09:27.903281+08
\.


--
-- Name: mart_dimension_rule_rule_id_seq; Type: SEQUENCE SET; Schema: mart; Owner: postgres
--

SELECT pg_catalog.setval('mart.mart_dimension_rule_rule_id_seq', 31, true);


--
-- Name: mart_dimension_rule mart_dimension_rule_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.mart_dimension_rule
    ADD CONSTRAINT mart_dimension_rule_pkey PRIMARY KEY (rule_id);


--
-- Name: mart_dimension_rule uk_dim_rule; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.mart_dimension_rule
    ADD CONSTRAINT uk_dim_rule UNIQUE (source_schema, source_table, dimension_name, dimension_value);


--
-- Name: SCHEMA mart; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA mart TO agent_readonly;


--
-- Name: FUNCTION assert_period(p_start_date date, p_end_date date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.assert_period(p_start_date date, p_end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.assert_period(p_start_date date, p_end_date date) TO agent_readonly;


--
-- Name: FUNCTION assert_rank_args(p_domain_key text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.assert_rank_args(p_domain_key text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.assert_rank_args(p_domain_key text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION compare_business_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.compare_business_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.compare_business_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) TO agent_readonly;


--
-- Name: FUNCTION format_percent_2(value_decimal numeric); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.format_percent_2(value_decimal numeric) FROM PUBLIC;


--
-- Name: FUNCTION get_account_contribution(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_account_name text, p_include_aggregate_bucket boolean, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_account_contribution(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_account_name text, p_include_aggregate_bucket boolean, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_account_contribution(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_account_name text, p_include_aggregate_bucket boolean, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION get_account_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_account_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_account_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_account_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_account_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_account_name text) TO agent_readonly;


--
-- Name: FUNCTION get_audience_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_audience_type text, p_carrier_type text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_audience_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_audience_type text, p_carrier_type text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_audience_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_audience_type text, p_carrier_type text) TO agent_readonly;


--
-- Name: FUNCTION get_business_contribution(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_business_contribution(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_business_contribution(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) TO agent_readonly;


--
-- Name: FUNCTION get_business_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_business_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_business_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) TO agent_readonly;


--
-- Name: FUNCTION get_carrier_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_carrier_type text, p_account_channel text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_carrier_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_carrier_type text, p_account_channel text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_carrier_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_carrier_type text, p_account_channel text) TO agent_readonly;


--
-- Name: FUNCTION get_category_contribution(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_category_contribution(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_category_contribution(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION get_category_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_category_l3 text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_category_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_category_l3 text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_category_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_category_l3 text) TO agent_readonly;


--
-- Name: FUNCTION get_content_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_selling_type text, p_carrier_type text, p_content_id text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_content_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_selling_type text, p_carrier_type text, p_content_id text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_content_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_selling_type text, p_carrier_type text, p_content_id text) TO agent_readonly;


--
-- Name: FUNCTION get_data_coverage(p_shop_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_data_coverage(p_shop_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_data_coverage(p_shop_name text) TO agent_readonly;


--
-- Name: FUNCTION get_price_band_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_price_band text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_price_band_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_price_band text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_price_band_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_price_band text) TO agent_readonly;


--
-- Name: FUNCTION get_product_contribution(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_product_id text, p_product_name text, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_product_contribution(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_product_id text, p_product_name text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_product_contribution(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_product_id text, p_product_name text, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION get_product_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_product_id text, p_product_name text, p_carrier_type text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_product_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_product_id text, p_product_name text, p_carrier_type text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_product_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_product_id text, p_product_name text, p_carrier_type text) TO agent_readonly;


--
-- Name: FUNCTION get_terminal_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_terminal_type text, p_selling_type text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_terminal_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_terminal_type text, p_selling_type text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_terminal_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_terminal_type text, p_selling_type text) TO agent_readonly;


--
-- Name: FUNCTION period_scope_rule(p_scope_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.period_scope_rule(p_scope_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.period_scope_rule(p_scope_key text) TO agent_readonly;


--
-- Name: FUNCTION previous_period(p_start_date date, p_end_date date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.previous_period(p_start_date date, p_end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.previous_period(p_start_date date, p_end_date date) TO agent_readonly;


--
-- Name: FUNCTION rank_accounts(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_include_aggregate_bucket boolean, p_account_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.rank_accounts(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_include_aggregate_bucket boolean, p_account_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.rank_accounts(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_include_aggregate_bucket boolean, p_account_name text) TO agent_readonly;


--
-- Name: FUNCTION rank_audiences(p_shop_name text, p_start_date date, p_end_date date, p_carrier_type text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.rank_audiences(p_shop_name text, p_start_date date, p_end_date date, p_carrier_type text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.rank_audiences(p_shop_name text, p_start_date date, p_end_date date, p_carrier_type text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION rank_carriers(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.rank_carriers(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.rank_carriers(p_shop_name text, p_start_date date, p_end_date date, p_sale_scope text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION rank_categories(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.rank_categories(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.rank_categories(p_shop_name text, p_start_date date, p_end_date date, p_category_level integer, p_category_l1 text, p_category_l2 text, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION rank_price_bands(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.rank_price_bands(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.rank_price_bands(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION rank_products(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_product_id text, p_product_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.rank_products(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_product_id text, p_product_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.rank_products(p_shop_name text, p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer, p_product_id text, p_product_name text) TO agent_readonly;


--
-- Name: FUNCTION resolve_scope(p_scope character varying); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.resolve_scope(p_scope character varying) FROM PUBLIC;


--
-- Name: FUNCTION scope_daily(p_scope character varying, p_date_from date, p_date_to date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.scope_daily(p_scope character varying, p_date_from date, p_date_to date) FROM PUBLIC;


--
-- Name: TABLE analysis_metric_whitelist; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.analysis_metric_whitelist TO agent_readonly;


--
-- Name: TABLE mart_dimension_rule; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.mart_dimension_rule TO agent_readonly;


--
-- Name: TABLE metric_rule_v14; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.metric_rule_v14 TO agent_readonly;


--
-- Name: TABLE stage3_expected_scope_map; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.stage3_expected_scope_map TO agent_readonly;


--
-- PostgreSQL database dump complete
--

