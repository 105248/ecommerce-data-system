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
-- Name: audit; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA audit;


ALTER SCHEMA audit OWNER TO postgres;

--
-- Name: SCHEMA audit; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA audit IS '审计记录层：保存文件导入批次、错误信息、处理结果和操作日志。';


--
-- Name: core; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA core;


ALTER SCHEMA core OWNER TO postgres;

--
-- Name: SCHEMA core; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA core IS '标准数据层：保存清洗完成、去重完成、可用于分析的正式日维度数据。';


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
-- Name: meta; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA meta;


ALTER SCHEMA meta OWNER TO postgres;

--
-- Name: SCHEMA meta; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA meta IS '基础资料层：保存平台、店铺、指标字典、字段映射等基础配置。';


--
-- Name: stg; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA stg;


ALTER SCHEMA stg OWNER TO postgres;

--
-- Name: SCHEMA stg; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA stg IS '临时数据层：Excel文件读取后先进入此层，校验通过后再写入正式数据表。';


--
-- Name: 中文数据; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA "中文数据";


ALTER SCHEMA "中文数据" OWNER TO postgres;

--
-- Name: SCHEMA "中文数据"; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA "中文数据" IS '业务数据库中文可读层。底层英文物理对象不改变，本Schema中的View用于pgAdmin人工查看和业务核对。';


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
-- Name: check_chinese_coverage(); Type: FUNCTION; Schema: meta; Owner: postgres
--

CREATE FUNCTION meta.check_chinese_coverage() RETURNS TABLE(check_item text, result text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total_tables INT;
    v_cn_tables INT;
    v_total_cols INT;
    v_cn_cols INT;
    v_conflicts INT;
    v_dup_cols INT;
BEGIN
    -- 对象覆盖率（core+meta+audit 物理表 vs 中文View）
    SELECT count(*) INTO v_total_tables
    FROM information_schema.tables
    WHERE table_schema IN ('core','meta','audit') AND table_type = 'BASE TABLE';

    SELECT count(*) INTO v_cn_tables
    FROM information_schema.views WHERE table_schema = '中文数据';

    -- 字段覆盖率（core 9表）
    SELECT count(*) INTO v_total_cols
    FROM information_schema.columns
    WHERE table_schema = 'core';

    SELECT count(*) INTO v_cn_cols
    FROM information_schema.columns
    WHERE table_schema = '中文数据'
      AND table_name IN ('抖音成交日报','抖音载体日报','抖音账号日报','抖音内容日报',
                         '抖音终端日报','抖音类目日报','抖音商品日报','抖音价格带日报','抖音人群日报');

    -- 冲突
    SELECT count(*) INTO v_conflicts
    FROM meta.database_object_dictionary
    WHERE name_resolution_status = 'conflict_pending' AND enabled = TRUE;

    -- 中文View内重复列名（中文数据 schema 内重名列）
    SELECT count(*) INTO v_dup_cols
    FROM (
        SELECT table_name, column_name, count(*) AS c
        FROM information_schema.columns
        WHERE table_schema = '中文数据'
        GROUP BY table_name, column_name
        HAVING count(*) > 1
    ) x;

    RETURN QUERY SELECT '业务对象(物理表数)', v_total_tables::text;
    RETURN QUERY SELECT '中文View数', v_cn_tables::text;
    RETURN QUERY SELECT 'core字段总数', v_total_cols::text;
    RETURN QUERY SELECT 'core中文字段数', v_cn_cols::text;
    RETURN QUERY SELECT '字段覆盖率', round(v_cn_cols::numeric / NULLIF(v_total_cols,0) * 100, 2)::text || '%';
    RETURN QUERY SELECT '冲突待决数', v_conflicts::text;
    RETURN QUERY SELECT '中文View重名列数', v_dup_cols::text;
END;
$$;


ALTER FUNCTION meta.check_chinese_coverage() OWNER TO postgres;

--
-- Name: FUNCTION check_chinese_coverage(); Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON FUNCTION meta.check_chinese_coverage() IS '中文可读层覆盖率检查：对象/字段覆盖率、冲突数、重名列数。';


--
-- Name: refresh_chinese_views(); Type: FUNCTION; Schema: meta; Owner: postgres
--

CREATE FUNCTION meta.refresh_chinese_views() RETURNS TABLE(result text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    rec RECORD;
    col_rec RECORD;
    cols TEXT := '';
    first BOOLEAN := TRUE;
    v_conflicts INT;
BEGIN
    -- 冲突检查：存在 conflict_pending 则禁止刷新
    SELECT count(*) INTO v_conflicts
    FROM meta.database_object_dictionary
    WHERE name_resolution_status = 'conflict_pending' AND enabled = TRUE;
    IF v_conflicts > 0 THEN
        RETURN QUERY SELECT 'ERROR: 存在 ' || v_conflicts::text || ' 条冲突待决，禁止刷新中文View';
        RETURN;
    END IF;

    -- 遍历所有已登记的中文表对象
    FOR rec IN
        SELECT DISTINCT schema_name, object_name, object_name_cn
        FROM meta.database_object_dictionary
        WHERE object_type = 'table' AND enabled = TRUE AND object_name_cn IS NOT NULL
        ORDER BY object_name_cn
    LOOP
        cols := '';
        first := TRUE;
        -- 收集字段（按 display_order 顺序）
        FOR col_rec IN
            SELECT column_name, column_name_cn
            FROM meta.database_object_dictionary
            WHERE schema_name = rec.schema_name AND object_name = rec.object_name
              AND object_type = 'column' AND enabled = TRUE AND visible_in_cn_view = TRUE
            ORDER BY display_order NULLS LAST, column_name
        LOOP
            IF NOT first THEN cols := cols || ','; END IF;
            cols := cols || '    ' || col_rec.column_name || ' AS "' || col_rec.column_name_cn || '"';
            first := FALSE;
        END LOOP;

        IF cols = '' THEN
            RETURN QUERY SELECT 'SKIP: ' || rec.object_name_cn || '（无字段）';
            CONTINUE;
        END IF;

        -- 重建View（仅中文数据 schema 内）
        EXECUTE format(
            'CREATE OR REPLACE VIEW "中文数据"."%s" AS SELECT %s FROM %s.%s;',
            rec.object_name_cn, cols, rec.schema_name, rec.object_name
        );
        RETURN QUERY SELECT 'OK: 已刷新 ' || rec.object_name_cn;
    END LOOP;
END;
$$;


ALTER FUNCTION meta.refresh_chinese_views() OWNER TO postgres;

--
-- Name: FUNCTION refresh_chinese_views(); Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON FUNCTION meta.refresh_chinese_views() IS '中文View刷新机制：仅读取字典元数据，仅在中文数据Schema内重建View；存在冲突则停止。';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: import_batch; Type: TABLE; Schema: audit; Owner: postgres
--

CREATE TABLE audit.import_batch (
    batch_id bigint NOT NULL,
    platform_code character varying(30) NOT NULL,
    shop_id bigint NOT NULL,
    source_file_name character varying(255) NOT NULL,
    source_file_path text,
    file_sha256 character(64),
    period_start date,
    period_end date,
    import_mode character varying(30) DEFAULT 'replace_period'::character varying NOT NULL,
    import_status character varying(30) DEFAULT 'pending'::character varying NOT NULL,
    source_row_count integer DEFAULT 0 NOT NULL,
    inserted_row_count integer DEFAULT 0 NOT NULL,
    error_message text,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_import_period CHECK (((period_start IS NULL) OR (period_end IS NULL) OR (period_start <= period_end))),
    CONSTRAINT ck_inserted_row_count CHECK ((inserted_row_count >= 0)),
    CONSTRAINT ck_source_row_count CHECK ((source_row_count >= 0))
);


ALTER TABLE audit.import_batch OWNER TO postgres;

--
-- Name: TABLE import_batch; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON TABLE audit.import_batch IS '数据导入批次表：每上传和处理一次Excel文件，就生成一条导入记录，用于追踪文件来源、数据周期、处理状态和错误信息。';


--
-- Name: COLUMN import_batch.batch_id; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.batch_id IS '导入批次ID：每次文件导入的唯一编号，由数据库自动生成。';


--
-- Name: COLUMN import_batch.platform_code; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.platform_code IS '平台编码：标识数据来自抖音、天猫、京东或其他平台。';


--
-- Name: COLUMN import_batch.shop_id; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.shop_id IS '店铺ID：关联店铺基础资料表，用于区分不同店铺的数据。';


--
-- Name: COLUMN import_batch.source_file_name; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.source_file_name IS '源文件名称：用户上传或导入的原始Excel文件名称。';


--
-- Name: COLUMN import_batch.source_file_path; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.source_file_path IS '源文件路径：原始Excel文件在本地电脑中的保存位置。';


--
-- Name: COLUMN import_batch.file_sha256; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.file_sha256 IS '文件SHA256指纹：根据文件内容生成的唯一值，用于识别完全相同的重复文件。';


--
-- Name: COLUMN import_batch.period_start; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.period_start IS '数据开始日期：该Excel文件中包含数据的最早业务日期。';


--
-- Name: COLUMN import_batch.period_end; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.period_end IS '数据结束日期：该Excel文件中包含数据的最晚业务日期。';


--
-- Name: COLUMN import_batch.import_mode; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.import_mode IS '导入模式：replace_period表示按店铺和日期范围覆盖原有数据。';


--
-- Name: COLUMN import_batch.import_status; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.import_status IS '导入状态：pending待处理、processing处理中、success成功、failed失败、cancelled取消。';


--
-- Name: COLUMN import_batch.source_row_count; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.source_row_count IS '源数据行数：Excel各工作表中读取到的有效数据总行数。';


--
-- Name: COLUMN import_batch.inserted_row_count; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.inserted_row_count IS '成功写入行数：完成清洗后实际写入正式数据表的数据行数。';


--
-- Name: COLUMN import_batch.error_message; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.error_message IS '错误信息：导入失败或数据校验异常时保存具体原因。';


--
-- Name: COLUMN import_batch.imported_at; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON COLUMN audit.import_batch.imported_at IS '导入时间：本次导入批次在数据库中创建的时间。';


--
-- Name: import_batch_batch_id_seq; Type: SEQUENCE; Schema: audit; Owner: postgres
--

CREATE SEQUENCE audit.import_batch_batch_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE audit.import_batch_batch_id_seq OWNER TO postgres;

--
-- Name: import_batch_batch_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: postgres
--

ALTER SEQUENCE audit.import_batch_batch_id_seq OWNED BY audit.import_batch.batch_id;


--
-- Name: douyin_account_daily; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.douyin_account_daily (
    row_id bigint NOT NULL,
    shop_id bigint NOT NULL,
    biz_date date NOT NULL,
    account_name character varying(300) DEFAULT ''::character varying NOT NULL,
    account_type character varying(100) DEFAULT ''::character varying NOT NULL,
    sale_scope character varying(100) DEFAULT ''::character varying NOT NULL,
    douyin_account_id character varying(100) DEFAULT ''::character varying NOT NULL,
    transaction_amount numeric(20,2),
    user_pay_amount numeric(20,2),
    settlement_amount numeric(20,2),
    transaction_refund_amount_pay_time numeric(20,2),
    refund_amount_pay_time numeric(20,2),
    refund_rate_pay_time numeric(18,8),
    ad_attributed_transaction_amount numeric(20,2),
    ad_attributed_transaction_share numeric(18,8),
    ad_spend_shop_promoted numeric(20,2),
    ad_spend_rate_net_refund_shop_promoted numeric(18,8),
    exposure_to_click_rate_users numeric(18,8),
    click_to_transaction_rate_users numeric(18,8),
    smart_coupon_amount numeric(20,2),
    platform_subsidy_amount numeric(20,2),
    creator_subsidy_amount numeric(20,2),
    presale_deposit_amount numeric(20,2),
    transaction_order_count bigint,
    transaction_item_count bigint,
    avg_item_amount numeric(20,4),
    transaction_buyer_count bigint,
    avg_customer_amount numeric(20,4),
    net_transaction_amount numeric(20,2),
    net_transaction_order_count bigint,
    settlement_amount_7d numeric(20,2),
    settlement_amount_14d numeric(20,2),
    settlement_amount_refund_time numeric(20,2),
    ad_attributed_settlement_amount numeric(20,2),
    net_user_pay_amount_pay_time numeric(20,2),
    net_smart_coupon_amount_pay_time numeric(20,2),
    net_platform_subsidy_amount_pay_time numeric(20,2),
    net_creator_subsidy_amount_pay_time numeric(20,2),
    refund_order_count_pay_time bigint,
    transaction_refund_amount_refund_time numeric(20,2),
    refund_amount_refund_time numeric(20,2),
    refund_order_count_refund_time bigint,
    one_hour_transaction_refund_amount_pay_time numeric(20,2),
    one_hour_refund_order_count_pay_time bigint,
    one_hour_refund_rate_pay_time numeric(18,8),
    ad_attributed_transaction_refund_amount_pay_time numeric(20,2),
    ad_attributed_refund_rate_pay_time numeric(18,8),
    product_exposure_count bigint,
    product_click_count bigint,
    exposure_to_click_rate_events numeric(18,8),
    click_to_transaction_rate_events numeric(18,8),
    exposure_to_transaction_rate_events numeric(18,8),
    product_exposure_user_count bigint,
    product_click_user_count bigint,
    exposure_to_transaction_rate_users numeric(18,8),
    user_pay_amount_per_1000_exposures numeric(20,4),
    ad_spend_shop_bound numeric(20,2),
    platform_commission_settlement numeric(20,2),
    creator_commission_settlement numeric(20,2),
    ad_spend_rate_shop_bound numeric(18,8),
    ad_spend_rate_shop_promoted numeric(18,8),
    ad_spend_rate_net_refund_shop_bound numeric(18,8),
    total_expense_rate_shop_bound numeric(18,8),
    total_expense_rate_shop_promoted numeric(18,8),
    total_expense_rate_net_refund_shop_bound numeric(18,8),
    total_expense_rate_net_refund_shop_promoted numeric(18,8),
    batch_id bigint NOT NULL,
    source_sheet_name character varying(50) NOT NULL,
    source_row_number integer NOT NULL,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT douyin_account_daily_source_row_number_check CHECK ((source_row_number >= 2))
);


ALTER TABLE core.douyin_account_daily OWNER TO postgres;

--
-- Name: TABLE douyin_account_daily; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON TABLE core.douyin_account_daily IS '抖音账号构成日表：按账号名称、账号类型和成交归属拆分。';


--
-- Name: COLUMN douyin_account_daily.row_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.row_id IS '数据行ID：数据库自动生成的唯一行编号';


--
-- Name: COLUMN douyin_account_daily.shop_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.shop_id IS '店铺ID：关联meta.shop，用于区分两个抖音店铺及后续其他平台店铺';


--
-- Name: COLUMN douyin_account_daily.biz_date; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.biz_date IS '业务日期：源字段“日期”。不聚合';


--
-- Name: COLUMN douyin_account_daily.account_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.account_name IS '账号名称：源字段“账号名称”。用于分组筛选';


--
-- Name: COLUMN douyin_account_daily.account_type; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.account_type IS '账号类型：源字段“账号类型”。用于分组筛选';


--
-- Name: COLUMN douyin_account_daily.sale_scope; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.sale_scope IS '成交归属（自营/合作）：源字段“自营/合作”。用于分组筛选';


--
-- Name: COLUMN douyin_account_daily.douyin_account_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.douyin_account_id IS '抖音号：源字段“抖音号”。不聚合';


--
-- Name: COLUMN douyin_account_daily.transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.transaction_amount IS '成交金额：源字段“成交金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.user_pay_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.user_pay_amount IS '用户支付金额：源字段“用户支付金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.settlement_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.settlement_amount IS '结算金额：源字段“结算金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.transaction_refund_amount_pay_time IS '成交退款金额(支付时间)：源字段“成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.refund_amount_pay_time IS '退款金额(支付时间)：源字段“退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.refund_rate_pay_time IS '源字段“退款率(支付时间)”。不可直接求和或平均；V1.4公式：退款金额(支付时间) ÷ 用户支付金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.ad_attributed_transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_attributed_transaction_amount IS '投放贡献成交金额：源字段“投放贡献成交金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.ad_attributed_transaction_share; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_attributed_transaction_share IS '源字段“投放贡献成交占比”。不可直接求和或平均；V1.4公式：投放贡献成交金额 ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.ad_spend_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_spend_shop_promoted IS '投放消耗(店铺被投)：源字段“投放消耗(店铺被投)”。SUM';


--
-- Name: COLUMN douyin_account_daily.ad_spend_rate_net_refund_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_spend_rate_net_refund_shop_promoted IS '源字段“投放费比(剔除退款、店铺被投)”。不可直接求和或平均；V1.4公式：投放消耗(店铺被投) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.exposure_to_click_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.exposure_to_click_rate_users IS '源字段“商品曝光-点击转化率(人数)”。不可直接求和或平均；V1.4公式：商品点击人数 ÷ 商品曝光人数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.click_to_transaction_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.click_to_transaction_rate_users IS '源字段“商品点击-成交转化率(人数)”。不可直接求和或平均；V1.4公式：成交人数 ÷ 商品点击人数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.smart_coupon_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.smart_coupon_amount IS '智能优惠券金额：源字段“智能优惠券金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.platform_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.platform_subsidy_amount IS '平台补贴金额：源字段“平台补贴金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.creator_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.creator_subsidy_amount IS '达人补贴金额：源字段“达人补贴金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.presale_deposit_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.presale_deposit_amount IS '预售定金：源字段“预售定金”。SUM';


--
-- Name: COLUMN douyin_account_daily.transaction_order_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.transaction_order_count IS '成交订单数：源字段“成交订单数”。SUM';


--
-- Name: COLUMN douyin_account_daily.transaction_item_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.transaction_item_count IS '成交件数：源字段“成交件数”。SUM';


--
-- Name: COLUMN douyin_account_daily.avg_item_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.avg_item_amount IS '源字段“件单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交件数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.transaction_buyer_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.transaction_buyer_count IS '成交人数：源字段“成交人数”。SUM';


--
-- Name: COLUMN douyin_account_daily.avg_customer_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.avg_customer_amount IS '源字段“客单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交人数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.net_transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.net_transaction_amount IS '净成交金额：源字段“净成交金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.net_transaction_order_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.net_transaction_order_count IS '净成交订单量：源字段“净成交订单量”。SUM';


--
-- Name: COLUMN douyin_account_daily.settlement_amount_7d; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.settlement_amount_7d IS '7日结算金额：源字段“7日结算金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.settlement_amount_14d; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.settlement_amount_14d IS '14日结算金额：源字段“14日结算金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.settlement_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.settlement_amount_refund_time IS '结算金额(退款时间)：源字段“结算金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.ad_attributed_settlement_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_attributed_settlement_amount IS '投放贡献结算金额：源字段“投放贡献结算金额”。SUM';


--
-- Name: COLUMN douyin_account_daily.net_user_pay_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.net_user_pay_amount_pay_time IS '退款后用户支付金额(支付时间)：源字段“退款后用户支付金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.net_smart_coupon_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.net_smart_coupon_amount_pay_time IS '退款后智能优惠券金额(支付时间)：源字段“退款后智能优惠券金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.net_platform_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.net_platform_subsidy_amount_pay_time IS '退款后平台补贴金额（支付时间）：源字段“退款后平台补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.net_creator_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.net_creator_subsidy_amount_pay_time IS '退款后达人补贴金额(支付时间)：源字段“退款后达人补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.refund_order_count_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.refund_order_count_pay_time IS '退款订单数(支付时间)：源字段“退款订单数(支付时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.transaction_refund_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.transaction_refund_amount_refund_time IS '成交退款金额(退款时间)：源字段“成交退款金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.refund_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.refund_amount_refund_time IS '退款金额(退款时间)：源字段“退款金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.refund_order_count_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.refund_order_count_refund_time IS '退款订单数(退款时间)：源字段“退款订单数(退款时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.one_hour_transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.one_hour_transaction_refund_amount_pay_time IS '1小时成交退款金额(支付时间)：源字段“1小时成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.one_hour_refund_order_count_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.one_hour_refund_order_count_pay_time IS '1小时退款订单数(支付时间)：源字段“1小时退款订单数(支付时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.one_hour_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.one_hour_refund_rate_pay_time IS '源字段“1小时退款率(支付时间)”。不可直接求和或平均；V1.4公式：平台源值；当前虽有1小时退款金额/订单数，但分母口径尚未确认；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.ad_attributed_transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_attributed_transaction_refund_amount_pay_time IS '投放贡献成交退款金额(支付时间)：源字段“投放贡献成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_account_daily.ad_attributed_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_attributed_refund_rate_pay_time IS '源字段“投放部分退款率(支付时间)”。不可直接求和或平均；V1.4公式：投放贡献成交退款金额(支付时间) ÷ 投放贡献成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.product_exposure_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.product_exposure_count IS '商品曝光次数：源字段“商品曝光次数”。SUM';


--
-- Name: COLUMN douyin_account_daily.product_click_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.product_click_count IS '商品点击次数：源字段“商品点击次数”。SUM';


--
-- Name: COLUMN douyin_account_daily.exposure_to_click_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.exposure_to_click_rate_events IS '源字段“商品曝光-点击转化率(次数)”。不可直接求和或平均；V1.4公式：商品点击次数 ÷ 商品曝光次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.click_to_transaction_rate_events IS '源字段“商品点击-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品点击次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.exposure_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.exposure_to_transaction_rate_events IS '源字段“商品曝光-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品曝光次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.product_exposure_user_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.product_exposure_user_count IS '商品曝光人数：源字段“商品曝光人数”。SUM';


--
-- Name: COLUMN douyin_account_daily.product_click_user_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.product_click_user_count IS '商品点击人数：源字段“商品点击人数”。SUM';


--
-- Name: COLUMN douyin_account_daily.exposure_to_transaction_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.exposure_to_transaction_rate_users IS '源字段“商品曝光-成交转化率(人数)”。不可直接求和或平均；V1.4公式：成交人数 ÷ 商品曝光人数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.user_pay_amount_per_1000_exposures; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.user_pay_amount_per_1000_exposures IS '源字段“千次曝光用户支付金额”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 商品曝光次数 × 1000；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.ad_spend_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_spend_shop_bound IS '投放消耗(店铺绑定)：源字段“投放消耗(店铺绑定)”。SUM';


--
-- Name: COLUMN douyin_account_daily.platform_commission_settlement; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.platform_commission_settlement IS '平台佣金(结算口径)：源字段“平台佣金(结算口径)”。SUM';


--
-- Name: COLUMN douyin_account_daily.creator_commission_settlement; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.creator_commission_settlement IS '达人佣金(结算口径)：源字段“达人佣金(结算口径)”。SUM';


--
-- Name: COLUMN douyin_account_daily.ad_spend_rate_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_spend_rate_shop_bound IS '源字段“投放费比(店铺绑定)”。不可直接求和或平均；V1.4公式：投放消耗(店铺绑定) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.ad_spend_rate_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_spend_rate_shop_promoted IS '源字段“投放费比(店铺被投)”。不可直接求和或平均；V1.4公式：投放消耗(店铺被投) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.ad_spend_rate_net_refund_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.ad_spend_rate_net_refund_shop_bound IS '源字段“投放费比(剔除退款、店铺绑定)”。不可直接求和或平均；V1.4公式：投放消耗(店铺绑定) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.total_expense_rate_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.total_expense_rate_shop_bound IS '源字段“综合费比(店铺绑定)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.total_expense_rate_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.total_expense_rate_shop_promoted IS '源字段“综合费比(店铺被投)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.total_expense_rate_net_refund_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.total_expense_rate_net_refund_shop_bound IS '源字段“综合费比(剔除退款、店铺绑定)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.total_expense_rate_net_refund_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.total_expense_rate_net_refund_shop_promoted IS '源字段“综合费比(剔除退款、店铺被投)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_account_daily.batch_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.batch_id IS '导入批次ID：关联audit.import_batch，追踪该行来自哪次文件导入';


--
-- Name: COLUMN douyin_account_daily.source_sheet_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.source_sheet_name IS '源工作表名称：原始Excel中的工作表名称';


--
-- Name: COLUMN douyin_account_daily.source_row_number; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.source_row_number IS '源文件行号：该数据在原始工作表中的行号，表头为第1行';


--
-- Name: COLUMN douyin_account_daily.imported_at; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_account_daily.imported_at IS '写入时间：该数据写入正式表的时间';


--
-- Name: douyin_account_daily_row_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.douyin_account_daily_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.douyin_account_daily_row_id_seq OWNER TO postgres;

--
-- Name: douyin_account_daily_row_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.douyin_account_daily_row_id_seq OWNED BY core.douyin_account_daily.row_id;


--
-- Name: douyin_audience_daily; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.douyin_audience_daily (
    row_id bigint NOT NULL,
    shop_id bigint NOT NULL,
    biz_date date NOT NULL,
    audience_type character varying(100) DEFAULT ''::character varying NOT NULL,
    carrier_type character varying(100) DEFAULT ''::character varying NOT NULL,
    user_pay_amount numeric(20,2),
    transaction_buyer_count bigint,
    avg_customer_amount numeric(20,4),
    transaction_order_count bigint,
    repeat_user_repeat_rate numeric(18,8),
    batch_id bigint NOT NULL,
    source_sheet_name character varying(50) NOT NULL,
    source_row_number integer NOT NULL,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT douyin_audience_daily_source_row_number_check CHECK ((source_row_number >= 2))
);


ALTER TABLE core.douyin_audience_daily OWNER TO postgres;

--
-- Name: TABLE douyin_audience_daily; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON TABLE core.douyin_audience_daily IS '抖音人群构成日表：按首购/复购人群和载体类型拆分。';


--
-- Name: COLUMN douyin_audience_daily.row_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.row_id IS '数据行ID：数据库自动生成的唯一行编号';


--
-- Name: COLUMN douyin_audience_daily.shop_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.shop_id IS '店铺ID：关联meta.shop，用于区分两个抖音店铺及后续其他平台店铺';


--
-- Name: COLUMN douyin_audience_daily.biz_date; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.biz_date IS '业务日期：源字段“日期”。不聚合';


--
-- Name: COLUMN douyin_audience_daily.audience_type; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.audience_type IS '人群类型：源字段“人群类型”。用于分组筛选';


--
-- Name: COLUMN douyin_audience_daily.carrier_type; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.carrier_type IS '载体类型：源字段“载体类型”。用于分组筛选';


--
-- Name: COLUMN douyin_audience_daily.user_pay_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.user_pay_amount IS '用户支付金额：源字段“用户支付金额”。SUM';


--
-- Name: COLUMN douyin_audience_daily.transaction_buyer_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.transaction_buyer_count IS '成交人数：源字段“成交人数”。SUM';


--
-- Name: COLUMN douyin_audience_daily.avg_customer_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.avg_customer_amount IS '源字段“客单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交人数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_audience_daily.transaction_order_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.transaction_order_count IS '成交订单数：源字段“成交订单数”。SUM';


--
-- Name: COLUMN douyin_audience_daily.repeat_user_repeat_rate; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.repeat_user_repeat_rate IS '源字段“复购用户复购率”。不可直接求和或平均；V1.4公式：平台源值；当前样表没有复购率专用分子/分母；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_audience_daily.batch_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.batch_id IS '导入批次ID：关联audit.import_batch，追踪该行来自哪次文件导入';


--
-- Name: COLUMN douyin_audience_daily.source_sheet_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.source_sheet_name IS '源工作表名称：原始Excel中的工作表名称';


--
-- Name: COLUMN douyin_audience_daily.source_row_number; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.source_row_number IS '源文件行号：该数据在原始工作表中的行号，表头为第1行';


--
-- Name: COLUMN douyin_audience_daily.imported_at; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_audience_daily.imported_at IS '写入时间：该数据写入正式表的时间';


--
-- Name: douyin_audience_daily_row_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.douyin_audience_daily_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.douyin_audience_daily_row_id_seq OWNER TO postgres;

--
-- Name: douyin_audience_daily_row_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.douyin_audience_daily_row_id_seq OWNED BY core.douyin_audience_daily.row_id;


--
-- Name: douyin_carrier_daily; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.douyin_carrier_daily (
    row_id bigint NOT NULL,
    shop_id bigint NOT NULL,
    biz_date date NOT NULL,
    sale_scope character varying(100) DEFAULT ''::character varying NOT NULL,
    carrier_type character varying(100) DEFAULT ''::character varying NOT NULL,
    account_channel character varying(300) DEFAULT ''::character varying NOT NULL,
    douyin_account_id character varying(100) DEFAULT ''::character varying NOT NULL,
    transaction_amount numeric(20,2),
    user_pay_amount numeric(20,2),
    settlement_amount numeric(20,2),
    transaction_refund_amount_pay_time numeric(20,2),
    refund_amount_pay_time numeric(20,2),
    refund_rate_pay_time numeric(18,8),
    ad_attributed_transaction_amount numeric(20,2),
    ad_attributed_transaction_share numeric(18,8),
    ad_spend_shop_promoted numeric(20,2),
    ad_spend_rate_net_refund_shop_promoted numeric(18,8),
    exposure_to_click_rate_users numeric(18,8),
    click_to_transaction_rate_users numeric(18,8),
    smart_coupon_amount numeric(20,2),
    platform_subsidy_amount numeric(20,2),
    creator_subsidy_amount numeric(20,2),
    presale_deposit_amount numeric(20,2),
    transaction_order_count bigint,
    transaction_item_count bigint,
    avg_item_amount numeric(20,4),
    transaction_buyer_count bigint,
    avg_customer_amount numeric(20,4),
    net_transaction_amount numeric(20,2),
    net_transaction_order_count bigint,
    settlement_amount_7d numeric(20,2),
    settlement_amount_14d numeric(20,2),
    settlement_amount_refund_time numeric(20,2),
    ad_attributed_settlement_amount numeric(20,2),
    net_user_pay_amount_pay_time numeric(20,2),
    net_smart_coupon_amount_pay_time numeric(20,2),
    net_platform_subsidy_amount_pay_time numeric(20,2),
    net_creator_subsidy_amount_pay_time numeric(20,2),
    refund_order_count_pay_time bigint,
    transaction_refund_amount_refund_time numeric(20,2),
    refund_amount_refund_time numeric(20,2),
    refund_order_count_refund_time bigint,
    one_hour_transaction_refund_amount_pay_time numeric(20,2),
    one_hour_refund_order_count_pay_time bigint,
    one_hour_refund_rate_pay_time numeric(18,8),
    ad_attributed_transaction_refund_amount_pay_time numeric(20,2),
    ad_attributed_refund_rate_pay_time numeric(18,8),
    product_exposure_count bigint,
    product_click_count bigint,
    exposure_to_click_rate_events numeric(18,8),
    click_to_transaction_rate_events numeric(18,8),
    exposure_to_transaction_rate_events numeric(18,8),
    product_exposure_user_count bigint,
    product_click_user_count bigint,
    exposure_to_transaction_rate_users numeric(18,8),
    user_pay_amount_per_1000_exposures numeric(20,4),
    ad_spend_shop_bound numeric(20,2),
    platform_commission_settlement numeric(20,2),
    creator_commission_settlement numeric(20,2),
    ad_spend_rate_shop_bound numeric(18,8),
    ad_spend_rate_shop_promoted numeric(18,8),
    ad_spend_rate_net_refund_shop_bound numeric(18,8),
    total_expense_rate_shop_bound numeric(18,8),
    total_expense_rate_shop_promoted numeric(18,8),
    total_expense_rate_net_refund_shop_bound numeric(18,8),
    total_expense_rate_net_refund_shop_promoted numeric(18,8),
    batch_id bigint NOT NULL,
    source_sheet_name character varying(50) NOT NULL,
    source_row_number integer NOT NULL,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT douyin_carrier_daily_source_row_number_check CHECK ((source_row_number >= 2))
);


ALTER TABLE core.douyin_carrier_daily OWNER TO postgres;

--
-- Name: TABLE douyin_carrier_daily; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON TABLE core.douyin_carrier_daily IS '抖音载体构成日表：按成交归属、载体类型、账号或渠道拆分。';


--
-- Name: COLUMN douyin_carrier_daily.row_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.row_id IS '数据行ID：数据库自动生成的唯一行编号';


--
-- Name: COLUMN douyin_carrier_daily.shop_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.shop_id IS '店铺ID：关联meta.shop，用于区分两个抖音店铺及后续其他平台店铺';


--
-- Name: COLUMN douyin_carrier_daily.biz_date; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.biz_date IS '业务日期：源字段“日期”。不聚合';


--
-- Name: COLUMN douyin_carrier_daily.sale_scope; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.sale_scope IS '成交归属（自营/合作）：源字段“自营/合作”。用于分组筛选';


--
-- Name: COLUMN douyin_carrier_daily.carrier_type; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.carrier_type IS '载体类型：源字段“载体类型”。用于分组筛选';


--
-- Name: COLUMN douyin_carrier_daily.account_channel; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.account_channel IS '账号/渠道：源字段“账号/渠道”。用于分组筛选';


--
-- Name: COLUMN douyin_carrier_daily.douyin_account_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.douyin_account_id IS '抖音号：源字段“抖音号”。不聚合';


--
-- Name: COLUMN douyin_carrier_daily.transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.transaction_amount IS '成交金额：源字段“成交金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.user_pay_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.user_pay_amount IS '用户支付金额：源字段“用户支付金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.settlement_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.settlement_amount IS '结算金额：源字段“结算金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.transaction_refund_amount_pay_time IS '成交退款金额(支付时间)：源字段“成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.refund_amount_pay_time IS '退款金额(支付时间)：源字段“退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.refund_rate_pay_time IS '源字段“退款率(支付时间)”。不可直接求和或平均；V1.4公式：退款金额(支付时间) ÷ 用户支付金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.ad_attributed_transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_attributed_transaction_amount IS '投放贡献成交金额：源字段“投放贡献成交金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.ad_attributed_transaction_share; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_attributed_transaction_share IS '源字段“投放贡献成交占比”。不可直接求和或平均；V1.4公式：投放贡献成交金额 ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.ad_spend_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_spend_shop_promoted IS '投放消耗(店铺被投)：源字段“投放消耗(店铺被投)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.ad_spend_rate_net_refund_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_spend_rate_net_refund_shop_promoted IS '源字段“投放费比(剔除退款、店铺被投)”。不可直接求和或平均；V1.4公式：投放消耗(店铺被投) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.exposure_to_click_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.exposure_to_click_rate_users IS '源字段“商品曝光-点击转化率(人数)”。不可直接求和或平均；V1.4公式：商品点击人数 ÷ 商品曝光人数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.click_to_transaction_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.click_to_transaction_rate_users IS '源字段“商品点击-成交转化率(人数)”。不可直接求和或平均；V1.4公式：成交人数 ÷ 商品点击人数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.smart_coupon_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.smart_coupon_amount IS '智能优惠券金额：源字段“智能优惠券金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.platform_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.platform_subsidy_amount IS '平台补贴金额：源字段“平台补贴金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.creator_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.creator_subsidy_amount IS '达人补贴金额：源字段“达人补贴金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.presale_deposit_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.presale_deposit_amount IS '预售定金：源字段“预售定金”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.transaction_order_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.transaction_order_count IS '成交订单数：源字段“成交订单数”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.transaction_item_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.transaction_item_count IS '成交件数：源字段“成交件数”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.avg_item_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.avg_item_amount IS '源字段“件单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交件数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.transaction_buyer_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.transaction_buyer_count IS '成交人数：源字段“成交人数”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.avg_customer_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.avg_customer_amount IS '源字段“客单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交人数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.net_transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.net_transaction_amount IS '净成交金额：源字段“净成交金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.net_transaction_order_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.net_transaction_order_count IS '净成交订单量：源字段“净成交订单量”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.settlement_amount_7d; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.settlement_amount_7d IS '7日结算金额：源字段“7日结算金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.settlement_amount_14d; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.settlement_amount_14d IS '14日结算金额：源字段“14日结算金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.settlement_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.settlement_amount_refund_time IS '结算金额(退款时间)：源字段“结算金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.ad_attributed_settlement_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_attributed_settlement_amount IS '投放贡献结算金额：源字段“投放贡献结算金额”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.net_user_pay_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.net_user_pay_amount_pay_time IS '退款后用户支付金额(支付时间)：源字段“退款后用户支付金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.net_smart_coupon_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.net_smart_coupon_amount_pay_time IS '退款后智能优惠券金额(支付时间)：源字段“退款后智能优惠券金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.net_platform_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.net_platform_subsidy_amount_pay_time IS '退款后平台补贴金额（支付时间）：源字段“退款后平台补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.net_creator_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.net_creator_subsidy_amount_pay_time IS '退款后达人补贴金额(支付时间)：源字段“退款后达人补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.refund_order_count_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.refund_order_count_pay_time IS '退款订单数(支付时间)：源字段“退款订单数(支付时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.transaction_refund_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.transaction_refund_amount_refund_time IS '成交退款金额(退款时间)：源字段“成交退款金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.refund_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.refund_amount_refund_time IS '退款金额(退款时间)：源字段“退款金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.refund_order_count_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.refund_order_count_refund_time IS '退款订单数(退款时间)：源字段“退款订单数(退款时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.one_hour_transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.one_hour_transaction_refund_amount_pay_time IS '1小时成交退款金额(支付时间)：源字段“1小时成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.one_hour_refund_order_count_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.one_hour_refund_order_count_pay_time IS '1小时退款订单数(支付时间)：源字段“1小时退款订单数(支付时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.one_hour_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.one_hour_refund_rate_pay_time IS '源字段“1小时退款率(支付时间)”。不可直接求和或平均；V1.4公式：平台源值；当前虽有1小时退款金额/订单数，但分母口径尚未确认；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.ad_attributed_transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_attributed_transaction_refund_amount_pay_time IS '投放贡献成交退款金额(支付时间)：源字段“投放贡献成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.ad_attributed_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_attributed_refund_rate_pay_time IS '源字段“投放部分退款率(支付时间)”。不可直接求和或平均；V1.4公式：投放贡献成交退款金额(支付时间) ÷ 投放贡献成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.product_exposure_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.product_exposure_count IS '商品曝光次数：源字段“商品曝光次数”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.product_click_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.product_click_count IS '商品点击次数：源字段“商品点击次数”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.exposure_to_click_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.exposure_to_click_rate_events IS '源字段“商品曝光-点击转化率(次数)”。不可直接求和或平均；V1.4公式：商品点击次数 ÷ 商品曝光次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.click_to_transaction_rate_events IS '源字段“商品点击-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品点击次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.exposure_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.exposure_to_transaction_rate_events IS '源字段“商品曝光-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品曝光次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.product_exposure_user_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.product_exposure_user_count IS '商品曝光人数：源字段“商品曝光人数”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.product_click_user_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.product_click_user_count IS '商品点击人数：源字段“商品点击人数”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.exposure_to_transaction_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.exposure_to_transaction_rate_users IS '源字段“商品曝光-成交转化率(人数)”。不可直接求和或平均；V1.4公式：成交人数 ÷ 商品曝光人数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.user_pay_amount_per_1000_exposures; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.user_pay_amount_per_1000_exposures IS '源字段“千次曝光用户支付金额”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 商品曝光次数 × 1000；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.ad_spend_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_spend_shop_bound IS '投放消耗(店铺绑定)：源字段“投放消耗(店铺绑定)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.platform_commission_settlement; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.platform_commission_settlement IS '平台佣金(结算口径)：源字段“平台佣金(结算口径)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.creator_commission_settlement; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.creator_commission_settlement IS '达人佣金(结算口径)：源字段“达人佣金(结算口径)”。SUM';


--
-- Name: COLUMN douyin_carrier_daily.ad_spend_rate_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_spend_rate_shop_bound IS '源字段“投放费比(店铺绑定)”。不可直接求和或平均；V1.4公式：投放消耗(店铺绑定) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.ad_spend_rate_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_spend_rate_shop_promoted IS '源字段“投放费比(店铺被投)”。不可直接求和或平均；V1.4公式：投放消耗(店铺被投) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.ad_spend_rate_net_refund_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.ad_spend_rate_net_refund_shop_bound IS '源字段“投放费比(剔除退款、店铺绑定)”。不可直接求和或平均；V1.4公式：投放消耗(店铺绑定) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.total_expense_rate_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.total_expense_rate_shop_bound IS '源字段“综合费比(店铺绑定)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.total_expense_rate_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.total_expense_rate_shop_promoted IS '源字段“综合费比(店铺被投)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.total_expense_rate_net_refund_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.total_expense_rate_net_refund_shop_bound IS '源字段“综合费比(剔除退款、店铺绑定)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.total_expense_rate_net_refund_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.total_expense_rate_net_refund_shop_promoted IS '源字段“综合费比(剔除退款、店铺被投)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_carrier_daily.batch_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.batch_id IS '导入批次ID：关联audit.import_batch，追踪该行来自哪次文件导入';


--
-- Name: COLUMN douyin_carrier_daily.source_sheet_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.source_sheet_name IS '源工作表名称：原始Excel中的工作表名称';


--
-- Name: COLUMN douyin_carrier_daily.source_row_number; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.source_row_number IS '源文件行号：该数据在原始工作表中的行号，表头为第1行';


--
-- Name: COLUMN douyin_carrier_daily.imported_at; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_carrier_daily.imported_at IS '写入时间：该数据写入正式表的时间';


--
-- Name: douyin_carrier_daily_row_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.douyin_carrier_daily_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.douyin_carrier_daily_row_id_seq OWNER TO postgres;

--
-- Name: douyin_carrier_daily_row_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.douyin_carrier_daily_row_id_seq OWNED BY core.douyin_carrier_daily.row_id;


--
-- Name: douyin_category_daily; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.douyin_category_daily (
    row_id bigint NOT NULL,
    shop_id bigint NOT NULL,
    biz_date date NOT NULL,
    category_level_1 character varying(100) DEFAULT ''::character varying NOT NULL,
    category_level_2 character varying(100) DEFAULT ''::character varying NOT NULL,
    category_level_3 character varying(100) DEFAULT ''::character varying NOT NULL,
    category_level_4 character varying(100) DEFAULT ''::character varying NOT NULL,
    user_pay_amount numeric(20,2),
    avg_transaction_order_amount numeric(20,4),
    click_to_transaction_rate_events numeric(18,8),
    refund_amount_pay_time numeric(20,2),
    refund_rate_pay_time numeric(18,8),
    batch_id bigint NOT NULL,
    source_sheet_name character varying(50) NOT NULL,
    source_row_number integer NOT NULL,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT douyin_category_daily_source_row_number_check CHECK ((source_row_number >= 2))
);


ALTER TABLE core.douyin_category_daily OWNER TO postgres;

--
-- Name: TABLE douyin_category_daily; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON TABLE core.douyin_category_daily IS '抖音品类构成日表：按一至四级类目拆分。';


--
-- Name: COLUMN douyin_category_daily.row_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.row_id IS '数据行ID：数据库自动生成的唯一行编号';


--
-- Name: COLUMN douyin_category_daily.shop_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.shop_id IS '店铺ID：关联meta.shop，用于区分两个抖音店铺及后续其他平台店铺';


--
-- Name: COLUMN douyin_category_daily.biz_date; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.biz_date IS '业务日期：源字段“日期”。不聚合';


--
-- Name: COLUMN douyin_category_daily.category_level_1; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.category_level_1 IS '一级类目：源字段“一级类目”。用于分组筛选';


--
-- Name: COLUMN douyin_category_daily.category_level_2; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.category_level_2 IS '二级类目：源字段“二级类目”。用于分组筛选';


--
-- Name: COLUMN douyin_category_daily.category_level_3; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.category_level_3 IS '三级类目：源字段“三级类目”。用于分组筛选';


--
-- Name: COLUMN douyin_category_daily.category_level_4; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.category_level_4 IS '四级类目：源字段“四级类目”。用于分组筛选';


--
-- Name: COLUMN douyin_category_daily.user_pay_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.user_pay_amount IS '用户支付金额：源字段“用户支付金额”。SUM';


--
-- Name: COLUMN douyin_category_daily.avg_transaction_order_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.avg_transaction_order_amount IS '源字段“成交笔单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交订单数；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_category_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.click_to_transaction_rate_events IS '源字段“商品点击-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品点击次数；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_category_daily.refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.refund_amount_pay_time IS '退款金额(支付时间)：源字段“退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_category_daily.refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.refund_rate_pay_time IS '源字段“退款率(支付时间)”。不可直接求和或平均；V1.4公式：退款金额(支付时间) ÷ 用户支付金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_category_daily.batch_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.batch_id IS '导入批次ID：关联audit.import_batch，追踪该行来自哪次文件导入';


--
-- Name: COLUMN douyin_category_daily.source_sheet_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.source_sheet_name IS '源工作表名称：原始Excel中的工作表名称';


--
-- Name: COLUMN douyin_category_daily.source_row_number; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.source_row_number IS '源文件行号：该数据在原始工作表中的行号，表头为第1行';


--
-- Name: COLUMN douyin_category_daily.imported_at; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_category_daily.imported_at IS '写入时间：该数据写入正式表的时间';


--
-- Name: douyin_category_daily_row_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.douyin_category_daily_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.douyin_category_daily_row_id_seq OWNER TO postgres;

--
-- Name: douyin_category_daily_row_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.douyin_category_daily_row_id_seq OWNED BY core.douyin_category_daily.row_id;


--
-- Name: douyin_content_daily; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.douyin_content_daily (
    row_id bigint NOT NULL,
    shop_id bigint NOT NULL,
    biz_date date NOT NULL,
    selling_type character varying(100) DEFAULT ''::character varying NOT NULL,
    carrier_type character varying(100) DEFAULT ''::character varying NOT NULL,
    content_id character varying(128) DEFAULT ''::character varying NOT NULL,
    content_title text,
    transaction_amount numeric(20,2),
    user_pay_amount numeric(20,2),
    settlement_amount numeric(20,2),
    transaction_refund_amount_pay_time numeric(20,2),
    refund_amount_pay_time numeric(20,2),
    refund_rate_pay_time numeric(18,8),
    ad_attributed_transaction_amount numeric(20,2),
    ad_attributed_transaction_share numeric(18,8),
    ad_spend_shop_promoted numeric(20,2),
    ad_spend_rate_net_refund_shop_promoted numeric(18,8),
    exposure_to_click_rate_users numeric(18,8),
    click_to_transaction_rate_users numeric(18,8),
    smart_coupon_amount numeric(20,2),
    platform_subsidy_amount numeric(20,2),
    creator_subsidy_amount numeric(20,2),
    presale_deposit_amount numeric(20,2),
    transaction_order_count bigint,
    transaction_item_count bigint,
    avg_item_amount numeric(20,4),
    transaction_buyer_count bigint,
    avg_customer_amount numeric(20,4),
    net_transaction_amount numeric(20,2),
    net_transaction_order_count bigint,
    settlement_amount_7d numeric(20,2),
    settlement_amount_14d numeric(20,2),
    settlement_amount_refund_time numeric(20,2),
    ad_attributed_settlement_amount numeric(20,2),
    net_user_pay_amount_pay_time numeric(20,2),
    net_smart_coupon_amount_pay_time numeric(20,2),
    net_platform_subsidy_amount_pay_time numeric(20,2),
    net_creator_subsidy_amount_pay_time numeric(20,2),
    refund_order_count_pay_time bigint,
    transaction_refund_amount_refund_time numeric(20,2),
    refund_amount_refund_time numeric(20,2),
    refund_order_count_refund_time bigint,
    one_hour_transaction_refund_amount_pay_time numeric(20,2),
    one_hour_refund_order_count_pay_time bigint,
    one_hour_refund_rate_pay_time numeric(18,8),
    ad_attributed_transaction_refund_amount_pay_time numeric(20,2),
    ad_attributed_refund_rate_pay_time numeric(18,8),
    product_exposure_count bigint,
    product_click_count bigint,
    exposure_to_click_rate_events numeric(18,8),
    click_to_transaction_rate_events numeric(18,8),
    exposure_to_transaction_rate_events numeric(18,8),
    product_exposure_user_count bigint,
    product_click_user_count bigint,
    exposure_to_transaction_rate_users numeric(18,8),
    user_pay_amount_per_1000_exposures numeric(20,4),
    ad_spend_shop_bound numeric(20,2),
    platform_commission_settlement numeric(20,2),
    creator_commission_settlement numeric(20,2),
    ad_spend_rate_shop_bound numeric(18,8),
    ad_spend_rate_shop_promoted numeric(18,8),
    ad_spend_rate_net_refund_shop_bound numeric(18,8),
    total_expense_rate_shop_bound numeric(18,8),
    total_expense_rate_shop_promoted numeric(18,8),
    total_expense_rate_net_refund_shop_bound numeric(18,8),
    total_expense_rate_net_refund_shop_promoted numeric(18,8),
    batch_id bigint NOT NULL,
    source_sheet_name character varying(50) NOT NULL,
    source_row_number integer NOT NULL,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT douyin_content_daily_source_row_number_check CHECK ((source_row_number >= 2))
);


ALTER TABLE core.douyin_content_daily OWNER TO postgres;

--
-- Name: TABLE douyin_content_daily; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON TABLE core.douyin_content_daily IS '抖音单载体构成日表：按直播间、短视频、图文等单个内容载体拆分。';


--
-- Name: COLUMN douyin_content_daily.row_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.row_id IS '数据行ID：数据库自动生成的唯一行编号';


--
-- Name: COLUMN douyin_content_daily.shop_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.shop_id IS '店铺ID：关联meta.shop，用于区分两个抖音店铺及后续其他平台店铺';


--
-- Name: COLUMN douyin_content_daily.biz_date; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.biz_date IS '业务日期：源字段“日期”。不聚合';


--
-- Name: COLUMN douyin_content_daily.selling_type; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.selling_type IS '售卖类型：源字段“售卖类型”。用于分组筛选';


--
-- Name: COLUMN douyin_content_daily.carrier_type; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.carrier_type IS '载体类型：源字段“载体类型”。用于分组筛选';


--
-- Name: COLUMN douyin_content_daily.content_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.content_id IS '内容或载体ID：源字段“ID”。不聚合';


--
-- Name: COLUMN douyin_content_daily.content_title; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.content_title IS '内容或载体标题/名称：源字段“标题/名称”。用于分组筛选';


--
-- Name: COLUMN douyin_content_daily.transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.transaction_amount IS '成交金额：源字段“成交金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.user_pay_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.user_pay_amount IS '用户支付金额：源字段“用户支付金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.settlement_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.settlement_amount IS '结算金额：源字段“结算金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.transaction_refund_amount_pay_time IS '成交退款金额(支付时间)：源字段“成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.refund_amount_pay_time IS '退款金额(支付时间)：源字段“退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.refund_rate_pay_time IS '源字段“退款率(支付时间)”。不可直接求和或平均；V1.4公式：退款金额(支付时间) ÷ 用户支付金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.ad_attributed_transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_attributed_transaction_amount IS '投放贡献成交金额：源字段“投放贡献成交金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.ad_attributed_transaction_share; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_attributed_transaction_share IS '源字段“投放贡献成交占比”。不可直接求和或平均；V1.4公式：投放贡献成交金额 ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.ad_spend_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_spend_shop_promoted IS '投放消耗(店铺被投)：源字段“投放消耗(店铺被投)”。SUM';


--
-- Name: COLUMN douyin_content_daily.ad_spend_rate_net_refund_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_spend_rate_net_refund_shop_promoted IS '源字段“投放费比(剔除退款、店铺被投)”。不可直接求和或平均；V1.4公式：投放消耗(店铺被投) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.exposure_to_click_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.exposure_to_click_rate_users IS '源字段“商品曝光-点击转化率(人数)”。不可直接求和或平均；V1.4公式：商品点击人数 ÷ 商品曝光人数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.click_to_transaction_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.click_to_transaction_rate_users IS '源字段“商品点击-成交转化率(人数)”。不可直接求和或平均；V1.4公式：成交人数 ÷ 商品点击人数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.smart_coupon_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.smart_coupon_amount IS '智能优惠券金额：源字段“智能优惠券金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.platform_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.platform_subsidy_amount IS '平台补贴金额：源字段“平台补贴金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.creator_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.creator_subsidy_amount IS '达人补贴金额：源字段“达人补贴金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.presale_deposit_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.presale_deposit_amount IS '预售定金：源字段“预售定金”。SUM';


--
-- Name: COLUMN douyin_content_daily.transaction_order_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.transaction_order_count IS '成交订单数：源字段“成交订单数”。SUM';


--
-- Name: COLUMN douyin_content_daily.transaction_item_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.transaction_item_count IS '成交件数：源字段“成交件数”。SUM';


--
-- Name: COLUMN douyin_content_daily.avg_item_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.avg_item_amount IS '源字段“件单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交件数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.transaction_buyer_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.transaction_buyer_count IS '成交人数：源字段“成交人数”。SUM';


--
-- Name: COLUMN douyin_content_daily.avg_customer_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.avg_customer_amount IS '源字段“客单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交人数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.net_transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.net_transaction_amount IS '净成交金额：源字段“净成交金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.net_transaction_order_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.net_transaction_order_count IS '净成交订单量：源字段“净成交订单量”。SUM';


--
-- Name: COLUMN douyin_content_daily.settlement_amount_7d; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.settlement_amount_7d IS '7日结算金额：源字段“7日结算金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.settlement_amount_14d; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.settlement_amount_14d IS '14日结算金额：源字段“14日结算金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.settlement_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.settlement_amount_refund_time IS '结算金额(退款时间)：源字段“结算金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.ad_attributed_settlement_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_attributed_settlement_amount IS '投放贡献结算金额：源字段“投放贡献结算金额”。SUM';


--
-- Name: COLUMN douyin_content_daily.net_user_pay_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.net_user_pay_amount_pay_time IS '退款后用户支付金额(支付时间)：源字段“退款后用户支付金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.net_smart_coupon_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.net_smart_coupon_amount_pay_time IS '退款后智能优惠券金额(支付时间)：源字段“退款后智能优惠券金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.net_platform_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.net_platform_subsidy_amount_pay_time IS '退款后平台补贴金额（支付时间）：源字段“退款后平台补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.net_creator_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.net_creator_subsidy_amount_pay_time IS '退款后达人补贴金额(支付时间)：源字段“退款后达人补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.refund_order_count_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.refund_order_count_pay_time IS '退款订单数(支付时间)：源字段“退款订单数(支付时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.transaction_refund_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.transaction_refund_amount_refund_time IS '成交退款金额(退款时间)：源字段“成交退款金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.refund_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.refund_amount_refund_time IS '退款金额(退款时间)：源字段“退款金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.refund_order_count_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.refund_order_count_refund_time IS '退款订单数(退款时间)：源字段“退款订单数(退款时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.one_hour_transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.one_hour_transaction_refund_amount_pay_time IS '1小时成交退款金额(支付时间)：源字段“1小时成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.one_hour_refund_order_count_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.one_hour_refund_order_count_pay_time IS '1小时退款订单数(支付时间)：源字段“1小时退款订单数(支付时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.one_hour_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.one_hour_refund_rate_pay_time IS '源字段“1小时退款率(支付时间)”。不可直接求和或平均；V1.4公式：平台源值；当前虽有1小时退款金额/订单数，但分母口径尚未确认；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.ad_attributed_transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_attributed_transaction_refund_amount_pay_time IS '投放贡献成交退款金额(支付时间)：源字段“投放贡献成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_content_daily.ad_attributed_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_attributed_refund_rate_pay_time IS '源字段“投放部分退款率(支付时间)”。不可直接求和或平均；V1.4公式：投放贡献成交退款金额(支付时间) ÷ 投放贡献成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.product_exposure_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.product_exposure_count IS '商品曝光次数：源字段“商品曝光次数”。SUM';


--
-- Name: COLUMN douyin_content_daily.product_click_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.product_click_count IS '商品点击次数：源字段“商品点击次数”。SUM';


--
-- Name: COLUMN douyin_content_daily.exposure_to_click_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.exposure_to_click_rate_events IS '源字段“商品曝光-点击转化率(次数)”。不可直接求和或平均；V1.4公式：商品点击次数 ÷ 商品曝光次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.click_to_transaction_rate_events IS '源字段“商品点击-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品点击次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.exposure_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.exposure_to_transaction_rate_events IS '源字段“商品曝光-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品曝光次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.product_exposure_user_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.product_exposure_user_count IS '商品曝光人数：源字段“商品曝光人数”。SUM';


--
-- Name: COLUMN douyin_content_daily.product_click_user_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.product_click_user_count IS '商品点击人数：源字段“商品点击人数”。SUM';


--
-- Name: COLUMN douyin_content_daily.exposure_to_transaction_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.exposure_to_transaction_rate_users IS '源字段“商品曝光-成交转化率(人数)”。不可直接求和或平均；V1.4公式：成交人数 ÷ 商品曝光人数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.user_pay_amount_per_1000_exposures; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.user_pay_amount_per_1000_exposures IS '源字段“千次曝光用户支付金额”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 商品曝光次数 × 1000；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.ad_spend_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_spend_shop_bound IS '投放消耗(店铺绑定)：源字段“投放消耗(店铺绑定)”。SUM';


--
-- Name: COLUMN douyin_content_daily.platform_commission_settlement; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.platform_commission_settlement IS '平台佣金(结算口径)：源字段“平台佣金(结算口径)”。SUM';


--
-- Name: COLUMN douyin_content_daily.creator_commission_settlement; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.creator_commission_settlement IS '达人佣金(结算口径)：源字段“达人佣金(结算口径)”。SUM';


--
-- Name: COLUMN douyin_content_daily.ad_spend_rate_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_spend_rate_shop_bound IS '源字段“投放费比(店铺绑定)”。不可直接求和或平均；V1.4公式：投放消耗(店铺绑定) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.ad_spend_rate_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_spend_rate_shop_promoted IS '源字段“投放费比(店铺被投)”。不可直接求和或平均；V1.4公式：投放消耗(店铺被投) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.ad_spend_rate_net_refund_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.ad_spend_rate_net_refund_shop_bound IS '源字段“投放费比(剔除退款、店铺绑定)”。不可直接求和或平均；V1.4公式：投放消耗(店铺绑定) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.total_expense_rate_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.total_expense_rate_shop_bound IS '源字段“综合费比(店铺绑定)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.total_expense_rate_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.total_expense_rate_shop_promoted IS '源字段“综合费比(店铺被投)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 成交金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.total_expense_rate_net_refund_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.total_expense_rate_net_refund_shop_bound IS '源字段“综合费比(剔除退款、店铺绑定)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺绑定)+平台佣金+达人佣金) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.total_expense_rate_net_refund_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.total_expense_rate_net_refund_shop_promoted IS '源字段“综合费比(剔除退款、店铺被投)”。不可直接求和或平均；V1.4公式：(投放消耗(店铺被投)+平台佣金+达人佣金) ÷ 结算金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_content_daily.batch_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.batch_id IS '导入批次ID：关联audit.import_batch，追踪该行来自哪次文件导入';


--
-- Name: COLUMN douyin_content_daily.source_sheet_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.source_sheet_name IS '源工作表名称：原始Excel中的工作表名称';


--
-- Name: COLUMN douyin_content_daily.source_row_number; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.source_row_number IS '源文件行号：该数据在原始工作表中的行号，表头为第1行';


--
-- Name: COLUMN douyin_content_daily.imported_at; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_content_daily.imported_at IS '写入时间：该数据写入正式表的时间';


--
-- Name: douyin_content_daily_row_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.douyin_content_daily_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.douyin_content_daily_row_id_seq OWNER TO postgres;

--
-- Name: douyin_content_daily_row_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.douyin_content_daily_row_id_seq OWNED BY core.douyin_content_daily.row_id;


--
-- Name: douyin_deal_daily; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.douyin_deal_daily (
    row_id bigint NOT NULL,
    shop_id bigint NOT NULL,
    biz_date date NOT NULL,
    sale_scope character varying(20) NOT NULL,
    carrier_type character varying(100) DEFAULT ''::character varying NOT NULL,
    ad_period character varying(100) DEFAULT ''::character varying NOT NULL,
    user_pay_amount numeric(20,2),
    net_user_pay_amount_pay_time numeric(20,2),
    smart_coupon_amount numeric(20,2),
    net_smart_coupon_amount_pay_time numeric(20,2),
    platform_subsidy_amount numeric(20,2),
    transaction_order_count bigint,
    transaction_buyer_count bigint,
    avg_customer_amount numeric(20,4),
    transaction_amount numeric(20,2),
    net_transaction_amount numeric(20,2),
    refund_amount_refund_time numeric(20,2),
    transaction_refund_amount_refund_time numeric(20,2),
    refund_order_count_refund_time bigint,
    refund_rate_pay_time numeric(18,8),
    refund_amount_pay_time numeric(20,2),
    transaction_refund_amount_pay_time numeric(20,2),
    refund_order_count_pay_time bigint,
    product_exposure_user_count bigint,
    product_click_user_count bigint,
    exposure_to_click_rate_users numeric(18,8),
    click_to_transaction_rate_users numeric(18,8),
    exposure_to_transaction_rate_users numeric(18,8),
    user_pay_amount_per_1000_exposures numeric(20,4),
    product_exposure_count bigint,
    product_click_count bigint,
    exposure_to_click_rate_events numeric(18,8),
    click_to_transaction_rate_events numeric(18,8),
    exposure_to_transaction_rate_events numeric(18,8),
    shipped_user_pay_amount_ship_time numeric(20,2),
    ship_within_2_days_rate numeric(18,8),
    settlement_amount numeric(20,2),
    settlement_amount_refund_time numeric(20,2),
    settlement_amount_7d numeric(20,2),
    settlement_amount_14d numeric(20,2),
    net_creator_subsidy_amount_pay_time numeric(20,2),
    creator_subsidy_amount numeric(20,2),
    presale_deposit_amount numeric(20,2),
    transaction_item_count bigint,
    avg_item_amount numeric(20,4),
    net_transaction_order_count bigint,
    pre_shipment_refund_rate_pay_time numeric(18,8),
    unreceived_refund_rate_pay_time numeric(18,8),
    received_refund_rate_pay_time numeric(18,8),
    received_return_refund_rate_pay_time numeric(18,8),
    one_hour_transaction_refund_amount_pay_time numeric(20,2),
    one_hour_refund_order_count_pay_time bigint,
    one_hour_refund_rate_pay_time numeric(18,8),
    net_platform_subsidy_amount_pay_time numeric(20,2),
    batch_id bigint NOT NULL,
    source_sheet_name character varying(50) NOT NULL,
    source_row_number integer NOT NULL,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT douyin_deal_daily_source_row_number_check CHECK ((source_row_number >= 2))
);


ALTER TABLE core.douyin_deal_daily OWNER TO postgres;

--
-- Name: TABLE douyin_deal_daily; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON TABLE core.douyin_deal_daily IS '抖音成交日表：合并成交概览、自营成交、合作成交三张工作表，以成交范围区分。';


--
-- Name: COLUMN douyin_deal_daily.row_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.row_id IS '数据行ID：数据库自动生成的唯一行编号';


--
-- Name: COLUMN douyin_deal_daily.shop_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.shop_id IS '店铺ID：关联meta.shop，用于区分两个抖音店铺及后续其他平台店铺';


--
-- Name: COLUMN douyin_deal_daily.biz_date; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.biz_date IS '业务日期：源字段“日期”。不聚合';


--
-- Name: COLUMN douyin_deal_daily.sale_scope; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.sale_scope IS '成交范围：由源工作表名称生成：成交概览=全部，自营成交=自营，合作成交=合作';


--
-- Name: COLUMN douyin_deal_daily.carrier_type; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.carrier_type IS '载体类型：源字段“载体类型”。用于分组筛选';


--
-- Name: COLUMN douyin_deal_daily.ad_period; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.ad_period IS '投放时段：源字段“投放时段”。用于分组筛选';


--
-- Name: COLUMN douyin_deal_daily.user_pay_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.user_pay_amount IS '用户支付金额：源字段“用户支付金额”。SUM';


--
-- Name: COLUMN douyin_deal_daily.net_user_pay_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.net_user_pay_amount_pay_time IS '退款后用户支付金额(支付时间)：源字段“退款后用户支付金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.smart_coupon_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.smart_coupon_amount IS '智能优惠券金额：源字段“智能优惠券金额”。SUM';


--
-- Name: COLUMN douyin_deal_daily.net_smart_coupon_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.net_smart_coupon_amount_pay_time IS '退款后智能优惠券金额(支付时间)：源字段“退款后智能优惠券金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.platform_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.platform_subsidy_amount IS '平台补贴金额：源字段“平台补贴金额”。SUM';


--
-- Name: COLUMN douyin_deal_daily.transaction_order_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.transaction_order_count IS '成交订单数：源字段“成交订单数”。SUM';


--
-- Name: COLUMN douyin_deal_daily.transaction_buyer_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.transaction_buyer_count IS '成交人数：源字段“成交人数”。SUM';


--
-- Name: COLUMN douyin_deal_daily.avg_customer_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.avg_customer_amount IS '源字段“客单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交人数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.transaction_amount IS '成交金额：源字段“成交金额”。SUM';


--
-- Name: COLUMN douyin_deal_daily.net_transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.net_transaction_amount IS '净成交金额：源字段“净成交金额”。SUM';


--
-- Name: COLUMN douyin_deal_daily.refund_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.refund_amount_refund_time IS '退款金额(退款时间)：源字段“退款金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.transaction_refund_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.transaction_refund_amount_refund_time IS '成交退款金额(退款时间)：源字段“成交退款金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.refund_order_count_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.refund_order_count_refund_time IS '退款订单数(退款时间)：源字段“退款订单数(退款时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.refund_rate_pay_time IS '源字段“退款率(支付时间)”。不可直接求和或平均；V1.4公式：退款金额(支付时间) ÷ 用户支付金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.refund_amount_pay_time IS '退款金额(支付时间)：源字段“退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.transaction_refund_amount_pay_time IS '成交退款金额(支付时间)：源字段“成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.refund_order_count_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.refund_order_count_pay_time IS '退款订单数(支付时间)：源字段“退款订单数(支付时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.product_exposure_user_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.product_exposure_user_count IS '商品曝光人数：源字段“商品曝光人数”。SUM';


--
-- Name: COLUMN douyin_deal_daily.product_click_user_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.product_click_user_count IS '商品点击人数：源字段“商品点击人数”。SUM';


--
-- Name: COLUMN douyin_deal_daily.exposure_to_click_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.exposure_to_click_rate_users IS '源字段“商品曝光-点击转化率(人数)”。不可直接求和或平均；V1.4公式：商品点击人数 ÷ 商品曝光人数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.click_to_transaction_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.click_to_transaction_rate_users IS '源字段“商品点击-成交转化率(人数)”。不可直接求和或平均；V1.4公式：成交人数 ÷ 商品点击人数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.exposure_to_transaction_rate_users; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.exposure_to_transaction_rate_users IS '源字段“商品曝光-成交转化率(人数)”。不可直接求和或平均；V1.4公式：成交人数 ÷ 商品曝光人数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.user_pay_amount_per_1000_exposures; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.user_pay_amount_per_1000_exposures IS '源字段“千次曝光用户支付金额”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 商品曝光次数 × 1000；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.product_exposure_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.product_exposure_count IS '商品曝光次数：源字段“商品曝光次数”。SUM';


--
-- Name: COLUMN douyin_deal_daily.product_click_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.product_click_count IS '商品点击次数：源字段“商品点击次数”。SUM';


--
-- Name: COLUMN douyin_deal_daily.exposure_to_click_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.exposure_to_click_rate_events IS '源字段“商品曝光-点击转化率(次数)”。不可直接求和或平均；V1.4公式：商品点击次数 ÷ 商品曝光次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.click_to_transaction_rate_events IS '源字段“商品点击-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品点击次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.exposure_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.exposure_to_transaction_rate_events IS '源字段“商品曝光-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品曝光次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.shipped_user_pay_amount_ship_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.shipped_user_pay_amount_ship_time IS '发货用户支付金额(发货时间)：源字段“发货用户支付金额(发货时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.ship_within_2_days_rate; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.ship_within_2_days_rate IS '源字段“两日内发货率”。不可直接求和或平均；V1.4公式：平台源值；当前样表缺少明确分子/分母；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.settlement_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.settlement_amount IS '结算金额：源字段“结算金额”。SUM';


--
-- Name: COLUMN douyin_deal_daily.settlement_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.settlement_amount_refund_time IS '结算金额(退款时间)：源字段“结算金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.settlement_amount_7d; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.settlement_amount_7d IS '7日结算金额：源字段“7日结算金额”。SUM';


--
-- Name: COLUMN douyin_deal_daily.settlement_amount_14d; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.settlement_amount_14d IS '14日结算金额：源字段“14日结算金额”。SUM';


--
-- Name: COLUMN douyin_deal_daily.net_creator_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.net_creator_subsidy_amount_pay_time IS '退款后达人补贴金额(支付时间)：源字段“退款后达人补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.creator_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.creator_subsidy_amount IS '达人补贴金额：源字段“达人补贴金额”。SUM';


--
-- Name: COLUMN douyin_deal_daily.presale_deposit_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.presale_deposit_amount IS '预售定金：源字段“预售定金”。SUM';


--
-- Name: COLUMN douyin_deal_daily.transaction_item_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.transaction_item_count IS '成交件数：源字段“成交件数”。SUM';


--
-- Name: COLUMN douyin_deal_daily.avg_item_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.avg_item_amount IS '源字段“件单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交件数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.net_transaction_order_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.net_transaction_order_count IS '净成交订单量：源字段“净成交订单量”。SUM';


--
-- Name: COLUMN douyin_deal_daily.pre_shipment_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.pre_shipment_refund_rate_pay_time IS '源字段“发货前退款率(支付时间)”。不可直接求和或平均；V1.4公式：平台源值；当前样表缺少发货前退款专用分子；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.unreceived_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.unreceived_refund_rate_pay_time IS '源字段“未收货退款率(支付时间)”。不可直接求和或平均；V1.4公式：平台源值；当前样表缺少未收货退款专用分子；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.received_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.received_refund_rate_pay_time IS '源字段“已收货退款率(支付时间)”。不可直接求和或平均；V1.4公式：平台源值；当前样表缺少已收货退款专用分子；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.received_return_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.received_return_refund_rate_pay_time IS '源字段“已收货退货退款率(支付时间)”。不可直接求和或平均；V1.4公式：平台源值；当前样表缺少已收货退货退款专用分子；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.one_hour_transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.one_hour_transaction_refund_amount_pay_time IS '1小时成交退款金额(支付时间)：源字段“1小时成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.one_hour_refund_order_count_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.one_hour_refund_order_count_pay_time IS '1小时退款订单数(支付时间)：源字段“1小时退款订单数(支付时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.one_hour_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.one_hour_refund_rate_pay_time IS '源字段“1小时成交退款率(支付时间)”。不可直接求和或平均；V1.4公式：平台源值；当前虽有1小时退款金额/订单数，但分母口径尚未确认；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_deal_daily.net_platform_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.net_platform_subsidy_amount_pay_time IS '退款后平台补贴金额（支付时间）：源字段“退款后电商平台补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_deal_daily.batch_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.batch_id IS '导入批次ID：关联audit.import_batch，追踪该行来自哪次文件导入';


--
-- Name: COLUMN douyin_deal_daily.source_sheet_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.source_sheet_name IS '源工作表名称：原始Excel中的工作表名称';


--
-- Name: COLUMN douyin_deal_daily.source_row_number; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.source_row_number IS '源文件行号：该数据在原始工作表中的行号，表头为第1行';


--
-- Name: COLUMN douyin_deal_daily.imported_at; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.imported_at IS '写入时间：该数据写入正式表的时间';


--
-- Name: douyin_deal_daily_row_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.douyin_deal_daily_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.douyin_deal_daily_row_id_seq OWNER TO postgres;

--
-- Name: douyin_deal_daily_row_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.douyin_deal_daily_row_id_seq OWNED BY core.douyin_deal_daily.row_id;


--
-- Name: douyin_price_band_daily; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.douyin_price_band_daily (
    row_id bigint NOT NULL,
    shop_id bigint NOT NULL,
    biz_date date NOT NULL,
    price_band character varying(100) DEFAULT ''::character varying NOT NULL,
    user_pay_amount numeric(20,2),
    avg_transaction_order_amount numeric(20,4),
    click_to_transaction_rate_events numeric(18,8),
    batch_id bigint NOT NULL,
    source_sheet_name character varying(50) NOT NULL,
    source_row_number integer NOT NULL,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT douyin_price_band_daily_source_row_number_check CHECK ((source_row_number >= 2))
);


ALTER TABLE core.douyin_price_band_daily OWNER TO postgres;

--
-- Name: TABLE douyin_price_band_daily; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON TABLE core.douyin_price_band_daily IS '抖音价格带构成日表：按价格带拆分。';


--
-- Name: COLUMN douyin_price_band_daily.row_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.row_id IS '数据行ID：数据库自动生成的唯一行编号';


--
-- Name: COLUMN douyin_price_band_daily.shop_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.shop_id IS '店铺ID：关联meta.shop，用于区分两个抖音店铺及后续其他平台店铺';


--
-- Name: COLUMN douyin_price_band_daily.biz_date; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.biz_date IS '业务日期：源字段“日期”。不聚合';


--
-- Name: COLUMN douyin_price_band_daily.price_band; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.price_band IS '价格带：源字段“价格带”。用于分组筛选';


--
-- Name: COLUMN douyin_price_band_daily.user_pay_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.user_pay_amount IS '用户支付金额：源字段“用户支付金额”。SUM';


--
-- Name: COLUMN douyin_price_band_daily.avg_transaction_order_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.avg_transaction_order_amount IS '源字段“成交笔单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交订单数；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_price_band_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.click_to_transaction_rate_events IS '源字段“商品点击-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品点击次数；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_price_band_daily.batch_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.batch_id IS '导入批次ID：关联audit.import_batch，追踪该行来自哪次文件导入';


--
-- Name: COLUMN douyin_price_band_daily.source_sheet_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.source_sheet_name IS '源工作表名称：原始Excel中的工作表名称';


--
-- Name: COLUMN douyin_price_band_daily.source_row_number; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.source_row_number IS '源文件行号：该数据在原始工作表中的行号，表头为第1行';


--
-- Name: COLUMN douyin_price_band_daily.imported_at; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_price_band_daily.imported_at IS '写入时间：该数据写入正式表的时间';


--
-- Name: douyin_price_band_daily_row_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.douyin_price_band_daily_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.douyin_price_band_daily_row_id_seq OWNER TO postgres;

--
-- Name: douyin_price_band_daily_row_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.douyin_price_band_daily_row_id_seq OWNED BY core.douyin_price_band_daily.row_id;


--
-- Name: douyin_product_daily; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.douyin_product_daily (
    row_id bigint NOT NULL,
    shop_id bigint NOT NULL,
    biz_date date NOT NULL,
    product_name text,
    product_id character varying(100) DEFAULT ''::character varying NOT NULL,
    carrier_type character varying(100) DEFAULT ''::character varying NOT NULL,
    user_pay_amount numeric(20,2),
    avg_transaction_order_amount numeric(20,4),
    click_to_transaction_rate_events numeric(18,8),
    refund_amount_pay_time numeric(20,2),
    refund_rate_pay_time numeric(18,8),
    smart_coupon_amount numeric(20,2),
    platform_subsidy_amount numeric(20,2),
    net_smart_coupon_amount_pay_time numeric(20,2),
    net_platform_subsidy_amount_pay_time numeric(20,2),
    batch_id bigint NOT NULL,
    source_sheet_name character varying(50) NOT NULL,
    source_row_number integer NOT NULL,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT douyin_product_daily_source_row_number_check CHECK ((source_row_number >= 2))
);


ALTER TABLE core.douyin_product_daily OWNER TO postgres;

--
-- Name: TABLE douyin_product_daily; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON TABLE core.douyin_product_daily IS '抖音商品构成日表：按商品和载体类型拆分。';


--
-- Name: COLUMN douyin_product_daily.row_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.row_id IS '数据行ID：数据库自动生成的唯一行编号';


--
-- Name: COLUMN douyin_product_daily.shop_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.shop_id IS '店铺ID：关联meta.shop，用于区分两个抖音店铺及后续其他平台店铺';


--
-- Name: COLUMN douyin_product_daily.biz_date; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.biz_date IS '业务日期：源字段“日期”。不聚合';


--
-- Name: COLUMN douyin_product_daily.product_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.product_name IS '商品名称：源字段“商品名称”。用于分组筛选';


--
-- Name: COLUMN douyin_product_daily.product_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.product_id IS '商品编号：源字段“商品编号”。不聚合';


--
-- Name: COLUMN douyin_product_daily.carrier_type; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.carrier_type IS '载体类型：源字段“载体类型”。用于分组筛选';


--
-- Name: COLUMN douyin_product_daily.user_pay_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.user_pay_amount IS '用户支付金额：源字段“用户支付金额”。SUM';


--
-- Name: COLUMN douyin_product_daily.avg_transaction_order_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.avg_transaction_order_amount IS '源字段“成交笔单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交订单数；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_product_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.click_to_transaction_rate_events IS '源字段“商品点击-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品点击次数；规则状态=缺基础字段；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_product_daily.refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.refund_amount_pay_time IS '退款金额(支付时间)：源字段“退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_product_daily.refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.refund_rate_pay_time IS '源字段“退款率(支付时间)”。不可直接求和或平均；V1.4公式：退款金额(支付时间) ÷ 用户支付金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_product_daily.smart_coupon_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.smart_coupon_amount IS '智能优惠券金额：源字段“智能优惠券金额”。SUM';


--
-- Name: COLUMN douyin_product_daily.platform_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.platform_subsidy_amount IS '电商平台补贴金额：源字段“电商平台补贴金额”。SUM';


--
-- Name: COLUMN douyin_product_daily.net_smart_coupon_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.net_smart_coupon_amount_pay_time IS '退款后智能优惠券金额(支付时间)：源字段“退款后智能优惠券金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_product_daily.net_platform_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.net_platform_subsidy_amount_pay_time IS '退款后平台补贴金额（支付时间）：源字段“退款后电商平台补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_product_daily.batch_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.batch_id IS '导入批次ID：关联audit.import_batch，追踪该行来自哪次文件导入';


--
-- Name: COLUMN douyin_product_daily.source_sheet_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.source_sheet_name IS '源工作表名称：原始Excel中的工作表名称';


--
-- Name: COLUMN douyin_product_daily.source_row_number; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.source_row_number IS '源文件行号：该数据在原始工作表中的行号，表头为第1行';


--
-- Name: COLUMN douyin_product_daily.imported_at; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_product_daily.imported_at IS '写入时间：该数据写入正式表的时间';


--
-- Name: douyin_product_daily_row_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.douyin_product_daily_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.douyin_product_daily_row_id_seq OWNER TO postgres;

--
-- Name: douyin_product_daily_row_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.douyin_product_daily_row_id_seq OWNED BY core.douyin_product_daily.row_id;


--
-- Name: douyin_terminal_daily; Type: TABLE; Schema: core; Owner: postgres
--

CREATE TABLE core.douyin_terminal_daily (
    row_id bigint NOT NULL,
    shop_id bigint NOT NULL,
    biz_date date NOT NULL,
    terminal_type character varying(100) DEFAULT ''::character varying NOT NULL,
    selling_type character varying(100) DEFAULT ''::character varying NOT NULL,
    transaction_amount numeric(20,2),
    user_pay_amount numeric(20,2),
    settlement_amount numeric(20,2),
    transaction_order_count bigint,
    transaction_refund_amount_pay_time numeric(20,2),
    refund_rate_pay_time numeric(18,8),
    product_exposure_count bigint,
    product_click_count bigint,
    exposure_to_click_rate_events numeric(18,8),
    click_to_transaction_rate_events numeric(18,8),
    smart_coupon_amount numeric(20,2),
    platform_subsidy_amount numeric(20,2),
    creator_subsidy_amount numeric(20,2),
    presale_deposit_amount numeric(20,2),
    transaction_item_count bigint,
    avg_item_amount numeric(20,4),
    settlement_amount_7d numeric(20,2),
    settlement_amount_14d numeric(20,2),
    settlement_amount_refund_time numeric(20,2),
    ad_attributed_settlement_amount numeric(20,2),
    net_user_pay_amount_pay_time numeric(20,2),
    net_smart_coupon_amount_pay_time numeric(20,2),
    net_platform_subsidy_amount_pay_time numeric(20,2),
    net_creator_subsidy_amount_pay_time numeric(20,2),
    refund_amount_pay_time numeric(20,2),
    refund_order_count_pay_time bigint,
    transaction_refund_amount_refund_time numeric(20,2),
    refund_amount_refund_time numeric(20,2),
    refund_order_count_refund_time bigint,
    one_hour_transaction_refund_amount_pay_time numeric(20,2),
    one_hour_refund_order_count_pay_time bigint,
    one_hour_refund_rate_pay_time numeric(18,8),
    exposure_to_transaction_rate_events numeric(18,8),
    user_pay_amount_per_1000_exposures numeric(20,4),
    batch_id bigint NOT NULL,
    source_sheet_name character varying(50) NOT NULL,
    source_row_number integer NOT NULL,
    imported_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT douyin_terminal_daily_source_row_number_check CHECK ((source_row_number >= 2))
);


ALTER TABLE core.douyin_terminal_daily OWNER TO postgres;

--
-- Name: TABLE douyin_terminal_daily; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON TABLE core.douyin_terminal_daily IS '抖音终端构成日表：按终端类型和售卖类型拆分。';


--
-- Name: COLUMN douyin_terminal_daily.row_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.row_id IS '数据行ID：数据库自动生成的唯一行编号';


--
-- Name: COLUMN douyin_terminal_daily.shop_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.shop_id IS '店铺ID：关联meta.shop，用于区分两个抖音店铺及后续其他平台店铺';


--
-- Name: COLUMN douyin_terminal_daily.biz_date; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.biz_date IS '业务日期：源字段“日期”。不聚合';


--
-- Name: COLUMN douyin_terminal_daily.terminal_type; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.terminal_type IS '终端类型：源字段“终端类型”。用于分组筛选';


--
-- Name: COLUMN douyin_terminal_daily.selling_type; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.selling_type IS '售卖类型：源字段“售卖类型”。用于分组筛选';


--
-- Name: COLUMN douyin_terminal_daily.transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.transaction_amount IS '成交金额：源字段“成交金额”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.user_pay_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.user_pay_amount IS '用户支付金额：源字段“用户支付金额”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.settlement_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.settlement_amount IS '结算金额：源字段“结算金额”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.transaction_order_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.transaction_order_count IS '成交订单数：源字段“成交订单数”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.transaction_refund_amount_pay_time IS '成交退款金额(支付时间)：源字段“成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.refund_rate_pay_time IS '源字段“退款率(支付时间)”。不可直接求和或平均；V1.4公式：退款金额(支付时间) ÷ 用户支付金额；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_terminal_daily.product_exposure_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.product_exposure_count IS '商品曝光次数：源字段“商品曝光次数”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.product_click_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.product_click_count IS '商品点击次数：源字段“商品点击次数”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.exposure_to_click_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.exposure_to_click_rate_events IS '源字段“商品曝光-点击转化率(次数)”。不可直接求和或平均；V1.4公式：商品点击次数 ÷ 商品曝光次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_terminal_daily.click_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.click_to_transaction_rate_events IS '源字段“商品点击-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品点击次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_terminal_daily.smart_coupon_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.smart_coupon_amount IS '智能优惠券金额：源字段“智能优惠券金额”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.platform_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.platform_subsidy_amount IS '平台补贴金额：源字段“平台补贴金额”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.creator_subsidy_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.creator_subsidy_amount IS '达人补贴金额：源字段“达人补贴金额”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.presale_deposit_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.presale_deposit_amount IS '预售定金：源字段“预售定金”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.transaction_item_count; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.transaction_item_count IS '成交件数：源字段“成交件数”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.avg_item_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.avg_item_amount IS '源字段“件单价”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 成交件数；规则状态=已确认；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_terminal_daily.settlement_amount_7d; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.settlement_amount_7d IS '7日结算金额：源字段“7日结算金额”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.settlement_amount_14d; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.settlement_amount_14d IS '14日结算金额：源字段“14日结算金额”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.settlement_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.settlement_amount_refund_time IS '结算金额(退款时间)：源字段“结算金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.ad_attributed_settlement_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.ad_attributed_settlement_amount IS '投放贡献结算金额：源字段“投放贡献结算金额”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.net_user_pay_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.net_user_pay_amount_pay_time IS '退款后用户支付金额(支付时间)：源字段“退款后用户支付金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.net_smart_coupon_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.net_smart_coupon_amount_pay_time IS '退款后智能优惠券金额(支付时间)：源字段“退款后智能优惠券金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.net_platform_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.net_platform_subsidy_amount_pay_time IS '退款后平台补贴金额（支付时间）：源字段“退款后平台补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.net_creator_subsidy_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.net_creator_subsidy_amount_pay_time IS '退款后达人补贴金额(支付时间)：源字段“退款后达人补贴金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.refund_amount_pay_time IS '退款金额(支付时间)：源字段“退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.refund_order_count_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.refund_order_count_pay_time IS '退款订单数(支付时间)：源字段“退款订单数(支付时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.transaction_refund_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.transaction_refund_amount_refund_time IS '成交退款金额(退款时间)：源字段“成交退款金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.refund_amount_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.refund_amount_refund_time IS '退款金额(退款时间)：源字段“退款金额(退款时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.refund_order_count_refund_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.refund_order_count_refund_time IS '退款订单数(退款时间)：源字段“退款订单数(退款时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.one_hour_transaction_refund_amount_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.one_hour_transaction_refund_amount_pay_time IS '1小时成交退款金额(支付时间)：源字段“1小时成交退款金额(支付时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.one_hour_refund_order_count_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.one_hour_refund_order_count_pay_time IS '1小时退款订单数(支付时间)：源字段“1小时退款订单数(支付时间)”。SUM';


--
-- Name: COLUMN douyin_terminal_daily.one_hour_refund_rate_pay_time; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.one_hour_refund_rate_pay_time IS '源字段“1小时退款率(支付时间)”。不可直接求和或平均；V1.4公式：平台源值；当前虽有1小时退款金额/订单数，但分母口径尚未确认；规则状态=待平台口径确认；跨期可精确重算=否；允许自动采用=否；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_terminal_daily.exposure_to_transaction_rate_events; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.exposure_to_transaction_rate_events IS '源字段“商品曝光-成交转化率(次数)”。不可直接求和或平均；V1.4公式：成交订单数 ÷ 商品曝光次数；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_terminal_daily.user_pay_amount_per_1000_exposures; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.user_pay_amount_per_1000_exposures IS '源字段“千次曝光用户支付金额”。不可直接求和或平均；V1.4公式：用户支付金额 ÷ 商品曝光次数 × 1000；规则状态=已明确；跨期可精确重算=是；允许自动采用=是；详见“指标公式规则”。';


--
-- Name: COLUMN douyin_terminal_daily.batch_id; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.batch_id IS '导入批次ID：关联audit.import_batch，追踪该行来自哪次文件导入';


--
-- Name: COLUMN douyin_terminal_daily.source_sheet_name; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.source_sheet_name IS '源工作表名称：原始Excel中的工作表名称';


--
-- Name: COLUMN douyin_terminal_daily.source_row_number; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.source_row_number IS '源文件行号：该数据在原始工作表中的行号，表头为第1行';


--
-- Name: COLUMN douyin_terminal_daily.imported_at; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_terminal_daily.imported_at IS '写入时间：该数据写入正式表的时间';


--
-- Name: douyin_terminal_daily_row_id_seq; Type: SEQUENCE; Schema: core; Owner: postgres
--

CREATE SEQUENCE core.douyin_terminal_daily_row_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE core.douyin_terminal_daily_row_id_seq OWNER TO postgres;

--
-- Name: douyin_terminal_daily_row_id_seq; Type: SEQUENCE OWNED BY; Schema: core; Owner: postgres
--

ALTER SEQUENCE core.douyin_terminal_daily_row_id_seq OWNED BY core.douyin_terminal_daily.row_id;


--
-- Name: shop; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.shop (
    shop_id bigint NOT NULL,
    platform_code character varying(30) NOT NULL,
    shop_code character varying(50) NOT NULL,
    shop_name character varying(100) NOT NULL,
    platform_shop_id character varying(100),
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE meta.shop OWNER TO postgres;

--
-- Name: TABLE shop; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.shop IS '店铺基础资料表：统一登记抖音、天猫、京东等平台的所有店铺。';


--
-- Name: COLUMN shop.shop_id; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.shop_id IS '店铺内部ID：数据库自动生成的唯一编号。';


--
-- Name: COLUMN shop.platform_code; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.platform_code IS '平台编码：例如douyin代表抖音，tmall代表天猫，jd代表京东。';


--
-- Name: COLUMN shop.shop_code; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.shop_code IS '店铺内部编码：企业自己制定的稳定店铺编码，不随店铺名称变化。';


--
-- Name: COLUMN shop.shop_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.shop_name IS '店铺名称：平台上显示的正式店铺名称。';


--
-- Name: COLUMN shop.platform_shop_id; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.platform_shop_id IS '平台店铺ID：抖音、天猫等平台提供的店铺唯一编号，没有时可以暂时为空。';


--
-- Name: COLUMN shop.enabled; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.enabled IS '是否启用：TRUE表示正常使用，FALSE表示停止导入和查询。';


--
-- Name: COLUMN shop.created_at; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.shop.created_at IS '创建时间：店铺资料写入数据库的时间。';


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
-- Name: metric_formula_rule; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.metric_formula_rule (
    metric_rule_id bigint NOT NULL,
    target_schema character varying(50) DEFAULT 'core'::character varying NOT NULL,
    target_table character varying(100) NOT NULL,
    target_column_name_cn character varying(300) NOT NULL,
    target_column_name character varying(150) NOT NULL,
    metric_category character varying(50) NOT NULL,
    calculation_mode character varying(30) NOT NULL,
    formula_cn text,
    numerator_expression text,
    denominator_expression text,
    multiplier numeric(20,8) DEFAULT 1 NOT NULL,
    single_row_formula text,
    period_formula_sql text,
    zero_denominator_rule character varying(30) DEFAULT 'NULL'::character varying NOT NULL,
    cross_period_recalculable boolean DEFAULT false NOT NULL,
    auto_use_allowed boolean DEFAULT false NOT NULL,
    rule_status character varying(30) NOT NULL,
    display_format character varying(30),
    mapping_version character varying(20) DEFAULT 'V1.4'::character varying NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    verification_method text,
    verification_period character varying(100),
    verification_result text
);


ALTER TABLE meta.metric_formula_rule OWNER TO postgres;

--
-- Name: TABLE metric_formula_rule; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.metric_formula_rule IS 'V1.4指标公式规则：记录比例/均值等非可加指标的分子、分母、跨期SQL、规则状态及真实Excel核对结果。';


--
-- Name: COLUMN metric_formula_rule.target_schema; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.target_schema IS '目标Schema，当前为core。';


--
-- Name: COLUMN metric_formula_rule.target_table; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.target_table IS '目标正式表。';


--
-- Name: COLUMN metric_formula_rule.target_column_name_cn; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.target_column_name_cn IS '指标中文名称。';


--
-- Name: COLUMN metric_formula_rule.target_column_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.target_column_name IS '指标英文物理字段名。';


--
-- Name: COLUMN metric_formula_rule.metric_category; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.metric_category IS '指标类别：比例指标或均值指标。';


--
-- Name: COLUMN metric_formula_rule.calculation_mode; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.calculation_mode IS '计算模式：ratio、ratio_x1000、ratio_expr或source_only。';


--
-- Name: COLUMN metric_formula_rule.formula_cn; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.formula_cn IS '业务公式中文说明。';


--
-- Name: COLUMN metric_formula_rule.numerator_expression; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.numerator_expression IS '分子字段或分子表达式。';


--
-- Name: COLUMN metric_formula_rule.denominator_expression; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.denominator_expression IS '分母字段或表达式。';


--
-- Name: COLUMN metric_formula_rule.multiplier; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.multiplier IS '计算倍率，例如千次曝光指标为1000。';


--
-- Name: COLUMN metric_formula_rule.single_row_formula; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.single_row_formula IS '单行英文公式；source_only或缺基础字段时为空。';


--
-- Name: COLUMN metric_formula_rule.period_formula_sql; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.period_formula_sql IS '跨期聚合SQL表达式；禁止简单SUM/AVG非可加指标。';


--
-- Name: COLUMN metric_formula_rule.zero_denominator_rule; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.zero_denominator_rule IS '分母为0规则，统一为NULL。';


--
-- Name: COLUMN metric_formula_rule.cross_period_recalculable; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.cross_period_recalculable IS '当前正式表是否具备完整基础字段，可精确跨期重算。';


--
-- Name: COLUMN metric_formula_rule.auto_use_allowed; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.auto_use_allowed IS '是否允许后续mart/MCP自动采用该规则。';


--
-- Name: COLUMN metric_formula_rule.rule_status; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.rule_status IS '当前状态：已确认、已明确、待平台口径确认或缺基础字段。';


--
-- Name: COLUMN metric_formula_rule.display_format; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.display_format IS '展示格式；比例指标通常为0.00%。';


--
-- Name: COLUMN metric_formula_rule.mapping_version; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.mapping_version IS '规则版本。';


--
-- Name: COLUMN metric_formula_rule.notes; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.notes IS '补充业务说明。';


--
-- Name: COLUMN metric_formula_rule.verification_method; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.verification_method IS '公式确认方式，例如真实6月Excel逐行反算核对。';


--
-- Name: COLUMN metric_formula_rule.verification_period; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.verification_period IS '公式核对样本期间。';


--
-- Name: COLUMN metric_formula_rule.verification_result; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.metric_formula_rule.verification_result IS '公式核对结果。';


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
-- Name: database_object_dictionary; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.database_object_dictionary (
    dictionary_id bigint NOT NULL,
    schema_name character varying(50) NOT NULL,
    object_name character varying(150) NOT NULL,
    object_type character varying(30) DEFAULT 'table'::character varying NOT NULL,
    object_name_cn character varying(200),
    column_name character varying(150),
    column_name_cn character varying(300),
    source_platform character varying(50) DEFAULT 'douyin'::character varying,
    source_sheet_name character varying(200),
    source_field_name_cn character varying(300),
    source_header_variants jsonb,
    chinese_name_source character varying(40) DEFAULT 'source_header'::character varying NOT NULL,
    name_resolution_status character varying(40) DEFAULT 'unique_source_header'::character varying NOT NULL,
    is_manual_override boolean DEFAULT false NOT NULL,
    override_reason text,
    business_definition text,
    display_order integer,
    visible_in_cn_view boolean DEFAULT true NOT NULL,
    mapping_version character varying(20) DEFAULT 'V1.1'::character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE meta.database_object_dictionary OWNER TO postgres;

--
-- Name: TABLE database_object_dictionary; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.database_object_dictionary IS '全库中英文字典：记录最终显示名称及其来源（原始表头/系统词典/人工覆盖），可溯源。';


--
-- Name: COLUMN database_object_dictionary.source_header_variants; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.database_object_dictionary.source_header_variants IS '同一物理字段对应的所有“工作表→原始表头”，JSONB保留多源信息。';


--
-- Name: COLUMN database_object_dictionary.chinese_name_source; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.database_object_dictionary.chinese_name_source IS '名称来源：source_header原始表头/manual人工/system_dictionary系统词典/comment注释。';


--
-- Name: COLUMN database_object_dictionary.name_resolution_status; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.database_object_dictionary.name_resolution_status IS '解析状态：unique_source_header唯一表头/manual_confirmed人工确认/system_field系统字段/conflict_pending冲突待决。';


--
-- Name: database_object_dictionary_dictionary_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.database_object_dictionary_dictionary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.database_object_dictionary_dictionary_id_seq OWNER TO postgres;

--
-- Name: database_object_dictionary_dictionary_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.database_object_dictionary_dictionary_id_seq OWNED BY meta.database_object_dictionary.dictionary_id;


--
-- Name: field_mapping; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.field_mapping (
    mapping_id bigint NOT NULL,
    source_sheet_name character varying(100) NOT NULL,
    source_sheet_code character varying(100) NOT NULL,
    source_column_order integer NOT NULL,
    source_column_name character varying(300) NOT NULL,
    target_schema character varying(50) DEFAULT 'core'::character varying NOT NULL,
    target_table character varying(100) NOT NULL,
    target_column_name character varying(150) NOT NULL,
    target_column_name_cn character varying(300) NOT NULL,
    target_data_type character varying(100) NOT NULL,
    field_category character varying(50) NOT NULL,
    aggregation_rule character varying(200) NOT NULL,
    transform_rule text,
    value_unit character varying(30) DEFAULT 'number'::character varying NOT NULL,
    display_format character varying(30),
    display_decimal_places smallint,
    is_business_key boolean DEFAULT false NOT NULL,
    is_required_header boolean DEFAULT true NOT NULL,
    mapping_version character varying(20) DEFAULT 'V1.1'::character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE meta.field_mapping OWNER TO postgres;

--
-- Name: TABLE field_mapping; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.field_mapping IS '字段映射表：逐字段记录11张源工作表的中文字段如何转换为正式表英文列、数据类型、聚合规则和清洗规则。';


--
-- Name: COLUMN field_mapping.mapping_id; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.mapping_id IS '字段映射ID：数据库自动生成。';


--
-- Name: COLUMN field_mapping.source_sheet_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.source_sheet_name IS '源工作表中文名称。';


--
-- Name: COLUMN field_mapping.source_sheet_code; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.source_sheet_code IS '源工作表英文编码。';


--
-- Name: COLUMN field_mapping.source_column_order; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.source_column_order IS '源字段顺序：从1开始，用于严格校验表头顺序。';


--
-- Name: COLUMN field_mapping.source_column_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.source_column_name IS '源Excel中文字段名。';


--
-- Name: COLUMN field_mapping.target_schema; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.target_schema IS '目标Schema。';


--
-- Name: COLUMN field_mapping.target_table; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.target_table IS '目标正式表。';


--
-- Name: COLUMN field_mapping.target_column_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.target_column_name IS '目标英文物理字段名。';


--
-- Name: COLUMN field_mapping.target_column_name_cn; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.target_column_name_cn IS '目标字段中文名称。';


--
-- Name: COLUMN field_mapping.target_data_type; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.target_data_type IS 'PostgreSQL目标数据类型。';


--
-- Name: COLUMN field_mapping.field_category; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.field_category IS '字段类别：日期、维度、标识、可累加金额、可累加计数、均值或比例。';


--
-- Name: COLUMN field_mapping.aggregation_rule; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.aggregation_rule IS '跨日期汇总规则；比例和均值禁止直接求和或简单平均。';


--
-- Name: COLUMN field_mapping.transform_rule; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.transform_rule IS '导入时的数据清洗和类型转换规则。';


--
-- Name: COLUMN field_mapping.value_unit; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.value_unit IS '数值单位：number普通数值、percent百分比。比例指标保存比率原始数值，不限制0—1；数值型源值原样保留。';


--
-- Name: COLUMN field_mapping.display_format; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.display_format IS '展示格式：百分比指标统一使用0.00%，例如数据库值0.0378展示为3.78%。';


--
-- Name: COLUMN field_mapping.display_decimal_places; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.display_decimal_places IS '展示小数位数：百分比指标固定为2。';


--
-- Name: COLUMN field_mapping.is_business_key; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.is_business_key IS '是否属于该正式表业务唯一键。';


--
-- Name: COLUMN field_mapping.is_required_header; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.is_required_header IS '源文件是否必须存在该字段表头。';


--
-- Name: COLUMN field_mapping.mapping_version; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.mapping_version IS '字段映射版本。';


--
-- Name: COLUMN field_mapping.enabled; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.enabled IS '是否启用该字段。';


--
-- Name: COLUMN field_mapping.notes; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.notes IS '补充说明。';


--
-- Name: COLUMN field_mapping.created_at; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.field_mapping.created_at IS '映射记录创建时间。';


--
-- Name: field_mapping_mapping_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.field_mapping_mapping_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.field_mapping_mapping_id_seq OWNER TO postgres;

--
-- Name: field_mapping_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.field_mapping_mapping_id_seq OWNED BY meta.field_mapping.mapping_id;


--
-- Name: metric_formula_rule_metric_rule_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.metric_formula_rule_metric_rule_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.metric_formula_rule_metric_rule_id_seq OWNER TO postgres;

--
-- Name: metric_formula_rule_metric_rule_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.metric_formula_rule_metric_rule_id_seq OWNED BY meta.metric_formula_rule.metric_rule_id;


--
-- Name: shop_shop_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.shop_shop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.shop_shop_id_seq OWNER TO postgres;

--
-- Name: shop_shop_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.shop_shop_id_seq OWNED BY meta.shop.shop_id;


--
-- Name: source_sheet_mapping; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.source_sheet_mapping (
    source_sheet_name character varying(100) NOT NULL,
    source_report_code character varying(100) DEFAULT 'douyin_compass_deal_analysis'::character varying NOT NULL,
    source_sheet_code character varying(100) NOT NULL,
    target_schema character varying(50) DEFAULT 'core'::character varying NOT NULL,
    target_table character varying(100) NOT NULL,
    sale_scope_override character varying(20),
    expected_column_count integer NOT NULL,
    sample_row_count integer,
    load_order integer NOT NULL,
    mapping_version character varying(20) DEFAULT 'V1.1'::character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE meta.source_sheet_mapping OWNER TO postgres;

--
-- Name: TABLE source_sheet_mapping; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.source_sheet_mapping IS '源工作表映射表：登记抖音成交分析Excel中每张工作表应写入的正式表、字段数量和派生规则。';


--
-- Name: COLUMN source_sheet_mapping.source_sheet_name; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.source_sheet_name IS '源工作表名称：必须与Excel标签名称完全一致。';


--
-- Name: COLUMN source_sheet_mapping.source_report_code; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.source_report_code IS '源报表编码：用于区分抖音成交分析、商品卡列表等不同报表。';


--
-- Name: COLUMN source_sheet_mapping.source_sheet_code; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.source_sheet_code IS '工作表内部编码：程序使用的稳定英文编码。';


--
-- Name: COLUMN source_sheet_mapping.target_schema; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.target_schema IS '目标Schema：本项目正式数据统一写入core层。';


--
-- Name: COLUMN source_sheet_mapping.target_table; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.target_table IS '目标正式表名称。';


--
-- Name: COLUMN source_sheet_mapping.sale_scope_override; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.sale_scope_override IS '成交范围覆盖值：成交概览=全部、自营成交=自营、合作成交=合作；其他工作表为空。';


--
-- Name: COLUMN source_sheet_mapping.expected_column_count; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.expected_column_count IS '预期字段数：导入时用于检查源文件是否改版。';


--
-- Name: COLUMN source_sheet_mapping.sample_row_count; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.sample_row_count IS '当前参考样表的数据行数，仅用于设计核对，不作为导入限制。';


--
-- Name: COLUMN source_sheet_mapping.load_order; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.load_order IS '导入顺序：数值越小越先处理。';


--
-- Name: COLUMN source_sheet_mapping.mapping_version; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.mapping_version IS '字段映射版本。';


--
-- Name: COLUMN source_sheet_mapping.enabled; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.enabled IS '是否启用该工作表导入。';


--
-- Name: COLUMN source_sheet_mapping.description; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.description IS '工作表中文用途说明。';


--
-- Name: COLUMN source_sheet_mapping.created_at; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON COLUMN meta.source_sheet_mapping.created_at IS '映射记录创建时间。';


--
-- Name: 人群构成分析; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."人群构成分析" AS
 SELECT shop_name AS "店铺名称",
    biz_date AS "日期",
    audience_type AS "人群类型",
    carrier_type AS "载体类型",
    user_pay_amount AS "用户支付金额",
    transaction_buyer_count AS "成交人数",
    avg_customer_amount AS "客单价",
    transaction_order_count AS "成交订单数",
    repeat_user_repeat_rate AS "复购用户复购率"
   FROM mart.audience_daily;


ALTER VIEW "中文数据"."人群构成分析" OWNER TO postgres;

--
-- Name: 价格带构成分析; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."价格带构成分析" AS
 SELECT shop_name AS "店铺名称",
    biz_date AS "日期",
    price_band AS "价格带",
    user_pay_amount AS "用户支付金额",
    avg_transaction_order_amount AS "成交笔单价",
    click_to_transaction_rate_events AS "商品点击-成交转化率(次数)"
   FROM mart.price_band_daily;


ALTER VIEW "中文数据"."价格带构成分析" OWNER TO postgres;

--
-- Name: 单载体内容分析; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."单载体内容分析" AS
 SELECT shop_name AS "店铺名称",
    biz_date AS "日期",
    selling_type AS "售卖类型",
    carrier_type AS "载体类型",
    content_id AS "内容ID",
    content_title AS "标题/名称",
    transaction_amount AS "成交金额",
    user_pay_amount AS "用户支付金额",
    settlement_amount AS "结算金额",
    transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    transaction_order_count AS "成交订单数",
    transaction_item_count AS "成交件数",
    transaction_buyer_count AS "成交人数",
    net_transaction_amount AS "净成交金额"
   FROM mart.content_daily;


ALTER VIEW "中文数据"."单载体内容分析" OWNER TO postgres;

--
-- Name: 品类构成分析; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."品类构成分析" AS
 SELECT shop_name AS "店铺名称",
    biz_date AS "日期",
    category_l1 AS "一级类目",
    category_l2 AS "二级类目",
    category_l3 AS "三级类目",
    category_l4 AS "四级类目",
    category_level AS "类目层级",
    is_total_row AS "是否汇总行",
    user_pay_amount AS "用户支付金额",
    avg_transaction_order_amount AS "成交笔单价",
    click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)"
   FROM mart.category_daily;


ALTER VIEW "中文数据"."品类构成分析" OWNER TO postgres;

--
-- Name: 商品构成分析; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."商品构成分析" AS
 SELECT shop_name AS "店铺名称",
    biz_date AS "日期",
    product_id AS "商品编号",
    product_name AS "商品名称",
    carrier_type AS "载体类型",
    user_pay_amount AS "用户支付金额",
    avg_transaction_order_amount AS "成交笔单价",
    click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    smart_coupon_amount AS "智能优惠券金额",
    platform_subsidy_amount AS "电商平台补贴金额"
   FROM mart.product_daily;


ALTER VIEW "中文数据"."商品构成分析" OWNER TO postgres;

--
-- Name: 字段映射规则; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."字段映射规则" AS
 SELECT mapping_id,
    source_sheet_name AS "源工作表名称",
    source_sheet_code AS "工作表编码",
    source_column_order AS "源字段顺序",
    source_column_name AS "源中文字段名",
    target_schema AS "目标Schema",
    target_table AS "目标正式表",
    target_column_name AS "目标英文字段名",
    target_column_name_cn AS "目标字段中文名",
    target_data_type AS "目标数据类型",
    field_category AS "字段类别",
    aggregation_rule AS "聚合规则",
    transform_rule AS "转换规则",
    value_unit AS "数值单位",
    display_format AS "展示格式",
    display_decimal_places AS "展示小数位",
    is_business_key AS "业务键标记",
    is_required_header AS "必填表头标记",
    mapping_version AS "映射版本",
    enabled AS "是否启用",
    notes AS "备注",
    created_at AS "创建时间"
   FROM meta.field_mapping;


ALTER VIEW "中文数据"."字段映射规则" OWNER TO postgres;

--
-- Name: 导入批次记录; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."导入批次记录" AS
 SELECT t.batch_id AS "导入批次ID",
    t.platform_code AS "平台编码",
    s.shop_name AS "店铺名称",
    t.source_file_name AS "源文件名",
    t.source_file_path AS "源文件路径",
    t.file_sha256 AS "文件SHA256",
    t.period_start AS "周期开始",
    t.period_end AS "周期结束",
    t.import_mode AS "导入模式",
    t.import_status AS "导入状态",
    t.source_row_count AS "源文件行数",
    t.inserted_row_count AS "写入行数",
    t.error_message AS "错误信息",
    t.imported_at AS "写入时间"
   FROM (audit.import_batch t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW "中文数据"."导入批次记录" OWNER TO postgres;

--
-- Name: 工作表映射规则; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."工作表映射规则" AS
 SELECT source_sheet_name AS "源工作表名称",
    source_report_code AS "源报表编码",
    source_sheet_code AS "工作表编码",
    target_schema AS "目标Schema",
    target_table AS "目标正式表",
    sale_scope_override AS "成交范围覆盖值",
    expected_column_count AS "预期字段数",
    sample_row_count AS "参考样表行数",
    load_order AS "导入顺序",
    mapping_version AS "映射版本",
    enabled AS "是否启用",
    description AS "说明",
    created_at AS "创建时间"
   FROM meta.source_sheet_mapping;


ALTER VIEW "中文数据"."工作表映射规则" OWNER TO postgres;

--
-- Name: 店铺信息; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."店铺信息" AS
 SELECT shop_id AS "店铺ID",
    platform_code AS "平台编码",
    shop_code AS "店铺编码",
    shop_name AS "店铺名称",
    platform_shop_id AS "平台店铺ID",
    enabled AS "是否启用",
    created_at AS "创建时间"
   FROM meta.shop;


ALTER VIEW "中文数据"."店铺信息" OWNER TO postgres;

--
-- Name: 店铺每日总览; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."店铺每日总览" AS
 SELECT shop_name AS "店铺名称",
    biz_date AS "日期",
    user_pay_amount AS "用户支付金额",
    net_user_pay_amount_pay_time AS "退款后用户支付金额(支付时间)",
    smart_coupon_amount AS "智能优惠券金额",
    platform_subsidy_amount AS "平台补贴金额",
    transaction_order_count AS "成交订单数",
    transaction_buyer_count AS "成交人数",
    avg_customer_amount AS "客单价",
    transaction_amount AS "成交金额",
    net_transaction_amount AS "净成交金额",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    settlement_amount AS "结算金额",
    creator_subsidy_amount AS "达人补贴金额",
    transaction_item_count AS "成交件数",
    avg_item_amount AS "件单价"
   FROM mart.shop_daily;


ALTER VIEW "中文数据"."店铺每日总览" OWNER TO postgres;

--
-- Name: 抖音人群日报; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音人群日报" AS
 SELECT t.row_id AS "数据行ID",
    s.shop_name AS "店铺名称",
    t.biz_date AS "日期",
    t.audience_type AS "人群类型",
    t.carrier_type AS "载体类型",
    t.user_pay_amount AS "用户支付金额",
    t.transaction_buyer_count AS "成交人数",
    t.avg_customer_amount AS "客单价",
    t.transaction_order_count AS "成交订单数",
    t.repeat_user_repeat_rate AS "复购用户复购率",
    t.batch_id AS "导入批次ID",
    t.source_sheet_name AS "源工作表名称",
    t.source_row_number AS "源文件行号",
    t.imported_at AS "写入时间"
   FROM (core.douyin_audience_daily t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW "中文数据"."抖音人群日报" OWNER TO postgres;

--
-- Name: 抖音价格带日报; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音价格带日报" AS
 SELECT t.row_id AS "数据行ID",
    s.shop_name AS "店铺名称",
    t.biz_date AS "日期",
    t.price_band AS "价格带",
    t.user_pay_amount AS "用户支付金额",
    t.avg_transaction_order_amount AS "成交笔单价",
    t.click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    t.batch_id AS "导入批次ID",
    t.source_sheet_name AS "源工作表名称",
    t.source_row_number AS "源文件行号",
    t.imported_at AS "写入时间"
   FROM (core.douyin_price_band_daily t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW "中文数据"."抖音价格带日报" OWNER TO postgres;

--
-- Name: 抖音内容日报; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音内容日报" AS
 SELECT t.row_id AS "数据行ID",
    s.shop_name AS "店铺名称",
    t.biz_date AS "日期",
    t.selling_type AS "售卖类型",
    t.carrier_type AS "载体类型",
    t.content_id AS "ID",
    t.content_title AS "标题/名称",
    t.transaction_amount AS "成交金额",
    t.user_pay_amount AS "用户支付金额",
    t.settlement_amount AS "结算金额",
    t.transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    t.refund_amount_pay_time AS "退款金额(支付时间)",
    t.refund_rate_pay_time AS "退款率(支付时间)",
    t.ad_attributed_transaction_amount AS "投放贡献成交金额",
    t.ad_attributed_transaction_share AS "投放贡献成交占比",
    t.ad_spend_shop_promoted AS "投放消耗(店铺被投)",
    t.ad_spend_rate_net_refund_shop_promoted AS "投放费比(剔除退款、店铺被投)",
    t.exposure_to_click_rate_users AS "商品曝光-点击转化率(人数)",
    t.click_to_transaction_rate_users AS "商品点击-成交转化率(人数)",
    t.smart_coupon_amount AS "智能优惠券金额",
    t.platform_subsidy_amount AS "平台补贴金额",
    t.creator_subsidy_amount AS "达人补贴金额",
    t.presale_deposit_amount AS "预售定金",
    t.transaction_order_count AS "成交订单数",
    t.transaction_item_count AS "成交件数",
    t.avg_item_amount AS "件单价",
    t.transaction_buyer_count AS "成交人数",
    t.avg_customer_amount AS "客单价",
    t.net_transaction_amount AS "净成交金额",
    t.net_transaction_order_count AS "净成交订单量",
    t.settlement_amount_7d AS "7日结算金额",
    t.settlement_amount_14d AS "14日结算金额",
    t.settlement_amount_refund_time AS "结算金额(退款时间)",
    t.ad_attributed_settlement_amount AS "投放贡献结算金额",
    t.net_user_pay_amount_pay_time AS "退款后用户支付金额(支付时间)",
    t.net_smart_coupon_amount_pay_time AS "退款后智能优惠券金额(支付时间)",
    t.net_platform_subsidy_amount_pay_time AS "退款后平台补贴金额(支付时间)",
    t.net_creator_subsidy_amount_pay_time AS "退款后达人补贴金额(支付时间)",
    t.refund_order_count_pay_time AS "退款订单数(支付时间)",
    t.transaction_refund_amount_refund_time AS "成交退款金额(退款时间)",
    t.refund_amount_refund_time AS "退款金额(退款时间)",
    t.refund_order_count_refund_time AS "退款订单数(退款时间)",
    t.one_hour_transaction_refund_amount_pay_time AS "1小时成交退款金额(支付时间)",
    t.one_hour_refund_order_count_pay_time AS "1小时退款订单数(支付时间)",
    t.one_hour_refund_rate_pay_time AS "1小时退款率(支付时间)",
    t.ad_attributed_transaction_refund_amount_pay_time AS "投放贡献成交退款金额(支付时间)",
    t.ad_attributed_refund_rate_pay_time AS "投放部分退款率(支付时间)",
    t.product_exposure_count AS "商品曝光次数",
    t.product_click_count AS "商品点击次数",
    t.exposure_to_click_rate_events AS "商品曝光-点击转化率(次数)",
    t.click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    t.exposure_to_transaction_rate_events AS "商品曝光-成交转化率(次数)",
    t.product_exposure_user_count AS "商品曝光人数",
    t.product_click_user_count AS "商品点击人数",
    t.exposure_to_transaction_rate_users AS "商品曝光-成交转化率(人数)",
    t.user_pay_amount_per_1000_exposures AS "千次曝光用户支付金额",
    t.ad_spend_shop_bound AS "投放消耗(店铺绑定)",
    t.platform_commission_settlement AS "平台佣金(结算口径)",
    t.creator_commission_settlement AS "达人佣金(结算口径)",
    t.ad_spend_rate_shop_bound AS "投放费比(店铺绑定)",
    t.ad_spend_rate_shop_promoted AS "投放费比(店铺被投)",
    t.ad_spend_rate_net_refund_shop_bound AS "投放费比(剔除退款、店铺绑定)",
    t.total_expense_rate_shop_bound AS "综合费比(店铺绑定)",
    t.total_expense_rate_shop_promoted AS "综合费比(店铺被投)",
    t.total_expense_rate_net_refund_shop_bound AS "综合费比(剔除退款、店铺绑定)",
    t.total_expense_rate_net_refund_shop_promoted AS "综合费比(剔除退款、店铺被投)",
    t.batch_id AS "导入批次ID",
    t.source_sheet_name AS "源工作表名称",
    t.source_row_number AS "源文件行号",
    t.imported_at AS "写入时间"
   FROM (core.douyin_content_daily t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW "中文数据"."抖音内容日报" OWNER TO postgres;

--
-- Name: 抖音商品日报; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音商品日报" AS
 SELECT t.row_id AS "数据行ID",
    s.shop_name AS "店铺名称",
    t.biz_date AS "日期",
    t.product_name AS "商品名称",
    t.product_id AS "商品编号",
    t.carrier_type AS "载体类型",
    t.user_pay_amount AS "用户支付金额",
    t.avg_transaction_order_amount AS "成交笔单价",
    t.click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    t.refund_amount_pay_time AS "退款金额(支付时间)",
    t.refund_rate_pay_time AS "退款率(支付时间)",
    t.smart_coupon_amount AS "智能优惠券金额",
    t.platform_subsidy_amount AS "电商平台补贴金额",
    t.net_smart_coupon_amount_pay_time AS "退款后智能优惠券金额(支付时间)",
    t.net_platform_subsidy_amount_pay_time AS "退款后电商平台补贴金额(支付时间)",
    t.batch_id AS "导入批次ID",
    t.source_sheet_name AS "源工作表名称",
    t.source_row_number AS "源文件行号",
    t.imported_at AS "写入时间"
   FROM (core.douyin_product_daily t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW "中文数据"."抖音商品日报" OWNER TO postgres;

--
-- Name: 抖音成交日报; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音成交日报" AS
 SELECT t.row_id AS "数据行ID",
    s.shop_name AS "店铺名称",
    t.biz_date AS "日期",
    t.sale_scope AS "成交范围",
    t.carrier_type AS "载体类型",
    t.ad_period AS "投放时段",
    t.user_pay_amount AS "用户支付金额",
    t.net_user_pay_amount_pay_time AS "退款后用户支付金额(支付时间)",
    t.smart_coupon_amount AS "智能优惠券金额",
    t.net_smart_coupon_amount_pay_time AS "退款后智能优惠券金额(支付时间)",
    t.platform_subsidy_amount AS "平台补贴金额",
    t.transaction_order_count AS "成交订单数",
    t.transaction_buyer_count AS "成交人数",
    t.avg_customer_amount AS "客单价",
    t.transaction_amount AS "成交金额",
    t.net_transaction_amount AS "净成交金额",
    t.refund_amount_refund_time AS "退款金额(退款时间)",
    t.transaction_refund_amount_refund_time AS "成交退款金额(退款时间)",
    t.refund_order_count_refund_time AS "退款订单数(退款时间)",
    t.refund_rate_pay_time AS "退款率(支付时间)",
    t.refund_amount_pay_time AS "退款金额(支付时间)",
    t.transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    t.refund_order_count_pay_time AS "退款订单数(支付时间)",
    t.product_exposure_user_count AS "商品曝光人数",
    t.product_click_user_count AS "商品点击人数",
    t.exposure_to_click_rate_users AS "商品曝光-点击转化率(人数)",
    t.click_to_transaction_rate_users AS "商品点击-成交转化率(人数)",
    t.exposure_to_transaction_rate_users AS "商品曝光-成交转化率(人数)",
    t.user_pay_amount_per_1000_exposures AS "千次曝光用户支付金额",
    t.product_exposure_count AS "商品曝光次数",
    t.product_click_count AS "商品点击次数",
    t.exposure_to_click_rate_events AS "商品曝光-点击转化率(次数)",
    t.click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    t.exposure_to_transaction_rate_events AS "商品曝光-成交转化率(次数)",
    t.shipped_user_pay_amount_ship_time AS "发货用户支付金额(发货时间)",
    t.ship_within_2_days_rate AS "两日内发货率",
    t.settlement_amount AS "结算金额",
    t.settlement_amount_refund_time AS "结算金额(退款时间)",
    t.settlement_amount_7d AS "7日结算金额",
    t.settlement_amount_14d AS "14日结算金额",
    t.net_creator_subsidy_amount_pay_time AS "退款后达人补贴金额(支付时间)",
    t.creator_subsidy_amount AS "达人补贴金额",
    t.presale_deposit_amount AS "预售定金",
    t.transaction_item_count AS "成交件数",
    t.avg_item_amount AS "件单价",
    t.net_transaction_order_count AS "净成交订单量",
    t.pre_shipment_refund_rate_pay_time AS "发货前退款率(支付时间)",
    t.unreceived_refund_rate_pay_time AS "未收货退款率(支付时间)",
    t.received_refund_rate_pay_time AS "已收货退款率(支付时间)",
    t.received_return_refund_rate_pay_time AS "已收货退货退款率(支付时间)",
    t.one_hour_transaction_refund_amount_pay_time AS "1小时成交退款金额(支付时间)",
    t.one_hour_refund_order_count_pay_time AS "1小时退款订单数(支付时间)",
    t.one_hour_refund_rate_pay_time AS "1小时成交退款率(支付时间)",
    t.net_platform_subsidy_amount_pay_time AS "退款后电商平台补贴金额(支付时间)",
    t.batch_id AS "导入批次ID",
    t.source_sheet_name AS "源工作表名称",
    t.source_row_number AS "源文件行号",
    t.imported_at AS "写入时间"
   FROM (core.douyin_deal_daily t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW "中文数据"."抖音成交日报" OWNER TO postgres;

--
-- Name: 抖音类目日报; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音类目日报" AS
 SELECT t.row_id AS "数据行ID",
    s.shop_name AS "店铺名称",
    t.biz_date AS "日期",
    t.category_level_1 AS "一级类目",
    t.category_level_2 AS "二级类目",
    t.category_level_3 AS "三级类目",
    t.category_level_4 AS "四级类目",
    t.user_pay_amount AS "用户支付金额",
    t.avg_transaction_order_amount AS "成交笔单价",
    t.click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    t.refund_amount_pay_time AS "退款金额(支付时间)",
    t.refund_rate_pay_time AS "退款率(支付时间)",
    t.batch_id AS "导入批次ID",
    t.source_sheet_name AS "源工作表名称",
    t.source_row_number AS "源文件行号",
    t.imported_at AS "写入时间"
   FROM (core.douyin_category_daily t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW "中文数据"."抖音类目日报" OWNER TO postgres;

--
-- Name: 抖音终端日报; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音终端日报" AS
 SELECT t.row_id AS "数据行ID",
    s.shop_name AS "店铺名称",
    t.biz_date AS "日期",
    t.terminal_type AS "终端类型",
    t.selling_type AS "售卖类型",
    t.transaction_amount AS "成交金额",
    t.user_pay_amount AS "用户支付金额",
    t.settlement_amount AS "结算金额",
    t.transaction_order_count AS "成交订单数",
    t.transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    t.refund_rate_pay_time AS "退款率(支付时间)",
    t.product_exposure_count AS "商品曝光次数",
    t.product_click_count AS "商品点击次数",
    t.exposure_to_click_rate_events AS "商品曝光-点击转化率(次数)",
    t.click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    t.smart_coupon_amount AS "智能优惠券金额",
    t.platform_subsidy_amount AS "平台补贴金额",
    t.creator_subsidy_amount AS "达人补贴金额",
    t.presale_deposit_amount AS "预售定金",
    t.transaction_item_count AS "成交件数",
    t.avg_item_amount AS "件单价",
    t.settlement_amount_7d AS "7日结算金额",
    t.settlement_amount_14d AS "14日结算金额",
    t.settlement_amount_refund_time AS "结算金额(退款时间)",
    t.ad_attributed_settlement_amount AS "投放贡献结算金额",
    t.net_user_pay_amount_pay_time AS "退款后用户支付金额(支付时间)",
    t.net_smart_coupon_amount_pay_time AS "退款后智能优惠券金额(支付时间)",
    t.net_platform_subsidy_amount_pay_time AS "退款后平台补贴金额(支付时间)",
    t.net_creator_subsidy_amount_pay_time AS "退款后达人补贴金额(支付时间)",
    t.refund_amount_pay_time AS "退款金额(支付时间)",
    t.refund_order_count_pay_time AS "退款订单数(支付时间)",
    t.transaction_refund_amount_refund_time AS "成交退款金额(退款时间)",
    t.refund_amount_refund_time AS "退款金额(退款时间)",
    t.refund_order_count_refund_time AS "退款订单数(退款时间)",
    t.one_hour_transaction_refund_amount_pay_time AS "1小时成交退款金额(支付时间)",
    t.one_hour_refund_order_count_pay_time AS "1小时退款订单数(支付时间)",
    t.one_hour_refund_rate_pay_time AS "1小时退款率(支付时间)",
    t.exposure_to_transaction_rate_events AS "商品曝光-成交转化率(次数)",
    t.user_pay_amount_per_1000_exposures AS "千次曝光用户支付金额",
    t.batch_id AS "导入批次ID",
    t.source_sheet_name AS "源工作表名称",
    t.source_row_number AS "源文件行号",
    t.imported_at AS "写入时间"
   FROM (core.douyin_terminal_daily t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW "中文数据"."抖音终端日报" OWNER TO postgres;

--
-- Name: 抖音账号日报; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音账号日报" AS
 SELECT t.row_id AS "数据行ID",
    s.shop_name AS "店铺名称",
    t.biz_date AS "日期",
    t.account_name AS "账号名称",
    t.account_type AS "账号类型",
    t.sale_scope AS "自营/合作",
    t.douyin_account_id AS "抖音号",
    t.transaction_amount AS "成交金额",
    t.user_pay_amount AS "用户支付金额",
    t.settlement_amount AS "结算金额",
    t.transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    t.refund_amount_pay_time AS "退款金额(支付时间)",
    t.refund_rate_pay_time AS "退款率(支付时间)",
    t.ad_attributed_transaction_amount AS "投放贡献成交金额",
    t.ad_attributed_transaction_share AS "投放贡献成交占比",
    t.ad_spend_shop_promoted AS "投放消耗(店铺被投)",
    t.ad_spend_rate_net_refund_shop_promoted AS "投放费比(剔除退款、店铺被投)",
    t.exposure_to_click_rate_users AS "商品曝光-点击转化率(人数)",
    t.click_to_transaction_rate_users AS "商品点击-成交转化率(人数)",
    t.smart_coupon_amount AS "智能优惠券金额",
    t.platform_subsidy_amount AS "平台补贴金额",
    t.creator_subsidy_amount AS "达人补贴金额",
    t.presale_deposit_amount AS "预售定金",
    t.transaction_order_count AS "成交订单数",
    t.transaction_item_count AS "成交件数",
    t.avg_item_amount AS "件单价",
    t.transaction_buyer_count AS "成交人数",
    t.avg_customer_amount AS "客单价",
    t.net_transaction_amount AS "净成交金额",
    t.net_transaction_order_count AS "净成交订单量",
    t.settlement_amount_7d AS "7日结算金额",
    t.settlement_amount_14d AS "14日结算金额",
    t.settlement_amount_refund_time AS "结算金额(退款时间)",
    t.ad_attributed_settlement_amount AS "投放贡献结算金额",
    t.net_user_pay_amount_pay_time AS "退款后用户支付金额(支付时间)",
    t.net_smart_coupon_amount_pay_time AS "退款后智能优惠券金额(支付时间)",
    t.net_platform_subsidy_amount_pay_time AS "退款后平台补贴金额(支付时间)",
    t.net_creator_subsidy_amount_pay_time AS "退款后达人补贴金额(支付时间)",
    t.refund_order_count_pay_time AS "退款订单数(支付时间)",
    t.transaction_refund_amount_refund_time AS "成交退款金额(退款时间)",
    t.refund_amount_refund_time AS "退款金额(退款时间)",
    t.refund_order_count_refund_time AS "退款订单数(退款时间)",
    t.one_hour_transaction_refund_amount_pay_time AS "1小时成交退款金额(支付时间)",
    t.one_hour_refund_order_count_pay_time AS "1小时退款订单数(支付时间)",
    t.one_hour_refund_rate_pay_time AS "1小时退款率(支付时间)",
    t.ad_attributed_transaction_refund_amount_pay_time AS "投放贡献成交退款金额(支付时间)",
    t.ad_attributed_refund_rate_pay_time AS "投放部分退款率(支付时间)",
    t.product_exposure_count AS "商品曝光次数",
    t.product_click_count AS "商品点击次数",
    t.exposure_to_click_rate_events AS "商品曝光-点击转化率(次数)",
    t.click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    t.exposure_to_transaction_rate_events AS "商品曝光-成交转化率(次数)",
    t.product_exposure_user_count AS "商品曝光人数",
    t.product_click_user_count AS "商品点击人数",
    t.exposure_to_transaction_rate_users AS "商品曝光-成交转化率(人数)",
    t.user_pay_amount_per_1000_exposures AS "千次曝光用户支付金额",
    t.ad_spend_shop_bound AS "投放消耗(店铺绑定)",
    t.platform_commission_settlement AS "平台佣金(结算口径)",
    t.creator_commission_settlement AS "达人佣金(结算口径)",
    t.ad_spend_rate_shop_bound AS "投放费比(店铺绑定)",
    t.ad_spend_rate_shop_promoted AS "投放费比(店铺被投)",
    t.ad_spend_rate_net_refund_shop_bound AS "投放费比(剔除退款、店铺绑定)",
    t.total_expense_rate_shop_bound AS "综合费比(店铺绑定)",
    t.total_expense_rate_shop_promoted AS "综合费比(店铺被投)",
    t.total_expense_rate_net_refund_shop_bound AS "综合费比(剔除退款、店铺绑定)",
    t.total_expense_rate_net_refund_shop_promoted AS "综合费比(剔除退款、店铺被投)",
    t.batch_id AS "导入批次ID",
    t.source_sheet_name AS "源工作表名称",
    t.source_row_number AS "源文件行号",
    t.imported_at AS "写入时间"
   FROM (core.douyin_account_daily t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW "中文数据"."抖音账号日报" OWNER TO postgres;

--
-- Name: 抖音载体日报; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音载体日报" AS
 SELECT t.row_id AS "数据行ID",
    s.shop_name AS "店铺名称",
    t.biz_date AS "日期",
    t.sale_scope AS "自营/合作",
    t.carrier_type AS "载体类型",
    t.account_channel AS "账号/渠道",
    t.douyin_account_id AS "抖音号",
    t.transaction_amount AS "成交金额",
    t.user_pay_amount AS "用户支付金额",
    t.settlement_amount AS "结算金额",
    t.transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    t.refund_amount_pay_time AS "退款金额(支付时间)",
    t.refund_rate_pay_time AS "退款率(支付时间)",
    t.ad_attributed_transaction_amount AS "投放贡献成交金额",
    t.ad_attributed_transaction_share AS "投放贡献成交占比",
    t.ad_spend_shop_promoted AS "投放消耗(店铺被投)",
    t.ad_spend_rate_net_refund_shop_promoted AS "投放费比(剔除退款、店铺被投)",
    t.exposure_to_click_rate_users AS "商品曝光-点击转化率(人数)",
    t.click_to_transaction_rate_users AS "商品点击-成交转化率(人数)",
    t.smart_coupon_amount AS "智能优惠券金额",
    t.platform_subsidy_amount AS "平台补贴金额",
    t.creator_subsidy_amount AS "达人补贴金额",
    t.presale_deposit_amount AS "预售定金",
    t.transaction_order_count AS "成交订单数",
    t.transaction_item_count AS "成交件数",
    t.avg_item_amount AS "件单价",
    t.transaction_buyer_count AS "成交人数",
    t.avg_customer_amount AS "客单价",
    t.net_transaction_amount AS "净成交金额",
    t.net_transaction_order_count AS "净成交订单量",
    t.settlement_amount_7d AS "7日结算金额",
    t.settlement_amount_14d AS "14日结算金额",
    t.settlement_amount_refund_time AS "结算金额(退款时间)",
    t.ad_attributed_settlement_amount AS "投放贡献结算金额",
    t.net_user_pay_amount_pay_time AS "退款后用户支付金额(支付时间)",
    t.net_smart_coupon_amount_pay_time AS "退款后智能优惠券金额(支付时间)",
    t.net_platform_subsidy_amount_pay_time AS "退款后平台补贴金额(支付时间)",
    t.net_creator_subsidy_amount_pay_time AS "退款后达人补贴金额(支付时间)",
    t.refund_order_count_pay_time AS "退款订单数(支付时间)",
    t.transaction_refund_amount_refund_time AS "成交退款金额(退款时间)",
    t.refund_amount_refund_time AS "退款金额(退款时间)",
    t.refund_order_count_refund_time AS "退款订单数(退款时间)",
    t.one_hour_transaction_refund_amount_pay_time AS "1小时成交退款金额(支付时间)",
    t.one_hour_refund_order_count_pay_time AS "1小时退款订单数(支付时间)",
    t.one_hour_refund_rate_pay_time AS "1小时退款率(支付时间)",
    t.ad_attributed_transaction_refund_amount_pay_time AS "投放贡献成交退款金额(支付时间)",
    t.ad_attributed_refund_rate_pay_time AS "投放部分退款率(支付时间)",
    t.product_exposure_count AS "商品曝光次数",
    t.product_click_count AS "商品点击次数",
    t.exposure_to_click_rate_events AS "商品曝光-点击转化率(次数)",
    t.click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    t.exposure_to_transaction_rate_events AS "商品曝光-成交转化率(次数)",
    t.product_exposure_user_count AS "商品曝光人数",
    t.product_click_user_count AS "商品点击人数",
    t.exposure_to_transaction_rate_users AS "商品曝光-成交转化率(人数)",
    t.user_pay_amount_per_1000_exposures AS "千次曝光用户支付金额",
    t.ad_spend_shop_bound AS "投放消耗(店铺绑定)",
    t.platform_commission_settlement AS "平台佣金(结算口径)",
    t.creator_commission_settlement AS "达人佣金(结算口径)",
    t.ad_spend_rate_shop_bound AS "投放费比(店铺绑定)",
    t.ad_spend_rate_shop_promoted AS "投放费比(店铺被投)",
    t.ad_spend_rate_net_refund_shop_bound AS "投放费比(剔除退款、店铺绑定)",
    t.total_expense_rate_shop_bound AS "综合费比(店铺绑定)",
    t.total_expense_rate_shop_promoted AS "综合费比(店铺被投)",
    t.total_expense_rate_net_refund_shop_bound AS "综合费比(剔除退款、店铺绑定)",
    t.total_expense_rate_net_refund_shop_promoted AS "综合费比(剔除退款、店铺被投)",
    t.batch_id AS "导入批次ID",
    t.source_sheet_name AS "源工作表名称",
    t.source_row_number AS "源文件行号",
    t.imported_at AS "写入时间"
   FROM (core.douyin_carrier_daily t
     JOIN meta.shop s ON ((t.shop_id = s.shop_id)));


ALTER VIEW "中文数据"."抖音载体日报" OWNER TO postgres;

--
-- Name: 指标公式规则; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."指标公式规则" AS
 SELECT metric_rule_id AS "指标规则ID",
    target_schema AS "目标Schema",
    target_table AS "目标正式表",
    target_column_name_cn AS "目标字段中文名",
    target_column_name AS "目标英文字段名",
    metric_category AS "指标类别",
    calculation_mode AS "计算模式",
    formula_cn AS "业务公式",
    numerator_expression AS "分子表达式",
    denominator_expression AS "分母表达式",
    multiplier AS "计算倍率",
    single_row_formula AS "单行公式",
    period_formula_sql AS "跨期SQL",
    zero_denominator_rule AS "分母为0规则",
    cross_period_recalculable AS "跨期可重算",
    auto_use_allowed AS "允许自动采用",
    rule_status AS "规则状态",
    display_format AS "展示格式",
    mapping_version AS "映射版本",
    notes AS "备注",
    created_at AS "创建时间",
    verification_method,
    verification_period,
    verification_result
   FROM meta.metric_formula_rule;


ALTER VIEW "中文数据"."指标公式规则" OWNER TO postgres;

--
-- Name: 数据库中英文字典; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."数据库中英文字典" AS
 SELECT dictionary_id AS "字典ID",
    schema_name,
    object_name AS "英文对象名",
    object_type AS "对象类型",
    object_name_cn AS "中文对象名",
    column_name AS "英文字段名",
    column_name_cn AS "中文字段名",
    source_platform AS "来源平台",
    source_sheet_name AS "源工作表名称",
    source_field_name_cn AS "原始中文表头",
    source_header_variants,
    chinese_name_source AS "名称来源",
    name_resolution_status AS "解析状态",
    is_manual_override AS "人工覆盖标记",
    override_reason AS "覆盖原因",
    business_definition AS "业务含义",
    display_order AS "字段顺序",
    visible_in_cn_view AS "中文视图可见",
    mapping_version AS "映射版本",
    enabled AS "是否启用",
    created_at AS "创建时间",
    updated_at AS "更新时间"
   FROM meta.database_object_dictionary;


ALTER VIEW "中文数据"."数据库中英文字典" OWNER TO postgres;

--
-- Name: 终端构成分析; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."终端构成分析" AS
 SELECT shop_name AS "店铺名称",
    biz_date AS "日期",
    terminal_type AS "终端类型",
    selling_type AS "售卖类型",
    transaction_amount AS "成交金额",
    user_pay_amount AS "用户支付金额",
    settlement_amount AS "结算金额",
    transaction_order_count AS "成交订单数",
    transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    transaction_item_count AS "成交件数",
    transaction_refund_amount_refund_time AS "成交退款金额(退款时间)"
   FROM mart.terminal_daily;


ALTER VIEW "中文数据"."终端构成分析" OWNER TO postgres;

--
-- Name: 账号构成分析; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."账号构成分析" AS
 SELECT shop_name AS "店铺名称",
    biz_date AS "日期",
    sale_scope AS "成交范围",
    account_name AS "账号名称",
    account_type AS "账号类型",
    transaction_amount AS "成交金额",
    user_pay_amount AS "用户支付金额",
    settlement_amount AS "结算金额",
    transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    transaction_order_count AS "成交订单数",
    transaction_item_count AS "成交件数",
    transaction_buyer_count AS "成交人数",
    net_transaction_amount AS "净成交金额"
   FROM mart.account_daily;


ALTER VIEW "中文数据"."账号构成分析" OWNER TO postgres;

--
-- Name: 载体构成分析; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."载体构成分析" AS
 SELECT shop_name AS "店铺名称",
    biz_date AS "日期",
    sale_scope AS "成交范围",
    carrier_type AS "载体类型",
    account_channel AS "账号/渠道",
    douyin_account_id AS "抖音号",
    transaction_amount AS "成交金额",
    user_pay_amount AS "用户支付金额",
    settlement_amount AS "结算金额",
    transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    ad_attributed_transaction_amount AS "投放贡献成交金额",
    ad_attributed_transaction_share AS "投放贡献成交占比",
    transaction_order_count AS "成交订单数",
    transaction_item_count AS "成交件数",
    transaction_buyer_count AS "成交人数",
    net_transaction_amount AS "净成交金额"
   FROM mart.carrier_daily;


ALTER VIEW "中文数据"."载体构成分析" OWNER TO postgres;

--
-- Name: import_batch batch_id; Type: DEFAULT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.import_batch ALTER COLUMN batch_id SET DEFAULT nextval('audit.import_batch_batch_id_seq'::regclass);


--
-- Name: douyin_account_daily row_id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_account_daily ALTER COLUMN row_id SET DEFAULT nextval('core.douyin_account_daily_row_id_seq'::regclass);


--
-- Name: douyin_audience_daily row_id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_audience_daily ALTER COLUMN row_id SET DEFAULT nextval('core.douyin_audience_daily_row_id_seq'::regclass);


--
-- Name: douyin_carrier_daily row_id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_carrier_daily ALTER COLUMN row_id SET DEFAULT nextval('core.douyin_carrier_daily_row_id_seq'::regclass);


--
-- Name: douyin_category_daily row_id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_category_daily ALTER COLUMN row_id SET DEFAULT nextval('core.douyin_category_daily_row_id_seq'::regclass);


--
-- Name: douyin_content_daily row_id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_content_daily ALTER COLUMN row_id SET DEFAULT nextval('core.douyin_content_daily_row_id_seq'::regclass);


--
-- Name: douyin_deal_daily row_id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_deal_daily ALTER COLUMN row_id SET DEFAULT nextval('core.douyin_deal_daily_row_id_seq'::regclass);


--
-- Name: douyin_price_band_daily row_id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_price_band_daily ALTER COLUMN row_id SET DEFAULT nextval('core.douyin_price_band_daily_row_id_seq'::regclass);


--
-- Name: douyin_product_daily row_id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_product_daily ALTER COLUMN row_id SET DEFAULT nextval('core.douyin_product_daily_row_id_seq'::regclass);


--
-- Name: douyin_terminal_daily row_id; Type: DEFAULT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_terminal_daily ALTER COLUMN row_id SET DEFAULT nextval('core.douyin_terminal_daily_row_id_seq'::regclass);


--
-- Name: mart_dimension_rule rule_id; Type: DEFAULT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.mart_dimension_rule ALTER COLUMN rule_id SET DEFAULT nextval('mart.mart_dimension_rule_rule_id_seq'::regclass);


--
-- Name: database_object_dictionary dictionary_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.database_object_dictionary ALTER COLUMN dictionary_id SET DEFAULT nextval('meta.database_object_dictionary_dictionary_id_seq'::regclass);


--
-- Name: field_mapping mapping_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping ALTER COLUMN mapping_id SET DEFAULT nextval('meta.field_mapping_mapping_id_seq'::regclass);


--
-- Name: metric_formula_rule metric_rule_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.metric_formula_rule ALTER COLUMN metric_rule_id SET DEFAULT nextval('meta.metric_formula_rule_metric_rule_id_seq'::regclass);


--
-- Name: shop shop_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.shop ALTER COLUMN shop_id SET DEFAULT nextval('meta.shop_shop_id_seq'::regclass);


--
-- Name: import_batch import_batch_pkey; Type: CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.import_batch
    ADD CONSTRAINT import_batch_pkey PRIMARY KEY (batch_id);


--
-- Name: douyin_account_daily douyin_account_daily_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_account_daily
    ADD CONSTRAINT douyin_account_daily_pkey PRIMARY KEY (row_id);


--
-- Name: douyin_audience_daily douyin_audience_daily_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_audience_daily
    ADD CONSTRAINT douyin_audience_daily_pkey PRIMARY KEY (row_id);


--
-- Name: douyin_carrier_daily douyin_carrier_daily_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_carrier_daily
    ADD CONSTRAINT douyin_carrier_daily_pkey PRIMARY KEY (row_id);


--
-- Name: douyin_category_daily douyin_category_daily_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_category_daily
    ADD CONSTRAINT douyin_category_daily_pkey PRIMARY KEY (row_id);


--
-- Name: douyin_content_daily douyin_content_daily_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_content_daily
    ADD CONSTRAINT douyin_content_daily_pkey PRIMARY KEY (row_id);


--
-- Name: douyin_deal_daily douyin_deal_daily_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_deal_daily
    ADD CONSTRAINT douyin_deal_daily_pkey PRIMARY KEY (row_id);


--
-- Name: douyin_price_band_daily douyin_price_band_daily_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_price_band_daily
    ADD CONSTRAINT douyin_price_band_daily_pkey PRIMARY KEY (row_id);


--
-- Name: douyin_product_daily douyin_product_daily_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_product_daily
    ADD CONSTRAINT douyin_product_daily_pkey PRIMARY KEY (row_id);


--
-- Name: douyin_terminal_daily douyin_terminal_daily_pkey; Type: CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_terminal_daily
    ADD CONSTRAINT douyin_terminal_daily_pkey PRIMARY KEY (row_id);


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
-- Name: database_object_dictionary database_object_dictionary_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.database_object_dictionary
    ADD CONSTRAINT database_object_dictionary_pkey PRIMARY KEY (dictionary_id);


--
-- Name: field_mapping field_mapping_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping
    ADD CONSTRAINT field_mapping_pkey PRIMARY KEY (mapping_id);


--
-- Name: metric_formula_rule metric_formula_rule_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.metric_formula_rule
    ADD CONSTRAINT metric_formula_rule_pkey PRIMARY KEY (metric_rule_id);


--
-- Name: shop shop_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.shop
    ADD CONSTRAINT shop_pkey PRIMARY KEY (shop_id);


--
-- Name: source_sheet_mapping source_sheet_mapping_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.source_sheet_mapping
    ADD CONSTRAINT source_sheet_mapping_pkey PRIMARY KEY (source_sheet_name);


--
-- Name: source_sheet_mapping source_sheet_mapping_source_sheet_code_key; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.source_sheet_mapping
    ADD CONSTRAINT source_sheet_mapping_source_sheet_code_key UNIQUE (source_sheet_code);


--
-- Name: database_object_dictionary uk_dict_obj_col; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.database_object_dictionary
    ADD CONSTRAINT uk_dict_obj_col UNIQUE (schema_name, object_name, column_name);


--
-- Name: field_mapping uk_field_mapping_sheet_column; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping
    ADD CONSTRAINT uk_field_mapping_sheet_column UNIQUE (source_sheet_name, source_column_name);


--
-- Name: field_mapping uk_field_mapping_sheet_order; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping
    ADD CONSTRAINT uk_field_mapping_sheet_order UNIQUE (source_sheet_name, source_column_order);


--
-- Name: metric_formula_rule uk_metric_formula_rule; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.metric_formula_rule
    ADD CONSTRAINT uk_metric_formula_rule UNIQUE (target_schema, target_table, target_column_name);


--
-- Name: shop uk_shop_code; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.shop
    ADD CONSTRAINT uk_shop_code UNIQUE (platform_code, shop_code);


--
-- Name: idx_import_batch_file_sha256; Type: INDEX; Schema: audit; Owner: postgres
--

CREATE INDEX idx_import_batch_file_sha256 ON audit.import_batch USING btree (file_sha256);


--
-- Name: idx_import_batch_shop_date; Type: INDEX; Schema: audit; Owner: postgres
--

CREATE INDEX idx_import_batch_shop_date ON audit.import_batch USING btree (shop_id, period_start, period_end);


--
-- Name: idx_import_batch_status; Type: INDEX; Schema: audit; Owner: postgres
--

CREATE INDEX idx_import_batch_status ON audit.import_batch USING btree (import_status);


--
-- Name: idx_douyin_account_daily_batch; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_account_daily_batch ON core.douyin_account_daily USING btree (batch_id);


--
-- Name: idx_douyin_account_daily_shop_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_account_daily_shop_date ON core.douyin_account_daily USING btree (shop_id, biz_date);


--
-- Name: idx_douyin_audience_daily_batch; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_audience_daily_batch ON core.douyin_audience_daily USING btree (batch_id);


--
-- Name: idx_douyin_audience_daily_shop_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_audience_daily_shop_date ON core.douyin_audience_daily USING btree (shop_id, biz_date);


--
-- Name: idx_douyin_carrier_daily_batch; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_carrier_daily_batch ON core.douyin_carrier_daily USING btree (batch_id);


--
-- Name: idx_douyin_carrier_daily_shop_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_carrier_daily_shop_date ON core.douyin_carrier_daily USING btree (shop_id, biz_date);


--
-- Name: idx_douyin_category_daily_batch; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_category_daily_batch ON core.douyin_category_daily USING btree (batch_id);


--
-- Name: idx_douyin_category_daily_shop_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_category_daily_shop_date ON core.douyin_category_daily USING btree (shop_id, biz_date);


--
-- Name: idx_douyin_content_daily_batch; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_content_daily_batch ON core.douyin_content_daily USING btree (batch_id);


--
-- Name: idx_douyin_content_daily_shop_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_content_daily_shop_date ON core.douyin_content_daily USING btree (shop_id, biz_date);


--
-- Name: idx_douyin_deal_daily_batch; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_deal_daily_batch ON core.douyin_deal_daily USING btree (batch_id);


--
-- Name: idx_douyin_deal_daily_shop_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_deal_daily_shop_date ON core.douyin_deal_daily USING btree (shop_id, biz_date);


--
-- Name: idx_douyin_price_band_daily_batch; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_price_band_daily_batch ON core.douyin_price_band_daily USING btree (batch_id);


--
-- Name: idx_douyin_price_band_daily_shop_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_price_band_daily_shop_date ON core.douyin_price_band_daily USING btree (shop_id, biz_date);


--
-- Name: idx_douyin_product_daily_batch; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_product_daily_batch ON core.douyin_product_daily USING btree (batch_id);


--
-- Name: idx_douyin_product_daily_shop_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_product_daily_shop_date ON core.douyin_product_daily USING btree (shop_id, biz_date);


--
-- Name: idx_douyin_terminal_daily_batch; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_terminal_daily_batch ON core.douyin_terminal_daily USING btree (batch_id);


--
-- Name: idx_douyin_terminal_daily_shop_date; Type: INDEX; Schema: core; Owner: postgres
--

CREATE INDEX idx_douyin_terminal_daily_shop_date ON core.douyin_terminal_daily USING btree (shop_id, biz_date);


--
-- Name: uk_douyin_account_daily_business; Type: INDEX; Schema: core; Owner: postgres
--

CREATE UNIQUE INDEX uk_douyin_account_daily_business ON core.douyin_account_daily USING btree (shop_id, biz_date, account_name, account_type, sale_scope, douyin_account_id);


--
-- Name: uk_douyin_audience_daily_business; Type: INDEX; Schema: core; Owner: postgres
--

CREATE UNIQUE INDEX uk_douyin_audience_daily_business ON core.douyin_audience_daily USING btree (shop_id, biz_date, audience_type, carrier_type);


--
-- Name: uk_douyin_carrier_daily_business; Type: INDEX; Schema: core; Owner: postgres
--

CREATE UNIQUE INDEX uk_douyin_carrier_daily_business ON core.douyin_carrier_daily USING btree (shop_id, biz_date, sale_scope, carrier_type, account_channel, douyin_account_id);


--
-- Name: uk_douyin_category_daily_business; Type: INDEX; Schema: core; Owner: postgres
--

CREATE UNIQUE INDEX uk_douyin_category_daily_business ON core.douyin_category_daily USING btree (shop_id, biz_date, category_level_1, category_level_2, category_level_3, category_level_4);


--
-- Name: uk_douyin_content_daily_business; Type: INDEX; Schema: core; Owner: postgres
--

CREATE UNIQUE INDEX uk_douyin_content_daily_business ON core.douyin_content_daily USING btree (shop_id, biz_date, selling_type, carrier_type, content_id);


--
-- Name: uk_douyin_deal_daily_business; Type: INDEX; Schema: core; Owner: postgres
--

CREATE UNIQUE INDEX uk_douyin_deal_daily_business ON core.douyin_deal_daily USING btree (shop_id, biz_date, sale_scope, carrier_type, ad_period);


--
-- Name: uk_douyin_price_band_daily_business; Type: INDEX; Schema: core; Owner: postgres
--

CREATE UNIQUE INDEX uk_douyin_price_band_daily_business ON core.douyin_price_band_daily USING btree (shop_id, biz_date, price_band);


--
-- Name: uk_douyin_product_daily_business; Type: INDEX; Schema: core; Owner: postgres
--

CREATE UNIQUE INDEX uk_douyin_product_daily_business ON core.douyin_product_daily USING btree (shop_id, biz_date, product_id, carrier_type);


--
-- Name: uk_douyin_terminal_daily_business; Type: INDEX; Schema: core; Owner: postgres
--

CREATE UNIQUE INDEX uk_douyin_terminal_daily_business ON core.douyin_terminal_daily USING btree (shop_id, biz_date, terminal_type, selling_type);


--
-- Name: import_batch fk_import_batch_shop; Type: FK CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.import_batch
    ADD CONSTRAINT fk_import_batch_shop FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: douyin_account_daily fk_douyin_account_daily_batch; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_account_daily
    ADD CONSTRAINT fk_douyin_account_daily_batch FOREIGN KEY (batch_id) REFERENCES audit.import_batch(batch_id);


--
-- Name: douyin_account_daily fk_douyin_account_daily_shop; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_account_daily
    ADD CONSTRAINT fk_douyin_account_daily_shop FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: douyin_audience_daily fk_douyin_audience_daily_batch; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_audience_daily
    ADD CONSTRAINT fk_douyin_audience_daily_batch FOREIGN KEY (batch_id) REFERENCES audit.import_batch(batch_id);


--
-- Name: douyin_audience_daily fk_douyin_audience_daily_shop; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_audience_daily
    ADD CONSTRAINT fk_douyin_audience_daily_shop FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: douyin_carrier_daily fk_douyin_carrier_daily_batch; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_carrier_daily
    ADD CONSTRAINT fk_douyin_carrier_daily_batch FOREIGN KEY (batch_id) REFERENCES audit.import_batch(batch_id);


--
-- Name: douyin_carrier_daily fk_douyin_carrier_daily_shop; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_carrier_daily
    ADD CONSTRAINT fk_douyin_carrier_daily_shop FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: douyin_category_daily fk_douyin_category_daily_batch; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_category_daily
    ADD CONSTRAINT fk_douyin_category_daily_batch FOREIGN KEY (batch_id) REFERENCES audit.import_batch(batch_id);


--
-- Name: douyin_category_daily fk_douyin_category_daily_shop; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_category_daily
    ADD CONSTRAINT fk_douyin_category_daily_shop FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: douyin_content_daily fk_douyin_content_daily_batch; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_content_daily
    ADD CONSTRAINT fk_douyin_content_daily_batch FOREIGN KEY (batch_id) REFERENCES audit.import_batch(batch_id);


--
-- Name: douyin_content_daily fk_douyin_content_daily_shop; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_content_daily
    ADD CONSTRAINT fk_douyin_content_daily_shop FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: douyin_deal_daily fk_douyin_deal_daily_batch; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_deal_daily
    ADD CONSTRAINT fk_douyin_deal_daily_batch FOREIGN KEY (batch_id) REFERENCES audit.import_batch(batch_id);


--
-- Name: douyin_deal_daily fk_douyin_deal_daily_shop; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_deal_daily
    ADD CONSTRAINT fk_douyin_deal_daily_shop FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: douyin_price_band_daily fk_douyin_price_band_daily_batch; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_price_band_daily
    ADD CONSTRAINT fk_douyin_price_band_daily_batch FOREIGN KEY (batch_id) REFERENCES audit.import_batch(batch_id);


--
-- Name: douyin_price_band_daily fk_douyin_price_band_daily_shop; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_price_band_daily
    ADD CONSTRAINT fk_douyin_price_band_daily_shop FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: douyin_product_daily fk_douyin_product_daily_batch; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_product_daily
    ADD CONSTRAINT fk_douyin_product_daily_batch FOREIGN KEY (batch_id) REFERENCES audit.import_batch(batch_id);


--
-- Name: douyin_product_daily fk_douyin_product_daily_shop; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_product_daily
    ADD CONSTRAINT fk_douyin_product_daily_shop FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: douyin_terminal_daily fk_douyin_terminal_daily_batch; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_terminal_daily
    ADD CONSTRAINT fk_douyin_terminal_daily_batch FOREIGN KEY (batch_id) REFERENCES audit.import_batch(batch_id);


--
-- Name: douyin_terminal_daily fk_douyin_terminal_daily_shop; Type: FK CONSTRAINT; Schema: core; Owner: postgres
--

ALTER TABLE ONLY core.douyin_terminal_daily
    ADD CONSTRAINT fk_douyin_terminal_daily_shop FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: field_mapping fk_field_mapping_sheet; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping
    ADD CONSTRAINT fk_field_mapping_sheet FOREIGN KEY (source_sheet_name) REFERENCES meta.source_sheet_mapping(source_sheet_name);


--
-- Name: SCHEMA audit; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA audit TO ecommerce_importer;
GRANT USAGE ON SCHEMA audit TO agent_readonly;


--
-- Name: SCHEMA core; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA core TO ecommerce_importer;


--
-- Name: SCHEMA mart; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA mart TO agent_readonly;


--
-- Name: SCHEMA meta; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA meta TO ecommerce_importer;
GRANT USAGE ON SCHEMA meta TO agent_readonly;


--
-- Name: SCHEMA stg; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA stg TO ecommerce_importer;


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
-- Name: TABLE import_batch; Type: ACL; Schema: audit; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE audit.import_batch TO ecommerce_importer;
GRANT SELECT ON TABLE audit.import_batch TO agent_readonly;


--
-- Name: SEQUENCE import_batch_batch_id_seq; Type: ACL; Schema: audit; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE audit.import_batch_batch_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_account_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_account_daily TO ecommerce_importer;


--
-- Name: SEQUENCE douyin_account_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_account_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_audience_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_audience_daily TO ecommerce_importer;


--
-- Name: SEQUENCE douyin_audience_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_audience_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_carrier_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_carrier_daily TO ecommerce_importer;


--
-- Name: SEQUENCE douyin_carrier_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_carrier_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_category_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_category_daily TO ecommerce_importer;


--
-- Name: SEQUENCE douyin_category_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_category_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_content_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_content_daily TO ecommerce_importer;


--
-- Name: SEQUENCE douyin_content_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_content_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_deal_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_deal_daily TO ecommerce_importer;


--
-- Name: SEQUENCE douyin_deal_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_deal_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_price_band_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_price_band_daily TO ecommerce_importer;


--
-- Name: SEQUENCE douyin_price_band_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_price_band_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_product_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_product_daily TO ecommerce_importer;


--
-- Name: SEQUENCE douyin_product_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_product_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_terminal_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_terminal_daily TO ecommerce_importer;


--
-- Name: SEQUENCE douyin_terminal_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_terminal_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE shop; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.shop TO ecommerce_importer;
GRANT SELECT ON TABLE meta.shop TO agent_readonly;


--
-- Name: TABLE analysis_metric_whitelist; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.analysis_metric_whitelist TO agent_readonly;


--
-- Name: TABLE mart_dimension_rule; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.mart_dimension_rule TO agent_readonly;


--
-- Name: TABLE metric_formula_rule; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.metric_formula_rule TO ecommerce_importer;


--
-- Name: TABLE metric_rule_v14; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.metric_rule_v14 TO agent_readonly;


--
-- Name: TABLE stage3_expected_scope_map; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.stage3_expected_scope_map TO agent_readonly;


--
-- Name: TABLE database_object_dictionary; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.database_object_dictionary TO ecommerce_importer;


--
-- Name: TABLE field_mapping; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.field_mapping TO ecommerce_importer;


--
-- Name: TABLE source_sheet_mapping; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.source_sheet_mapping TO ecommerce_importer;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: audit; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA audit GRANT SELECT,INSERT,UPDATE ON TABLES TO ecommerce_importer;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: core; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA core GRANT SELECT,USAGE ON SEQUENCES TO ecommerce_importer;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: core; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA core GRANT SELECT,INSERT,DELETE,UPDATE ON TABLES TO ecommerce_importer;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: meta; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA meta GRANT SELECT ON TABLES TO ecommerce_importer;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: stg; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA stg GRANT ALL ON SEQUENCES TO ecommerce_importer;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: stg; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA stg GRANT ALL ON TABLES TO ecommerce_importer;


--
-- PostgreSQL database dump complete
--

