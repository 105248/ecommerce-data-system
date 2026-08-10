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
-- Name: _diag_account(text, date, date, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart._diag_account(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) RETURNS TABLE(shop_name text, domain_key text, domain_name_cn text, entity_id text, entity_name text, scope_key text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint, current_contribution numeric, previous_contribution numeric, contribution_change numeric, contribution_denominator_type text, contribution_denominator_value numeric, current_coverage_days integer, expected_current_days integer, previous_coverage_days integer, expected_previous_days integer, current_coverage_complete boolean, previous_coverage_complete boolean, calculation_status text, data_status text, notes text)
    LANGUAGE plpgsql STABLE
    AS $$
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
$$;


ALTER FUNCTION mart._diag_account(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) OWNER TO postgres;

--
-- Name: FUNCTION _diag_account(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart._diag_account(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) IS 'V1.1 账号域诊断快照（内部函数，不对外授权）。';


--
-- Name: _diag_carrier(text, date, date, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart._diag_carrier(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) RETURNS TABLE(shop_name text, domain_key text, domain_name_cn text, entity_id text, entity_name text, scope_key text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint, current_contribution numeric, previous_contribution numeric, contribution_change numeric, contribution_denominator_type text, contribution_denominator_value numeric, current_coverage_days integer, expected_current_days integer, previous_coverage_days integer, expected_previous_days integer, current_coverage_complete boolean, previous_coverage_complete boolean, calculation_status text, data_status text, notes text)
    LANGUAGE plpgsql STABLE
    AS $$
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
$$;


ALTER FUNCTION mart._diag_carrier(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) OWNER TO postgres;

--
-- Name: FUNCTION _diag_carrier(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart._diag_carrier(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) IS 'V1.1 载体域诊断快照（内部函数，不对外授权）。';


--
-- Name: _diag_category(text, date, date, date, date, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart._diag_category(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_category_level integer) RETURNS TABLE(shop_name text, domain_key text, domain_name_cn text, entity_id text, entity_name text, scope_key text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint, current_contribution numeric, previous_contribution numeric, contribution_change numeric, contribution_denominator_type text, contribution_denominator_value numeric, current_coverage_days integer, expected_current_days integer, previous_coverage_days integer, expected_previous_days integer, current_coverage_complete boolean, previous_coverage_complete boolean, calculation_status text, data_status text, notes text)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_en text;
    v_level int;
BEGIN
    SELECT COALESCE(s.shop_name, '平台汇总') INTO v_en FROM meta.shop s WHERE s.shop_name = p_shop_name;
    IF v_en IS NULL THEN v_en := '平台汇总'; END IF;
    v_level := COALESCE(p_category_level, 3);

    RETURN QUERY
    WITH raw AS (
        SELECT
            c.category_level_3 AS eid,
            c.category_level_3 AS ename,
            count(DISTINCT CASE WHEN c.biz_date BETWEEN p_cs AND p_ce THEN c.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN c.biz_date BETWEEN p_ps AND p_pe THEN c.biz_date END)::int AS p_days,
            sum(CASE WHEN c.biz_date BETWEEN p_cs AND p_ce THEN c.user_pay_amount END) AS c_up,
            sum(CASE WHEN c.biz_date BETWEEN p_ps AND p_pe THEN c.user_pay_amount END) AS p_up,
            sum(CASE WHEN c.biz_date BETWEEN p_cs AND p_ce THEN c.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN c.biz_date BETWEEN p_ps AND p_pe THEN c.refund_amount_pay_time END) AS p_refund
        FROM core.douyin_category_daily c
        JOIN meta.shop s ON s.shop_id = c.shop_id
        WHERE c.biz_date BETWEEN p_ps AND p_ce
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
          AND c.category_level_3 IS NOT NULL AND c.category_level_3 <> '' AND c.category_level_3 <> '全部'
          AND (v_level = 3 OR c.category_level_1 IS NOT NULL AND c.category_level_1 <> '')
        GROUP BY c.category_level_3
    ),
    metrics AS (
        SELECT r.*, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
            END AS p_val
        FROM raw r
        CROSS JOIN LATERAL (VALUES
            ('user_pay_amount','用户支付金额','成交','amount','金额'),
            ('refund_amount_pay_time','退款金额(支付时间)','售后','amount','金额'),
            ('refund_rate_pay_time','退款率(支付时间)','售后','ratio','0.00%')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        v_en AS shop_name,
        'category' AS domain_key,
        '类目' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        NULL::text AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs AS current_start_date, p_ce AS current_end_date,
        p_ps AS previous_start_date, p_pe AS previous_end_date,
        m.c_val AS current_value, m.p_val AS previous_value,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.eid,
                        DENSE_RANK() OVER (ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid)
             ELSE NULL END AS current_rank,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.eid,
                        DENSE_RANK() OVER (ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid)
             ELSE NULL END AS previous_rank,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
             THEN (SELECT t.rnk FROM (SELECT m2.eid,
                        DENSE_RANK() OVER (ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid)
                  - (SELECT t.rnk FROM (SELECT m2.eid,
                        DENSE_RANK() OVER (ORDER BY
                            CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                            CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                            m2.eid) AS rnk
                    FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid)
             ELSE NULL END AS rank_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS current_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS previous_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time') AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0)
                - m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS contribution_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time') THEN 'domain' ELSE NULL END AS contribution_denominator_type,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN (SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key) ELSE NULL END AS contribution_denominator_value,
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
        '类目快照（L' || v_level || ' 粒度）' AS notes
    FROM metrics m
    ORDER BY m.eid, m.metric_key;
END;
$$;


ALTER FUNCTION mart._diag_category(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_category_level integer) OWNER TO postgres;

--
-- Name: FUNCTION _diag_category(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_category_level integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart._diag_category(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_category_level integer) IS 'V1.1 类目域诊断快照（内部函数，不对外授权）。';


--
-- Name: _diag_master_product(text, date, date, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart._diag_master_product(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_id text, p_entity_name text) RETURNS TABLE(shop_name text, domain_key text, domain_name_cn text, entity_id text, entity_name text, scope_key text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint, current_contribution numeric, previous_contribution numeric, contribution_change numeric, contribution_denominator_type text, contribution_denominator_value numeric, current_coverage_days integer, expected_current_days integer, previous_coverage_days integer, expected_previous_days integer, current_coverage_complete boolean, previous_coverage_complete boolean, calculation_status text, data_status text, notes text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    WITH mp_list AS (
        SELECT mp.master_product_id::text AS eid, mp.master_product_name AS ename
        FROM meta.master_product mp
        WHERE mp.enabled
          AND EXISTS (SELECT 1 FROM meta.platform_product_mapping m
                      WHERE m.master_product_id = mp.master_product_id AND m.enabled AND m.mapping_status='CONFIRMED')
          AND (p_entity_id IS NULL OR mp.master_product_id = p_entity_id::bigint)
          AND (p_entity_name IS NULL OR mp.master_product_name = p_entity_name)
    ),
    members AS (
        SELECT m.master_product_id, m.shop_id, m.platform_product_id
        FROM meta.platform_product_mapping m
        WHERE m.enabled AND m.mapping_status = 'CONFIRMED'
    ),
    raw AS (
        SELECT
            ml.eid, ml.ename,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.biz_date END)::int AS p_days,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.user_pay_amount END) AS c_up,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.user_pay_amount END) AS p_up,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.refund_amount_pay_time END) AS p_refund,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN mem.shop_id END)::int AS c_mapped_shops
        FROM mp_list ml
        JOIN members mem ON mem.master_product_id = ml.eid::bigint
        LEFT JOIN core.douyin_product_daily d
          ON d.shop_id = mem.shop_id AND d.product_id = mem.platform_product_id
         AND d.biz_date BETWEEN p_ps AND p_ce AND d.carrier_type = '全部'
        GROUP BY ml.eid, ml.ename
    ),
    metrics AS (
        SELECT r.*, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
            END AS p_val
        FROM raw r
        CROSS JOIN LATERAL (VALUES
            ('user_pay_amount','用户支付金额','成交','amount','金额'),
            ('refund_amount_pay_time','退款金额(支付时间)','售后','amount','金额'),
            ('refund_rate_pay_time','退款率(支付时间)','售后','ratio','0.00%')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        COALESCE((SELECT s.shop_name::text FROM meta.shop s WHERE s.shop_name = p_shop_name), '平台汇总') AS shop_name,
        'master_product' AS domain_key,
        '公司商品' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        NULL::text AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs, p_ce, p_ps, p_pe,
        m.c_val, m.p_val,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        (SELECT t.rnk FROM (SELECT m2.eid,
             DENSE_RANK() OVER (ORDER BY CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                                           CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                                           m2.eid) AS rnk
             FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid) AS current_rank,
        (SELECT t.rnk FROM (SELECT m2.eid,
             DENSE_RANK() OVER (ORDER BY CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                                           CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                                           m2.eid) AS rnk
             FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid) AS previous_rank,
        NULL::bigint AS rank_change,
        m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0) AS current_contribution,
        m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0) AS previous_contribution,
        NULL::numeric AS contribution_change,
        'domain' AS contribution_denominator_type,
        (SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key) AS contribution_denominator_value,
        m.c_days, (p_ce - p_cs + 1)::int,
        m.p_days, (p_pe - p_ps + 1)::int,
        (m.c_days >= (p_ce - p_cs + 1)::int) AS current_coverage_complete,
        (m.p_days >= (p_pe - p_ps + 1)::int) AS previous_coverage_complete,
        CASE WHEN m.p_val IS NOT NULL AND m.p_val = 0 THEN 'PREVIOUS_ZERO' ELSE 'CALCULATED' END AS calculation_status,
        CASE WHEN m.c_days = 0 THEN 'NO_CURRENT_DATA'
             WHEN m.p_days = 0 THEN 'NO_PREVIOUS_DATA'
             WHEN m.c_days < (p_ce - p_cs + 1)::int AND m.p_days < (p_pe - p_ps + 1)::int THEN 'BOTH_INCOMPLETE'
             WHEN m.c_days < (p_ce - p_cs + 1)::int THEN 'CURRENT_INCOMPLETE'
             WHEN m.p_days < (p_pe - p_ps + 1)::int THEN 'PREVIOUS_INCOMPLETE'
             ELSE 'OK' END AS data_status,
        'Master Product（仅CONFIRMED成员）；mapping_coverage附: mapped_shops=' || m.c_mapped_shops || '/2' AS notes
    FROM metrics m
    ORDER BY m.eid, m.metric_key;
END;
$$;


ALTER FUNCTION mart._diag_master_product(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_id text, p_entity_name text) OWNER TO postgres;

--
-- Name: _diag_product(text, date, date, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart._diag_product(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_id text, p_entity_name text) RETURNS TABLE(shop_name text, domain_key text, domain_name_cn text, entity_id text, entity_name text, scope_key text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint, current_contribution numeric, previous_contribution numeric, contribution_change numeric, contribution_denominator_type text, contribution_denominator_value numeric, current_coverage_days integer, expected_current_days integer, previous_coverage_days integer, expected_previous_days integer, current_coverage_complete boolean, previous_coverage_complete boolean, calculation_status text, data_status text, notes text)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_en text;
BEGIN
    SELECT COALESCE(s.shop_name, '平台汇总') INTO v_en FROM meta.shop s WHERE s.shop_name = p_shop_name;
    IF v_en IS NULL THEN v_en := '平台汇总'; END IF;

    RETURN QUERY
    WITH top100 AS (
        SELECT p.product_id
        FROM core.douyin_product_daily p
        JOIN meta.shop s ON s.shop_id = p.shop_id
        WHERE p.biz_date BETWEEN p_cs AND p_ce
          AND p.carrier_type = '全部'
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
        GROUP BY p.product_id
        ORDER BY sum(p.user_pay_amount) DESC NULLS LAST, p.product_id
        LIMIT 100
    ),
    all_raw AS (
        -- 全量对象聚合（排名/贡献分母用；不受 entity 过滤与 TOP100 限制）
        SELECT
            p.product_id AS eid,
            p.product_name AS ename,
            sum(CASE WHEN p.biz_date BETWEEN p_cs AND p_ce THEN p.user_pay_amount END) AS c_up,
            sum(CASE WHEN p.biz_date BETWEEN p_ps AND p_pe THEN p.user_pay_amount END) AS p_up,
            sum(CASE WHEN p.biz_date BETWEEN p_cs AND p_ce THEN p.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN p.biz_date BETWEEN p_ps AND p_pe THEN p.refund_amount_pay_time END) AS p_refund
        FROM core.douyin_product_daily p
        JOIN meta.shop s ON s.shop_id = p.shop_id
        WHERE p.biz_date BETWEEN p_ps AND p_ce
          AND p.carrier_type = '全部'
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
        GROUP BY p.product_id, p.product_name
    ),
    raw AS (
        SELECT
            p.product_id AS eid,
            p.product_name AS ename,
            count(DISTINCT CASE WHEN p.biz_date BETWEEN p_cs AND p_ce THEN p.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN p.biz_date BETWEEN p_ps AND p_pe THEN p.biz_date END)::int AS p_days,
            sum(CASE WHEN p.biz_date BETWEEN p_cs AND p_ce THEN p.user_pay_amount END) AS c_up,
            sum(CASE WHEN p.biz_date BETWEEN p_ps AND p_pe THEN p.user_pay_amount END) AS p_up,
            sum(CASE WHEN p.biz_date BETWEEN p_cs AND p_ce THEN p.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN p.biz_date BETWEEN p_ps AND p_pe THEN p.refund_amount_pay_time END) AS p_refund
        FROM core.douyin_product_daily p
        JOIN meta.shop s ON s.shop_id = p.shop_id
        WHERE p.biz_date BETWEEN p_ps AND p_ce
          AND p.carrier_type = '全部'
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
          AND (p_entity_id IS NULL OR p.product_id = p_entity_id)
          AND (p_entity_name IS NULL OR p.product_name = p_entity_name)
          AND (p_entity_id IS NOT NULL OR p_entity_name IS NOT NULL OR p.product_id IN (SELECT product_id FROM top100))
        GROUP BY p.product_id, p.product_name
    ),
    metrics AS (
        SELECT r.*, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
            END AS p_val
        FROM raw r
        CROSS JOIN LATERAL (VALUES
            ('user_pay_amount','用户支付金额','成交','amount','金额'),
            ('refund_amount_pay_time','退款金额(支付时间)','售后','amount','金额'),
            ('refund_rate_pay_time','退款率(支付时间)','售后','ratio','0.00%')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    ),
    all_metrics AS (
        -- 全量对象指标（排名/贡献分母用，不受 entity 过滤影响）
        SELECT r.eid, r.ename, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
            END AS p_val
        FROM all_raw r
        CROSS JOIN LATERAL (VALUES
            ('user_pay_amount','用户支付金额','成交','amount','金额'),
            ('refund_amount_pay_time','退款金额(支付时间)','售后','amount','金额'),
            ('refund_rate_pay_time','退款率(支付时间)','售后','ratio','0.00%')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    ),
    full_rank AS (
        -- 全量对象排名（全体排名 → 再筛选；方向：退款率 ASC 其余 DESC）
        SELECT am.eid,
            am.metric_key,
            DENSE_RANK() OVER (PARTITION BY am.metric_key ORDER BY
                CASE WHEN am.metric_key='refund_rate_pay_time' THEN am.c_val END ASC NULLS LAST,
                CASE WHEN am.metric_key<>'refund_rate_pay_time' THEN am.c_val END DESC NULLS LAST,
                am.eid) AS cur_rnk,
            DENSE_RANK() OVER (PARTITION BY am.metric_key ORDER BY
                CASE WHEN am.metric_key='refund_rate_pay_time' THEN am.p_val END ASC NULLS LAST,
                CASE WHEN am.metric_key<>'refund_rate_pay_time' THEN am.p_val END DESC NULLS LAST,
                am.eid) AS prev_rnk
        FROM all_metrics am
    )
    SELECT
        v_en AS shop_name,
        'product' AS domain_key,
        '商品' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        NULL::text AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs AS current_start_date, p_ce AS current_end_date,
        p_ps AS previous_start_date, p_pe AS previous_end_date,
        m.c_val AS current_value, m.p_val AS previous_value,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        fr.cur_rnk AS current_rank,
        fr.prev_rnk AS previous_rank,
        (fr.prev_rnk - fr.cur_rnk) AS rank_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM all_metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS current_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN m.p_val / NULLIF((SELECT sum(m2.p_val) FROM all_metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS previous_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time') AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val / NULLIF((SELECT sum(m2.c_val) FROM all_metrics m2 WHERE m2.metric_key = m.metric_key), 0)
                - m.p_val / NULLIF((SELECT sum(m2.p_val) FROM all_metrics m2 WHERE m2.metric_key = m.metric_key), 0)
             ELSE NULL END AS contribution_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time') THEN 'domain' ELSE NULL END AS contribution_denominator_type,
        CASE WHEN m.metric_key IN ('user_pay_amount','refund_amount_pay_time')
             THEN (SELECT sum(m2.c_val) FROM all_metrics m2 WHERE m2.metric_key = m.metric_key) ELSE NULL END AS contribution_denominator_value,
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
        '商品快照（carrier=全部 独立TOTAL）；贡献=域内占比' AS notes
    FROM metrics m
    LEFT JOIN full_rank fr ON fr.eid = m.eid AND fr.metric_key = m.metric_key
    ORDER BY m.eid, m.metric_key;
END;
$$;


ALTER FUNCTION mart._diag_product(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_id text, p_entity_name text) OWNER TO postgres;

--
-- Name: FUNCTION _diag_product(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_id text, p_entity_name text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart._diag_product(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_id text, p_entity_name text) IS 'V1.1 商品域诊断快照（内部函数，不对外授权）。';


--
-- Name: _diag_product_line(text, date, date, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart._diag_product_line(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_name text) RETURNS TABLE(shop_name text, domain_key text, domain_name_cn text, entity_id text, entity_name text, scope_key text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint, current_contribution numeric, previous_contribution numeric, contribution_change numeric, contribution_denominator_type text, contribution_denominator_value numeric, current_coverage_days integer, expected_current_days integer, previous_coverage_days integer, expected_previous_days integer, current_coverage_complete boolean, previous_coverage_complete boolean, calculation_status text, data_status text, notes text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    WITH pl_list AS (
        SELECT pl.product_line_id::text AS eid, pl.product_line_name AS ename
        FROM meta.product_line pl
        WHERE (p_entity_name IS NULL OR pl.product_line_name = p_entity_name)
          AND EXISTS (SELECT 1 FROM meta.master_product mp
                      WHERE mp.product_line_id = pl.product_line_id AND mp.enabled
                        AND EXISTS (SELECT 1 FROM meta.platform_product_mapping m
                                    WHERE m.master_product_id = mp.master_product_id AND m.enabled AND m.mapping_status='CONFIRMED'))
    ),
    members AS (
        SELECT m.master_product_id, m.shop_id, m.platform_product_id
        FROM meta.platform_product_mapping m
        JOIN meta.master_product mp ON mp.master_product_id = m.master_product_id
        WHERE m.enabled AND m.mapping_status = 'CONFIRMED'
          AND mp.product_line_id IN (SELECT eid::integer FROM pl_list)
    ),
    raw AS (
        SELECT
            pll.eid, pll.ename,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.biz_date END)::int AS p_days,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.user_pay_amount END) AS c_up,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.user_pay_amount END) AS p_up,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.refund_amount_pay_time END) AS p_refund,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN mem.shop_id END)::int AS c_mapped_shops
        FROM pl_list pll
        JOIN meta.master_product mpl ON mpl.product_line_id = pll.eid::integer
        JOIN members mem ON mem.master_product_id = mpl.master_product_id
        LEFT JOIN core.douyin_product_daily d
          ON d.shop_id = mem.shop_id AND d.product_id = mem.platform_product_id
         AND d.biz_date BETWEEN p_ps AND p_ce AND d.carrier_type = '全部'
        GROUP BY pll.eid, pll.ename
    ),
    metrics AS (
        SELECT r.*, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
            END AS p_val
        FROM raw r
        CROSS JOIN LATERAL (VALUES
            ('user_pay_amount','用户支付金额','成交','amount','金额'),
            ('refund_amount_pay_time','退款金额(支付时间)','售后','amount','金额'),
            ('refund_rate_pay_time','退款率(支付时间)','售后','ratio','0.00%')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        COALESCE((SELECT s.shop_name::text FROM meta.shop s WHERE s.shop_name = p_shop_name), '平台汇总') AS shop_name,
        'product_line' AS domain_key,
        '品线' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        NULL::text AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs, p_ce, p_ps, p_pe,
        m.c_val, m.p_val,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        (SELECT t.rnk FROM (SELECT m2.eid,
             DENSE_RANK() OVER (ORDER BY CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.c_val END ASC NULLS LAST,
                                           CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.c_val END DESC NULLS LAST,
                                           m2.eid) AS rnk
             FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid) AS current_rank,
        (SELECT t.rnk FROM (SELECT m2.eid,
             DENSE_RANK() OVER (ORDER BY CASE WHEN m.metric_key='refund_rate_pay_time' THEN m2.p_val END ASC NULLS LAST,
                                           CASE WHEN m.metric_key<>'refund_rate_pay_time' THEN m2.p_val END DESC NULLS LAST,
                                           m2.eid) AS rnk
             FROM metrics m2 WHERE m2.metric_key = m.metric_key) t WHERE t.eid = m.eid) AS previous_rank,
        NULL::bigint AS rank_change,
        m.c_val / NULLIF((SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0) AS current_contribution,
        m.p_val / NULLIF((SELECT sum(m2.p_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key), 0) AS previous_contribution,
        NULL::numeric AS contribution_change,
        'domain' AS contribution_denominator_type,
        (SELECT sum(m2.c_val) FROM metrics m2 WHERE m2.metric_key = m.metric_key) AS contribution_denominator_value,
        m.c_days, (p_ce - p_cs + 1)::int,
        m.p_days, (p_pe - p_ps + 1)::int,
        (m.c_days >= (p_ce - p_cs + 1)::int) AS current_coverage_complete,
        (m.p_days >= (p_pe - p_ps + 1)::int) AS previous_coverage_complete,
        CASE WHEN m.p_val IS NOT NULL AND m.p_val = 0 THEN 'PREVIOUS_ZERO' ELSE 'CALCULATED' END AS calculation_status,
        CASE WHEN m.c_days = 0 THEN 'NO_CURRENT_DATA'
             WHEN m.p_days = 0 THEN 'NO_PREVIOUS_DATA'
             WHEN m.c_days < (p_ce - p_cs + 1)::int AND m.p_days < (p_pe - p_ps + 1)::int THEN 'BOTH_INCOMPLETE'
             WHEN m.c_days < (p_ce - p_cs + 1)::int THEN 'CURRENT_INCOMPLETE'
             WHEN m.p_days < (p_pe - p_ps + 1)::int THEN 'PREVIOUS_INCOMPLETE'
             ELSE 'OK' END AS data_status,
        '品线（仅已确认Master Product成员）；mapped_shops=' || m.c_mapped_shops || '/2' AS notes
    FROM metrics m
    ORDER BY m.eid, m.metric_key;
END;
$$;


ALTER FUNCTION mart._diag_product_line(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_name text) OWNER TO postgres;

--
-- Name: _diag_scope(text, date, date, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart._diag_scope(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) RETURNS TABLE(shop_name text, domain_key text, domain_name_cn text, entity_id text, entity_name text, scope_key text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint, current_contribution numeric, previous_contribution numeric, contribution_change numeric, contribution_denominator_type text, contribution_denominator_value numeric, current_coverage_days integer, expected_current_days integer, previous_coverage_days integer, expected_previous_days integer, current_coverage_complete boolean, previous_coverage_complete boolean, calculation_status text, data_status text, notes text)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_en text;
BEGIN
    SELECT COALESCE(s.shop_name, '平台汇总') INTO v_en FROM meta.shop s WHERE s.shop_name = p_shop_name;
    IF v_en IS NULL THEN v_en := '平台汇总'; END IF;

    RETURN QUERY
    WITH scope_list AS (
        SELECT v.scope, r.sale_scope, r.carrier_type, r.ad_period
        FROM (VALUES ('全店'),('自营'),('合作'),('商品卡'),('短视频'),('直播'),('图文'),('其他'),
                     ('自营商品卡'),('合作商品卡'),('自营短视频'),('合作短视频'),
                     ('自营直播'),('合作直播'),('自营图文'),('合作图文'),('自营其他'),('合作其他')) v(scope)
        CROSS JOIN LATERAL mart.resolve_scope(v.scope) r
        WHERE p_scope_key IS NULL OR v.scope = p_scope_key
    ),
    raw AS (
        SELECT
            sl.scope AS eid,
            sl.scope AS ename,
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
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.total_expense_rate_net_refund_shop_bound * d.settlement_amount END) AS p_total_exp,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.ad_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS c_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.ad_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS p_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.ad_efficiency_shop_bound * d.ad_spend_shop_bound END) AS c_eff_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.ad_efficiency_shop_bound * d.ad_spend_shop_bound END) AS p_eff_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.store_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS c_st_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.store_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS p_st_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.store_efficiency_shop_bound * d.ad_spend_shop_bound END) AS c_st_eff_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.store_efficiency_shop_bound * d.ad_spend_shop_bound END) AS p_st_eff_bound
        FROM scope_list sl
        JOIN core.douyin_deal_daily d
          ON d.sale_scope = sl.sale_scope AND d.carrier_type = sl.carrier_type AND d.ad_period = sl.ad_period
        JOIN meta.shop s ON s.shop_id = d.shop_id
        WHERE d.biz_date BETWEEN p_ps AND p_ce
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
        GROUP BY sl.scope
    ),
    store_tot AS (
        SELECT
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.user_pay_amount END) AS c_up,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.user_pay_amount END) AS p_up,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.transaction_amount END) AS c_trans,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.transaction_amount END) AS p_trans,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.refund_amount_pay_time END) AS c_refund,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.refund_amount_pay_time END) AS p_refund
        FROM core.douyin_deal_daily d
        JOIN meta.shop s ON s.shop_id = d.shop_id
        WHERE d.biz_date BETWEEN p_ps AND p_ce
          AND d.sale_scope = '全部' AND d.carrier_type = '全部' AND d.ad_period = '不限'
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
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
                WHEN 'ad_efficiency_shop_promoted' THEN r.c_eff_promoted / NULLIF(r.c_ad_promoted, 0)
                WHEN 'ad_efficiency_shop_bound' THEN r.c_eff_bound / NULLIF(r.c_ad_bound, 0)
                WHEN 'store_efficiency_shop_promoted' THEN r.c_st_eff_promoted / NULLIF(r.c_ad_promoted, 0)
                WHEN 'store_efficiency_shop_bound' THEN r.c_st_eff_bound / NULLIF(r.c_ad_bound, 0)
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
                WHEN 'ad_efficiency_shop_promoted' THEN r.p_eff_promoted / NULLIF(r.p_ad_promoted, 0)
                WHEN 'ad_efficiency_shop_bound' THEN r.p_eff_bound / NULLIF(r.p_ad_bound, 0)
                WHEN 'store_efficiency_shop_promoted' THEN r.p_st_eff_promoted / NULLIF(r.p_ad_promoted, 0)
                WHEN 'store_efficiency_shop_bound' THEN r.p_st_eff_bound / NULLIF(r.p_ad_bound, 0)
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
            ('total_expense_rate_net_refund_shop_bound','综合费比(剔除退款、店铺绑定)','投放','ratio','0.00%'),
            ('ad_efficiency_shop_promoted','投放效率(店铺被投)','投放','efficiency','0.00'),
            ('ad_efficiency_shop_bound','投放效率(店铺绑定)','投放','efficiency','0.00'),
            ('store_efficiency_shop_promoted','全店效率(店铺被投)','投放','efficiency','0.00'),
            ('store_efficiency_shop_bound','全店效率(店铺绑定)','投放','efficiency','0.00')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        v_en AS shop_name,
        'scope' AS domain_key,
        '经营Scope' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        m.eid AS scope_key,
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
        NULL::bigint AS current_rank, NULL::bigint AS previous_rank, NULL::bigint AS rank_change,
        CASE WHEN m.metric_key = 'user_pay_amount' THEN m.c_val / NULLIF(st.c_up, 0)
             WHEN m.metric_key = 'transaction_amount' THEN m.c_val / NULLIF(st.c_trans, 0)
             WHEN m.metric_key = 'refund_amount_pay_time' THEN m.c_val / NULLIF(st.c_refund, 0)
             ELSE NULL END AS current_contribution,
        CASE WHEN m.metric_key = 'user_pay_amount' THEN m.p_val / NULLIF(st.p_up, 0)
             WHEN m.metric_key = 'transaction_amount' THEN m.p_val / NULLIF(st.p_trans, 0)
             WHEN m.metric_key = 'refund_amount_pay_time' THEN m.p_val / NULLIF(st.p_refund, 0)
             ELSE NULL END AS previous_contribution,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time')
              AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN (m.c_val / NULLIF(st.c_up, 0)) - (m.p_val / NULLIF(st.p_up, 0)) ELSE NULL END AS contribution_change,
        CASE WHEN m.metric_key IN ('user_pay_amount','transaction_amount','refund_amount_pay_time')
             THEN 'store' ELSE NULL END AS contribution_denominator_type,
        CASE WHEN m.metric_key = 'user_pay_amount' THEN st.c_up
             WHEN m.metric_key = 'transaction_amount' THEN st.c_trans
             WHEN m.metric_key = 'refund_amount_pay_time' THEN st.c_refund
             ELSE NULL END AS contribution_denominator_value,
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
        'Scope 快照；贡献=占全店比重' AS notes
    FROM metrics m, store_tot st
    ORDER BY m.eid, m.grp, m.metric_key;
END;
$$;


ALTER FUNCTION mart._diag_scope(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) OWNER TO postgres;

--
-- Name: FUNCTION _diag_scope(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart._diag_scope(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) IS 'V1.1 经营Scope域诊断快照（内部函数，不对外授权）。';


--
-- Name: _diag_shop(text, date, date, date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart._diag_shop(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date) RETURNS TABLE(shop_name text, domain_key text, domain_name_cn text, entity_id text, entity_name text, scope_key text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint, current_contribution numeric, previous_contribution numeric, contribution_change numeric, contribution_denominator_type text, contribution_denominator_value numeric, current_coverage_days integer, expected_current_days integer, previous_coverage_days integer, expected_previous_days integer, current_coverage_complete boolean, previous_coverage_complete boolean, calculation_status text, data_status text, notes text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    WITH raw AS (
        SELECT
            s.shop_id::text AS eid,
            s.shop_name AS ename,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.biz_date END)::int AS c_days,
            count(DISTINCT CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.biz_date END)::int AS p_days,
            -- 双期原始量（金额/计数/加权分子分母）
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
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.total_expense_rate_net_refund_shop_bound * d.settlement_amount END) AS p_total_exp,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.ad_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS c_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.ad_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS p_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.ad_efficiency_shop_bound * d.ad_spend_shop_bound END) AS c_eff_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.ad_efficiency_shop_bound * d.ad_spend_shop_bound END) AS p_eff_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.store_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS c_st_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.store_efficiency_shop_promoted * d.ad_spend_shop_promoted END) AS p_st_eff_promoted,
            sum(CASE WHEN d.biz_date BETWEEN p_cs AND p_ce THEN d.store_efficiency_shop_bound * d.ad_spend_shop_bound END) AS c_st_eff_bound,
            sum(CASE WHEN d.biz_date BETWEEN p_ps AND p_pe THEN d.store_efficiency_shop_bound * d.ad_spend_shop_bound END) AS p_st_eff_bound
        FROM core.douyin_deal_daily d
        JOIN meta.shop s ON s.shop_id = d.shop_id
        WHERE d.biz_date BETWEEN p_ps AND p_ce
          AND d.sale_scope = '全部' AND d.carrier_type = '全部' AND d.ad_period = '不限'
          AND (p_shop_name IS NULL OR s.shop_name = p_shop_name)
        GROUP BY s.shop_id, s.shop_name
    ),
    metrics AS (
        SELECT r.*, vv.metric_key, vv.name_cn, vv.grp, vv.typ, vv.fmt,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.c_up
                WHEN 'transaction_amount' THEN r.c_trans
                WHEN 'settlement_amount' THEN r.c_settle
                WHEN 'transaction_order_count' THEN r.c_ord
                WHEN 'transaction_buyer_count' THEN r.c_buyer
                WHEN 'transaction_item_count' THEN r.c_items
                WHEN 'avg_customer_amount' THEN r.c_up / NULLIF(r.c_buyer, 0)
                WHEN 'avg_item_amount' THEN r.c_up / NULLIF(r.c_items, 0)
                WHEN 'product_exposure_user_count' THEN r.c_exp_u
                WHEN 'product_click_user_count' THEN r.c_click_u
                WHEN 'exposure_to_click_rate_users' THEN r.c_click_u / NULLIF(r.c_exp_u, 0)
                WHEN 'click_to_transaction_rate_users' THEN r.c_buyer / NULLIF(r.c_click_u, 0)
                WHEN 'exposure_to_transaction_rate_users' THEN r.c_buyer / NULLIF(r.c_exp_u, 0)
                WHEN 'product_exposure_count' THEN r.c_exp_c
                WHEN 'product_click_count' THEN r.c_click_c
                WHEN 'exposure_to_click_rate_events' THEN r.c_click_c / NULLIF(r.c_exp_c, 0)
                WHEN 'click_to_transaction_rate_events' THEN r.c_ord / NULLIF(r.c_click_c, 0)
                WHEN 'exposure_to_transaction_rate_events' THEN r.c_ord / NULLIF(r.c_exp_c, 0)
                WHEN 'transaction_refund_amount_pay_time' THEN r.c_trefund
                WHEN 'refund_amount_pay_time' THEN r.c_refund
                WHEN 'refund_rate_pay_time' THEN r.c_refund / NULLIF(r.c_up, 0)
                WHEN 'ad_spend_shop_promoted' THEN r.c_ad_promoted
                WHEN 'ad_spend_shop_bound' THEN r.c_ad_bound
                WHEN 'ad_attributed_transaction_amount' THEN r.c_ad_attrib
                WHEN 'ad_attributed_transaction_share' THEN r.c_ad_attrib / NULLIF(r.c_trans, 0)
                WHEN 'ad_spend_rate_net_refund_shop_bound' THEN r.c_ad_bound / NULLIF(r.c_settle, 0)
                WHEN 'total_expense_rate_net_refund_shop_bound' THEN r.c_total_exp / NULLIF(r.c_settle, 0)
                WHEN 'ad_efficiency_shop_promoted' THEN r.c_eff_promoted / NULLIF(r.c_ad_promoted, 0)
                WHEN 'ad_efficiency_shop_bound' THEN r.c_eff_bound / NULLIF(r.c_ad_bound, 0)
                WHEN 'store_efficiency_shop_promoted' THEN r.c_st_eff_promoted / NULLIF(r.c_ad_promoted, 0)
                WHEN 'store_efficiency_shop_bound' THEN r.c_st_eff_bound / NULLIF(r.c_ad_bound, 0)
            END AS c_val,
            CASE vv.metric_key
                WHEN 'user_pay_amount' THEN r.p_up
                WHEN 'transaction_amount' THEN r.p_trans
                WHEN 'settlement_amount' THEN r.p_settle
                WHEN 'transaction_order_count' THEN r.p_ord
                WHEN 'transaction_buyer_count' THEN r.p_buyer
                WHEN 'transaction_item_count' THEN r.p_items
                WHEN 'avg_customer_amount' THEN r.p_up / NULLIF(r.p_buyer, 0)
                WHEN 'avg_item_amount' THEN r.p_up / NULLIF(r.p_items, 0)
                WHEN 'product_exposure_user_count' THEN r.p_exp_u
                WHEN 'product_click_user_count' THEN r.p_click_u
                WHEN 'exposure_to_click_rate_users' THEN r.p_click_u / NULLIF(r.p_exp_u, 0)
                WHEN 'click_to_transaction_rate_users' THEN r.p_buyer / NULLIF(r.p_click_u, 0)
                WHEN 'exposure_to_transaction_rate_users' THEN r.p_buyer / NULLIF(r.p_exp_u, 0)
                WHEN 'product_exposure_count' THEN r.p_exp_c
                WHEN 'product_click_count' THEN r.p_click_c
                WHEN 'exposure_to_click_rate_events' THEN r.p_click_c / NULLIF(r.p_exp_c, 0)
                WHEN 'click_to_transaction_rate_events' THEN r.p_ord / NULLIF(r.p_click_c, 0)
                WHEN 'exposure_to_transaction_rate_events' THEN r.p_ord / NULLIF(r.p_exp_c, 0)
                WHEN 'transaction_refund_amount_pay_time' THEN r.p_trefund
                WHEN 'refund_amount_pay_time' THEN r.p_refund
                WHEN 'refund_rate_pay_time' THEN r.p_refund / NULLIF(r.p_up, 0)
                WHEN 'ad_spend_shop_promoted' THEN r.p_ad_promoted
                WHEN 'ad_spend_shop_bound' THEN r.p_ad_bound
                WHEN 'ad_attributed_transaction_amount' THEN r.p_ad_attrib
                WHEN 'ad_attributed_transaction_share' THEN r.p_ad_attrib / NULLIF(r.p_trans, 0)
                WHEN 'ad_spend_rate_net_refund_shop_bound' THEN r.p_ad_bound / NULLIF(r.p_settle, 0)
                WHEN 'total_expense_rate_net_refund_shop_bound' THEN r.p_total_exp / NULLIF(r.p_settle, 0)
                WHEN 'ad_efficiency_shop_promoted' THEN r.p_eff_promoted / NULLIF(r.p_ad_promoted, 0)
                WHEN 'ad_efficiency_shop_bound' THEN r.p_eff_bound / NULLIF(r.p_ad_bound, 0)
                WHEN 'store_efficiency_shop_promoted' THEN r.p_st_eff_promoted / NULLIF(r.p_ad_promoted, 0)
                WHEN 'store_efficiency_shop_bound' THEN r.p_st_eff_bound / NULLIF(r.p_ad_bound, 0)
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
            ('total_expense_rate_net_refund_shop_bound','综合费比(剔除退款、店铺绑定)','投放','ratio','0.00%'),
            ('ad_efficiency_shop_promoted','投放效率(店铺被投)','投放','efficiency','0.00'),
            ('ad_efficiency_shop_bound','投放效率(店铺绑定)','投放','efficiency','0.00'),
            ('store_efficiency_shop_promoted','全店效率(店铺被投)','投放','efficiency','0.00'),
            ('store_efficiency_shop_bound','全店效率(店铺绑定)','投放','efficiency','0.00')
        ) AS vv(metric_key, name_cn, grp, typ, fmt)
    )
    SELECT
        m.ename::text AS shop_name,
        'shop' AS domain_key,
        '店铺整体' AS domain_name_cn,
        m.eid::text AS entity_id,
        m.ename::text AS entity_name,
        '全店' AS scope_key,
        m.metric_key, m.name_cn AS metric_name_cn, m.grp AS metric_group, m.typ AS metric_type, m.fmt AS display_format,
        p_cs AS current_start_date, p_ce AS current_end_date,
        p_ps AS previous_start_date, p_pe AS previous_end_date,
        m.c_val AS current_value, m.p_val AS previous_value,
        (m.c_val - m.p_val) AS absolute_change,
        CASE WHEN m.p_val IS NULL THEN NULL
             WHEN m.p_val = 0 THEN NULL
             ELSE (m.c_val - m.p_val) / abs(m.p_val) END AS relative_change,
        CASE WHEN m.typ = 'ratio' AND m.metric_key IN ('exposure_to_click_rate_users','click_to_transaction_rate_users',
                    'exposure_to_transaction_rate_users','exposure_to_click_rate_events','click_to_transaction_rate_events',
                    'exposure_to_transaction_rate_events','refund_rate_pay_time','ad_attributed_transaction_share',
                    'ad_spend_rate_net_refund_shop_bound','total_expense_rate_net_refund_shop_bound')
             AND m.c_val IS NOT NULL AND m.p_val IS NOT NULL
             THEN m.c_val - m.p_val ELSE NULL END AS percentage_point_change,
        NULL::bigint AS current_rank, NULL::bigint AS previous_rank, NULL::bigint AS rank_change,
        NULL::numeric AS current_contribution, NULL::numeric AS previous_contribution, NULL::numeric AS contribution_change,
        NULL::text AS contribution_denominator_type, NULL::numeric AS contribution_denominator_value,
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
        '店铺整体快照' AS notes
    FROM metrics m
    ORDER BY m.grp, m.metric_key;
END;
$$;


ALTER FUNCTION mart._diag_shop(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date) OWNER TO postgres;

--
-- Name: FUNCTION _diag_shop(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart._diag_shop(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date) IS 'V1.1 店铺整体域诊断快照（内部函数，不对外授权）。';


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
-- Name: check_mapping_period_conflict(text, bigint, text, date, date, bigint); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.check_mapping_period_conflict(p_platform_code text, p_shop_id bigint, p_platform_product_id text, p_valid_from date, p_valid_to date, p_exclude_mapping_id bigint DEFAULT NULL::bigint) RETURNS TABLE(conflict_mapping_id bigint, master_product_id integer, valid_from date, valid_to date)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT m.mapping_id, m.master_product_id, m.valid_from, m.valid_to
    FROM meta.platform_product_mapping m
    WHERE m.platform_code = p_platform_code AND m.shop_id = p_shop_id
      AND m.platform_product_id = p_platform_product_id AND m.enabled
      AND (p_exclude_mapping_id IS NULL OR m.mapping_id <> p_exclude_mapping_id)
      AND m.valid_from < coalesce(p_valid_to, 'infinity'::date)
      AND coalesce(m.valid_to, 'infinity'::date) > p_valid_from;
END; $$;


ALTER FUNCTION mart.check_mapping_period_conflict(p_platform_code text, p_shop_id bigint, p_platform_product_id text, p_valid_from date, p_valid_to date, p_exclude_mapping_id bigint) OWNER TO postgres;

--
-- Name: FUNCTION check_mapping_period_conflict(p_platform_code text, p_shop_id bigint, p_platform_product_id text, p_valid_from date, p_valid_to date, p_exclude_mapping_id bigint); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.check_mapping_period_conflict(p_platform_code text, p_shop_id bigint, p_platform_product_id text, p_valid_from date, p_valid_to date, p_exclude_mapping_id bigint) IS 'V1.3 映射时间区间重叠检测：同一平台店铺商品在重叠有效期内存在多条启用映射 → CONFLICT（不静默覆盖）。';


--
-- Name: compare_advertising_period(text, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.compare_advertising_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) RETURNS TABLE(metric_key text, metric_name_cn text, value_type text, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
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
$$;


ALTER FUNCTION mart.compare_advertising_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) OWNER TO postgres;

--
-- Name: FUNCTION compare_advertising_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.compare_advertising_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) IS 'V1.0.1 投放环比：本期N天 vs 紧邻前N天；比例输出百分点+相对，效率只输出绝对+相对（不输出百分点）。';


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
-- Name: compare_platform_business(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.compare_platform_business(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text DEFAULT '全店'::text, p_metric_key text DEFAULT 'user_pay_amount'::text) RETURNS TABLE(platform_code text, platform_name text, scope_key text, metric_key text, metric_name_cn text, value_type text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, enabled_shop_count integer, covered_shop_count integer, current_coverage_complete boolean, previous_coverage_complete boolean, comparison_status text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
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
$$;


ALTER FUNCTION mart.compare_platform_business(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) OWNER TO postgres;

--
-- Name: FUNCTION compare_platform_business(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.compare_platform_business(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) IS 'V1.3 平台环比：本期 vs 等长上期（金额/计数可比较；比例返回百分点+相对变化）。';


--
-- Name: decompose_master_product_by_shop_product(bigint, date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.decompose_master_product_by_shop_product(p_master_product_id bigint, p_start_date date, p_end_date date) RETURNS TABLE(master_product_id integer, master_product_name text, shop_name text, platform_product_id text, platform_product_name text, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, net_change numeric, gross_negative_impact numeric, gross_positive_offset numeric, negative_impact_share numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_ps date; v_pe date; v_days int;
BEGIN
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);
    RETURN QUERY
    WITH members AS (
        SELECT m.shop_id, m.platform_product_id
        FROM meta.platform_product_mapping m
        WHERE m.master_product_id = p_master_product_id AND m.enabled AND m.mapping_status='CONFIRMED'
    ),
    member_chg AS (
        SELECT mem.shop_id, mem.platform_product_id,
               sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.user_pay_amount END) AS c_val,
               sum(CASE WHEN d.biz_date BETWEEN v_ps AND v_pe THEN d.user_pay_amount END) AS p_val
        FROM members mem
        LEFT JOIN core.douyin_product_daily d
          ON d.shop_id = mem.shop_id AND d.product_id = mem.platform_product_id
         AND d.biz_date BETWEEN v_ps AND p_end_date AND d.carrier_type='全部'
        GROUP BY mem.shop_id, mem.platform_product_id
    ),
    totals AS (
        SELECT sum(c_val - p_val) AS net_chg,
               sum(CASE WHEN (c_val - p_val) < 0 THEN abs(c_val - p_val) ELSE 0 END) AS gross_neg,
               sum(CASE WHEN (c_val - p_val) > 0 THEN (c_val - p_val) ELSE 0 END) AS gross_pos
        FROM member_chg
    )
    SELECT
        p_master_product_id::integer,
        (SELECT mpp.master_product_name FROM meta.master_product mpp WHERE mpp.master_product_id = p_master_product_id),
        s.shop_name::text,
        mc.platform_product_id,
        (SELECT m2.platform_product_name_snapshot FROM meta.platform_product_mapping m2
         WHERE m2.master_product_id = p_master_product_id AND m2.shop_id = mc.shop_id AND m2.platform_product_id = mc.platform_product_id
           AND m2.enabled LIMIT 1),
        mc.c_val, mc.p_val,
        (mc.c_val - mc.p_val) AS absolute_change,
        CASE WHEN mc.p_val IS NULL THEN NULL WHEN mc.p_val = 0 THEN NULL
             ELSE (mc.c_val - mc.p_val) / abs(mc.p_val) END AS relative_change,
        t.net_chg, t.gross_neg, t.gross_pos,
        CASE WHEN t.gross_neg IS NULL OR t.gross_neg = 0 THEN NULL
             ELSE abs(mc.c_val - mc.p_val) / t.gross_neg END AS negative_impact_share
    FROM member_chg mc
    JOIN meta.shop s ON s.shop_id = mc.shop_id
    CROSS JOIN totals t
    ORDER BY absolute_change ASC NULLS LAST;
END;
$$;


ALTER FUNCTION mart.decompose_master_product_by_shop_product(p_master_product_id bigint, p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: FUNCTION decompose_master_product_by_shop_product(p_master_product_id bigint, p_start_date date, p_end_date date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.decompose_master_product_by_shop_product(p_master_product_id bigint, p_start_date date, p_end_date date) IS 'V1.3/V1.1 Master Product → 店铺商品拆解：定位哪家店商品拖累（negative_impact_share=单店商品负向/全部负向）。';


--
-- Name: decompose_platform_change_by_shop(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.decompose_platform_change_by_shop(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text DEFAULT '全店'::text, p_metric_key text DEFAULT 'user_pay_amount'::text) RETURNS TABLE(platform_code text, platform_name text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, scope_key text, metric_key text, shop_name text, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, net_change numeric, gross_negative_impact numeric, gross_positive_offset numeric, negative_impact_share numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_scope_sale text; v_scope_carrier text; v_scope_period text;
    v_ps date; v_pe date; v_days int;
BEGIN
    SELECT sale_scope, carrier_type, ad_period INTO v_scope_sale, v_scope_carrier, v_scope_period
    FROM mart.resolve_scope(p_scope_key);
    IF v_scope_sale IS NULL THEN RAISE EXCEPTION '未知经营语义: %', p_scope_key; END IF;
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);

    RETURN QUERY
    WITH enabled_shops AS (
        SELECT s.shop_id, s.shop_name FROM meta.shop s
        WHERE s.platform_code = p_platform_code AND s.enabled
    ),
    shop_chg AS (
        SELECT es.shop_name,
               sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.user_pay_amount END) AS c_val,
               sum(CASE WHEN d.biz_date BETWEEN v_ps AND v_pe THEN d.user_pay_amount END) AS p_val
        FROM enabled_shops es
        LEFT JOIN core.douyin_deal_daily d
          ON d.shop_id = es.shop_id
         AND d.biz_date BETWEEN v_ps AND p_end_date
         AND d.sale_scope = v_scope_sale AND d.carrier_type = v_scope_carrier AND d.ad_period = v_scope_period
        GROUP BY es.shop_name
    ),
    totals AS (
        SELECT
            sum(c_val - p_val) AS net_chg,
            sum(CASE WHEN (c_val - p_val) < 0 THEN abs(c_val - p_val) ELSE 0 END) AS gross_neg,
            sum(CASE WHEN (c_val - p_val) > 0 THEN (c_val - p_val) ELSE 0 END) AS gross_pos
        FROM shop_chg
    )
    SELECT
        p_platform_code,
        (SELECT p.platform_name FROM meta.platform p WHERE p.platform_code = p_platform_code),
        p_start_date, p_end_date, v_ps, v_pe,
        p_scope_key, p_metric_key,
        sc.shop_name::text,
        sc.c_val AS current_value, sc.p_val AS previous_value,
        (sc.c_val - sc.p_val) AS absolute_change,
        CASE WHEN sc.p_val IS NULL THEN NULL WHEN sc.p_val = 0 THEN NULL
             ELSE (sc.c_val - sc.p_val) / abs(sc.p_val) END AS relative_change,
        t.net_chg AS net_change,
        t.gross_neg AS gross_negative_impact,
        t.gross_pos AS gross_positive_offset,
        CASE WHEN t.gross_neg IS NULL OR t.gross_neg = 0 THEN NULL
             ELSE abs(sc.c_val - sc.p_val) / t.gross_neg END AS negative_impact_share
    FROM shop_chg sc
    CROSS JOIN totals t
    ORDER BY absolute_change ASC;
END;
$$;


ALTER FUNCTION mart.decompose_platform_change_by_shop(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) OWNER TO postgres;

--
-- Name: FUNCTION decompose_platform_change_by_shop(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.decompose_platform_change_by_shop(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) IS 'V1.3 平台变化按店铺拆解：net_change=Σ单店变化；gross_negative_impact=Σ负向绝对值；gross_positive_offset=Σ正向；
negative_impact_share=单店负向绝对值/全部负向绝对值（文档二十二节：不除以净下降额）。';


--
-- Name: detect_anomalies(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.detect_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_ps date; v_pe date; v_days int;
    v_event_count int := 0;
    v_shop_cov bool; v_map_cov bool;
    r_rule record;
    r_ent record;
    v_cur numeric; v_prev numeric; v_rel numeric; v_pp numeric;
    v_base numeric; v_status text;
    v_sev_score numeric; v_sev text;
    v_prev_events int; v_consec int;
    v_chain text;
    v_plat_enabled int; v_plat_covered int; v_plat_complete bool;
    v_shop_enabled int; v_shop_covered int; v_shop_complete bool;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RAISE EXCEPTION '非法日期区间: % ~ %', p_start_date, p_end_date;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM mart.diagnostic_entity_rule WHERE domain_key = p_domain_key AND enabled) THEN
        RAISE EXCEPTION '未知/未启用诊断域: %', p_domain_key;
    END IF;
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);
    v_chain := 'S1|' || p_domain_key || '|' || p_platform_code;

    IF p_domain_key = 'platform' THEN
        CREATE TEMP TABLE snap_rows ON COMMIT DROP AS
        SELECT entity_id::text AS entity_id, entity_name::text AS entity_name, scope_key,
               metric_key, current_value, previous_value, relative_change, percentage_point_change,
               data_status, current_coverage_complete AS coverage_complete
        FROM mart.get_platform_diagnostic_snapshot(p_platform_code, p_start_date, p_end_date, '全店');
    ELSE
        CREATE TEMP TABLE snap_rows ON COMMIT DROP AS
        SELECT entity_id, entity_name, scope_key,
               metric_key, current_value, previous_value, relative_change, percentage_point_change,
               data_status, current_coverage_complete AS coverage_complete
        FROM mart.get_diagnostic_snapshot(p_shop_name, p_start_date, p_end_date, p_domain_key, NULL, NULL, NULL, NULL);
    END IF;

    -- 平台/店铺覆盖信息
    IF p_domain_key = 'platform' THEN
        SELECT enabled_shop_count, covered_shop_count, coverage_complete INTO v_plat_enabled, v_plat_covered, v_plat_complete
        FROM mart.get_platform_business_period_summary(p_platform_code, p_start_date, p_end_date, '全店');
    END IF;

    FOR r_rule IN SELECT * FROM mart.anomaly_rule WHERE enabled ORDER BY rule_code LOOP
        -- 域×指标支持检查（不支持跳过）
        IF NOT EXISTS (SELECT 1 FROM mart.get_diagnostic_entity_metrics(p_domain_key) m WHERE m.metric_key = r_rule.metric_key) THEN
            CONTINUE;
        END IF;

        FOR r_ent IN
            SELECT DISTINCT entity_id, entity_name, scope_key FROM snap_rows
            WHERE metric_key = r_rule.metric_key
        LOOP
            SELECT current_value, previous_value, relative_change, percentage_point_change, data_status
              INTO v_cur, v_prev, v_rel, v_pp, v_status
            FROM snap_rows
            WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
              AND metric_key = r_rule.metric_key
              AND scope_key IS NOT DISTINCT FROM r_ent.scope_key
            LIMIT 1;
            IF v_cur IS NULL AND v_prev IS NULL THEN CONTINUE; END IF;

            -- coverage 优先级（文档十三节）：NO DATA → COVERAGE → UNSUPPORTED → LOW BASE → THRESHOLD
            IF v_status IN ('NO_CURRENT_DATA','NO_PREVIOUS_DATA','CURRENT_INCOMPLETE','PREVIOUS_INCOMPLETE','BOTH_INCOMPLETE') THEN
                CONTINUE;  -- 数据不完整不判异常（平台缺店 → COVERAGE_INCOMPLETE 语义）
            END IF;
            -- 平台 coverage 不完整 → 不判异常
            IF p_domain_key = 'platform' AND NOT v_plat_complete THEN
                CONTINUE;
            END IF;
            IF v_prev IS NULL OR v_prev = 0 THEN CONTINUE; END IF;  -- PREVIOUS_ZERO / 无上期 → 不判

            -- 低基数（base 用该指标行 current 值；ratio 类用对应数量指标）
            v_base := v_cur;
            IF r_rule.low_base_metric IS NOT NULL AND r_rule.low_base_metric <> r_rule.metric_key THEN
                SELECT current_value INTO v_base FROM snap_rows
                WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
                  AND metric_key = r_rule.low_base_metric
                  AND scope_key IS NOT DISTINCT FROM r_ent.scope_key
                LIMIT 1;
            END IF;
            IF v_base IS NULL OR v_base < r_rule.low_base_value THEN CONTINUE; END IF;  -- LOW BASE

            -- 阈值判断
            IF r_rule.metric_direction = 'DROP' THEN
                IF r_rule.metric_key IN ('refund_rate_pay_time','exposure_to_click_rate_users','click_to_transaction_rate_users','ad_attributed_transaction_share','ad_spend_rate_net_refund_shop_bound') THEN
                    -- ratio 指标用百分点
                    IF v_pp IS NULL OR (-v_pp) < coalesce(r_rule.threshold_pp, 0.02) THEN CONTINUE; END IF;
                ELSE
                    IF v_rel IS NULL OR (-v_rel) < r_rule.threshold_relative THEN CONTINUE; END IF;
                END IF;
            ELSE  -- RISE
                IF r_rule.metric_key = 'refund_rate_pay_time' THEN
                    IF v_pp IS NULL OR v_pp < coalesce(r_rule.threshold_pp, 0.02) THEN CONTINUE; END IF;
                ELSE
                    IF v_rel IS NULL OR v_rel < r_rule.threshold_relative THEN CONTINUE; END IF;
                END IF;
            END IF;

            -- persistence：查历史同实体同类型事件
            SELECT count(*) INTO v_prev_events FROM mart.anomaly_event
            WHERE domain_key = p_domain_key AND entity_id IS NOT DISTINCT FROM r_ent.entity_id
              AND anomaly_type = r_rule.rule_code AND status <> 'RESOLVED';
            v_consec := least(v_prev_events + 1, 30);

            -- severity：magnitude + materiality + persistence + data_quality
            v_sev_score := r_rule.severity_base
                + least(abs(coalesce(v_rel, 0)) * 100, 20)
                + least(abs(coalesce(v_pp, 0)) * 400, 10)
                + least(v_consec * 3, 15);
            IF p_domain_key = 'platform' AND NOT v_plat_complete THEN v_sev_score := v_sev_score - 15; END IF;
            v_sev_score := greatest(v_sev_score, 0);
            IF v_sev_score >= 80 THEN v_sev := 'CRITICAL';
            ELSIF v_sev_score >= 65 THEN v_sev := 'HIGH';
            ELSIF v_sev_score >= 50 THEN v_sev := 'MEDIUM';
            ELSIF v_sev_score >= 35 THEN v_sev := 'LOW';
            ELSE v_sev := 'INFO'; END IF;

            -- 生成事件（幂等：唯一键冲突自动跳过）
            INSERT INTO mart.anomaly_event
                (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                 metric_key, anomaly_type, current_start_date, current_end_date, previous_start_date, previous_end_date,
                 current_value, previous_value, absolute_change, relative_change, percentage_point_change,
                 low_base_value, materiality, triggered_period_count, consecutive_day_count,
                 severity, severity_score, coverage_complete, shop_coverage_complete, mapping_complete,
                 data_quality_score, diagnostic_chain_key, status, rule_version, notes)
            VALUES
                (p_platform_code,
                 CASE WHEN p_domain_key = 'platform' THEN NULL ELSE p_shop_name END,
                 p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                 r_rule.metric_key, r_rule.rule_code,
                 p_start_date, p_end_date, v_ps, v_pe,
                 v_cur, v_prev, (v_cur - v_prev), v_rel, v_pp,
                 r_rule.low_base_value, abs(v_cur - v_prev),
                 v_prev_events + 1, v_consec,
                 v_sev, v_sev_score,
                 (v_status = 'OK'), v_plat_complete, NULL,
                 CASE WHEN v_status = 'OK' THEN 90 ELSE 60 END,
                 v_chain, 'OPEN', 'v1',
                 '多店兼容异常检测（' || r_rule.rule_name_cn || '）')
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    DROP TABLE IF EXISTS snap_rows;
    RETURN (SELECT count(*)::int FROM mart.anomaly_event
            WHERE current_start_date = p_start_date AND current_end_date = p_end_date
              AND domain_key = p_domain_key AND platform_code = p_platform_code);
END;
$$;


ALTER FUNCTION mart.detect_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text) OWNER TO postgres;

--
-- Name: FUNCTION detect_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.detect_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text) IS 'V1.1 异常检测（多店兼容）：对指定域全部实体×8类规则检测，幂等写 anomaly_event。
检测链=快照→支持→coverage→低基数→阈值→持续性→严重度→事件。';


--
-- Name: detect_growth_opportunities(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.detect_growth_opportunities(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text DEFAULT NULL::text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_ps date; v_pe date; v_days int;
    r_ent record; v_rule record;
    v_up_cur numeric; v_up_prev numeric; v_up_rel numeric;
    v_cvr_cur numeric; v_cvr_rel numeric; v_ctr_rel numeric;
    v_refund_cur numeric; v_refund_rel numeric;
    v_eff_rel numeric; v_spend_cur numeric; v_spend_rel numeric;
    v_exp_cur numeric;
    v_score numeric; v_level text; v_avail numeric;
    v_peer_p50 numeric; v_peer_p75 numeric; v_peer_count int;
    v_status text; v_code text; v_flags text;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RAISE EXCEPTION '非法日期区间: % ~ %', p_start_date, p_end_date;
    END IF;
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);

    IF p_domain_key = 'platform' THEN
        CREATE TEMP TABLE snap_rows ON COMMIT DROP AS
        SELECT entity_id::text AS entity_id, entity_name::text AS entity_name, scope_key, metric_key,
               current_value, previous_value, relative_change, data_status
        FROM mart.get_platform_diagnostic_snapshot(p_platform_code, p_start_date, p_end_date, '全店');
    ELSE
        CREATE TEMP TABLE snap_rows ON COMMIT DROP AS
        SELECT entity_id, entity_name, scope_key, metric_key,
               current_value, previous_value, relative_change, data_status
        FROM mart.get_diagnostic_snapshot(p_shop_name, p_start_date, p_end_date, p_domain_key, NULL, NULL, NULL, NULL);
    END IF;

    FOR r_ent IN SELECT DISTINCT entity_id, entity_name, scope_key FROM snap_rows LOOP
        -- 取指标
        SELECT current_value, previous_value, relative_change INTO v_up_cur, v_up_prev, v_up_rel
        FROM snap_rows WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='user_pay_amount' LIMIT 1;
        SELECT current_value, relative_change INTO v_cvr_cur, v_cvr_rel
        FROM snap_rows WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='click_to_transaction_rate_users' LIMIT 1;
        SELECT relative_change INTO v_ctr_rel FROM snap_rows WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='exposure_to_click_rate_users' LIMIT 1;
        SELECT current_value, relative_change INTO v_refund_cur, v_refund_rel FROM snap_rows
          WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='refund_rate_pay_time' LIMIT 1;
        SELECT relative_change INTO v_eff_rel FROM snap_rows WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='ad_efficiency_shop_promoted' LIMIT 1;
        SELECT current_value, relative_change INTO v_spend_cur, v_spend_rel FROM snap_rows
          WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='ad_spend_shop_promoted' LIMIT 1;
        SELECT current_value INTO v_exp_cur FROM snap_rows WHERE entity_id IS NOT DISTINCT FROM r_ent.entity_id
          AND scope_key IS NOT DISTINCT FROM r_ent.scope_key AND metric_key='product_exposure_user_count' LIMIT 1;

        -- 状态判定
        v_status := 'QUALIFIED'; v_flags := '';
        IF v_up_cur IS NULL THEN CONTINUE; END IF;
        IF v_up_prev IS NULL OR v_up_prev = 0 THEN
            INSERT INTO mart.opportunity_event (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                current_start_date, current_end_date, previous_start_date, previous_end_date, current_value, previous_value,
                relative_change, opportunity_score, opportunity_level, available_weight, status, notes, created_at)
            VALUES (p_platform_code, p_shop_name, p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                p_start_date, p_end_date, v_ps, v_pe, v_up_cur, v_up_prev, NULL, 0, 'LOW', 0, 'NEW_BASE_SIGNAL',
                '上期=0，仅新基线信号（不判机会）', now()) ON CONFLICT DO NOTHING;
            CONTINUE;
        END IF;
        IF v_up_cur < 3000 THEN
            INSERT INTO mart.opportunity_event (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                current_start_date, current_end_date, previous_start_date, previous_end_date, current_value, previous_value,
                relative_change, opportunity_score, opportunity_level, available_weight, status, notes, created_at)
            VALUES (p_platform_code, p_shop_name, p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                p_start_date, p_end_date, v_ps, v_pe, v_up_cur, v_up_prev, v_up_rel, 0, 'LOW', 0, 'LOW_BASE',
                '成交规模低于低基数门槛3000（小样本高增不得判机会）', now()) ON CONFLICT DO NOTHING;
            CONTINUE;
        END IF;
        -- 平台 coverage（shop 覆盖）
        IF p_domain_key = 'platform' THEN
            v_status := 'QUALIFIED';
        END IF;

        -- Peer 池：同域同 scope 的 growth 分布
        SELECT count(*), percentile_cont(0.5) WITHIN GROUP (ORDER BY rel), percentile_cont(0.75) WITHIN GROUP (ORDER BY rel)
        INTO v_peer_count, v_peer_p50, v_peer_p75
        FROM (SELECT relative_change AS rel FROM snap_rows s2 WHERE s2.metric_key='user_pay_amount'
              AND s2.scope_key IS NOT DISTINCT FROM r_ent.scope_key AND s2.relative_change IS NOT NULL) t;
        IF v_peer_count < 3 THEN
            INSERT INTO mart.opportunity_event (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                current_start_date, current_end_date, previous_start_date, previous_end_date, current_value, previous_value,
                relative_change, opportunity_score, opportunity_level, available_weight, benchmark_peer_count, status, notes, created_at)
            VALUES (p_platform_code, p_shop_name, p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                p_start_date, p_end_date, v_ps, v_pe, v_up_cur, v_up_prev, v_up_rel, 0, 'LOW', 0, v_peer_count, 'INSUFFICIENT_PEERS',
                '同域 peer 不足3个，不得说高于同行', now()) ON CONFLICT DO NOTHING;
            CONTINUE;
        END IF;

        FOR v_rule IN SELECT * FROM mart.opportunity_rule WHERE rule_code IN (
            'O01_SUSTAINED_GROWTH','O02_CONVERSION_IMPROVEMENT','O03_TRAFFIC_SCALE_OPPORTUNITY',
            'O04_HIGH_EFFICIENCY_AD_OPPORTUNITY','O05_ORGANIC_GROWTH_OPPORTUNITY','O06_HEALTHY_LOW_REFUND_GROWTH',
            'O07_CHANNEL_EXPANSION_OPPORTUNITY','O08_CATEGORY_OR_PRODUCT_LINE_OPPORTUNITY') ORDER BY rule_code
        LOOP
            -- O 类型触发条件
            v_code := v_rule.rule_code;
            v_status := 'QUALIFIED'; v_flags := '';
            IF v_code = 'O01_SUSTAINED_GROWTH' AND (v_up_rel IS NULL OR v_up_rel < v_rule.min_growth) THEN CONTINUE; END IF;
            IF v_code = 'O02_CONVERSION_IMPROVEMENT' AND (v_cvr_rel IS NULL OR v_cvr_rel <= 0 OR v_ctr_rel IS NULL OR v_ctr_rel <= 0) THEN CONTINUE; END IF;
            IF v_code = 'O03_TRAFFIC_SCALE_OPPORTUNITY' AND (v_cvr_rel IS NULL OR v_cvr_rel < 0 OR v_exp_cur IS NULL OR v_exp_cur > coalesce(v_peer_p50, 0)) THEN CONTINUE; END IF;
            IF v_code = 'O04_HIGH_EFFICIENCY_AD_OPPORTUNITY' AND (v_eff_rel IS NULL OR v_eff_rel <= 0 OR coalesce(v_spend_cur,0) < 1000) THEN CONTINUE; END IF;
            IF v_code = 'O05_ORGANIC_GROWTH_OPPORTUNITY' AND (v_up_rel IS NULL OR v_up_rel < 0.15 OR coalesce(v_spend_rel, 0) > 0.05) THEN CONTINUE; END IF;
            IF v_code = 'O06_HEALTHY_LOW_REFUND_GROWTH' AND (v_up_rel IS NULL OR v_up_rel < 0.15 OR coalesce(v_refund_rel, 0) > 0.05) THEN CONTINUE; END IF;
            IF v_code = 'O07_CHANNEL_EXPANSION_OPPORTUNITY' AND p_domain_key NOT IN ('scope','carrier','shop','platform') THEN CONTINUE; END IF;
            IF v_code = 'O07_CHANNEL_EXPANSION_OPPORTUNITY' AND (v_up_rel IS NULL OR v_up_rel < 0.15) THEN CONTINUE; END IF;
            IF v_code = 'O08_CATEGORY_OR_PRODUCT_LINE_OPPORTUNITY' AND p_domain_key NOT IN ('product_line','category') THEN CONTINUE; END IF;
            IF v_code = 'O08_CATEGORY_OR_PRODUCT_LINE_OPPORTUNITY' AND (v_up_rel IS NULL OR v_up_rel < 0.15) THEN CONTINUE; END IF;

            -- 7 维评分（0-100）
            v_score := 0; v_avail := 0;
            -- growth
            IF v_up_rel IS NOT NULL THEN
                v_score := v_score + v_rule.weight_growth * greatest(0, least(v_up_rel * 3, 1));
                v_avail := v_avail + v_rule.weight_growth;
            END IF;
            -- persistence（增长为正即满分代理）
            IF v_up_rel IS NOT NULL THEN
                v_score := v_score + v_rule.weight_persistence * (CASE WHEN v_up_rel > 0 THEN 1 ELSE 0 END);
                v_avail := v_avail + v_rule.weight_persistence;
            END IF;
            -- conversion
            IF v_cvr_rel IS NOT NULL THEN
                v_score := v_score + v_rule.weight_conversion * greatest(0, least(v_cvr_rel * 3, 1));
                v_avail := v_avail + v_rule.weight_conversion;
            END IF;
            -- refund_health
            IF v_refund_rel IS NOT NULL THEN
                v_score := v_score + v_rule.weight_refund * greatest(0, least(1 - (v_refund_rel + 0.05) * 5, 1));
                v_avail := v_avail + v_rule.weight_refund;
                IF v_refund_rel > 0.1 THEN v_flags := v_flags || 'refund_risk;'; END IF;
            END IF;
            -- ad_efficiency
            IF v_eff_rel IS NOT NULL THEN
                v_score := v_score + v_rule.weight_ad_efficiency * greatest(0, least(v_eff_rel * 2, 1));
                v_avail := v_avail + v_rule.weight_ad_efficiency;
            END IF;
            -- materiality（成交规模对数归一：10万=满分）
            v_score := v_score + v_rule.weight_materiality * least(v_up_cur / 100000, 1);
            v_avail := v_avail + v_rule.weight_materiality;
            -- contribution（域内占比）
            IF (SELECT sum(current_value) FROM snap_rows WHERE metric_key='user_pay_amount' AND scope_key IS NOT DISTINCT FROM r_ent.scope_key) > 0 THEN
                v_score := v_score + v_rule.weight_contribution * least(
                    v_up_cur / (SELECT sum(current_value) FROM snap_rows WHERE metric_key='user_pay_amount' AND scope_key IS NOT DISTINCT FROM r_ent.scope_key) * 5, 1);
                v_avail := v_avail + v_rule.weight_contribution;
            END IF;

            -- 重归一
            IF v_avail < 70 THEN
                INSERT INTO mart.opportunity_event (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                    opportunity_code, current_start_date, current_end_date, previous_start_date, previous_end_date,
                    current_value, previous_value, relative_change, opportunity_score, opportunity_level, available_weight, status, notes, created_at)
                VALUES (p_platform_code, p_shop_name, p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                    v_code, p_start_date, p_end_date, v_ps, v_pe, v_up_cur, v_up_prev, v_up_rel,
                    0, 'LOW', v_avail, 'INSUFFICIENT_EVIDENCE', '可用维度权重不足70%（缺失维度过多）', now()) ON CONFLICT DO NOTHING;
                CONTINUE;
            END IF;
            v_score := v_score / v_avail * 100;
            IF v_score >= 85 THEN v_level := 'STRONG';
            ELSIF v_score >= 70 THEN v_level := 'HIGH';
            ELSIF v_score >= 50 THEN v_level := 'MEDIUM';
            ELSE v_level := 'LOW'; END IF;

            INSERT INTO mart.opportunity_event (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
                opportunity_code, current_start_date, current_end_date, previous_start_date, previous_end_date,
                current_value, previous_value, relative_change, growth_score, conversion_score, refund_score,
                opportunity_score, opportunity_level, available_weight,
                benchmark_pool, benchmark_peer_count, benchmark_p50, benchmark_p75,
                coverage_complete, risk_flags, diagnostic_chain_id, status, notes, created_at)
            VALUES (p_platform_code, p_shop_name, p_domain_key, p_domain_key, r_ent.entity_id, r_ent.entity_name, r_ent.scope_key,
                v_code, p_start_date, p_end_date, v_ps, v_pe, v_up_cur, v_up_prev, v_up_rel,
                round(greatest(0, least(v_up_rel * 100, 100)), 2),
                round(greatest(0, least(v_cvr_rel * 100, 100)), 2),
                round(greatest(0, 1 - (coalesce(v_refund_rel, 0) + 0.05) * 5) * 100, 2),
                round(v_score, 2), v_level, round(v_avail, 2),
                '同域peer(' || p_domain_key || ')', v_peer_count, round(coalesce(v_peer_p50, 0), 4), round(coalesce(v_peer_p75, 0), 4),
                true, NULLIF(v_flags, ''), 'OP|' || p_domain_key || '|' || coalesce(r_ent.entity_name, ''),
                v_status, '机会评分=' || round(v_score, 0) || '（机会质量排序分，非未来成功概率）', now())
            ON CONFLICT DO NOTHING;
        END LOOP;
    END LOOP;

    DROP TABLE IF EXISTS snap_rows;
    RETURN (SELECT count(*)::int FROM mart.opportunity_event
            WHERE current_start_date = p_start_date AND current_end_date = p_end_date
              AND domain_key = p_domain_key AND platform_code = p_platform_code);
END;
$$;


ALTER FUNCTION mart.detect_growth_opportunities(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text) OWNER TO postgres;

--
-- Name: FUNCTION detect_growth_opportunities(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.detect_growth_opportunities(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text) IS 'V1.1 机会检测：同域 peer 分池 + 7 维评分（缺失重归一）+ O01-O08 类型判定 + 幂等。';


--
-- Name: diagnose_anomaly(bigint); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.diagnose_anomaly(p_anomaly_event_id bigint) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_ev record; v_id bigint;
BEGIN
    SELECT * INTO v_ev FROM mart.anomaly_event WHERE anomaly_event_id = p_anomaly_event_id;
    IF v_ev IS NULL THEN RAISE EXCEPTION '异常事件不存在: %', p_anomaly_event_id; END IF;
    v_id := mart.diagnose_entity(v_ev.domain_key, coalesce(v_ev.entity_name, '抖音整体'),
                                 v_ev.current_start_date, v_ev.current_end_date,
                                 v_ev.shop_name, v_ev.scope_key, p_anomaly_event_id);
    RETURN v_id;
END;
$$;


ALTER FUNCTION mart.diagnose_anomaly(p_anomaly_event_id bigint) OWNER TO postgres;

--
-- Name: FUNCTION diagnose_anomaly(p_anomaly_event_id bigint); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.diagnose_anomaly(p_anomaly_event_id bigint) IS 'V1.1 从异常事件入口生成诊断（Stage2 异常 → Stage3 定位）。';


--
-- Name: diagnose_entity(text, text, date, date, text, text, bigint); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.diagnose_entity(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text DEFAULT NULL::text, p_scope_key text DEFAULT NULL::text, p_anomaly_event_id bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_ps date; v_pe date; v_days int;
    v_up_cur numeric; v_up_prev numeric; v_up_rel numeric;
    v_exp_cur numeric; v_click_cur numeric; v_conv_cur numeric; v_refund_cur numeric;
    v_exp_rel numeric; v_click_rel numeric; v_conv_rel numeric; v_refund_rel numeric;
    v_primary text := 'unknown';
    v_diag_code text := 'D01_SALES_DECLINE';
    v_status text := 'DIAGNOSED';
    v_conf numeric := 0;
    v_neg_stages int := 0;
    v_evidence jsonb; v_path jsonb;
    v_chain text;
    v_id bigint;
    r record;
BEGIN
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RAISE EXCEPTION '非法日期区间: % ~ %', p_start_date, p_end_date;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM mart.diagnostic_entity_rule WHERE domain_key = p_domain_key AND enabled) THEN
        RAISE EXCEPTION '未知/未启用诊断域: %', p_domain_key;
    END IF;
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);

    -- 快照取该实体各指标
    FOR r IN
        SELECT metric_key, current_value, previous_value, relative_change, data_status, current_coverage_complete
        FROM mart.get_diagnostic_snapshot(p_shop_name, p_start_date, p_end_date, p_domain_key, p_scope_key,
                                          CASE WHEN p_domain_key='product_line' THEN NULL ELSE p_entity_name END,
                                          CASE WHEN p_domain_key='product_line' THEN p_entity_name ELSE NULL END,
                                          NULL)
        WHERE entity_name = p_entity_name OR entity_id = p_entity_name
    LOOP
        IF r.metric_key = 'user_pay_amount' THEN
            v_up_cur := r.current_value; v_up_prev := r.previous_value; v_up_rel := r.relative_change;
        ELSIF r.metric_key = 'product_exposure_user_count' THEN
            v_exp_cur := r.current_value; v_exp_rel := r.relative_change;
        ELSIF r.metric_key = 'product_click_user_count' THEN
            v_click_cur := r.current_value; v_click_rel := r.relative_change;
        ELSIF r.metric_key = 'transaction_buyer_count' THEN
            v_conv_cur := r.current_value; v_conv_rel := r.relative_change;
        ELSIF r.metric_key = 'refund_rate_pay_time' THEN
            v_refund_cur := r.current_value; v_refund_rel := r.relative_change;
        END IF;
    END LOOP;

    -- 无数据 → NO_CONFIRMED_ANOMALY / COVERAGE
    IF v_up_cur IS NULL AND v_up_prev IS NULL THEN
        INSERT INTO mart.diagnostic_result
            (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
             diagnostic_code, primary_stage, diagnostic_status,
             current_start_date, current_end_date, previous_start_date, previous_end_date,
             confidence_score, evidence_json, path_json, diagnostic_chain_id, source_anomaly_event_id,
             coverage_complete, mapping_complete, notes, created_at)
        VALUES
            ('douyin', p_shop_name, p_domain_key, p_domain_key, NULL, p_entity_name, p_scope_key,
             NULL, 'unknown', 'NO_CONFIRMED_ANOMALY',
             p_start_date, p_end_date, v_ps, v_pe,
             0, '{}'::jsonb, jsonb_build_array(jsonb_build_object('domain', p_domain_key, 'entity', p_entity_name)),
             NULL, p_anomaly_event_id, NULL, NULL, '无当前/上期数据，不构成可诊断异常', now())
        RETURNING diagnostic_id INTO v_id;
        RETURN v_id;
    END IF;

    -- primary_stage：最负向环节（漏斗优先）
    v_neg_stages := 0;
    IF v_exp_rel IS NOT NULL AND v_exp_rel < -0.05 THEN v_neg_stages := v_neg_stages + 1; v_primary := 'traffic'; END IF;
    IF v_click_rel IS NOT NULL AND v_click_rel < -0.05 THEN v_neg_stages := v_neg_stages + 1; IF v_primary = 'unknown' THEN v_primary := 'click'; END IF; END IF;
    IF v_conv_rel IS NOT NULL AND v_conv_rel < -0.05 THEN v_neg_stages := v_neg_stages + 1; IF v_primary = 'unknown' THEN v_primary := 'conversion'; END IF; END IF;
    IF v_refund_rel IS NOT NULL AND v_refund_rel > 0.05 THEN v_neg_stages := v_neg_stages + 1; IF v_primary = 'unknown' THEN v_primary := 'refund'; END IF; END IF;
    IF v_neg_stages >= 2 THEN
        v_status := 'MULTI_FACTOR'; v_diag_code := 'D08_MULTI_FACTOR_DECLINE';
    ELSIF v_up_rel IS NOT NULL AND v_up_rel < 0 THEN
        v_diag_code := CASE v_primary
            WHEN 'traffic' THEN 'D02_TRAFFIC_DECLINE'
            WHEN 'click' THEN 'D03_CLICK_FUNNEL_DECLINE'
            WHEN 'conversion' THEN 'D04_CONVERSION_FUNNEL_DECLINE'
            WHEN 'refund' THEN 'D05_REFUND_DETERIORATION'
            ELSE 'D01_SALES_DECLINE' END;
        IF v_primary = 'unknown' THEN v_primary := 'conversion'; END IF;
    ELSIF v_up_rel IS NOT NULL AND v_up_rel >= 0 THEN
        v_status := 'NO_CONFIRMED_ANOMALY';
    END IF;

    -- 置信度（evidence 完整度 + coverage）
    v_conf := 0;
    IF v_up_cur IS NOT NULL THEN v_conf := v_conf + 20; END IF;
    IF v_up_prev IS NOT NULL THEN v_conf := v_conf + 20; END IF;
    IF v_exp_rel IS NOT NULL THEN v_conf := v_conf + 15; END IF;
    IF v_click_rel IS NOT NULL THEN v_conf := v_conf + 15; END IF;
    IF v_conv_rel IS NOT NULL THEN v_conf := v_conf + 15; END IF;
    IF v_refund_rel IS NOT NULL THEN v_conf := v_conf + 15; END IF;

    v_chain := 'D3|' || p_domain_key || '|' || coalesce(p_entity_name, '') || '|' || p_start_date || '~' || p_end_date;
    v_evidence := jsonb_build_object(
        'current', v_up_cur, 'previous', v_up_prev, 'relative_change', v_up_rel,
        'funnel', jsonb_build_object('traffic_rel', v_exp_rel, 'click_rel', v_click_rel,
                                      'conversion_rel', v_conv_rel, 'refund_rel', v_refund_rel),
        'coverage_complete', true);
    v_path := jsonb_build_array(jsonb_build_object('domain', p_domain_key, 'entity', p_entity_name));

    INSERT INTO mart.diagnostic_result
        (platform_code, shop_name, domain_key, entity_level, entity_id, entity_name, scope_key,
         diagnostic_code, primary_stage, diagnostic_status,
         current_start_date, current_end_date, previous_start_date, previous_end_date,
         current_value, previous_value, absolute_change, relative_change,
         confidence_score, evidence_json, path_json, diagnostic_chain_id, source_anomaly_event_id,
         coverage_complete, mapping_complete, notes, created_at)
    VALUES
        ('douyin', p_shop_name, p_domain_key, p_domain_key, NULL, p_entity_name, p_scope_key,
         v_diag_code, v_primary, v_status,
         p_start_date, p_end_date, v_ps, v_pe,
         v_up_cur, v_up_prev, (v_up_cur - v_up_prev), v_up_rel,
         v_conf, v_evidence, v_path, v_chain, p_anomaly_event_id,
         true, NULL, '数据层问题定位（漏斗/贡献/投放拆解）', now())
    RETURNING diagnostic_id INTO v_id;
    RETURN v_id;
END;
$$;


ALTER FUNCTION mart.diagnose_entity(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text, p_anomaly_event_id bigint) OWNER TO postgres;

--
-- Name: FUNCTION diagnose_entity(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text, p_anomaly_event_id bigint); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.diagnose_entity(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text, p_anomaly_event_id bigint) IS 'V1.1 实体诊断主函数：快照+漏斗环节→primary_stage→diagnostic_code→置信度→证据链→diagnostic_result。
多因素(MULTI_FACTOR)不强制唯一根因；无数据→NO_CONFIRMED_ANOMALY。';


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
-- Name: generate_daily_action_items(text, date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.generate_daily_action_items(p_platform_code text, p_start_date date, p_end_date date) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_ins int := 0; v_upd int := 0;
BEGIN
    -- ========== 0. 冷却：同 dedupe 键的 OPEN 卡更新原卡（不重复生成） ==========
    UPDATE mart.daily_action_item a SET
        occurrence_count = a.occurrence_count + 1,
        last_seen_date = p_end_date,
        updated_at = now()
    FROM mart.anomaly_event e
    JOIN mart.anomaly_rule r ON r.rule_code = e.anomaly_type
    WHERE a.dedupe_group_key = e.diagnostic_chain_key || '|RISK|' || e.entity_id
      AND e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status = 'OPEN'
      AND a.status IN ('OPEN','WATCHING');

    UPDATE mart.daily_action_item a SET
        occurrence_count = a.occurrence_count + 1,
        last_seen_date = p_end_date,
        updated_at = now()
    FROM mart.opportunity_event e
    WHERE a.dedupe_group_key = e.diagnostic_chain_id || '|OPP|' || e.entity_id
      AND e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status = 'QUALIFIED'
      AND a.status IN ('OPEN','WATCHING');

    UPDATE mart.daily_action_item a SET
        occurrence_count = a.occurrence_count + 1,
        last_seen_date = p_end_date,
        updated_at = now()
    FROM mart.opportunity_event e
    WHERE a.dedupe_group_key = e.diagnostic_chain_id || '|WATCH|' || e.entity_id || '|' || e.status
      AND e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status IN ('LOW_BASE','NEW_BASE_SIGNAL','INSUFFICIENT_PEERS','INSUFFICIENT_EVIDENCE','COVERAGE_INCOMPLETE','MAPPING_INCOMPLETE')
      AND a.status IN ('OPEN','WATCHING');

    -- ========== 1. RISK：从 OPEN anomaly_event 生成 ==========
    INSERT INTO mart.daily_action_item
        (platform_code, shop_name, entity_level, domain_key, entity_id, entity_name, scope_key,
         master_product_id, product_line_id, item_type, source_anomaly_code,
         risk_priority_score, risk_level, action_category,
         current_start_date, current_end_date, business_impact, impact_source,
         coverage_complete, mapping_complete, diagnostic_chain_id, action_group_key, dedupe_group_key,
         status, first_seen_date, last_seen_date, occurrence_count, notes, created_at, updated_at)
    SELECT
        e.platform_code, e.shop_name, e.domain_key, e.domain_key, e.entity_id, e.entity_name, e.scope_key,
        CASE WHEN e.domain_key='master_product' THEN e.entity_id END AS master_product_id,
        CASE WHEN e.domain_key='product_line' THEN e.entity_id END AS product_line_id,
        'RISK', e.anomaly_type,
        -- risk_priority_score：severity30 + impact25 + persistence15 + strategic10 + confidence10 + evidence10
        round(
            e.severity_score * 0.30
            + least(e.materiality / 100000, 1) * 25
            + least(e.consecutive_day_count, 10) * 1.5
            + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
            + CASE WHEN e.coverage_complete THEN 10 ELSE 0 END
            + 10,
        2) AS risk_score,
        CASE WHEN (e.severity_score * 0.30 + least(e.materiality / 100000, 1) * 25
                   + least(e.consecutive_day_count, 10) * 1.5
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.coverage_complete THEN 10 ELSE 0 END + 10) >= 90 THEN 'P1_URGENT'
             WHEN (e.severity_score * 0.30 + least(e.materiality / 100000, 1) * 25
                   + least(e.consecutive_day_count, 10) * 1.5
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.coverage_complete THEN 10 ELSE 0 END + 10) >= 75 THEN 'P2_HIGH'
             WHEN (e.severity_score * 0.30 + least(e.materiality / 100000, 1) * 25
                   + least(e.consecutive_day_count, 10) * 1.5
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.coverage_complete THEN 10 ELSE 0 END + 10) >= 60 THEN 'P3_MEDIUM'
             ELSE 'P4_LOW' END,
        CASE e.anomaly_type
            WHEN 'A01_SALES_DROP' THEN 'CHECK_CONVERSION'
            WHEN 'A02_SALES_SPIKE' THEN 'CHECK_TRAFFIC'
            WHEN 'A03_TRAFFIC_DROP' THEN 'CHECK_TRAFFIC'
            WHEN 'A04_CLICK_RATE_DROP' THEN 'CHECK_CLICK'
            WHEN 'A05_CONVERSION_DROP' THEN 'CHECK_CONVERSION'
            WHEN 'A06_REFUND_DETERIORATION' THEN 'CHECK_REFUND'
            WHEN 'A07_AD_EFFICIENCY_DETERIORATION' THEN 'CHECK_AD_EFFICIENCY'
            WHEN 'A08_CONTRIBUTION_DROP' THEN 'CHECK_CONTRIBUTION'
            ELSE 'CHECK_TRAFFIC' END,
        e.current_start_date, e.current_end_date,
        e.materiality, 'stage2_materiality',
        e.coverage_complete, e.mapping_complete,
        e.diagnostic_chain_key, e.diagnostic_chain_key || '|RISK', e.diagnostic_chain_key || '|RISK|' || e.entity_id,
        'OPEN', e.current_start_date, e.current_end_date, 1,
        '排查方向（非已证原因）：' || r.rule_name_cn, now(), now()
    FROM mart.anomaly_event e
    JOIN mart.anomaly_rule r ON r.rule_code = e.anomaly_type
    WHERE e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status = 'OPEN'
    ON CONFLICT DO NOTHING;

    -- ========== 2. OPPORTUNITY：从 QUALIFIED opportunity_event 生成 ==========
    INSERT INTO mart.daily_action_item
        (platform_code, shop_name, entity_level, domain_key, entity_id, entity_name, scope_key,
         master_product_id, product_line_id, item_type, source_opportunity_code,
         opportunity_priority_score, opportunity_level, action_category,
         current_start_date, current_end_date, business_impact, impact_source,
         coverage_complete, mapping_complete, diagnostic_chain_id, action_group_key, dedupe_group_key,
         status, first_seen_date, last_seen_date, occurrence_count, notes, created_at, updated_at)
    SELECT
        e.platform_code, e.shop_name, e.domain_key, e.domain_key, e.entity_id, e.entity_name, e.scope_key,
        CASE WHEN e.domain_key='master_product' THEN e.entity_id END,
        CASE WHEN e.domain_key='product_line' THEN e.entity_id END,
        'OPPORTUNITY', e.opportunity_code,
        -- opportunity_priority_score：Stage4 40 + volume 20 + persistence 15 + strategic 10 + risk_safety 10 + evidence 5
        round(
            e.opportunity_score * 0.40
            + least(e.current_value / 100000, 1) * 20
            + (CASE WHEN e.relative_change > 0 THEN 15 ELSE 0 END)
            + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
            + CASE WHEN e.risk_flags IS NULL THEN 10 ELSE 2 END
            + 5,
        2) AS opp_score,
        CASE WHEN (e.opportunity_score * 0.40 + least(e.current_value / 100000, 1) * 20
                   + (CASE WHEN e.relative_change > 0 THEN 15 ELSE 0 END)
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.risk_flags IS NULL THEN 10 ELSE 2 END + 5) >= 85 THEN 'O1_STRONG'
             WHEN (e.opportunity_score * 0.40 + least(e.current_value / 100000, 1) * 20
                   + (CASE WHEN e.relative_change > 0 THEN 15 ELSE 0 END)
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.risk_flags IS NULL THEN 10 ELSE 2 END + 5) >= 70 THEN 'O2_HIGH'
             WHEN (e.opportunity_score * 0.40 + least(e.current_value / 100000, 1) * 20
                   + (CASE WHEN e.relative_change > 0 THEN 15 ELSE 0 END)
                   + (SELECT coalesce(w.strategic_weight, 1.0) * 10 FROM mart.priority_entity_weight w WHERE w.entity_level = e.domain_key)
                   + CASE WHEN e.risk_flags IS NULL THEN 10 ELSE 2 END + 5) >= 55 THEN 'O3_MEDIUM'
             ELSE 'O4_WATCH' END,
        CASE WHEN e.domain_key='product_line' THEN 'WATCH_PRODUCT_LINE_GROWTH'
             WHEN e.domain_key='category' THEN 'WATCH_CATEGORY_GROWTH'
             WHEN e.opportunity_code='O02_CONVERSION_IMPROVEMENT' THEN 'WATCH_CONVERSION_IMPROVEMENT'
             WHEN e.opportunity_code='O03_TRAFFIC_SCALE_OPPORTUNITY' THEN 'WATCH_TRAFFIC_SCALE'
             WHEN e.opportunity_code='O04_HIGH_EFFICIENCY_AD_OPPORTUNITY' THEN 'WATCH_AD_OPPORTUNITY'
             WHEN e.opportunity_code='O07_CHANNEL_EXPANSION_OPPORTUNITY' THEN 'WATCH_CHANNEL_GROWTH'
             ELSE 'WATCH_GROWTH' END,
        e.current_start_date, e.current_end_date,
        e.current_value, 'stage4_current_value',
        e.coverage_complete, e.mapping_complete,
        e.diagnostic_chain_id, e.diagnostic_chain_id || '|OPP', e.diagnostic_chain_id || '|OPP|' || e.entity_id,
        'OPEN', e.current_start_date, e.current_end_date, 1,
        '机会质量排序分（非未来成功概率）' || CASE WHEN e.risk_flags IS NOT NULL THEN '；并存风险:' || e.risk_flags ELSE '' END,
        now(), now()
    FROM mart.opportunity_event e
    WHERE e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status = 'QUALIFIED'
    ON CONFLICT DO NOTHING;

    -- ========== 3. WATCH：coverage/mapping/证据不足状态事件 ==========
    INSERT INTO mart.daily_action_item
        (platform_code, shop_name, entity_level, domain_key, entity_id, entity_name, scope_key,
         item_type, action_category, current_start_date, current_end_date,
         diagnostic_chain_id, dedupe_group_key, status, first_seen_date, last_seen_date, occurrence_count, notes, created_at, updated_at)
    SELECT e.platform_code, e.shop_name, e.domain_key, e.domain_key, e.entity_id, e.entity_name, e.scope_key,
           'WATCH', 'WATCH_GROWTH', e.current_start_date, e.current_end_date,
           e.diagnostic_chain_id, e.diagnostic_chain_id || '|WATCH|' || e.entity_id || '|' || e.status,
           'WATCHING', e.current_start_date, e.current_end_date, 1,
           '观察：' || e.status || '（' || e.notes || '）', now(), now()
    FROM mart.opportunity_event e
    WHERE e.platform_code = p_platform_code
      AND e.current_start_date = p_start_date AND e.current_end_date = p_end_date
      AND e.status IN ('LOW_BASE','NEW_BASE_SIGNAL','INSUFFICIENT_PEERS','INSUFFICIENT_EVIDENCE','COVERAGE_INCOMPLETE','MAPPING_INCOMPLETE')
    ON CONFLICT DO NOTHING;

    RETURN (SELECT count(*)::int FROM mart.daily_action_item
            WHERE current_start_date = p_start_date AND current_end_date = p_end_date AND platform_code = p_platform_code);
END;
$$;


ALTER FUNCTION mart.generate_daily_action_items(p_platform_code text, p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: FUNCTION generate_daily_action_items(p_platform_code text, p_start_date date, p_end_date date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.generate_daily_action_items(p_platform_code text, p_start_date date, p_end_date date) IS 'V1.1 每日行动生成器（后台）：消费异常/机会/观察事件 → RISK/OPPORTUNITY/WATCH 三类行动项；冷却=更新原卡；幂等。';


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
-- Name: get_advertising_diagnosis(text, text, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_advertising_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text DEFAULT NULL::text) RETURNS TABLE(metric_key text, metric_name_cn text, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, diagnostic_note text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_ps date; v_pe date; v_days int;
BEGIN
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);
    RETURN QUERY
    WITH snap AS (
        SELECT s.entity_id, s.entity_name, s.metric_key, s.current_value, s.previous_value, s.relative_change
        FROM mart.get_diagnostic_snapshot(p_shop_name, p_start_date, p_end_date, p_domain_key, NULL, NULL, p_entity_name, NULL) s
    )
    SELECT m.metric_key, r.metric_name_cn,
           m.current_value, m.previous_value,
           (m.current_value - m.previous_value) AS absolute_change,
           m.relative_change,
           CASE WHEN m.metric_key='ad_efficiency_shop_promoted' THEN '效率倍数，非百分比'
                WHEN m.metric_key='ad_spend_rate_net_refund_shop_bound' THEN '费比（剔除退款、店铺绑定）'
                ELSE '' END AS diagnostic_note
    FROM snap m
    JOIN mart.diagnostic_metric_rule r ON r.metric_key = m.metric_key
    WHERE m.metric_key IN ('ad_spend_shop_promoted','ad_spend_shop_bound','ad_attributed_transaction_amount',
                           'ad_attributed_transaction_share','ad_spend_rate_net_refund_shop_bound',
                           'total_expense_rate_net_refund_shop_bound','ad_efficiency_shop_promoted',
                           'store_efficiency_shop_promoted')
    ORDER BY m.metric_key;
END;
$$;


ALTER FUNCTION mart.get_advertising_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text) OWNER TO postgres;

--
-- Name: FUNCTION get_advertising_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_advertising_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text) IS 'V1.1 投放诊断（复用快照投放指标；平台=跨店加权，单店=原口径）。';


--
-- Name: get_advertising_period_summary(text, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_advertising_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) RETURNS TABLE(shop_name text, period_start date, period_end date, scope_key text, ad_spend_shop_promoted numeric, ad_spend_shop_bound numeric, ad_attributed_transaction_amount numeric, ad_attributed_transaction_share numeric, ad_spend_rate_net_refund_shop_bound numeric, total_expense_rate_net_refund_shop_bound numeric, ad_efficiency_shop_promoted numeric, ad_efficiency_shop_bound numeric, store_efficiency_shop_promoted numeric, store_efficiency_shop_bound numeric, expected_days integer, coverage_days integer, coverage_complete boolean, calculation_notes text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
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
$$;


ALTER FUNCTION mart.get_advertising_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) OWNER TO postgres;

--
-- Name: FUNCTION get_advertising_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_advertising_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) IS 'V1.0.1 投放经营汇总：一次返回10项投放指标+coverage。仅ad_period=不限参与；综合费比/效率为加权源比率，禁止AVG。';


--
-- Name: get_anomalies(text, date, date, text, text, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_anomalies(p_platform_code text DEFAULT 'douyin'::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_domain_key text DEFAULT NULL::text, p_entity_name text DEFAULT NULL::text, p_severity text DEFAULT NULL::text, p_status text DEFAULT 'OPEN'::text) RETURNS TABLE(platform_code text, shop_name text, domain_key text, entity_level text, entity_id text, entity_name text, scope_key text, metric_key text, anomaly_type text, anomaly_name_cn text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, triggered_period_count integer, consecutive_day_count integer, severity text, severity_score numeric, coverage_complete boolean, shop_coverage_complete boolean, mapping_complete boolean, materiality numeric, diagnostic_chain_key text, status text, created_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT e.platform_code, e.shop_name, e.domain_key, e.entity_level,
           e.entity_id, e.entity_name, e.scope_key,
           e.metric_key, e.anomaly_type, r.rule_name_cn,
           e.current_start_date, e.current_end_date,
           e.previous_start_date, e.previous_end_date,
           e.current_value, e.previous_value,
           e.absolute_change, e.relative_change, e.percentage_point_change,
           e.triggered_period_count, e.consecutive_day_count,
           e.severity, e.severity_score,
           e.coverage_complete, e.shop_coverage_complete, e.mapping_complete,
           e.materiality, e.diagnostic_chain_key, e.status, e.created_at
    FROM mart.anomaly_event e
    JOIN mart.anomaly_rule r ON r.rule_code = e.anomaly_type
    WHERE e.platform_code = p_platform_code
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
      AND (p_domain_key IS NULL OR e.domain_key = p_domain_key)
      AND (p_entity_name IS NULL OR e.entity_name = p_entity_name)
      AND (p_severity IS NULL OR e.severity = p_severity)
      AND (p_status IS NULL OR e.status = p_status)
    ORDER BY e.severity_score DESC, e.current_end_date DESC;
$$;


ALTER FUNCTION mart.get_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_entity_name text, p_severity text, p_status text) OWNER TO postgres;

--
-- Name: FUNCTION get_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_entity_name text, p_severity text, p_status text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_entity_name text, p_severity text, p_status text) IS 'V1.1 异常查询（按平台/区间/域/实体/严重度/状态过滤）。';


--
-- Name: get_anomaly_summary(text, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_anomaly_summary(p_platform_code text DEFAULT 'douyin'::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_status text DEFAULT 'OPEN'::text) RETURNS TABLE(domain_key text, anomaly_type text, anomaly_name_cn text, event_count bigint, severity text, total_materiality numeric, avg_relative_change numeric)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT e.domain_key, e.anomaly_type, r.rule_name_cn,
           count(*)::bigint AS event_count,
           max(e.severity) AS severity,
           sum(e.materiality) AS total_materiality,
           avg(e.relative_change) AS avg_relative_change
    FROM mart.anomaly_event e
    JOIN mart.anomaly_rule r ON r.rule_code = e.anomaly_type
    WHERE e.platform_code = p_platform_code
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
      AND (p_status IS NULL OR e.status = p_status)
    GROUP BY e.domain_key, e.anomaly_type, r.rule_name_cn
    ORDER BY event_count DESC;
$$;


ALTER FUNCTION mart.get_anomaly_summary(p_platform_code text, p_start_date date, p_end_date date, p_status text) OWNER TO postgres;

--
-- Name: FUNCTION get_anomaly_summary(p_platform_code text, p_start_date date, p_end_date date, p_status text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_anomaly_summary(p_platform_code text, p_start_date date, p_end_date date, p_status text) IS 'V1.1 异常汇总（按域×类型统计事件数/严重度/影响额）。';


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

CREATE FUNCTION mart.get_business_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) RETURNS TABLE(shop_name text, start_date date, end_date date, expected_days integer, coverage_days integer, coverage_complete boolean, scope_key text, sale_scope text, carrier_type text, ad_period text, source_row_count bigint, user_pay_amount numeric, net_user_pay_amount_pay_time numeric, smart_coupon_amount numeric, net_smart_coupon_amount_pay_time numeric, platform_subsidy_amount numeric, transaction_order_count bigint, transaction_buyer_count bigint, avg_customer_amount numeric, transaction_amount numeric, net_transaction_amount numeric, refund_amount_refund_time numeric, transaction_refund_amount_refund_time numeric, refund_order_count_refund_time bigint, refund_rate_pay_time numeric, refund_amount_pay_time numeric, transaction_refund_amount_pay_time numeric, refund_order_count_pay_time bigint, product_exposure_user_count bigint, product_click_user_count bigint, exposure_to_click_rate_users numeric, click_to_transaction_rate_users numeric, exposure_to_transaction_rate_users numeric, user_pay_amount_per_1000_exposures numeric, product_exposure_count bigint, product_click_count bigint, exposure_to_click_rate_events numeric, click_to_transaction_rate_events numeric, exposure_to_transaction_rate_events numeric, shipped_user_pay_amount_ship_time numeric, ship_within_2_days_rate numeric, settlement_amount numeric, settlement_amount_refund_time numeric, settlement_amount_7d numeric, settlement_amount_14d numeric, net_creator_subsidy_amount_pay_time numeric, creator_subsidy_amount numeric, presale_deposit_amount numeric, transaction_item_count bigint, avg_item_amount numeric, net_transaction_order_count bigint, pre_shipment_refund_rate_pay_time numeric, unreceived_refund_rate_pay_time numeric, received_refund_rate_pay_time numeric, received_return_refund_rate_pay_time numeric, one_hour_transaction_refund_amount_pay_time numeric, one_hour_refund_order_count_pay_time bigint, one_hour_refund_rate_pay_time numeric, net_platform_subsidy_amount_pay_time numeric, ad_spend_shop_promoted numeric, ad_spend_shop_bound numeric, ad_attributed_transaction_amount numeric, ad_attributed_transaction_share numeric, ad_spend_rate_net_refund_shop_bound numeric, total_expense_rate_net_refund_shop_bound numeric, ad_efficiency_shop_promoted numeric, ad_efficiency_shop_bound numeric, store_efficiency_shop_promoted numeric, store_efficiency_shop_bound numeric, unrecalculable_metrics text[])
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
$$;


ALTER FUNCTION mart.get_business_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) OWNER TO postgres;

--
-- Name: get_business_report(date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_business_report(p_start_date date, p_end_date date) RETURNS TABLE(section text, business_type text, user_pay_amount numeric, refund_amount numeric, settlement_amount numeric, refund_rate numeric, ad_spend numeric, ad_fee_rate numeric, ad_bound numeric)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_min_date date;
    v_max_date date;
BEGIN
    -- ---------- 周期校验 ----------
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION 'p_start_date / p_end_date 不能为空';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'p_start_date(%) 不能晚于 p_end_date(%)', p_start_date, p_end_date;
    END IF;
    SELECT min(biz_date), max(biz_date) INTO v_min_date, v_max_date FROM core.douyin_deal_daily;
    IF p_start_date < v_min_date OR p_end_date > v_max_date THEN
        RAISE EXCEPTION '区间 % ~ % 超出数据覆盖范围(% ~ %)', p_start_date, p_end_date, v_min_date, v_max_date;
    END IF;

    RETURN QUERY
    WITH filtered AS (
        SELECT d.shop_id,
               d.biz_date,
               CASE
                   WHEN d.sale_scope = '全部' AND d.carrier_type = '全部'
                       THEN '整体'
                   WHEN d.sale_scope = '自营' AND d.carrier_type = '直播'
                       THEN '自营直播'
                   WHEN d.sale_scope = '自营' AND d.carrier_type IN ('短视频','商品卡','其他','图文')
                       THEN '自营商品'
                   WHEN d.sale_scope = '合作' AND d.carrier_type = '直播'
                       THEN '达人直播'
                   WHEN d.sale_scope = '合作' AND d.carrier_type IN ('短视频','图文')
                       THEN '达人短视频'
                   WHEN d.sale_scope = '合作' AND d.carrier_type IN ('商品卡','其他')
                       THEN '橱窗'
                   ELSE NULL
               END AS biz_type,
               d.user_pay_amount       AS f_user_pay,
               d.refund_amount_pay_time AS f_refund,
               d.settlement_amount      AS f_settlement,
               d.ad_spend_shop_promoted AS f_ad_spend,
               d.ad_spend_shop_bound    AS f_ad_bound
        FROM core.douyin_deal_daily d
        WHERE d.biz_date BETWEEN p_start_date AND p_end_date
          AND d.ad_period = '不限'
          AND (   (d.sale_scope = '全部' AND d.carrier_type = '全部')     -- 整体行
               OR (d.sale_scope <> '全部' AND d.carrier_type <> '全部'))  -- 经营类型明细行
    ),
    agg AS (
        -- 抖音整体：跨两店合计
        SELECT NULL::bigint AS shop_id,
               biz_type,
               round(sum(f_user_pay), 2)                                   AS user_pay_amount,
               round(sum(f_refund), 2)                                     AS refund_amount,
               round(sum(f_settlement), 2)                                 AS settlement_amount,
               round(sum(f_refund) / NULLIF(sum(f_user_pay), 0), 10)       AS refund_rate,
               round(sum(f_ad_spend), 2)                                   AS ad_spend,
               round(sum(f_ad_bound) / NULLIF(sum(f_settlement), 0), 10)   AS ad_fee_rate,
               round(sum(f_ad_bound), 2)                                   AS ad_bound
        FROM filtered
        WHERE biz_type IS NOT NULL
        GROUP BY biz_type
        UNION ALL
        -- 单店板块
        SELECT shop_id,
               biz_type,
               round(sum(f_user_pay), 2),
               round(sum(f_refund), 2),
               round(sum(f_settlement), 2),
               round(sum(f_refund) / NULLIF(sum(f_user_pay), 0), 10),
               round(sum(f_ad_spend), 2),
               round(sum(f_ad_bound) / NULLIF(sum(f_settlement), 0), 10),
               round(sum(f_ad_bound), 2)
        FROM filtered
        WHERE biz_type IS NOT NULL
          AND shop_id IS NOT NULL
        GROUP BY shop_id, biz_type
    ),
    template AS (
        SELECT * FROM (VALUES
            -- 板块一 抖音整体（shop_id=NULL = 跨店合计）
            (1, 1, '抖音整体',                '抖音整体',                NULL::bigint, '整体'),
            (1, 2, '抖音整体',                '自营直播',                NULL,         '自营直播'),
            (1, 3, '抖音整体',                '自营商品',                NULL,         '自营商品'),
            (1, 4, '抖音整体',                '达人直播',                NULL,         '达人直播'),
            (1, 5, '抖音整体',                '达人短视频',              NULL,         '达人短视频'),
            (1, 6, '抖音整体',                '橱窗',                    NULL,         '橱窗'),
            -- 板块二 抖音弹动官方旗舰店（shop_id=1）
            (2, 1, '抖音弹动官方旗舰店',     '抖音弹动官方旗舰店',      1::bigint,    '整体'),
            (2, 2, '抖音弹动官方旗舰店',     '自营直播',                1,            '自营直播'),
            (2, 3, '抖音弹动官方旗舰店',     '自营商品',                1,            '自营商品'),
            (2, 4, '抖音弹动官方旗舰店',     '达人直播',                1,            '达人直播'),
            (2, 5, '抖音弹动官方旗舰店',     '达人短视频',              1,            '达人短视频'),
            (2, 6, '抖音弹动官方旗舰店',     '橱窗',                    1,            '橱窗'),
            -- 板块三 抖音弹动个人护理旗舰店（shop_id=2）
            (3, 1, '抖音弹动个人护理旗舰店', '抖音弹动个人护理旗舰店',  2::bigint,    '整体'),
            (3, 2, '抖音弹动个人护理旗舰店', '自营直播',                2,            '自营直播'),
            (3, 3, '抖音弹动个人护理旗舰店', '自营商品',                2,            '自营商品'),
            (3, 4, '抖音弹动个人护理旗舰店', '达人直播',                2,            '达人直播'),
            (3, 5, '抖音弹动个人护理旗舰店', '达人短视频',              2,            '达人短视频'),
            (3, 6, '抖音弹动个人护理旗舰店', '橱窗',                    2,            '橱窗')
        ) AS t(section_seq, row_seq, section, business_type, filter_shop_id, biz_type)
    )
    SELECT t.section,
           t.business_type,
           COALESCE(a.user_pay_amount, 0),
           COALESCE(a.refund_amount, 0),
           COALESCE(a.settlement_amount, 0),
           a.refund_rate,
           COALESCE(a.ad_spend, 0),
           a.ad_fee_rate,
           COALESCE(a.ad_bound, 0)
    FROM template t
    LEFT JOIN agg a
           ON a.biz_type = t.biz_type
          AND a.shop_id IS NOT DISTINCT FROM t.filter_shop_id
    ORDER BY t.section_seq, t.row_seq;
END;
$$;


ALTER FUNCTION mart.get_business_report(p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: FUNCTION get_business_report(p_start_date date, p_end_date date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_business_report(p_start_date date, p_end_date date) IS '抖音日报/周报数据模板 V1.0 报表：三板块(抖音整体/抖音弹动官方旗舰店/抖音弹动个人护理旗舰店)×六行(整体/自营直播/自营商品/达人直播/达人短视频/橱窗)。
指标：成交金额=SUM(user_pay_amount)、成交退款金额=SUM(refund_amount_pay_time)、结算金额=SUM(settlement_amount)、
退款率=退款金额/成交金额、投放消耗=SUM(ad_spend_shop_promoted)、投放费比=SUM(ad_spend_shop_bound)/SUM(settlement_amount)。
防重口径：仅取 ad_period=不限(平台汇总行)。比率返回小数。无利润计算。';


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
-- Name: get_daily_action_list(text, date, date, text, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_daily_action_list(p_platform_code text DEFAULT 'douyin'::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_item_type text DEFAULT NULL::text, p_limit integer DEFAULT 20) RETURNS TABLE(action_item_id bigint, shop_name text, entity_level text, entity_name text, scope_key text, item_type text, source_anomaly_code text, source_opportunity_code text, risk_priority_score numeric, opportunity_priority_score numeric, risk_level text, opportunity_level text, action_category text, business_impact numeric, occurrence_count integer, diagnostic_chain_id text, status text, notes text, last_seen_date date)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT a.action_item_id, a.shop_name, a.entity_level, a.entity_name, a.scope_key,
           a.item_type, a.source_anomaly_code, a.source_opportunity_code,
           a.risk_priority_score, a.opportunity_priority_score,
           a.risk_level, a.opportunity_level, a.action_category,
           a.business_impact, a.occurrence_count,
           a.diagnostic_chain_id, a.status, a.notes, a.last_seen_date
    FROM mart.daily_action_item a
    WHERE a.platform_code = p_platform_code
      AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR a.current_end_date = p_end_date)
      AND (p_item_type IS NULL OR a.item_type = p_item_type)
    ORDER BY coalesce(a.risk_priority_score, a.opportunity_priority_score) DESC NULLS LAST
    LIMIT p_limit;
$$;


ALTER FUNCTION mart.get_daily_action_list(p_platform_code text, p_start_date date, p_end_date date, p_item_type text, p_limit integer) OWNER TO postgres;

--
-- Name: get_daily_business_brief(text, date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_daily_business_brief(p_platform_code text DEFAULT 'douyin'::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date) RETURNS TABLE(brief_type text, item_type text, entity_level text, entity_name text, priority_score numeric, level text, action_category text, business_impact numeric, notes text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    (SELECT 'TOP5_RISK'::text AS brief_type, a.item_type, a.entity_level, a.entity_name,
            a.risk_priority_score, a.risk_level, a.action_category, a.business_impact, a.notes
     FROM mart.daily_action_item a
     WHERE a.platform_code = p_platform_code AND a.item_type='RISK'
       AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
       AND (p_end_date IS NULL OR a.current_end_date = p_end_date) AND a.status='OPEN'
     ORDER BY a.risk_priority_score DESC NULLS LAST LIMIT 5)
    UNION ALL
    (SELECT 'TOP5_OPPORTUNITY', a.item_type, a.entity_level, a.entity_name,
            a.opportunity_priority_score, a.opportunity_level, a.action_category, a.business_impact, a.notes
     FROM mart.daily_action_item a
     WHERE a.platform_code = p_platform_code AND a.item_type='OPPORTUNITY'
       AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
       AND (p_end_date IS NULL OR a.current_end_date = p_end_date) AND a.status='OPEN'
     ORDER BY a.opportunity_priority_score DESC NULLS LAST LIMIT 5)
    UNION ALL
    (SELECT 'TOP5_WATCH', a.item_type, a.entity_level, a.entity_name,
            NULL::numeric, NULL::text, a.action_category, a.business_impact, a.notes
     FROM mart.daily_action_item a
     WHERE a.platform_code = p_platform_code AND a.item_type='WATCH'
       AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
       AND (p_end_date IS NULL OR a.current_end_date = p_end_date)
     ORDER BY a.last_seen_date DESC LIMIT 5);
$$;


ALTER FUNCTION mart.get_daily_business_brief(p_platform_code text, p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: get_daily_opportunity_priorities(text, date, date, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_daily_opportunity_priorities(p_platform_code text DEFAULT 'douyin'::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_limit integer DEFAULT 5) RETURNS TABLE(action_item_id bigint, shop_name text, entity_level text, entity_id text, entity_name text, source_opportunity_code text, opportunity_priority_score numeric, opportunity_level text, action_category text, business_impact numeric, occurrence_count integer, diagnostic_chain_id text, coverage_complete boolean, status text, notes text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT t.action_item_id, t.shop_name, t.entity_level, t.entity_id, t.entity_name,
           t.source_opportunity_code, t.opportunity_priority_score, t.opportunity_level,
           t.action_category, t.business_impact, t.occurrence_count,
           t.diagnostic_chain_id, t.coverage_complete, t.status, t.notes
    FROM (
        SELECT DISTINCT ON (a.entity_id, a.scope_key)
               a.action_item_id, a.shop_name, a.entity_level, a.entity_id, a.entity_name,
               a.source_opportunity_code, a.opportunity_priority_score, a.opportunity_level,
               a.action_category, a.business_impact, a.occurrence_count,
               a.diagnostic_chain_id, a.coverage_complete, a.status, a.notes
        FROM mart.daily_action_item a
        WHERE a.platform_code = p_platform_code AND a.item_type = 'OPPORTUNITY'
          AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
          AND (p_end_date IS NULL OR a.current_end_date = p_end_date)
          AND a.status IN ('OPEN','WATCHING')
        ORDER BY a.entity_id, a.scope_key, a.opportunity_priority_score DESC NULLS LAST
    ) t
    ORDER BY t.opportunity_priority_score DESC NULLS LAST
    LIMIT p_limit;
$$;


ALTER FUNCTION mart.get_daily_opportunity_priorities(p_platform_code text, p_start_date date, p_end_date date, p_limit integer) OWNER TO postgres;

--
-- Name: get_daily_risk_priorities(text, date, date, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_daily_risk_priorities(p_platform_code text DEFAULT 'douyin'::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_limit integer DEFAULT 5) RETURNS TABLE(action_item_id bigint, shop_name text, entity_level text, entity_id text, entity_name text, source_anomaly_code text, risk_priority_score numeric, risk_level text, action_category text, business_impact numeric, occurrence_count integer, diagnostic_chain_id text, coverage_complete boolean, status text, notes text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT t.action_item_id, t.shop_name, t.entity_level, t.entity_id, t.entity_name,
           t.source_anomaly_code, t.risk_priority_score, t.risk_level,
           t.action_category, t.business_impact, t.occurrence_count,
           t.diagnostic_chain_id, t.coverage_complete, t.status, t.notes
    FROM (
        SELECT DISTINCT ON (a.entity_id, a.scope_key)
               a.action_item_id, a.shop_name, a.entity_level, a.entity_id, a.entity_name,
               a.source_anomaly_code, a.risk_priority_score, a.risk_level,
               a.action_category, a.business_impact, a.occurrence_count,
               a.diagnostic_chain_id, a.coverage_complete, a.status, a.notes
        FROM mart.daily_action_item a
        WHERE a.platform_code = p_platform_code AND a.item_type = 'RISK'
          AND (p_start_date IS NULL OR a.current_start_date = p_start_date)
          AND (p_end_date IS NULL OR a.current_end_date = p_end_date)
          AND a.status IN ('OPEN','WATCHING')
        ORDER BY a.entity_id, a.scope_key, a.risk_priority_score DESC NULLS LAST
    ) t
    ORDER BY t.risk_priority_score DESC NULLS LAST
    LIMIT p_limit;
$$;


ALTER FUNCTION mart.get_daily_risk_priorities(p_platform_code text, p_start_date date, p_end_date date, p_limit integer) OWNER TO postgres;

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
-- Name: get_diagnostic_entity_metrics(text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_diagnostic_entity_metrics(p_domain_key text) RETURNS TABLE(domain_key text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, diagnostic_enabled boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    WITH domain_support AS (
        SELECT 'shop' AS dk, metric_key FROM mart.diagnostic_metric_rule WHERE diagnostic_enabled
        UNION ALL SELECT 'scope', metric_key FROM mart.diagnostic_metric_rule WHERE diagnostic_enabled
        UNION ALL SELECT 'platform', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','transaction_amount','settlement_amount','refund_amount_pay_time','refund_rate_pay_time',
                                 'transaction_order_count','transaction_buyer_count','transaction_item_count',
                                 'ad_spend_shop_promoted','ad_spend_shop_bound','ad_attributed_transaction_amount',
                                 'ad_attributed_transaction_share','ad_spend_rate_net_refund_shop_bound',
                                 'total_expense_rate_net_refund_shop_bound','ad_efficiency_shop_promoted','store_efficiency_shop_promoted')
        UNION ALL SELECT 'product', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
        UNION ALL SELECT 'shop_product', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
        UNION ALL SELECT 'master_product', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
        UNION ALL SELECT 'product_line', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
        UNION ALL SELECT 'carrier', metric_key FROM mart.diagnostic_metric_rule WHERE diagnostic_enabled
            AND metric_key NOT IN ('ad_efficiency_shop_promoted','ad_efficiency_shop_bound',
                                   'store_efficiency_shop_promoted','store_efficiency_shop_bound')
        UNION ALL SELECT 'account', metric_key FROM mart.diagnostic_metric_rule WHERE diagnostic_enabled
            AND metric_key NOT IN ('ad_efficiency_shop_promoted','ad_efficiency_shop_bound',
                                   'store_efficiency_shop_promoted','store_efficiency_shop_bound')
        UNION ALL SELECT 'category', metric_key FROM mart.diagnostic_metric_rule
            WHERE metric_key IN ('user_pay_amount','refund_amount_pay_time','refund_rate_pay_time')
    )
    SELECT ds.dk AS domain_key, m.metric_key, m.metric_name_cn, m.metric_group,
           m.metric_type, m.display_format, m.diagnostic_enabled
    FROM domain_support ds
    JOIN mart.diagnostic_metric_rule m ON m.metric_key = ds.metric_key
    WHERE ds.dk = p_domain_key
    ORDER BY m.metric_group, m.metric_key;
$$;


ALTER FUNCTION mart.get_diagnostic_entity_metrics(p_domain_key text) OWNER TO postgres;

--
-- Name: get_diagnostic_result(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_diagnostic_result(p_platform_code text DEFAULT 'douyin'::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_domain_key text DEFAULT NULL::text, p_status text DEFAULT NULL::text) RETURNS TABLE(diagnostic_id bigint, platform_code text, shop_name text, domain_key text, entity_level text, entity_name text, scope_key text, diagnostic_code text, diagnostic_name_cn text, primary_stage text, diagnostic_status text, current_start_date date, current_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, confidence_score numeric, evidence_json jsonb, path_json jsonb, diagnostic_chain_id text, coverage_complete boolean, mapping_complete boolean, created_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT d.diagnostic_id, d.platform_code, d.shop_name, d.domain_key, d.entity_level,
           d.entity_name, d.scope_key, d.diagnostic_code, t.diagnostic_name_cn,
           d.primary_stage, d.diagnostic_status,
           d.current_start_date, d.current_end_date,
           d.current_value, d.previous_value, d.absolute_change, d.relative_change,
           d.confidence_score, d.evidence_json, d.path_json, d.diagnostic_chain_id,
           d.coverage_complete, d.mapping_complete, d.created_at
    FROM mart.diagnostic_result d
    LEFT JOIN mart.diagnostic_type t ON t.diagnostic_code = d.diagnostic_code
    WHERE d.platform_code = p_platform_code
      AND (p_start_date IS NULL OR d.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR d.current_end_date = p_end_date)
      AND (p_domain_key IS NULL OR d.domain_key = p_domain_key)
      AND (p_status IS NULL OR d.diagnostic_status = p_status)
    ORDER BY d.diagnostic_id DESC;
$$;


ALTER FUNCTION mart.get_diagnostic_result(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_status text) OWNER TO postgres;

--
-- Name: get_diagnostic_snapshot(text, date, date, text, text, text, text, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_diagnostic_snapshot(p_shop_name text, p_start_date date, p_end_date date, p_domain_key text, p_scope_key text DEFAULT NULL::text, p_entity_id text DEFAULT NULL::text, p_entity_name text DEFAULT NULL::text, p_category_level integer DEFAULT NULL::integer) RETURNS TABLE(shop_name text, domain_key text, domain_name_cn text, entity_id text, entity_name text, scope_key text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, current_rank bigint, previous_rank bigint, rank_change bigint, current_contribution numeric, previous_contribution numeric, contribution_change numeric, contribution_denominator_type text, contribution_denominator_value numeric, current_coverage_days integer, expected_current_days integer, previous_coverage_days integer, expected_previous_days integer, current_coverage_complete boolean, previous_coverage_complete boolean, calculation_status text, data_status text, notes text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_domain_name text; v_enabled boolean;
    v_cs date; v_ce date; v_ps date; v_pe date; v_days integer;
BEGIN
    -- 店铺校验
    IF p_shop_name IS NOT NULL AND NOT EXISTS (SELECT 1 FROM meta.shop s WHERE s.shop_name = p_shop_name) THEN
        RAISE EXCEPTION '未知店铺: %', p_shop_name;
    END IF;
    -- 日期校验
    IF p_start_date IS NULL OR p_end_date IS NULL OR p_start_date > p_end_date THEN
        RAISE EXCEPTION '非法日期区间: % ~ %', p_start_date, p_end_date;
    END IF;
    -- 域校验
    SELECT r.domain_name_cn, r.enabled INTO v_domain_name, v_enabled
    FROM mart.diagnostic_entity_rule r WHERE r.domain_key = p_domain_key;
    IF v_domain_name IS NULL THEN RAISE EXCEPTION '未知诊断域: %', p_domain_key; END IF;
    IF NOT v_enabled THEN RAISE EXCEPTION '诊断域 % 未启用', p_domain_key; END IF;
    -- 周期（等长前置）
    v_ce := p_end_date; v_cs := p_start_date;
    v_days := (v_ce - v_cs) + 1;
    v_pe := v_cs - 1;
    v_ps := v_pe - (v_days - 1);

    IF p_domain_key = 'shop' THEN
        RETURN QUERY SELECT * FROM mart._diag_shop(p_shop_name, v_cs, v_ce, v_ps, v_pe);
    ELSIF p_domain_key = 'scope' THEN
        RETURN QUERY SELECT * FROM mart._diag_scope(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_scope_key);
    ELSIF p_domain_key IN ('product','shop_product') THEN
        RETURN QUERY SELECT * FROM mart._diag_product(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_entity_id, p_entity_name);
    ELSIF p_domain_key = 'master_product' THEN
        RETURN QUERY SELECT * FROM mart._diag_master_product(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_entity_id, p_entity_name);
    ELSIF p_domain_key = 'product_line' THEN
        RETURN QUERY SELECT * FROM mart._diag_product_line(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_entity_name);
    ELSIF p_domain_key = 'carrier' THEN
        RETURN QUERY SELECT * FROM mart._diag_carrier(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_scope_key);
    ELSIF p_domain_key = 'account' THEN
        RETURN QUERY SELECT * FROM mart._diag_account(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_scope_key);
    ELSIF p_domain_key = 'category' THEN
        RETURN QUERY SELECT * FROM mart._diag_category(p_shop_name, v_cs, v_ce, v_ps, v_pe, p_category_level);
    ELSE
        RAISE EXCEPTION '诊断域 % 不支持', p_domain_key;
    END IF;
END;
$$;


ALTER FUNCTION mart.get_diagnostic_snapshot(p_shop_name text, p_start_date date, p_end_date date, p_domain_key text, p_scope_key text, p_entity_id text, p_entity_name text, p_category_level integer) OWNER TO postgres;

--
-- Name: FUNCTION get_diagnostic_snapshot(p_shop_name text, p_start_date date, p_end_date date, p_domain_key text, p_scope_key text, p_entity_id text, p_entity_name text, p_category_level integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_diagnostic_snapshot(p_shop_name text, p_start_date date, p_end_date date, p_domain_key text, p_scope_key text, p_entity_id text, p_entity_name text, p_category_level integer) IS 'V1.1 统一诊断快照（SECURITY DEFINER，固定 search_path；agent_readonly 可执行；内部 _diag_* 不对外）。';


--
-- Name: get_diagnostic_supported_metrics(); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_diagnostic_supported_metrics() RETURNS TABLE(metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, cross_period_recalculable boolean, diagnostic_enabled boolean, higher_is_better boolean, supports_percentage_point boolean, supports_rank boolean, supports_contribution boolean, source_rule_reference text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT metric_key, metric_name_cn, metric_group, metric_type, display_format,
           cross_period_recalculable, diagnostic_enabled, higher_is_better,
           supports_percentage_point, supports_rank, supports_contribution,
           source_rule_reference
    FROM mart.diagnostic_metric_rule
    ORDER BY metric_group, metric_key;
$$;


ALTER FUNCTION mart.get_diagnostic_supported_metrics() OWNER TO postgres;

--
-- Name: FUNCTION get_diagnostic_supported_metrics(); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_diagnostic_supported_metrics() IS 'V1.1 支持的诊断指标目录（全部已注册且 diagnostic_enabled=true 的指标）。';


--
-- Name: get_entity_anomalies(text, text, text, date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_entity_anomalies(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date) RETURNS TABLE(platform_code text, shop_name text, domain_key text, entity_level text, entity_id text, entity_name text, scope_key text, metric_key text, anomaly_type text, anomaly_name_cn text, current_start_date date, current_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, triggered_period_count integer, consecutive_day_count integer, severity text, severity_score numeric, coverage_complete boolean, shop_coverage_complete boolean, mapping_complete boolean, materiality numeric, status text, created_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT e.platform_code, e.shop_name, e.domain_key, e.entity_level,
           e.entity_id, e.entity_name, e.scope_key,
           e.metric_key, e.anomaly_type, r.rule_name_cn,
           e.current_start_date, e.current_end_date,
           e.current_value, e.previous_value,
           e.absolute_change, e.relative_change, e.percentage_point_change,
           e.triggered_period_count, e.consecutive_day_count,
           e.severity, e.severity_score,
           e.coverage_complete, e.shop_coverage_complete, e.mapping_complete,
           e.materiality, e.status, e.created_at
    FROM mart.anomaly_event e
    JOIN mart.anomaly_rule r ON r.rule_code = e.anomaly_type
    WHERE e.platform_code = p_platform_code
      AND e.domain_key = p_domain_key
      AND e.entity_name = p_entity_name
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
    ORDER BY e.severity_score DESC;
$$;


ALTER FUNCTION mart.get_entity_anomalies(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: FUNCTION get_entity_anomalies(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_entity_anomalies(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date) IS 'V1.1 单实体异常查询（域+实体名过滤）。';


--
-- Name: get_entity_opportunity(text, text, text, date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_entity_opportunity(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date) RETURNS TABLE(platform_code text, shop_name text, domain_key text, entity_level text, entity_name text, scope_key text, opportunity_code text, opportunity_name_cn text, current_start_date date, current_end_date date, current_value numeric, previous_value numeric, relative_change numeric, opportunity_score numeric, opportunity_level text, available_weight numeric, benchmark_peer_count integer, benchmark_p50 numeric, benchmark_p75 numeric, coverage_complete boolean, risk_flags text, status text, created_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT e.platform_code, e.shop_name, e.domain_key, e.entity_level,
           e.entity_name, e.scope_key, e.opportunity_code, t.opportunity_name_cn,
           e.current_start_date, e.current_end_date,
           e.current_value, e.previous_value, e.relative_change,
           e.opportunity_score, e.opportunity_level, e.available_weight,
           e.benchmark_peer_count, e.benchmark_p50, e.benchmark_p75,
           e.coverage_complete, e.risk_flags, e.status, e.created_at
    FROM mart.opportunity_event e
    JOIN mart.opportunity_type t ON t.opportunity_code = e.opportunity_code
    WHERE e.platform_code = p_platform_code
      AND e.domain_key = p_domain_key
      AND e.entity_name = p_entity_name
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
    ORDER BY e.opportunity_score DESC;
$$;


ALTER FUNCTION mart.get_entity_opportunity(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: FUNCTION get_entity_opportunity(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_entity_opportunity(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date) IS 'V1.1 单实体机会（域+实体名过滤）。';


--
-- Name: get_funnel_diagnosis(text, text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_funnel_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text DEFAULT NULL::text, p_scope_key text DEFAULT NULL::text) RETURNS TABLE(stage text, metric_key text, metric_name_cn text, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, contribution_share numeric, primary_stage text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_ps date; v_pe date; v_days int;
BEGIN
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);
    RETURN QUERY
    WITH snap AS (
        SELECT s.entity_id, s.entity_name, s.metric_key, s.current_value, s.previous_value,
               s.relative_change, s.data_status
        FROM mart.get_diagnostic_snapshot(p_shop_name, p_start_date, p_end_date, p_domain_key, p_scope_key,
                                          CASE WHEN p_domain_key='product_line' THEN NULL ELSE p_entity_name END,
                                          CASE WHEN p_domain_key='product_line' THEN p_entity_name ELSE NULL END,
                                          NULL) s
    ),
    sel AS (
        SELECT * FROM snap WHERE entity_name = p_entity_name OR entity_id = p_entity_name
    )
    SELECT
        CASE m.metric_key
            WHEN 'product_exposure_user_count' THEN 'traffic'
            WHEN 'product_click_user_count' THEN 'click'
            WHEN 'transaction_buyer_count' THEN 'conversion'
            WHEN 'refund_rate_pay_time' THEN 'refund'
            ELSE 'other' END AS stage,
        m.metric_key, r.metric_name_cn,
        m.current_value, m.previous_value,
        (m.current_value - m.previous_value) AS absolute_change,
        m.relative_change,
        CASE WHEN m.metric_key='product_exposure_user_count' THEN 1.0
             WHEN m.metric_key='product_click_user_count' THEN
                (SELECT c.current_value FROM sel c WHERE c.metric_key='product_click_user_count')
                / NULLIF((SELECT e.current_value FROM sel e WHERE e.metric_key='product_exposure_user_count'), 0)
             WHEN m.metric_key='transaction_buyer_count' THEN
                (SELECT c.current_value FROM sel c WHERE c.metric_key='transaction_buyer_count')
                / NULLIF((SELECT e.current_value FROM sel e WHERE e.metric_key='product_exposure_user_count'), 0)
             WHEN m.metric_key='refund_rate_pay_time' THEN m.current_value
             ELSE NULL END AS contribution_share,
        NULL::text AS primary_stage
    FROM sel m
    JOIN mart.diagnostic_metric_rule r ON r.metric_key = m.metric_key
    WHERE m.metric_key IN ('product_exposure_user_count','product_click_user_count','transaction_buyer_count','refund_rate_pay_time')
    ORDER BY CASE m.metric_key
        WHEN 'product_exposure_user_count' THEN 1 WHEN 'product_click_user_count' THEN 2
        WHEN 'transaction_buyer_count' THEN 3 WHEN 'refund_rate_pay_time' THEN 4 END;
END;
$$;


ALTER FUNCTION mart.get_funnel_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text) OWNER TO postgres;

--
-- Name: FUNCTION get_funnel_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_funnel_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text) IS 'V1.1 漏斗诊断：曝光→点击→成交→退款 各环节变化（缺字段跳过，不跨domain补数）。';


--
-- Name: get_growth_opportunities(text, date, date, text, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_growth_opportunities(p_platform_code text DEFAULT 'douyin'::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_domain_key text DEFAULT NULL::text, p_opportunity_code text DEFAULT NULL::text, p_min_level text DEFAULT NULL::text) RETURNS TABLE(platform_code text, shop_name text, domain_key text, entity_level text, entity_name text, scope_key text, opportunity_code text, opportunity_name_cn text, current_start_date date, current_end_date date, current_value numeric, previous_value numeric, relative_change numeric, opportunity_score numeric, opportunity_level text, available_weight numeric, benchmark_peer_count integer, benchmark_p50 numeric, benchmark_p75 numeric, coverage_complete boolean, risk_flags text, status text, created_at timestamp with time zone)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT e.platform_code, e.shop_name, e.domain_key, e.entity_level,
           e.entity_name, e.scope_key, e.opportunity_code, t.opportunity_name_cn,
           e.current_start_date, e.current_end_date,
           e.current_value, e.previous_value, e.relative_change,
           e.opportunity_score, e.opportunity_level, e.available_weight,
           e.benchmark_peer_count, e.benchmark_p50, e.benchmark_p75,
           e.coverage_complete, e.risk_flags, e.status, e.created_at
    FROM mart.opportunity_event e
    JOIN mart.opportunity_type t ON t.opportunity_code = e.opportunity_code
    WHERE e.platform_code = p_platform_code
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
      AND (p_domain_key IS NULL OR e.domain_key = p_domain_key)
      AND (p_opportunity_code IS NULL OR e.opportunity_code = p_opportunity_code)
      AND (p_min_level IS NULL OR
           (e.opportunity_level='LOW' AND p_min_level='LOW') OR
           (e.opportunity_level IN ('MEDIUM','HIGH','STRONG') AND p_min_level IN ('MEDIUM','HIGH','STRONG')) OR
           (e.opportunity_level IN ('HIGH','STRONG') AND p_min_level='HIGH') OR
           (e.opportunity_level='STRONG' AND p_min_level='STRONG'))
    ORDER BY e.opportunity_score DESC;
$$;


ALTER FUNCTION mart.get_growth_opportunities(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_opportunity_code text, p_min_level text) OWNER TO postgres;

--
-- Name: get_master_product_members(bigint); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_master_product_members(p_master_product_id bigint) RETURNS TABLE(platform_code text, shop_id bigint, shop_name text, platform_product_id text, platform_product_name text, mapping_status text, mapping_source text, confidence_score numeric, valid_from date, valid_to date)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT m.platform_code, m.shop_id, s.shop_name,
           m.platform_product_id, m.platform_product_name_snapshot,
           m.mapping_status, m.mapping_source, m.confidence_score,
           m.valid_from, m.valid_to
    FROM meta.platform_product_mapping m
    JOIN meta.shop s ON s.shop_id = m.shop_id
    WHERE m.master_product_id = p_master_product_id AND m.enabled
    ORDER BY s.shop_id, m.platform_product_id;
$$;


ALTER FUNCTION mart.get_master_product_members(p_master_product_id bigint) OWNER TO postgres;

--
-- Name: FUNCTION get_master_product_members(p_master_product_id bigint); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_master_product_members(p_master_product_id bigint) IS 'V1.3 Master Product 跨店成员（平台/店铺/平台商品ID/状态/有效期）。';


--
-- Name: get_master_product_period_summary(bigint, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_master_product_period_summary(p_master_product_id bigint, p_start_date date, p_end_date date, p_shop_name text DEFAULT NULL::text) RETURNS TABLE(master_product_id integer, master_product_code text, master_product_name text, product_line_id integer, product_line_name text, start_date date, end_date date, mapped_shop_count bigint, unmapped_member_count bigint, mapping_complete boolean, user_pay_amount numeric, refund_amount_pay_time numeric, refund_rate_pay_time numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
BEGIN
    RETURN QUERY
    WITH mp AS (
        SELECT m.master_product_id, m.master_product_code, m.master_product_name,
               m.product_line_id FROM meta.master_product m WHERE m.master_product_id = p_master_product_id
    ),
    members AS (
        SELECT m.shop_id, m.platform_product_id
        FROM meta.platform_product_mapping m
        WHERE m.master_product_id = p_master_product_id AND m.enabled AND m.mapping_status = 'CONFIRMED'
          AND (p_shop_name IS NULL OR m.shop_id = (SELECT shop_id FROM meta.shop WHERE shop_name = p_shop_name))
    ),
    agg AS (
        SELECT
            count(DISTINCT d.shop_id)::bigint AS mapped_shop_count,
            sum(d.user_pay_amount) AS up,
            sum(d.refund_amount_pay_time) AS refund
        FROM members mem
        JOIN core.douyin_product_daily d
          ON d.shop_id = mem.shop_id AND d.product_id = mem.platform_product_id
         AND d.biz_date BETWEEN p_start_date AND p_end_date AND d.carrier_type = '全部'
    )
    SELECT
        mp.master_product_id, mp.master_product_code, mp.master_product_name,
        mp.product_line_id,
        (SELECT l.product_line_name FROM meta.product_line l WHERE l.product_line_id = mp.product_line_id),
        p_start_date, p_end_date,
        a.mapped_shop_count,
        ((SELECT count(DISTINCT shop_id) FROM meta.shop WHERE platform_code='douyin' AND enabled) - a.mapped_shop_count)::bigint AS unmapped_member_count,
        (a.mapped_shop_count >= (SELECT count(*) FROM meta.shop WHERE platform_code='douyin' AND enabled)) AS mapping_complete,
        round(a.up, 2), round(a.refund, 2),
        round(a.refund / NULLIF(a.up, 0), 10)
    FROM mp, agg a;
END; $$;


ALTER FUNCTION mart.get_master_product_period_summary(p_master_product_id bigint, p_start_date date, p_end_date date, p_shop_name text) OWNER TO postgres;

--
-- Name: FUNCTION get_master_product_period_summary(p_master_product_id bigint, p_start_date date, p_end_date date, p_shop_name text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_master_product_period_summary(p_master_product_id bigint, p_start_date date, p_end_date date, p_shop_name text) IS 'V1.3 跨店 Master Product 经营汇总（仅 CONFIRMED 成员；返回 mapped_shop_count/unmapped_member_count/mapping_complete）。';


--
-- Name: get_masterdata_quality(date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_masterdata_quality(p_start_date date, p_end_date date) RETURNS TABLE(metric_key text, metric_name_cn text, metric_value numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
BEGIN
    RETURN QUERY
    WITH sales AS (
        SELECT d.shop_id, d.product_id, sum(d.user_pay_amount) AS gmv
        FROM core.douyin_product_daily d
        WHERE d.carrier_type = '全部' AND d.biz_date BETWEEN p_start_date AND p_end_date
        GROUP BY d.shop_id, d.product_id
    ),
    mapped_sales AS (
        SELECT s.gmv FROM sales s
        JOIN meta.platform_product_mapping m
          ON m.shop_id = s.shop_id AND m.platform_product_id = s.product_id
         AND m.enabled AND m.mapping_status = 'CONFIRMED'
    )
    SELECT
        'product_mapping_rate_by_gmv' AS metric_key,
        '已确认映射商品成交金额覆盖率(GMV)' AS metric_name_cn,
        round((SELECT sum(gmv) FROM mapped_sales) / NULLIF((SELECT sum(gmv) FROM sales), 0), 6) AS metric_value
    UNION ALL SELECT
        'product_mapping_rate_by_product_count',
        '已确认映射商品数量覆盖率',
        round((SELECT count(*)::numeric FROM mapped_sales) / NULLIF((SELECT count(*)::numeric FROM sales), 0), 6)
    UNION ALL SELECT
        'product_line_assignment_rate',
        'Master Product 品线归属率(已启用)',
        round((SELECT count(*)::numeric FROM meta.master_product WHERE enabled AND product_line_id IS NOT NULL)
              / NULLIF((SELECT count(*)::numeric FROM meta.master_product WHERE enabled), 0), 6)
    UNION ALL SELECT
        'conflict_count',
        '商品映射冲突数',
        (SELECT count(*)::numeric FROM mart.product_mapping_conflicts)
    UNION ALL SELECT
        'unmapped_high_value_count',
        '近30天高价值未映射商品数(GMV>10000)',
        (SELECT count(*)::numeric FROM mart.unmapped_products WHERE 近30天成交金额 > 10000)
    UNION ALL SELECT
        'sku_mapping_rate',
        'SKU映射覆盖率',
        NULL::numeric  -- SKU 源不可用，无法计算
    ;
END; $$;


ALTER FUNCTION mart.get_masterdata_quality(p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: FUNCTION get_masterdata_quality(p_start_date date, p_end_date date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_masterdata_quality(p_start_date date, p_end_date date) IS 'V1.3 主数据质量指标（GMV覆盖率/数量覆盖率/品线归属率/冲突数/高价值未映射数）。';


--
-- Name: get_opportunity_summary(text, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_opportunity_summary(p_platform_code text DEFAULT 'douyin'::text, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_status text DEFAULT 'QUALIFIED'::text) RETURNS TABLE(domain_key text, opportunity_code text, opportunity_name_cn text, event_count bigint, max_score numeric, avg_score numeric, level_distribution text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT e.domain_key, e.opportunity_code, t.opportunity_name_cn,
           count(*)::bigint, max(e.opportunity_score), avg(e.opportunity_score),
           string_agg(DISTINCT e.opportunity_level, '/' ORDER BY e.opportunity_level)
    FROM mart.opportunity_event e
    JOIN mart.opportunity_type t ON t.opportunity_code = e.opportunity_code
    WHERE e.platform_code = p_platform_code
      AND (p_start_date IS NULL OR e.current_start_date = p_start_date)
      AND (p_end_date IS NULL OR e.current_end_date = p_end_date)
      AND (p_status IS NULL OR e.status = p_status)
    GROUP BY e.domain_key, e.opportunity_code, t.opportunity_name_cn
    ORDER BY count(*) DESC;
$$;


ALTER FUNCTION mart.get_opportunity_summary(p_platform_code text, p_start_date date, p_end_date date, p_status text) OWNER TO postgres;

--
-- Name: get_platform_business_period_summary(text, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_platform_business_period_summary(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text DEFAULT '全店'::text) RETURNS TABLE(platform_code text, platform_name text, start_date date, end_date date, scope_key text, enabled_shop_count integer, covered_shop_count integer, missing_shop_count integer, missing_shops text, coverage_complete boolean, coverage_days integer, expected_days integer, user_pay_amount numeric, transaction_amount numeric, settlement_amount numeric, refund_amount_pay_time numeric, refund_rate_pay_time numeric, transaction_order_count bigint, transaction_buyer_count bigint, transaction_item_count bigint, avg_customer_amount numeric, avg_item_amount numeric, product_exposure_count bigint, product_click_count bigint, exposure_to_click_rate_events numeric, click_to_transaction_rate_events numeric, exposure_to_transaction_rate_events numeric, exposure_to_click_rate_users numeric, click_to_transaction_rate_users numeric, exposure_to_transaction_rate_users numeric, ad_spend_shop_promoted numeric, ad_spend_shop_bound numeric, ad_attributed_transaction_amount numeric, ad_attributed_transaction_share numeric, ad_spend_rate_net_refund_shop_bound numeric, total_expense_rate_net_refund_shop_bound numeric, ad_efficiency_shop_promoted numeric, ad_efficiency_shop_bound numeric, store_efficiency_shop_promoted numeric, store_efficiency_shop_bound numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
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
$$;


ALTER FUNCTION mart.get_platform_business_period_summary(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text) OWNER TO postgres;

--
-- Name: FUNCTION get_platform_business_period_summary(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_platform_business_period_summary(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text) IS 'V1.3 平台整体经营汇总：范围=enabled且platform_code匹配的店铺；可加指标SUM、比例分子/分母重算、效率加权；coverage含启用/覆盖/缺失店铺数与日期完整性。成交人数=各店之和（跨店不去重）。';


--
-- Name: get_platform_diagnostic_snapshot(text, date, date, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_platform_diagnostic_snapshot(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text DEFAULT '全店'::text) RETURNS TABLE(platform_code text, platform_name text, scope_key text, entity_id text, entity_name text, metric_key text, metric_name_cn text, metric_group text, metric_type text, display_format text, current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_value numeric, previous_value numeric, absolute_change numeric, relative_change numeric, percentage_point_change numeric, enabled_shop_count integer, covered_shop_count integer, current_coverage_complete boolean, previous_coverage_complete boolean, data_status text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
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
$$;


ALTER FUNCTION mart.get_platform_diagnostic_snapshot(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text) OWNER TO postgres;

--
-- Name: FUNCTION get_platform_diagnostic_snapshot(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_platform_diagnostic_snapshot(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text) IS 'V1.3 平台整体诊断快照：对象=抖音整体，指标=平台汇总口径（18项），带 shop coverage 与数据状态。';


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
-- Name: get_product_line_members(text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_product_line_members(p_product_line_name text) RETURNS TABLE(product_line_id integer, product_line_name text, master_product_id integer, master_product_code text, master_product_name text, mapping_count bigint, covered_shop_count bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT pl.product_line_id, pl.product_line_name,
           mp.master_product_id, mp.master_product_code, mp.master_product_name,
           count(m.mapping_id) AS mapping_count,
           count(DISTINCT m.shop_id) AS covered_shop_count
    FROM meta.product_line pl
    JOIN meta.master_product mp ON mp.product_line_id = pl.product_line_id AND mp.enabled
    LEFT JOIN meta.platform_product_mapping m ON m.master_product_id = mp.master_product_id AND m.enabled AND m.mapping_status = 'CONFIRMED'
    WHERE pl.product_line_name = p_product_line_name
    GROUP BY pl.product_line_id, pl.product_line_name, mp.master_product_id, mp.master_product_code, mp.master_product_name
    ORDER BY mp.master_product_id;
$$;


ALTER FUNCTION mart.get_product_line_members(p_product_line_name text) OWNER TO postgres;

--
-- Name: FUNCTION get_product_line_members(p_product_line_name text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_product_line_members(p_product_line_name text) IS 'V1.3 品线成员：品线 → Master Product → 已确认映射数/店铺覆盖。';


--
-- Name: get_product_line_period_summary(text, date, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_product_line_period_summary(p_product_line_name text, p_start_date date, p_end_date date) RETURNS TABLE(product_line_id integer, product_line_name text, start_date date, end_date date, expected_member_count bigint, mapped_member_count bigint, unmapped_member_count bigint, enabled_shop_count bigint, covered_shop_count bigint, mapping_complete boolean, data_coverage_complete boolean, user_pay_amount numeric, refund_amount_pay_time numeric)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
BEGIN
    RETURN QUERY
    WITH pl AS (
        SELECT l.product_line_id, l.product_line_name FROM meta.product_line l WHERE l.product_line_name = p_product_line_name
    ),
    mp_list AS (
        SELECT m.master_product_id FROM meta.master_product m
        JOIN pl ON pl.product_line_id = m.product_line_id
        WHERE m.enabled
    ),
    mapped_mp AS (
        SELECT DISTINCT m.master_product_id FROM meta.platform_product_mapping m
        JOIN mp_list ml ON ml.master_product_id = m.master_product_id
        WHERE m.enabled AND m.mapping_status = 'CONFIRMED'
    ),
    agg AS (
        SELECT
            count(DISTINCT mp_list.master_product_id)::bigint AS expected,
            count(DISTINCT mm.master_product_id)::bigint AS mapped,
            sum(d.user_pay_amount) AS up,
            sum(d.refund_amount_pay_time) AS refund,
            count(DISTINCT d.shop_id)::bigint AS covered_shop
        FROM mp_list
        LEFT JOIN mapped_mp mm ON mm.master_product_id = mp_list.master_product_id
        LEFT JOIN meta.platform_product_mapping m
          ON m.master_product_id = mp_list.master_product_id AND m.enabled AND m.mapping_status='CONFIRMED'
        LEFT JOIN core.douyin_product_daily d
          ON d.shop_id = m.shop_id AND d.product_id = m.platform_product_id
         AND d.biz_date BETWEEN p_start_date AND p_end_date AND d.carrier_type='全部'
    )
    SELECT
        pl.product_line_id, pl.product_line_name, p_start_date, p_end_date,
        a.expected, a.mapped, (a.expected - a.mapped) AS unmapped,
        (SELECT count(*)::bigint FROM meta.shop WHERE platform_code='douyin' AND enabled) AS enabled_shop,
        a.covered_shop,
        (a.mapped = a.expected) AS mapping_complete,
        (a.covered_shop >= (SELECT count(*) FROM meta.shop WHERE platform_code='douyin' AND enabled)) AS data_coverage_complete,
        round(a.up, 2), round(a.refund, 2)
    FROM pl, agg a;
END; $$;


ALTER FUNCTION mart.get_product_line_period_summary(p_product_line_name text, p_start_date date, p_end_date date) OWNER TO postgres;

--
-- Name: FUNCTION get_product_line_period_summary(p_product_line_name text, p_start_date date, p_end_date date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_product_line_period_summary(p_product_line_name text, p_start_date date, p_end_date date) IS 'V1.3 品线跨店汇总（expected/mapped/unmapped 成员数 + 店铺覆盖 + mapping_complete/data_coverage_complete）。';


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
-- Name: get_shop_contribution(text, date, date, text, text); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.get_shop_contribution(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text DEFAULT '全店'::text, p_metric_key text DEFAULT 'user_pay_amount'::text) RETURNS TABLE(platform_code text, platform_name text, start_date date, end_date date, scope_key text, metric_key text, shop_name text, current_value numeric, platform_total numeric, contribution numeric, previous_value numeric, previous_contribution numeric, contribution_change numeric, coverage_complete boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
DECLARE
    v_scope_sale text; v_scope_carrier text; v_scope_period text;
    v_ps date; v_pe date; v_days int;
BEGIN
    SELECT sale_scope, carrier_type, ad_period INTO v_scope_sale, v_scope_carrier, v_scope_period
    FROM mart.resolve_scope(p_scope_key);
    IF v_scope_sale IS NULL THEN RAISE EXCEPTION '未知经营语义: %', p_scope_key; END IF;
    v_days := (p_end_date - p_start_date) + 1;
    v_pe := p_start_date - 1;
    v_ps := v_pe - (v_days - 1);

    RETURN QUERY
    WITH enabled_shops AS (
        SELECT s.shop_id, s.shop_name FROM meta.shop s
        WHERE s.platform_code = p_platform_code AND s.enabled
    ),
    shop_vals AS (
        SELECT es.shop_name,
               sum(CASE WHEN d.biz_date BETWEEN p_start_date AND p_end_date THEN d.user_pay_amount END) AS c_val,
               sum(CASE WHEN d.biz_date BETWEEN v_ps AND v_pe THEN d.user_pay_amount END) AS p_val
        FROM enabled_shops es
        LEFT JOIN core.douyin_deal_daily d
          ON d.shop_id = es.shop_id
         AND d.biz_date BETWEEN v_ps AND p_end_date
         AND d.sale_scope = v_scope_sale AND d.carrier_type = v_scope_carrier AND d.ad_period = v_scope_period
        GROUP BY es.shop_name
    ),
    totals AS (
        SELECT sum(c_val) AS c_tot, sum(p_val) AS p_tot FROM shop_vals
    )
    SELECT
        p_platform_code,
        (SELECT p.platform_name FROM meta.platform p WHERE p.platform_code = p_platform_code),
        p_start_date, p_end_date, p_scope_key, p_metric_key,
        sv.shop_name::text,
        sv.c_val AS current_value,
        t.c_tot AS platform_total,
        CASE WHEN t.c_tot IS NULL OR t.c_tot = 0 THEN NULL ELSE sv.c_val / t.c_tot END AS contribution,
        sv.p_val AS previous_value,
        CASE WHEN t.p_tot IS NULL OR t.p_tot = 0 THEN NULL ELSE sv.p_val / t.p_tot END AS previous_contribution,
        CASE WHEN t.c_tot IS NULL OR t.c_tot = 0 OR t.p_tot IS NULL OR t.p_tot = 0 THEN NULL
             ELSE (sv.c_val / t.c_tot) - (sv.p_val / t.p_tot) END AS contribution_change,
        (SELECT count(*) FROM enabled_shops) > 0 AND
        (SELECT bool_and(sd.cnt >= (p_end_date - p_start_date) + 1)
           FROM (SELECT es2.shop_id, count(DISTINCT d2.biz_date) AS cnt
                 FROM enabled_shops es2 LEFT JOIN core.douyin_deal_daily d2
                   ON d2.shop_id = es2.shop_id
                  AND d2.biz_date BETWEEN p_start_date AND p_end_date
                  AND d2.sale_scope = v_scope_sale AND d2.carrier_type = v_scope_carrier AND d2.ad_period = v_scope_period
                 GROUP BY es2.shop_id) sd) AS coverage_complete
    FROM shop_vals sv
    CROSS JOIN totals t
    ORDER BY contribution DESC NULLS LAST, sv.shop_name;
END;
$$;


ALTER FUNCTION mart.get_shop_contribution(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) OWNER TO postgres;

--
-- Name: FUNCTION get_shop_contribution(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.get_shop_contribution(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) IS 'V1.3 店铺贡献度：单店值/平台总额/贡献占比（本期+上期+变化）。仅支持可加指标（默认 user_pay_amount）。';


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
-- Name: rank_master_products(date, date, text, text, text, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.rank_master_products(p_start_date date, p_end_date date, p_metric_key text DEFAULT 'user_pay_amount'::text, p_sort_by text DEFAULT 'current_value'::text, p_sort_direction text DEFAULT 'DESC'::text, p_limit integer DEFAULT 20) RETURNS TABLE(master_product_id integer, master_product_code text, master_product_name text, product_line_name text, metric_key text, current_value numeric, mapped_shop_count bigint, mapping_complete boolean)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        mp.master_product_id, mp.master_product_code, mp.master_product_name,
        (SELECT l.product_line_name FROM meta.product_line l WHERE l.product_line_id = mp.product_line_id),
        p_metric_key,
        round(sum(d.user_pay_amount), 2) AS current_value,
        count(DISTINCT m.shop_id)::bigint AS mapped_shop_count,
        (count(DISTINCT m.shop_id) >= (SELECT count(*) FROM meta.shop WHERE platform_code='douyin' AND enabled)) AS mapping_complete
    FROM meta.master_product mp
    JOIN meta.platform_product_mapping m
      ON m.master_product_id = mp.master_product_id AND m.enabled AND m.mapping_status = 'CONFIRMED'
    LEFT JOIN core.douyin_product_daily d
      ON d.shop_id = m.shop_id AND d.product_id = m.platform_product_id
     AND d.biz_date BETWEEN p_start_date AND p_end_date AND d.carrier_type = '全部'
    GROUP BY mp.master_product_id, mp.master_product_code, mp.master_product_name
    ORDER BY CASE WHEN upper(p_sort_direction)='DESC' THEN sum(d.user_pay_amount) END DESC NULLS LAST,
             CASE WHEN upper(p_sort_direction)='ASC' THEN sum(d.user_pay_amount) END ASC NULLS LAST,
             mp.master_product_id
    LIMIT p_limit;
END; $$;


ALTER FUNCTION mart.rank_master_products(p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) OWNER TO postgres;

--
-- Name: FUNCTION rank_master_products(p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.rank_master_products(p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) IS 'V1.3 Master Product 跨店排名（仅 CONFIRMED 成员；与店铺内 rank_products 并存）。';


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
-- Name: resolve_diagnostic_period(text, date, integer); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.resolve_diagnostic_period(p_period_key text, p_end_date date, p_current_days integer DEFAULT NULL::integer) RETURNS TABLE(current_start_date date, current_end_date date, previous_start_date date, previous_end_date date, current_days integer)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_days integer;
BEGIN
    IF p_period_key = 'custom' THEN
        IF p_current_days IS NULL OR p_current_days < 1 THEN
            RAISE EXCEPTION 'custom 周期必须提供 p_current_days(>=1)';
        END IF;
        v_days := p_current_days;
    ELSE
        SELECT r.current_days INTO v_days FROM mart.diagnostic_period_rule r WHERE r.period_key = p_period_key;
        IF v_days IS NULL THEN
            RAISE EXCEPTION '未知诊断周期 key: %', p_period_key;
        END IF;
    END IF;
    IF p_end_date IS NULL THEN
        RAISE EXCEPTION 'p_end_date 不能为空';
    END IF;

    current_end_date   := p_end_date;
    current_start_date := p_end_date - (v_days - 1);
    previous_end_date  := current_start_date - 1;
    previous_start_date := previous_end_date - (v_days - 1);
    current_days       := v_days;
    RETURN NEXT;
END;
$$;


ALTER FUNCTION mart.resolve_diagnostic_period(p_period_key text, p_end_date date, p_current_days integer) OWNER TO postgres;

--
-- Name: FUNCTION resolve_diagnostic_period(p_period_key text, p_end_date date, p_current_days integer); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.resolve_diagnostic_period(p_period_key text, p_end_date date, p_current_days integer) IS 'V1.1 诊断周期解析：等长前置对比。previous_end = current_start - 1。';


--
-- Name: resolve_master_product(text, text, text, date); Type: FUNCTION; Schema: mart; Owner: postgres
--

CREATE FUNCTION mart.resolve_master_product(p_platform_code text, p_shop_name text, p_platform_product_id text, p_biz_date date DEFAULT CURRENT_DATE) RETURNS TABLE(platform_code text, shop_name text, platform_product_id text, platform_product_name text, master_product_id integer, master_product_code text, master_product_name text, product_line_id integer, product_line_name text, mapping_status text, mapping_source text, confidence_score numeric, valid_from date, valid_to date, sku_source_status text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'mart', 'core', 'meta', 'audit'
    AS $$
    SELECT
        m.platform_code,
        s.shop_name,
        m.platform_product_id,
        m.platform_product_name_snapshot,
        mp.master_product_id,
        mp.master_product_code,
        mp.master_product_name,
        pl.product_line_id,
        pl.product_line_name,
        m.mapping_status, m.mapping_source, m.confidence_score,
        m.valid_from, m.valid_to,
        'SKU_SOURCE_NOT_AVAILABLE'::text AS sku_source_status
    FROM meta.platform_product_mapping m
    JOIN meta.shop s ON s.shop_id = m.shop_id
    JOIN meta.master_product mp ON mp.master_product_id = m.master_product_id
    LEFT JOIN meta.product_line pl ON pl.product_line_id = mp.product_line_id
    WHERE m.platform_code = p_platform_code
      AND s.shop_name = p_shop_name
      AND m.platform_product_id = p_platform_product_id
      AND m.enabled
      AND m.valid_from <= p_biz_date
      AND (m.valid_to IS NULL OR m.valid_to >= p_biz_date)
      AND NOT EXISTS (
          -- 同期间多条启用映射（时间重叠）→ CONFLICT，不返回
          SELECT 1 FROM meta.platform_product_mapping m2
          WHERE m2.platform_code = m.platform_code AND m2.shop_id = m.shop_id
            AND m2.platform_product_id = m.platform_product_id AND m2.enabled
            AND m2.mapping_id <> m.mapping_id
            AND m2.valid_from < coalesce(m.valid_to, 'infinity'::date)
            AND coalesce(m2.valid_to, 'infinity'::date) > m.valid_from
      )
    ORDER BY m.mapping_status = 'CONFIRMED' DESC, m.mapping_id
    LIMIT 1;
$$;


ALTER FUNCTION mart.resolve_master_product(p_platform_code text, p_shop_name text, p_platform_product_id text, p_biz_date date) OWNER TO postgres;

--
-- Name: FUNCTION resolve_master_product(p_platform_code text, p_shop_name text, p_platform_product_id text, p_biz_date date); Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON FUNCTION mart.resolve_master_product(p_platform_code text, p_shop_name text, p_platform_product_id text, p_biz_date date) IS 'V1.3 查商品归属：平台+店铺+平台商品ID+业务日期 → Master Product/品线/状态。
当前抖音源无 SKU 维度（SKU_SOURCE_NOT_AVAILABLE），SKU 优先规则在真实 SKU 数据接入后启用。';


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
-- Name: audit_mapping(); Type: FUNCTION; Schema: meta; Owner: postgres
--

CREATE FUNCTION meta.audit_mapping() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_obj text; v_id text; v_act text;
BEGIN
    v_obj := TG_TABLE_NAME;
    IF TG_OP = 'INSERT' THEN
        v_act := 'CREATE_MAPPING'; v_id := NEW.mapping_id::text;
        INSERT INTO audit.masterdata_change_log (object_type, object_id, change_type, old_value, new_value, changed_by)
        VALUES (upper(v_obj), v_id, v_act, NULL, to_jsonb(NEW), coalesce(NEW.reviewed_by, 'SYSTEM'));
    ELSIF TG_OP = 'UPDATE' THEN
        v_act := 'UPDATE_MAPPING'; v_id := NEW.mapping_id::text;
        IF OLD.mapping_status = 'SUGGESTED' AND NEW.mapping_status = 'CONFIRMED' THEN v_act := 'CONFIRM_MAPPING'; END IF;
        IF OLD.enabled AND NOT NEW.enabled THEN v_act := 'CLOSE_MAPPING'; END IF;
        INSERT INTO audit.masterdata_change_log (object_type, object_id, change_type, old_value, new_value, changed_by)
        VALUES (upper(v_obj), v_id, v_act, to_jsonb(OLD), to_jsonb(NEW), coalesce(NEW.reviewed_by, 'SYSTEM'));
    END IF;
    RETURN NULL;
END; $$;


ALTER FUNCTION meta.audit_mapping() OWNER TO postgres;

--
-- Name: audit_masterdata(); Type: FUNCTION; Schema: meta; Owner: postgres
--

CREATE FUNCTION meta.audit_masterdata() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_obj text;
BEGIN
    v_obj := TG_TABLE_NAME;
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit.masterdata_change_log (object_type, object_id, change_type, old_value, new_value, changed_by)
        VALUES (upper(v_obj), NEW.master_product_id::text, 'CREATE', NULL, to_jsonb(NEW), 'SYSTEM');
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit.masterdata_change_log (object_type, object_id, change_type, old_value, new_value, changed_by)
        VALUES (upper(v_obj), NEW.master_product_id::text, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), 'SYSTEM');
    END IF;
    RETURN NULL;
END; $$;


ALTER FUNCTION meta.audit_masterdata() OWNER TO postgres;

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
-- Name: gen_master_product_code(); Type: FUNCTION; Schema: meta; Owner: postgres
--

CREATE FUNCTION meta.gen_master_product_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.master_product_code IS NULL THEN
        NEW.master_product_code := 'MP' || lpad(NEW.master_product_id::text, 6, '0');
    END IF;
    RETURN NEW;
END; $$;


ALTER FUNCTION meta.gen_master_product_code() OWNER TO postgres;

--
-- Name: gen_master_sku_code(); Type: FUNCTION; Schema: meta; Owner: postgres
--

CREATE FUNCTION meta.gen_master_sku_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.master_sku_code IS NULL THEN
        NEW.master_sku_code := 'MS' || lpad(NEW.master_sku_id::text, 6, '0');
    END IF;
    RETURN NEW;
END; $$;


ALTER FUNCTION meta.gen_master_sku_code() OWNER TO postgres;

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
-- Name: ai_diagnosis_run; Type: TABLE; Schema: audit; Owner: postgres
--

CREATE TABLE audit.ai_diagnosis_run (
    run_id bigint NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    intent text,
    question_hash text,
    scope_text text,
    tools_called jsonb,
    result_id text,
    duration_ms integer,
    error_type text,
    note text
);


ALTER TABLE audit.ai_diagnosis_run OWNER TO postgres;

--
-- Name: TABLE ai_diagnosis_run; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON TABLE audit.ai_diagnosis_run IS 'V1.1 AI 诊断审计（不含密码/密钥/.env/完整system prompt）。';


--
-- Name: ai_diagnosis_run_run_id_seq; Type: SEQUENCE; Schema: audit; Owner: postgres
--

CREATE SEQUENCE audit.ai_diagnosis_run_run_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE audit.ai_diagnosis_run_run_id_seq OWNER TO postgres;

--
-- Name: ai_diagnosis_run_run_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: postgres
--

ALTER SEQUENCE audit.ai_diagnosis_run_run_id_seq OWNED BY audit.ai_diagnosis_run.run_id;


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
-- Name: masterdata_change_log; Type: TABLE; Schema: audit; Owner: postgres
--

CREATE TABLE audit.masterdata_change_log (
    change_id integer NOT NULL,
    object_type text NOT NULL,
    object_id text NOT NULL,
    change_type text NOT NULL,
    old_value jsonb,
    new_value jsonb,
    changed_by text DEFAULT 'SYSTEM'::text NOT NULL,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    reason text
);


ALTER TABLE audit.masterdata_change_log OWNER TO postgres;

--
-- Name: TABLE masterdata_change_log; Type: COMMENT; Schema: audit; Owner: postgres
--

COMMENT ON TABLE audit.masterdata_change_log IS 'V1.3 主数据变更审计（历史可追溯，禁止物理删除历史映射）。';


--
-- Name: masterdata_change_log_change_id_seq; Type: SEQUENCE; Schema: audit; Owner: postgres
--

CREATE SEQUENCE audit.masterdata_change_log_change_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE audit.masterdata_change_log_change_id_seq OWNER TO postgres;

--
-- Name: masterdata_change_log_change_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: postgres
--

ALTER SEQUENCE audit.masterdata_change_log_change_id_seq OWNED BY audit.masterdata_change_log.change_id;


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
    ad_spend_shop_promoted numeric(20,2),
    ad_spend_shop_bound numeric(20,2),
    ad_attributed_transaction_amount numeric(20,2),
    ad_attributed_transaction_share numeric(18,8),
    ad_spend_rate_net_refund_shop_bound numeric(18,8),
    total_expense_rate_net_refund_shop_bound numeric(18,8),
    ad_efficiency_shop_promoted numeric(20,8),
    ad_efficiency_shop_bound numeric(20,8),
    store_efficiency_shop_promoted numeric(20,8),
    store_efficiency_shop_bound numeric(20,8),
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
-- Name: COLUMN douyin_deal_daily.ad_spend_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.ad_spend_shop_promoted IS '投放消耗(店铺被投) (V1.0.1新增, 类别:投放指标-可加金额, 聚合:SUM)';


--
-- Name: COLUMN douyin_deal_daily.ad_spend_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.ad_spend_shop_bound IS '投放消耗(店铺绑定) (V1.0.1新增, 类别:投放指标-可加金额, 聚合:SUM)';


--
-- Name: COLUMN douyin_deal_daily.ad_attributed_transaction_amount; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.ad_attributed_transaction_amount IS '投放贡献成交金额 (V1.0.1新增, 类别:投放指标-可加金额, 聚合:SUM)';


--
-- Name: COLUMN douyin_deal_daily.ad_attributed_transaction_share; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.ad_attributed_transaction_share IS '投放贡献成交占比 (V1.0.1新增, 类别:投放指标-比例, 聚合:weighted_source_ratio)';


--
-- Name: COLUMN douyin_deal_daily.ad_spend_rate_net_refund_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.ad_spend_rate_net_refund_shop_bound IS '投放费比(剔除退款、店铺绑定) (V1.0.1新增, 类别:投放指标-比例, 聚合:weighted_source_ratio)';


--
-- Name: COLUMN douyin_deal_daily.total_expense_rate_net_refund_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.total_expense_rate_net_refund_shop_bound IS '综合费比(剔除退款、店铺绑定) (V1.0.1新增, 类别:投放指标-比例, 聚合:weighted_source_ratio)';


--
-- Name: COLUMN douyin_deal_daily.ad_efficiency_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.ad_efficiency_shop_promoted IS '投放效率(店铺被投) (V1.0.1新增, 类别:投放指标-效率, 聚合:weighted_source_ratio)';


--
-- Name: COLUMN douyin_deal_daily.ad_efficiency_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.ad_efficiency_shop_bound IS '投放效率(店铺绑定) (V1.0.1新增, 类别:投放指标-效率, 聚合:weighted_source_ratio)';


--
-- Name: COLUMN douyin_deal_daily.store_efficiency_shop_promoted; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.store_efficiency_shop_promoted IS '全店效率(店铺被投) (V1.0.1新增, 类别:投放指标-效率, 聚合:weighted_source_ratio)';


--
-- Name: COLUMN douyin_deal_daily.store_efficiency_shop_bound; Type: COMMENT; Schema: core; Owner: postgres
--

COMMENT ON COLUMN core.douyin_deal_daily.store_efficiency_shop_bound IS '全店效率(店铺绑定) (V1.0.1新增, 类别:投放指标-效率, 聚合:weighted_source_ratio)';


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
   FROM ( VALUES ('business'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('business'::text,'transaction_amount'::text,'成交金额'::text,'additive'::text,true,true,'DESC'::text), ('business'::text,'refund_amount_pay_time'::text,'退款金额(支付时间)'::text,'additive'::text,true,true,'DESC'::text), ('business'::text,'settlement_amount'::text,'结算金额'::text,'additive'::text,true,false,'DESC'::text), ('business'::text,'transaction_order_count'::text,'成交订单数'::text,'additive'::text,true,false,'DESC'::text), ('business'::text,'transaction_buyer_count'::text,'成交人数'::text,'additive'::text,true,false,'DESC'::text), ('business'::text,'transaction_item_count'::text,'成交件数'::text,'additive'::text,true,false,'DESC'::text), ('business'::text,'avg_customer_amount'::text,'客单价'::text,'average'::text,true,false,'DESC'::text), ('business'::text,'avg_item_amount'::text,'件单价'::text,'average'::text,true,false,'DESC'::text), ('business'::text,'refund_rate_pay_time'::text,'退款率(支付时间)'::text,'ratio'::text,true,false,'ASC'::text), ('business'::text,'exposure_to_click_rate_users'::text,'商品曝光-点击转化率(人数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'click_to_transaction_rate_users'::text,'商品点击-成交转化率(人数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'exposure_to_transaction_rate_users'::text,'商品曝光-成交转化率(人数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'exposure_to_click_rate_events'::text,'商品曝光-点击转化率(次数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'click_to_transaction_rate_events'::text,'商品点击-成交转化率(次数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'exposure_to_transaction_rate_events'::text,'商品曝光-成交转化率(次数)'::text,'ratio'::text,true,false,'DESC'::text), ('business'::text,'user_pay_amount_per_1000_exposures'::text,'千次曝光用户支付金额'::text,'average'::text,true,false,'DESC'::text), ('product'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('product'::text,'refund_amount_pay_time'::text,'退款金额(支付时间)'::text,'additive'::text,true,true,'DESC'::text), ('product'::text,'refund_rate_pay_time'::text,'退款率(支付时间)'::text,'ratio'::text,true,false,'ASC'::text), ('account'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('account'::text,'transaction_amount'::text,'成交金额'::text,'additive'::text,true,true,'DESC'::text), ('account'::text,'refund_amount_pay_time'::text,'退款金额(支付时间)'::text,'additive'::text,true,true,'DESC'::text), ('account'::text,'refund_rate_pay_time'::text,'退款率(支付时间)'::text,'ratio'::text,true,false,'ASC'::text), ('account'::text,'transaction_order_count'::text,'成交订单数'::text,'additive'::text,true,false,'DESC'::text), ('account'::text,'transaction_buyer_count'::text,'成交人数'::text,'additive'::text,true,false,'DESC'::text), ('account'::text,'avg_customer_amount'::text,'客单价'::text,'average'::text,true,false,'DESC'::text), ('carrier'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('carrier'::text,'transaction_amount'::text,'成交金额'::text,'additive'::text,true,true,'DESC'::text), ('carrier'::text,'refund_amount_pay_time'::text,'退款金额(支付时间)'::text,'additive'::text,true,true,'DESC'::text), ('carrier'::text,'refund_rate_pay_time'::text,'退款率(支付时间)'::text,'ratio'::text,true,false,'ASC'::text), ('category'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('category'::text,'refund_amount_pay_time'::text,'退款金额(支付时间)'::text,'additive'::text,true,true,'DESC'::text), ('category'::text,'refund_rate_pay_time'::text,'退款率(支付时间)'::text,'ratio'::text,true,false,'ASC'::text), ('price_band'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('audience'::text,'user_pay_amount'::text,'用户支付金额'::text,'additive'::text,true,true,'DESC'::text), ('audience'::text,'transaction_buyer_count'::text,'成交人数'::text,'additive'::text,true,true,'DESC'::text), ('audience'::text,'transaction_order_count'::text,'成交订单数'::text,'additive'::text,true,true,'DESC'::text), ('audience'::text,'avg_customer_amount'::text,'客单价'::text,'average'::text,true,false,'DESC'::text), ('advertising'::text,'ad_spend_shop_promoted'::text,'投放消耗(店铺被投)'::text,'additive'::text,false,false,'DESC'::text), ('advertising'::text,'ad_spend_shop_bound'::text,'投放消耗(店铺绑定)'::text,'additive'::text,false,false,'DESC'::text), ('advertising'::text,'ad_attributed_transaction_amount'::text,'投放贡献成交金额'::text,'additive'::text,false,false,'DESC'::text), ('advertising'::text,'ad_attributed_transaction_share'::text,'投放贡献成交占比'::text,'ratio'::text,false,false,'DESC'::text), ('advertising'::text,'ad_spend_rate_net_refund_shop_bound'::text,'投放费比(剔除退款、店铺绑定)'::text,'ratio'::text,false,false,'DESC'::text), ('advertising'::text,'total_expense_rate_net_refund_shop_bound'::text,'综合费比(剔除退款、店铺绑定)'::text,'ratio'::text,false,false,'DESC'::text), ('advertising'::text,'ad_efficiency_shop_promoted'::text,'投放效率(店铺被投)'::text,'efficiency'::text,false,false,'DESC'::text), ('advertising'::text,'ad_efficiency_shop_bound'::text,'投放效率(店铺绑定)'::text,'efficiency'::text,false,false,'DESC'::text), ('advertising'::text,'store_efficiency_shop_promoted'::text,'全店效率(店铺被投)'::text,'efficiency'::text,false,false,'DESC'::text), ('advertising'::text,'store_efficiency_shop_bound'::text,'全店效率(店铺绑定)'::text,'efficiency'::text,false,false,'DESC'::text)) v(domain_key, metric_key, metric_name_cn, value_type, rank_allowed, contribution_allowed, default_rank_direction);


ALTER VIEW mart.analysis_metric_whitelist OWNER TO postgres;

--
-- Name: VIEW analysis_metric_whitelist; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.analysis_metric_whitelist IS '阶段3分析指标白名单。排名/贡献/环比禁止接受任意字段名；value_type=ratio时可计算百分点变化。';


--
-- Name: anomaly_event; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.anomaly_event (
    anomaly_event_id bigint NOT NULL,
    platform_code text NOT NULL,
    shop_name text,
    domain_key text NOT NULL,
    entity_level text NOT NULL,
    entity_id text,
    entity_name text,
    scope_key text,
    metric_key text NOT NULL,
    anomaly_type text NOT NULL,
    current_start_date date NOT NULL,
    current_end_date date NOT NULL,
    previous_start_date date,
    previous_end_date date,
    current_value numeric,
    previous_value numeric,
    absolute_change numeric,
    relative_change numeric,
    percentage_point_change numeric,
    low_base_value numeric,
    materiality numeric,
    triggered_period_count integer DEFAULT 1 NOT NULL,
    consecutive_day_count integer DEFAULT 1 NOT NULL,
    severity text DEFAULT 'LOW'::text NOT NULL,
    severity_score numeric DEFAULT 0 NOT NULL,
    coverage_complete boolean,
    shop_coverage_complete boolean,
    mapping_complete boolean,
    data_quality_score numeric DEFAULT 80 NOT NULL,
    diagnostic_chain_key text,
    parent_anomaly_event_id bigint,
    status text DEFAULT 'OPEN'::text NOT NULL,
    rule_version text DEFAULT 'v1'::text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT anomaly_event_severity_check CHECK ((severity = ANY (ARRAY['INFO'::text, 'LOW'::text, 'MEDIUM'::text, 'HIGH'::text, 'CRITICAL'::text]))),
    CONSTRAINT anomaly_event_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'RESOLVED'::text, 'SUPPRESSED'::text])))
);


ALTER TABLE mart.anomaly_event OWNER TO postgres;

--
-- Name: TABLE anomaly_event; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON TABLE mart.anomaly_event IS 'V1.1 异常事件（只记录"哪里异常/多严重/是否持续/影响多大"；唯一键防重复；生命周期 OPEN/RESOLVED/SUPPRESSED）。';


--
-- Name: anomaly_event_anomaly_event_id_seq; Type: SEQUENCE; Schema: mart; Owner: postgres
--

CREATE SEQUENCE mart.anomaly_event_anomaly_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE mart.anomaly_event_anomaly_event_id_seq OWNER TO postgres;

--
-- Name: anomaly_event_anomaly_event_id_seq; Type: SEQUENCE OWNED BY; Schema: mart; Owner: postgres
--

ALTER SEQUENCE mart.anomaly_event_anomaly_event_id_seq OWNED BY mart.anomaly_event.anomaly_event_id;


--
-- Name: anomaly_rule; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.anomaly_rule (
    rule_code text NOT NULL,
    rule_name_cn text NOT NULL,
    metric_key text NOT NULL,
    metric_direction text NOT NULL,
    low_base_metric text,
    low_base_value numeric DEFAULT 0,
    threshold_relative numeric,
    threshold_pp numeric,
    severity_base numeric DEFAULT 40,
    enabled boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT anomaly_rule_metric_direction_check CHECK ((metric_direction = ANY (ARRAY['DROP'::text, 'RISE'::text])))
);


ALTER TABLE mart.anomaly_rule OWNER TO postgres;

--
-- Name: TABLE anomaly_rule; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON TABLE mart.anomaly_rule IS 'V1.1 异常规则（8 类；base/阈值可配置；多店/主数据域可用独立 base）。';


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
-- Name: daily_action_item; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.daily_action_item (
    action_item_id bigint NOT NULL,
    platform_code text NOT NULL,
    shop_name text,
    entity_level text NOT NULL,
    domain_key text NOT NULL,
    entity_id text,
    entity_name text,
    scope_key text,
    master_product_id text,
    product_line_id text,
    item_type text NOT NULL,
    source_anomaly_code text,
    source_opportunity_code text,
    risk_priority_score numeric,
    opportunity_priority_score numeric,
    risk_level text,
    opportunity_level text,
    action_category text NOT NULL,
    current_start_date date NOT NULL,
    current_end_date date NOT NULL,
    business_impact numeric,
    impact_source text,
    coverage_complete boolean,
    mapping_complete boolean,
    diagnostic_chain_id text,
    action_group_key text,
    dedupe_group_key text,
    status text DEFAULT 'OPEN'::text NOT NULL,
    first_seen_date date DEFAULT CURRENT_DATE NOT NULL,
    last_seen_date date DEFAULT CURRENT_DATE NOT NULL,
    occurrence_count integer DEFAULT 1 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT daily_action_item_item_type_check CHECK ((item_type = ANY (ARRAY['RISK'::text, 'OPPORTUNITY'::text, 'WATCH'::text]))),
    CONSTRAINT daily_action_item_opportunity_level_check CHECK ((opportunity_level = ANY (ARRAY['O1_STRONG'::text, 'O2_HIGH'::text, 'O3_MEDIUM'::text, 'O4_WATCH'::text]))),
    CONSTRAINT daily_action_item_risk_level_check CHECK ((risk_level = ANY (ARRAY['P1_URGENT'::text, 'P2_HIGH'::text, 'P3_MEDIUM'::text, 'P4_LOW'::text]))),
    CONSTRAINT daily_action_item_status_check CHECK ((status = ANY (ARRAY['OPEN'::text, 'WATCHING'::text, 'RESOLVED'::text, 'EXPIRED'::text])))
);


ALTER TABLE mart.daily_action_item OWNER TO postgres;

--
-- Name: TABLE daily_action_item; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON TABLE mart.daily_action_item IS 'V1.1 每日行动项：只消费 Stage2/3/4 事件；risk/opportunity 独立优先级；chain 去重（同链仅 1 主卡）；冷却=更新原卡；禁止自动动作。';


--
-- Name: daily_action_item_action_item_id_seq; Type: SEQUENCE; Schema: mart; Owner: postgres
--

CREATE SEQUENCE mart.daily_action_item_action_item_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE mart.daily_action_item_action_item_id_seq OWNER TO postgres;

--
-- Name: daily_action_item_action_item_id_seq; Type: SEQUENCE OWNED BY; Schema: mart; Owner: postgres
--

ALTER SEQUENCE mart.daily_action_item_action_item_id_seq OWNED BY mart.daily_action_item.action_item_id;


--
-- Name: diagnostic_entity_rule; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.diagnostic_entity_rule (
    domain_key text NOT NULL,
    domain_name_cn text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    entity_id_field text,
    entity_name_field text,
    supports_rank boolean DEFAULT false NOT NULL,
    supports_contribution boolean DEFAULT false NOT NULL,
    supports_scope boolean DEFAULT false NOT NULL,
    source_object text NOT NULL,
    notes text
);


ALTER TABLE mart.diagnostic_entity_rule OWNER TO postgres;

--
-- Name: TABLE diagnostic_entity_rule; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON TABLE mart.diagnostic_entity_rule IS 'V1.1 诊断对象注册表：登记首批智能诊断业务域及对象能力（排名/贡献/Scope）。';


--
-- Name: diagnostic_metric_rule; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.diagnostic_metric_rule (
    metric_key text NOT NULL,
    metric_name_cn text NOT NULL,
    metric_group text NOT NULL,
    source_domain text NOT NULL,
    metric_type text NOT NULL,
    display_format text NOT NULL,
    cross_period_recalculable boolean DEFAULT true NOT NULL,
    diagnostic_enabled boolean DEFAULT true NOT NULL,
    higher_is_better boolean DEFAULT true NOT NULL,
    supports_percentage_point boolean DEFAULT false NOT NULL,
    supports_rank boolean DEFAULT false NOT NULL,
    supports_contribution boolean DEFAULT false NOT NULL,
    source_rule_reference text,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT diagnostic_metric_rule_metric_type_check CHECK ((metric_type = ANY (ARRAY['amount'::text, 'count'::text, 'average'::text, 'ratio'::text, 'efficiency'::text])))
);


ALTER TABLE mart.diagnostic_metric_rule OWNER TO postgres;

--
-- Name: TABLE diagnostic_metric_rule; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON TABLE mart.diagnostic_metric_rule IS 'V1.1 诊断指标注册表：登记可稳定跨期比较的诊断指标及属性（类型/方向/可重算/排名/贡献），不做异常判定。';


--
-- Name: diagnostic_period_rule; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.diagnostic_period_rule (
    period_key text NOT NULL,
    period_name_cn text NOT NULL,
    current_days integer,
    previous_rule text DEFAULT 'EQUAL_PRECEDING'::text NOT NULL,
    notes text
);


ALTER TABLE mart.diagnostic_period_rule OWNER TO postgres;

--
-- Name: TABLE diagnostic_period_rule; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON TABLE mart.diagnostic_period_rule IS 'V1.1 诊断周期规则：当前周期与等长前置对比周期。previous_end = current_start - 1。';


--
-- Name: diagnostic_result; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.diagnostic_result (
    diagnostic_id bigint NOT NULL,
    platform_code text NOT NULL,
    shop_name text,
    domain_key text NOT NULL,
    entity_level text NOT NULL,
    entity_id text,
    entity_name text,
    scope_key text,
    parent_entity text,
    master_product_id text,
    product_line_id text,
    diagnostic_code text,
    primary_stage text,
    diagnostic_status text DEFAULT 'DIAGNOSED'::text NOT NULL,
    current_start_date date NOT NULL,
    current_end_date date NOT NULL,
    previous_start_date date,
    previous_end_date date,
    current_value numeric,
    previous_value numeric,
    absolute_change numeric,
    relative_change numeric,
    percentage_point_change numeric,
    confidence_score numeric DEFAULT 0 NOT NULL,
    evidence_json jsonb,
    path_json jsonb,
    diagnostic_chain_id text,
    source_anomaly_event_id bigint,
    coverage_complete boolean,
    mapping_complete boolean,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT diagnostic_result_diagnostic_status_check CHECK ((diagnostic_status = ANY (ARRAY['DIAGNOSED'::text, 'MULTI_FACTOR'::text, 'INSUFFICIENT_EVIDENCE'::text, 'NO_CONFIRMED_ANOMALY'::text, 'UNSUPPORTED_DOMAIN'::text, 'UNSUPPORTED_DIAGNOSTIC_PATH'::text, 'COVERAGE_INCOMPLETE'::text, 'MAPPING_INCOMPLETE'::text]))),
    CONSTRAINT diagnostic_result_primary_stage_check CHECK ((primary_stage = ANY (ARRAY['traffic'::text, 'click'::text, 'conversion'::text, 'refund'::text, 'advertising'::text, 'mix'::text, 'contribution'::text, 'unknown'::text])))
);


ALTER TABLE mart.diagnostic_result OWNER TO postgres;

--
-- Name: TABLE diagnostic_result; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON TABLE mart.diagnostic_result IS 'V1.1 诊断结果（数据层问题定位）：层级/漏斗/贡献/投放拆解 + 证据链 + 置信度 + 问题链。
evidence_json 只写事实，禁止未证实业务原因。';


--
-- Name: diagnostic_result_diagnostic_id_seq; Type: SEQUENCE; Schema: mart; Owner: postgres
--

CREATE SEQUENCE mart.diagnostic_result_diagnostic_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE mart.diagnostic_result_diagnostic_id_seq OWNER TO postgres;

--
-- Name: diagnostic_result_diagnostic_id_seq; Type: SEQUENCE OWNED BY; Schema: mart; Owner: postgres
--

ALTER SEQUENCE mart.diagnostic_result_diagnostic_id_seq OWNED BY mart.diagnostic_result.diagnostic_id;


--
-- Name: diagnostic_type; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.diagnostic_type (
    diagnostic_code text NOT NULL,
    diagnostic_name_cn text NOT NULL,
    description text,
    enabled boolean DEFAULT true NOT NULL
);


ALTER TABLE mart.diagnostic_type OWNER TO postgres;

--
-- Name: douyin_platform_daily; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.douyin_platform_daily AS
 SELECT 'douyin'::text AS platform_code,
    d.biz_date,
    '全店'::text AS scope_key,
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
   FROM (core.douyin_deal_daily d
     JOIN meta.shop s ON ((s.shop_id = d.shop_id)))
  WHERE (((s.platform_code)::text = 'douyin'::text) AND s.enabled AND ((d.sale_scope)::text = '全部'::text) AND ((d.carrier_type)::text = '全部'::text) AND ((d.ad_period)::text = '不限'::text))
  GROUP BY d.biz_date;


ALTER VIEW mart.douyin_platform_daily OWNER TO postgres;

--
-- Name: VIEW douyin_platform_daily; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.douyin_platform_daily IS 'V1.3 平台日表（全店TOTAL口径）：platform×date，两店合计。平台整体只存在于 mart 语义，不建 shop_id=0。';


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
    single_row_formula,
    period_formula_sql,
    zero_denominator_rule,
    cross_period_recalculable,
    auto_use_allowed,
    rule_status,
    display_format,
    mapping_version,
    notes,
    created_at,
    verification_method,
    verification_period,
    verification_result
   FROM meta.metric_formula_rule
  WHERE ((mapping_version)::text = ANY ((ARRAY['V1.4'::character varying, 'V1.0.1'::character varying])::text[]));


ALTER VIEW mart.metric_rule_v14 OWNER TO postgres;

--
-- Name: opportunity_event; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.opportunity_event (
    opportunity_event_id bigint NOT NULL,
    platform_code text NOT NULL,
    shop_name text,
    domain_key text NOT NULL,
    entity_level text NOT NULL,
    entity_id text,
    entity_name text,
    scope_key text,
    master_product_id text,
    product_line_id text,
    opportunity_code text,
    current_start_date date NOT NULL,
    current_end_date date NOT NULL,
    previous_start_date date,
    previous_end_date date,
    current_value numeric,
    previous_value numeric,
    relative_change numeric,
    percentage_point_change numeric,
    growth_score numeric,
    persistence_score numeric,
    conversion_score numeric,
    refund_score numeric,
    ad_efficiency_score numeric,
    materiality_score numeric,
    contribution_score numeric,
    opportunity_score numeric NOT NULL,
    opportunity_level text NOT NULL,
    available_weight numeric NOT NULL,
    benchmark_pool text,
    benchmark_peer_count integer,
    benchmark_p50 numeric,
    benchmark_p75 numeric,
    coverage_complete boolean,
    mapping_complete boolean,
    risk_flags text,
    diagnostic_chain_id text,
    status text DEFAULT 'QUALIFIED'::text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT opportunity_event_opportunity_level_check CHECK ((opportunity_level = ANY (ARRAY['LOW'::text, 'MEDIUM'::text, 'HIGH'::text, 'STRONG'::text]))),
    CONSTRAINT opportunity_event_status_check CHECK ((status = ANY (ARRAY['QUALIFIED'::text, 'COVERAGE_INCOMPLETE'::text, 'MAPPING_INCOMPLETE'::text, 'INSUFFICIENT_PEERS'::text, 'INSUFFICIENT_EVIDENCE'::text, 'NEW_BASE_SIGNAL'::text, 'LOW_BASE'::text])))
);


ALTER TABLE mart.opportunity_event OWNER TO postgres;

--
-- Name: TABLE opportunity_event; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON TABLE mart.opportunity_event IS 'V1.1 机会事件（机会质量排序分，非未来成功概率；幂等；COVERAGE/MAPPING/PEERS/WEIGHT 惩罚状态）。';


--
-- Name: opportunity_event_opportunity_event_id_seq; Type: SEQUENCE; Schema: mart; Owner: postgres
--

CREATE SEQUENCE mart.opportunity_event_opportunity_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE mart.opportunity_event_opportunity_event_id_seq OWNER TO postgres;

--
-- Name: opportunity_event_opportunity_event_id_seq; Type: SEQUENCE OWNED BY; Schema: mart; Owner: postgres
--

ALTER SEQUENCE mart.opportunity_event_opportunity_event_id_seq OWNED BY mart.opportunity_event.opportunity_event_id;


--
-- Name: opportunity_rule; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.opportunity_rule (
    rule_code text NOT NULL,
    weight_growth numeric DEFAULT 20 NOT NULL,
    weight_persistence numeric DEFAULT 20 NOT NULL,
    weight_conversion numeric DEFAULT 20 NOT NULL,
    weight_refund numeric DEFAULT 15 NOT NULL,
    weight_ad_efficiency numeric DEFAULT 10 NOT NULL,
    weight_materiality numeric DEFAULT 10 NOT NULL,
    weight_contribution numeric DEFAULT 5 NOT NULL,
    min_peer_count integer DEFAULT 3 NOT NULL,
    min_materiality numeric DEFAULT 3000 NOT NULL,
    min_growth numeric DEFAULT 0.15 NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE mart.opportunity_rule OWNER TO postgres;

--
-- Name: TABLE opportunity_rule; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON TABLE mart.opportunity_rule IS 'V1.1 机会规则：7 维权重（默认20/20/20/15/10/10/5）+ peer 最小数量 + 低基数门槛。';


--
-- Name: opportunity_type; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.opportunity_type (
    opportunity_code text NOT NULL,
    opportunity_name_cn text NOT NULL,
    description text,
    enabled boolean DEFAULT true NOT NULL
);


ALTER TABLE mart.opportunity_type OWNER TO postgres;

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
-- Name: priority_entity_weight; Type: TABLE; Schema: mart; Owner: postgres
--

CREATE TABLE mart.priority_entity_weight (
    entity_level text NOT NULL,
    strategic_weight numeric DEFAULT 1.0 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE mart.priority_entity_weight OWNER TO postgres;

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
-- Name: master_product; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.master_product (
    master_product_id integer NOT NULL,
    master_product_code text NOT NULL,
    master_product_name text NOT NULL,
    brand_name text,
    product_line_id integer,
    product_status text DEFAULT 'ACTIVE'::text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    merged_into_master_product_id integer,
    valid_from date,
    valid_to date,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT master_product_product_status_check CHECK ((product_status = ANY (ARRAY['ACTIVE'::text, 'DISCONTINUED'::text, 'MERGED'::text, 'TEST'::text])))
);


ALTER TABLE meta.master_product OWNER TO postgres;

--
-- Name: TABLE master_product; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.master_product IS 'V1.3 公司级真实商品主档（master_product_id 代表公司认定的同一真实商品）。';


--
-- Name: platform_product_mapping; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.platform_product_mapping (
    mapping_id integer NOT NULL,
    platform_code text NOT NULL,
    shop_id bigint NOT NULL,
    platform_product_id text NOT NULL,
    platform_product_name_snapshot text,
    master_product_id integer NOT NULL,
    mapping_status text DEFAULT 'SUGGESTED'::text NOT NULL,
    mapping_source text DEFAULT 'MANUAL'::text NOT NULL,
    confidence_score numeric(5,4),
    valid_from date DEFAULT '2026-01-01'::date NOT NULL,
    valid_to date,
    enabled boolean DEFAULT true NOT NULL,
    reviewed_by text,
    reviewed_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT platform_product_mapping_mapping_source_check CHECK ((mapping_source = ANY (ARRAY['MANUAL'::text, 'EXACT_ID_RULE'::text, 'EXACT_NAME_SUGGESTION'::text, 'ALIAS_SUGGESTION'::text, 'AI_SUGGESTION'::text, 'IMPORT_FILE'::text]))),
    CONSTRAINT platform_product_mapping_mapping_status_check CHECK ((mapping_status = ANY (ARRAY['CONFIRMED'::text, 'SUGGESTED'::text, 'UNMAPPED'::text, 'CONFLICT'::text, 'DISABLED'::text])))
);


ALTER TABLE meta.platform_product_mapping OWNER TO postgres;

--
-- Name: TABLE platform_product_mapping; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.platform_product_mapping IS 'V1.3 平台商品→Master Product 映射（跨店按 shop_id 隔离；历史不物理删除）。';


--
-- Name: product_mapping_conflicts; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.product_mapping_conflicts AS
 SELECT 'MULTI_MAPPING'::text AS conflict_type,
    m.platform_code AS "平台",
    s.shop_name AS "店铺名称",
    m.platform_product_id AS "平台商品id",
    m.mapping_id AS "映射id",
    m.master_product_id AS "公司商品id",
    mp.master_product_code AS "公司商品编码",
    m.mapping_status AS "映射状态",
    m.valid_from AS "有效开始",
    m.valid_to AS "有效结束"
   FROM ((meta.platform_product_mapping m
     JOIN meta.shop s ON ((s.shop_id = m.shop_id)))
     JOIN meta.master_product mp ON ((mp.master_product_id = m.master_product_id)))
  WHERE (m.enabled AND (EXISTS ( SELECT 1
           FROM meta.platform_product_mapping m2
          WHERE ((m2.platform_code = m.platform_code) AND (m2.shop_id = m.shop_id) AND (m2.platform_product_id = m.platform_product_id) AND m2.enabled AND (m2.mapping_id <> m.mapping_id) AND (m2.valid_from < COALESCE(m.valid_to, 'infinity'::date)) AND (COALESCE(m2.valid_to, 'infinity'::date) > m.valid_from)))));


ALTER VIEW mart.product_mapping_conflicts OWNER TO postgres;

--
-- Name: VIEW product_mapping_conflicts; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.product_mapping_conflicts IS 'V1.3 商品映射冲突（同一平台店铺商品多条启用映射时间重叠）。';


--
-- Name: product_line; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.product_line (
    product_line_id integer NOT NULL,
    product_line_code text NOT NULL,
    product_line_name text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    display_order integer DEFAULT 0 NOT NULL,
    valid_from date,
    valid_to date,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE meta.product_line OWNER TO postgres;

--
-- Name: TABLE product_line; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.product_line IS 'V1.3 公司级品线（只初始化品线，不按名称关键词自动归属商品）。';


--
-- Name: product_master_resolution; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.product_master_resolution AS
 SELECT m.platform_code,
    m.shop_id,
    s.shop_name,
    m.platform_product_id,
    m.platform_product_name_snapshot AS platform_product_name,
    mp.master_product_id,
    mp.master_product_code,
    mp.master_product_name,
    pl.product_line_id,
    pl.product_line_name,
    m.mapping_status,
    m.mapping_source,
    m.confidence_score,
    m.valid_from,
    m.valid_to
   FROM (((meta.platform_product_mapping m
     JOIN meta.shop s ON ((s.shop_id = m.shop_id)))
     JOIN meta.master_product mp ON ((mp.master_product_id = m.master_product_id)))
     LEFT JOIN meta.product_line pl ON ((pl.product_line_id = mp.product_line_id)));


ALTER VIEW mart.product_master_resolution OWNER TO postgres;

--
-- Name: VIEW product_master_resolution; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.product_master_resolution IS 'V1.3 商品主数据解析（平台商品 → Master Product → 品线 → 状态/来源/有效期）。';


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
    d.avg_item_amount,
    d.ad_spend_shop_promoted,
    d.ad_spend_shop_bound,
    d.ad_attributed_transaction_amount,
    d.ad_attributed_transaction_share,
    d.ad_spend_rate_net_refund_shop_bound,
    d.total_expense_rate_net_refund_shop_bound,
    d.ad_efficiency_shop_promoted,
    d.ad_efficiency_shop_bound,
    d.store_efficiency_shop_promoted,
    d.store_efficiency_shop_bound
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
-- Name: sku_mapping_conflicts; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.sku_mapping_conflicts AS
 SELECT 'SKU_SOURCE_NOT_AVAILABLE'::text AS conflict_type,
    '当前抖音源无SKU维度，无SKU映射冲突可检测'::text AS note
  WHERE false;


ALTER VIEW mart.sku_mapping_conflicts OWNER TO postgres;

--
-- Name: VIEW sku_mapping_conflicts; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.sku_mapping_conflicts IS 'V1.3 SKU 映射冲突（预留；SKU 数据源接入后启用）。';


--
-- Name: sku_master_resolution; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.sku_master_resolution AS
 SELECT 'SKU_SOURCE_NOT_AVAILABLE'::text AS sku_source_status,
    '当前抖音正式商品经营事实源不包含 SKU ID/名称维度；已建立 Master SKU 与映射框架，但不伪造平台 SKU（V1.3 文档第三十节）。'::text AS note
  WHERE false;


ALTER VIEW mart.sku_master_resolution OWNER TO postgres;

--
-- Name: VIEW sku_master_resolution; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.sku_master_resolution IS 'V1.3 SKU 解析：当前抖音源无 SKU 维度，明确返回 SKU_SOURCE_NOT_AVAILABLE（不伪造）。';


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
-- Name: unmapped_products; Type: VIEW; Schema: mart; Owner: postgres
--

CREATE VIEW mart.unmapped_products AS
 WITH product_sales AS (
         SELECT d.shop_id,
            d.product_id,
            d.product_name,
            count(DISTINCT d.biz_date) AS appear_days,
            min(d.biz_date) AS first_date,
            max(d.biz_date) AS last_date,
            sum(d.user_pay_amount) AS gmv_30d
           FROM core.douyin_product_daily d
          WHERE (((d.carrier_type)::text = '全部'::text) AND (d.biz_date >= ( SELECT (max(douyin_product_daily.biz_date) - 29)
                   FROM core.douyin_product_daily)))
          GROUP BY d.shop_id, d.product_id, d.product_name
        ), mapped AS (
         SELECT DISTINCT platform_product_mapping.shop_id,
            platform_product_mapping.platform_product_id
           FROM meta.platform_product_mapping
          WHERE (platform_product_mapping.enabled AND (platform_product_mapping.mapping_status = ANY (ARRAY['CONFIRMED'::text, 'SUGGESTED'::text])))
        )
 SELECT s.shop_name AS "店铺名称",
    ps.product_id AS "商品id",
    ps.product_name AS "商品名称",
    ps.first_date AS "首次出现日期",
    ps.last_date AS "最近出现日期",
    ps.appear_days AS "出现天数",
    round(ps.gmv_30d, 2) AS "近30天成交金额",
    'UNMAPPED'::text AS "映射状态"
   FROM ((product_sales ps
     JOIN meta.shop s ON ((s.shop_id = ps.shop_id)))
     LEFT JOIN mapped mp ON (((mp.shop_id = ps.shop_id) AND (mp.platform_product_id = (ps.product_id)::text))))
  WHERE ((mp.platform_product_id IS NULL) AND ((ps.product_id)::text <> ''::text) AND (ps.product_name <> '其他'::text))
  ORDER BY ps.gmv_30d DESC;


ALTER VIEW mart.unmapped_products OWNER TO postgres;

--
-- Name: VIEW unmapped_products; Type: COMMENT; Schema: mart; Owner: postgres
--

COMMENT ON VIEW mart.unmapped_products IS 'V1.3 未映射商品（近30天GMV降序，成交金额仅用于决定处理优先级，不用于自动匹配）。';


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
-- Name: master_product_alias; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.master_product_alias (
    alias_id integer NOT NULL,
    master_product_id integer NOT NULL,
    alias_name text NOT NULL,
    alias_type text DEFAULT 'COMMON'::text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT master_product_alias_alias_type_check CHECK ((alias_type = ANY (ARRAY['COMMON'::text, 'SHORT_NAME'::text, 'OLD_NAME'::text, 'PLATFORM_SPECIFIC'::text])))
);


ALTER TABLE meta.master_product_alias OWNER TO postgres;

--
-- Name: TABLE master_product_alias; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.master_product_alias IS 'V1.3 公司商品别名（鱼子酱洗发水/鱼子酱洗发露 等，用于候选匹配）。';


--
-- Name: master_product_alias_alias_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.master_product_alias_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.master_product_alias_alias_id_seq OWNER TO postgres;

--
-- Name: master_product_alias_alias_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.master_product_alias_alias_id_seq OWNED BY meta.master_product_alias.alias_id;


--
-- Name: master_product_master_product_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.master_product_master_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.master_product_master_product_id_seq OWNER TO postgres;

--
-- Name: master_product_master_product_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.master_product_master_product_id_seq OWNED BY meta.master_product.master_product_id;


--
-- Name: master_sku; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.master_sku (
    master_sku_id integer NOT NULL,
    master_sku_code text NOT NULL,
    master_product_id integer NOT NULL,
    master_sku_name text NOT NULL,
    specification text,
    net_content text,
    variant_name text,
    enabled boolean DEFAULT true NOT NULL,
    valid_from date,
    valid_to date,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE meta.master_sku OWNER TO postgres;

--
-- Name: TABLE master_sku; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.master_sku IS 'V1.3 公司级 SKU 主档（一个 Master Product 可有多个 SKU）。';


--
-- Name: master_sku_alias; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.master_sku_alias (
    alias_id integer NOT NULL,
    master_sku_id integer NOT NULL,
    alias_name text NOT NULL,
    alias_type text DEFAULT 'COMMON'::text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT master_sku_alias_alias_type_check CHECK ((alias_type = ANY (ARRAY['COMMON'::text, 'SHORT_NAME'::text, 'OLD_NAME'::text, 'PLATFORM_SPECIFIC'::text])))
);


ALTER TABLE meta.master_sku_alias OWNER TO postgres;

--
-- Name: TABLE master_sku_alias; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.master_sku_alias IS 'V1.3 公司 SKU 别名（500ml/500ML/500毫升 等）。';


--
-- Name: master_sku_alias_alias_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.master_sku_alias_alias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.master_sku_alias_alias_id_seq OWNER TO postgres;

--
-- Name: master_sku_alias_alias_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.master_sku_alias_alias_id_seq OWNED BY meta.master_sku_alias.alias_id;


--
-- Name: master_sku_master_sku_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.master_sku_master_sku_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.master_sku_master_sku_id_seq OWNER TO postgres;

--
-- Name: master_sku_master_sku_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.master_sku_master_sku_id_seq OWNED BY meta.master_sku.master_sku_id;


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
-- Name: platform; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.platform (
    platform_code text NOT NULL,
    platform_name text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE meta.platform OWNER TO postgres;

--
-- Name: TABLE platform; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.platform IS 'V1.3 平台维度：platform_code 为聚合范围语义，平台整体只存在于 mart 查询层，不进 core。';


--
-- Name: platform_product_mapping_mapping_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.platform_product_mapping_mapping_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.platform_product_mapping_mapping_id_seq OWNER TO postgres;

--
-- Name: platform_product_mapping_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.platform_product_mapping_mapping_id_seq OWNED BY meta.platform_product_mapping.mapping_id;


--
-- Name: platform_sku_mapping; Type: TABLE; Schema: meta; Owner: postgres
--

CREATE TABLE meta.platform_sku_mapping (
    mapping_id integer NOT NULL,
    platform_code text NOT NULL,
    shop_id bigint NOT NULL,
    platform_product_id text NOT NULL,
    platform_sku_id text NOT NULL,
    platform_product_name_snapshot text,
    platform_sku_name_snapshot text,
    master_product_id integer NOT NULL,
    master_sku_id integer NOT NULL,
    mapping_status text DEFAULT 'SUGGESTED'::text NOT NULL,
    mapping_source text DEFAULT 'MANUAL'::text NOT NULL,
    confidence_score numeric(5,4),
    valid_from date DEFAULT '2026-01-01'::date NOT NULL,
    valid_to date,
    enabled boolean DEFAULT true NOT NULL,
    reviewed_by text,
    reviewed_at timestamp with time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT platform_sku_mapping_mapping_source_check CHECK ((mapping_source = ANY (ARRAY['MANUAL'::text, 'EXACT_ID_RULE'::text, 'EXACT_NAME_SUGGESTION'::text, 'ALIAS_SUGGESTION'::text, 'AI_SUGGESTION'::text, 'IMPORT_FILE'::text]))),
    CONSTRAINT platform_sku_mapping_mapping_status_check CHECK ((mapping_status = ANY (ARRAY['CONFIRMED'::text, 'SUGGESTED'::text, 'UNMAPPED'::text, 'CONFLICT'::text, 'DISABLED'::text])))
);


ALTER TABLE meta.platform_sku_mapping OWNER TO postgres;

--
-- Name: TABLE platform_sku_mapping; Type: COMMENT; Schema: meta; Owner: postgres
--

COMMENT ON TABLE meta.platform_sku_mapping IS 'V1.3 平台 SKU→Master SKU 映射。当前抖音源无 SKU 维度（SKU_SOURCE_NOT_AVAILABLE），本表保留框架，不伪造平台 SKU。';


--
-- Name: platform_sku_mapping_mapping_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.platform_sku_mapping_mapping_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.platform_sku_mapping_mapping_id_seq OWNER TO postgres;

--
-- Name: platform_sku_mapping_mapping_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.platform_sku_mapping_mapping_id_seq OWNED BY meta.platform_sku_mapping.mapping_id;


--
-- Name: product_line_product_line_id_seq; Type: SEQUENCE; Schema: meta; Owner: postgres
--

CREATE SEQUENCE meta.product_line_product_line_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE meta.product_line_product_line_id_seq OWNER TO postgres;

--
-- Name: product_line_product_line_id_seq; Type: SEQUENCE OWNED BY; Schema: meta; Owner: postgres
--

ALTER SEQUENCE meta.product_line_product_line_id_seq OWNED BY meta.product_line.product_line_id;


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
-- Name: sku映射冲突; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."sku映射冲突" AS
 SELECT conflict_type,
    note
   FROM mart.sku_mapping_conflicts;


ALTER VIEW "中文数据"."sku映射冲突" OWNER TO postgres;

--
-- Name: VIEW "sku映射冲突"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."sku映射冲突" IS 'V1.3 SKU映射冲突（预留）。';


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
-- Name: 公司sku主档; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."公司sku主档" AS
 SELECT ms.master_sku_code AS "公司sku编码",
    ms.master_sku_name AS "公司sku名称",
    mp.master_product_code AS "所属公司商品编码",
    ms.specification AS "规格",
    ms.net_content AS "净含量",
    ms.variant_name AS "变体名称",
    ms.enabled AS "启用",
    ms.valid_from AS "有效开始",
    ms.valid_to AS "有效结束"
   FROM (meta.master_sku ms
     JOIN meta.master_product mp ON ((mp.master_product_id = ms.master_product_id)));


ALTER VIEW "中文数据"."公司sku主档" OWNER TO postgres;

--
-- Name: VIEW "公司sku主档"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."公司sku主档" IS 'V1.3 公司SKU主档（中文）。';


--
-- Name: 公司商品主档; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."公司商品主档" AS
 SELECT master_product_code AS "公司商品编码",
    master_product_name AS "公司商品名称",
    brand_name AS "品牌",
    ( SELECT pl.product_line_name
           FROM meta.product_line pl
          WHERE (pl.product_line_id = mp.product_line_id)) AS "所属品线",
    product_status AS "商品状态",
    enabled AS "启用",
    valid_from AS "有效开始",
    valid_to AS "有效结束",
    notes AS "备注"
   FROM meta.master_product mp;


ALTER VIEW "中文数据"."公司商品主档" OWNER TO postgres;

--
-- Name: VIEW "公司商品主档"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."公司商品主档" IS 'V1.3 公司商品主档（中文）。';


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
-- Name: 品线配置; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."品线配置" AS
 SELECT product_line_code AS "品线编码",
    product_line_name AS "品线名称",
    enabled AS "启用",
    display_order AS "排序",
    valid_from AS "有效开始",
    valid_to AS "有效结束",
    notes AS "备注"
   FROM meta.product_line;


ALTER VIEW "中文数据"."品线配置" OWNER TO postgres;

--
-- Name: VIEW "品线配置"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."品线配置" IS 'V1.3 品线配置（中文）。';


--
-- Name: 商品映射冲突; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."商品映射冲突" AS
 SELECT conflict_type,
    "平台",
    "店铺名称",
    "平台商品id",
    "映射id",
    "公司商品id",
    "公司商品编码",
    "映射状态",
    "有效开始",
    "有效结束"
   FROM mart.product_mapping_conflicts;


ALTER VIEW "中文数据"."商品映射冲突" OWNER TO postgres;

--
-- Name: VIEW "商品映射冲突"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."商品映射冲突" IS 'V1.3 商品映射冲突。';


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
-- Name: 平台sku映射; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."平台sku映射" AS
 SELECT 'SKU_SOURCE_NOT_AVAILABLE'::text AS "状态说明",
    '当前抖音正式商品事实源不含SKU维度；Master SKU 与映射框架已建立，不伪造平台SKU'::text AS "说明"
  WHERE false;


ALTER VIEW "中文数据"."平台sku映射" OWNER TO postgres;

--
-- Name: VIEW "平台sku映射"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."平台sku映射" IS 'V1.3 平台SKU映射（中文；当前SKU源不可用）。';


--
-- Name: 平台商品映射; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."平台商品映射" AS
 SELECT m.platform_code AS "平台",
    s.shop_name AS "店铺名称",
    m.platform_product_id AS "平台商品id",
    m.platform_product_name_snapshot AS "平台商品名称",
    mp.master_product_code AS "公司商品编码",
    mp.master_product_name AS "公司商品名称",
    ( SELECT pl.product_line_name
           FROM meta.product_line pl
          WHERE (pl.product_line_id = mp.product_line_id)) AS "所属品线",
    m.mapping_status AS "映射状态",
    m.mapping_source AS "映射来源",
    m.confidence_score AS "置信度",
    m.valid_from AS "有效开始",
    m.valid_to AS "有效结束"
   FROM ((meta.platform_product_mapping m
     JOIN meta.shop s ON ((s.shop_id = m.shop_id)))
     JOIN meta.master_product mp ON ((mp.master_product_id = m.master_product_id)));


ALTER VIEW "中文数据"."平台商品映射" OWNER TO postgres;

--
-- Name: VIEW "平台商品映射"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."平台商品映射" IS 'V1.3 平台商品映射（中文）。';


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
-- Name: 抖音多店数据覆盖; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音多店数据覆盖" AS
 SELECT platform_code AS "平台",
    shop_name AS "店铺名称",
    enabled AS "启用",
    ( SELECT (min(d.biz_date))::text AS min
           FROM core.douyin_deal_daily d
          WHERE (d.shop_id = s.shop_id)) AS "最早数据日期",
    ( SELECT (max(d.biz_date))::text AS max
           FROM core.douyin_deal_daily d
          WHERE (d.shop_id = s.shop_id)) AS "最晚数据日期",
    ( SELECT count(DISTINCT d.biz_date) AS count
           FROM core.douyin_deal_daily d
          WHERE (d.shop_id = s.shop_id)) AS "有数据天数"
   FROM meta.shop s
  WHERE ((platform_code)::text = 'douyin'::text)
  ORDER BY shop_id;


ALTER VIEW "中文数据"."抖音多店数据覆盖" OWNER TO postgres;

--
-- Name: VIEW "抖音多店数据覆盖"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."抖音多店数据覆盖" IS 'V1.3 抖音各店独立数据覆盖（不因他店有数据而误判）。';


--
-- Name: 抖音多店经营日报; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音多店经营日报" AS
 SELECT biz_date AS "日期",
    platform_code AS "平台",
    scope_key AS "经营范围",
    user_pay_amount AS "用户支付金额",
    transaction_amount AS "成交金额",
    settlement_amount AS "结算金额",
    refund_amount_pay_time AS "退款金额",
    transaction_order_count AS "成交订单数",
    transaction_buyer_count AS "成交人数",
    ad_spend_shop_promoted AS "投放消耗",
    ad_attributed_transaction_amount AS "投放贡献成交金额"
   FROM mart.douyin_platform_daily p;


ALTER VIEW "中文数据"."抖音多店经营日报" OWNER TO postgres;

--
-- Name: VIEW "抖音多店经营日报"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."抖音多店经营日报" IS 'V1.3 平台日表（抖音两店合计，全店口径）。';


--
-- Name: 抖音店铺贡献; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."抖音店铺贡献" AS
 SELECT platform_name AS "平台",
    start_date AS "开始日期",
    end_date AS "结束日期",
    scope_key AS "经营范围",
    metric_key AS "指标",
    shop_name AS "店铺名称",
    current_value AS "本期值",
    platform_total AS "平台总额",
    contribution AS "贡献占比",
    previous_contribution AS "上期贡献占比",
    contribution_change AS "贡献变化",
    coverage_complete AS "覆盖完整"
   FROM mart.get_shop_contribution('douyin'::text, ( SELECT min(douyin_deal_daily.biz_date) AS min
           FROM core.douyin_deal_daily), ( SELECT max(douyin_deal_daily.biz_date) AS max
           FROM core.douyin_deal_daily), '全店'::text, 'user_pay_amount'::text) c(platform_code, platform_name, start_date, end_date, scope_key, metric_key, shop_name, current_value, platform_total, contribution, previous_value, previous_contribution, contribution_change, coverage_complete);


ALTER VIEW "中文数据"."抖音店铺贡献" OWNER TO postgres;

--
-- Name: VIEW "抖音店铺贡献"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."抖音店铺贡献" IS 'V1.3 抖音店铺贡献度（默认全月全店 user_pay）。';


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
    t.imported_at AS "写入时间",
    t.ad_spend_shop_promoted AS "投放消耗(店铺被投)",
    t.ad_spend_shop_bound AS "投放消耗(店铺绑定)",
    t.ad_attributed_transaction_amount AS "投放贡献成交金额",
    t.ad_attributed_transaction_share AS "投放贡献成交占比",
    t.ad_spend_rate_net_refund_shop_bound AS "投放费比(剔除退款、店铺绑定)",
    t.total_expense_rate_net_refund_shop_bound AS "综合费比(剔除退款、店铺绑定)",
    t.ad_efficiency_shop_promoted AS "投放效率(店铺被投)",
    t.ad_efficiency_shop_bound AS "投放效率(店铺绑定)",
    t.store_efficiency_shop_promoted AS "全店效率(店铺被投)",
    t.store_efficiency_shop_bound AS "全店效率(店铺绑定)"
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
-- Name: 未归属sku; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."未归属sku" AS
 SELECT 'SKU_SOURCE_NOT_AVAILABLE'::text AS "状态说明",
    '当前抖音源无SKU维度'::text AS "说明"
  WHERE false;


ALTER VIEW "中文数据"."未归属sku" OWNER TO postgres;

--
-- Name: VIEW "未归属sku"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."未归属sku" IS 'V1.3 未归属SKU（当前SKU源不可用）。';


--
-- Name: 未归属商品; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."未归属商品" AS
 SELECT "店铺名称",
    "商品id",
    "商品名称",
    "首次出现日期",
    "最近出现日期",
    "出现天数",
    "近30天成交金额",
    "映射状态"
   FROM mart.unmapped_products;


ALTER VIEW "中文数据"."未归属商品" OWNER TO postgres;

--
-- Name: VIEW "未归属商品"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."未归属商品" IS 'V1.3 未归属商品（近30天GMV排序）。';


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
-- Name: 经营诊断快照; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."经营诊断快照" AS
 SELECT shop_name AS "店铺名称",
    domain_name_cn AS "分析域",
    entity_id AS "对象编号",
    entity_name AS "对象名称",
    scope_key AS "经营范围",
    metric_name_cn AS "指标名称",
    metric_group AS "指标分组",
    metric_type AS "指标类型",
    current_start_date AS "本期开始",
    current_end_date AS "本期结束",
    previous_start_date AS "上期开始",
    previous_end_date AS "上期结束",
    current_value AS "本期值",
    previous_value AS "上期值",
    absolute_change AS "绝对变化",
    relative_change AS "相对变化",
    percentage_point_change AS "百分点变化",
    current_rank AS "本期排名",
    previous_rank AS "上期排名",
    rank_change AS "排名变化",
    current_contribution AS "本期贡献度",
    previous_contribution AS "上期贡献度",
    contribution_change AS "贡献度变化",
    current_coverage_days AS "本期覆盖天数",
    previous_coverage_days AS "上期覆盖天数",
    data_status AS "数据状态",
    notes AS "备注"
   FROM mart.get_diagnostic_snapshot('弹动官方旗舰店'::text, ( SELECT (max(douyin_deal_daily.biz_date) - 6)
           FROM core.douyin_deal_daily), ( SELECT max(douyin_deal_daily.biz_date) AS max
           FROM core.douyin_deal_daily), 'shop'::text) get_diagnostic_snapshot(shop_name, domain_key, domain_name_cn, entity_id, entity_name, scope_key, metric_key, metric_name_cn, metric_group, metric_type, display_format, current_start_date, current_end_date, previous_start_date, previous_end_date, current_value, previous_value, absolute_change, relative_change, percentage_point_change, current_rank, previous_rank, rank_change, current_contribution, previous_contribution, contribution_change, contribution_denominator_type, contribution_denominator_value, current_coverage_days, expected_current_days, previous_coverage_days, expected_previous_days, current_coverage_complete, previous_coverage_complete, calculation_status, data_status, notes);


ALTER VIEW "中文数据"."经营诊断快照" OWNER TO postgres;

--
-- Name: VIEW "经营诊断快照"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."经营诊断快照" IS 'V1.1 经营诊断快照（默认最近7天×店铺整体，中文列）。';


--
-- Name: 诊断周期规则; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."诊断周期规则" AS
 SELECT period_key AS "周期编码",
    period_name_cn AS "周期名称",
    current_days AS "当前周期天数",
    previous_rule AS "对比规则",
    notes AS "备注"
   FROM mart.diagnostic_period_rule;


ALTER VIEW "中文数据"."诊断周期规则" OWNER TO postgres;

--
-- Name: VIEW "诊断周期规则"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."诊断周期规则" IS 'V1.1 诊断周期规则（中文）。';


--
-- Name: 诊断对象规则; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."诊断对象规则" AS
 SELECT domain_key AS "分析域编码",
    domain_name_cn AS "分析域名称",
    enabled AS "启用",
    entity_id_field AS "对象编号字段",
    entity_name_field AS "对象名称字段",
    supports_rank AS "支持排名",
    supports_contribution AS "支持贡献度",
    supports_scope AS "支持scope",
    source_object AS "底层来源",
    notes AS "备注"
   FROM mart.diagnostic_entity_rule;


ALTER VIEW "中文数据"."诊断对象规则" OWNER TO postgres;

--
-- Name: VIEW "诊断对象规则"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."诊断对象规则" IS 'V1.1 诊断对象注册表（中文）。';


--
-- Name: 诊断指标规则; Type: VIEW; Schema: 中文数据; Owner: postgres
--

CREATE VIEW "中文数据"."诊断指标规则" AS
 SELECT metric_key AS "指标编码",
    metric_name_cn AS "指标名称",
    metric_group AS "指标分组",
    source_domain AS "来源域",
    metric_type AS "指标类型",
    display_format AS "展示格式",
    cross_period_recalculable AS "可跨期重算",
    diagnostic_enabled AS "诊断启用",
    higher_is_better AS "越高越好",
    supports_percentage_point AS "支持百分点",
    supports_rank AS "支持排名",
    supports_contribution AS "支持贡献度",
    source_rule_reference AS "规则引用",
    notes AS "备注"
   FROM mart.diagnostic_metric_rule;


ALTER VIEW "中文数据"."诊断指标规则" OWNER TO postgres;

--
-- Name: VIEW "诊断指标规则"; Type: COMMENT; Schema: 中文数据; Owner: postgres
--

COMMENT ON VIEW "中文数据"."诊断指标规则" IS 'V1.1 诊断指标注册表（中文）。';


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
-- Name: ai_diagnosis_run run_id; Type: DEFAULT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.ai_diagnosis_run ALTER COLUMN run_id SET DEFAULT nextval('audit.ai_diagnosis_run_run_id_seq'::regclass);


--
-- Name: import_batch batch_id; Type: DEFAULT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.import_batch ALTER COLUMN batch_id SET DEFAULT nextval('audit.import_batch_batch_id_seq'::regclass);


--
-- Name: masterdata_change_log change_id; Type: DEFAULT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.masterdata_change_log ALTER COLUMN change_id SET DEFAULT nextval('audit.masterdata_change_log_change_id_seq'::regclass);


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
-- Name: anomaly_event anomaly_event_id; Type: DEFAULT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.anomaly_event ALTER COLUMN anomaly_event_id SET DEFAULT nextval('mart.anomaly_event_anomaly_event_id_seq'::regclass);


--
-- Name: daily_action_item action_item_id; Type: DEFAULT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.daily_action_item ALTER COLUMN action_item_id SET DEFAULT nextval('mart.daily_action_item_action_item_id_seq'::regclass);


--
-- Name: diagnostic_result diagnostic_id; Type: DEFAULT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.diagnostic_result ALTER COLUMN diagnostic_id SET DEFAULT nextval('mart.diagnostic_result_diagnostic_id_seq'::regclass);


--
-- Name: mart_dimension_rule rule_id; Type: DEFAULT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.mart_dimension_rule ALTER COLUMN rule_id SET DEFAULT nextval('mart.mart_dimension_rule_rule_id_seq'::regclass);


--
-- Name: opportunity_event opportunity_event_id; Type: DEFAULT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.opportunity_event ALTER COLUMN opportunity_event_id SET DEFAULT nextval('mart.opportunity_event_opportunity_event_id_seq'::regclass);


--
-- Name: database_object_dictionary dictionary_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.database_object_dictionary ALTER COLUMN dictionary_id SET DEFAULT nextval('meta.database_object_dictionary_dictionary_id_seq'::regclass);


--
-- Name: field_mapping mapping_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping ALTER COLUMN mapping_id SET DEFAULT nextval('meta.field_mapping_mapping_id_seq'::regclass);


--
-- Name: master_product master_product_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_product ALTER COLUMN master_product_id SET DEFAULT nextval('meta.master_product_master_product_id_seq'::regclass);


--
-- Name: master_product_alias alias_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_product_alias ALTER COLUMN alias_id SET DEFAULT nextval('meta.master_product_alias_alias_id_seq'::regclass);


--
-- Name: master_sku master_sku_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_sku ALTER COLUMN master_sku_id SET DEFAULT nextval('meta.master_sku_master_sku_id_seq'::regclass);


--
-- Name: master_sku_alias alias_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_sku_alias ALTER COLUMN alias_id SET DEFAULT nextval('meta.master_sku_alias_alias_id_seq'::regclass);


--
-- Name: metric_formula_rule metric_rule_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.metric_formula_rule ALTER COLUMN metric_rule_id SET DEFAULT nextval('meta.metric_formula_rule_metric_rule_id_seq'::regclass);


--
-- Name: platform_product_mapping mapping_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.platform_product_mapping ALTER COLUMN mapping_id SET DEFAULT nextval('meta.platform_product_mapping_mapping_id_seq'::regclass);


--
-- Name: platform_sku_mapping mapping_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.platform_sku_mapping ALTER COLUMN mapping_id SET DEFAULT nextval('meta.platform_sku_mapping_mapping_id_seq'::regclass);


--
-- Name: product_line product_line_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.product_line ALTER COLUMN product_line_id SET DEFAULT nextval('meta.product_line_product_line_id_seq'::regclass);


--
-- Name: shop shop_id; Type: DEFAULT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.shop ALTER COLUMN shop_id SET DEFAULT nextval('meta.shop_shop_id_seq'::regclass);


--
-- Name: ai_diagnosis_run ai_diagnosis_run_pkey; Type: CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.ai_diagnosis_run
    ADD CONSTRAINT ai_diagnosis_run_pkey PRIMARY KEY (run_id);


--
-- Name: import_batch import_batch_pkey; Type: CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.import_batch
    ADD CONSTRAINT import_batch_pkey PRIMARY KEY (batch_id);


--
-- Name: masterdata_change_log masterdata_change_log_pkey; Type: CONSTRAINT; Schema: audit; Owner: postgres
--

ALTER TABLE ONLY audit.masterdata_change_log
    ADD CONSTRAINT masterdata_change_log_pkey PRIMARY KEY (change_id);


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
-- Name: anomaly_event anomaly_event_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.anomaly_event
    ADD CONSTRAINT anomaly_event_pkey PRIMARY KEY (anomaly_event_id);


--
-- Name: anomaly_rule anomaly_rule_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.anomaly_rule
    ADD CONSTRAINT anomaly_rule_pkey PRIMARY KEY (rule_code);


--
-- Name: daily_action_item daily_action_item_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.daily_action_item
    ADD CONSTRAINT daily_action_item_pkey PRIMARY KEY (action_item_id);


--
-- Name: diagnostic_entity_rule diagnostic_entity_rule_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.diagnostic_entity_rule
    ADD CONSTRAINT diagnostic_entity_rule_pkey PRIMARY KEY (domain_key);


--
-- Name: diagnostic_metric_rule diagnostic_metric_rule_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.diagnostic_metric_rule
    ADD CONSTRAINT diagnostic_metric_rule_pkey PRIMARY KEY (metric_key);


--
-- Name: diagnostic_period_rule diagnostic_period_rule_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.diagnostic_period_rule
    ADD CONSTRAINT diagnostic_period_rule_pkey PRIMARY KEY (period_key);


--
-- Name: diagnostic_result diagnostic_result_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.diagnostic_result
    ADD CONSTRAINT diagnostic_result_pkey PRIMARY KEY (diagnostic_id);


--
-- Name: diagnostic_type diagnostic_type_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.diagnostic_type
    ADD CONSTRAINT diagnostic_type_pkey PRIMARY KEY (diagnostic_code);


--
-- Name: mart_dimension_rule mart_dimension_rule_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.mart_dimension_rule
    ADD CONSTRAINT mart_dimension_rule_pkey PRIMARY KEY (rule_id);


--
-- Name: opportunity_event opportunity_event_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.opportunity_event
    ADD CONSTRAINT opportunity_event_pkey PRIMARY KEY (opportunity_event_id);


--
-- Name: opportunity_rule opportunity_rule_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.opportunity_rule
    ADD CONSTRAINT opportunity_rule_pkey PRIMARY KEY (rule_code);


--
-- Name: opportunity_type opportunity_type_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.opportunity_type
    ADD CONSTRAINT opportunity_type_pkey PRIMARY KEY (opportunity_code);


--
-- Name: priority_entity_weight priority_entity_weight_pkey; Type: CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.priority_entity_weight
    ADD CONSTRAINT priority_entity_weight_pkey PRIMARY KEY (entity_level);


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
-- Name: master_product_alias master_product_alias_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_product_alias
    ADD CONSTRAINT master_product_alias_pkey PRIMARY KEY (alias_id);


--
-- Name: master_product master_product_master_product_code_key; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_product
    ADD CONSTRAINT master_product_master_product_code_key UNIQUE (master_product_code);


--
-- Name: master_product master_product_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_product
    ADD CONSTRAINT master_product_pkey PRIMARY KEY (master_product_id);


--
-- Name: master_sku_alias master_sku_alias_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_sku_alias
    ADD CONSTRAINT master_sku_alias_pkey PRIMARY KEY (alias_id);


--
-- Name: master_sku master_sku_master_sku_code_key; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_sku
    ADD CONSTRAINT master_sku_master_sku_code_key UNIQUE (master_sku_code);


--
-- Name: master_sku master_sku_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_sku
    ADD CONSTRAINT master_sku_pkey PRIMARY KEY (master_sku_id);


--
-- Name: metric_formula_rule metric_formula_rule_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.metric_formula_rule
    ADD CONSTRAINT metric_formula_rule_pkey PRIMARY KEY (metric_rule_id);


--
-- Name: platform platform_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.platform
    ADD CONSTRAINT platform_pkey PRIMARY KEY (platform_code);


--
-- Name: platform_product_mapping platform_product_mapping_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.platform_product_mapping
    ADD CONSTRAINT platform_product_mapping_pkey PRIMARY KEY (mapping_id);


--
-- Name: platform_sku_mapping platform_sku_mapping_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.platform_sku_mapping
    ADD CONSTRAINT platform_sku_mapping_pkey PRIMARY KEY (mapping_id);


--
-- Name: product_line product_line_pkey; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.product_line
    ADD CONSTRAINT product_line_pkey PRIMARY KEY (product_line_id);


--
-- Name: product_line product_line_product_line_code_key; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.product_line
    ADD CONSTRAINT product_line_product_line_code_key UNIQUE (product_line_code);


--
-- Name: product_line product_line_product_line_name_key; Type: CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.product_line
    ADD CONSTRAINT product_line_product_line_name_key UNIQUE (product_line_name);


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
-- Name: idx_daily_action_item_date; Type: INDEX; Schema: mart; Owner: postgres
--

CREATE INDEX idx_daily_action_item_date ON mart.daily_action_item USING btree (current_end_date, item_type, status);


--
-- Name: uk_anomaly_event_dedup; Type: INDEX; Schema: mart; Owner: postgres
--

CREATE UNIQUE INDEX uk_anomaly_event_dedup ON mart.anomaly_event USING btree (platform_code, COALESCE(shop_name, ''::text), domain_key, COALESCE(entity_id, ''::text), COALESCE(scope_key, ''::text), metric_key, anomaly_type, current_start_date, current_end_date, rule_version);


--
-- Name: uk_daily_action_dedup; Type: INDEX; Schema: mart; Owner: postgres
--

CREATE UNIQUE INDEX uk_daily_action_dedup ON mart.daily_action_item USING btree (platform_code, COALESCE(shop_name, ''::text), domain_key, COALESCE(entity_id, ''::text), item_type, COALESCE(source_anomaly_code, ''::text), COALESCE(source_opportunity_code, ''::text), current_start_date, current_end_date);


--
-- Name: uk_opportunity_dedup; Type: INDEX; Schema: mart; Owner: postgres
--

CREATE UNIQUE INDEX uk_opportunity_dedup ON mart.opportunity_event USING btree (platform_code, COALESCE(shop_name, ''::text), domain_key, COALESCE(entity_id, ''::text), COALESCE(scope_key, ''::text), COALESCE(opportunity_code, ''::text), current_start_date, current_end_date);


--
-- Name: uk_ppm_active_from; Type: INDEX; Schema: meta; Owner: postgres
--

CREATE UNIQUE INDEX uk_ppm_active_from ON meta.platform_product_mapping USING btree (platform_code, shop_id, platform_product_id, valid_from) WHERE enabled;


--
-- Name: master_product trg_audit_master_product; Type: TRIGGER; Schema: meta; Owner: postgres
--

CREATE TRIGGER trg_audit_master_product AFTER INSERT OR UPDATE ON meta.master_product FOR EACH ROW EXECUTE FUNCTION meta.audit_masterdata();


--
-- Name: platform_product_mapping trg_audit_ppm; Type: TRIGGER; Schema: meta; Owner: postgres
--

CREATE TRIGGER trg_audit_ppm AFTER INSERT OR UPDATE ON meta.platform_product_mapping FOR EACH ROW EXECUTE FUNCTION meta.audit_mapping();


--
-- Name: platform_sku_mapping trg_audit_psm; Type: TRIGGER; Schema: meta; Owner: postgres
--

CREATE TRIGGER trg_audit_psm AFTER INSERT OR UPDATE ON meta.platform_sku_mapping FOR EACH ROW EXECUTE FUNCTION meta.audit_mapping();


--
-- Name: master_product trg_master_product_code; Type: TRIGGER; Schema: meta; Owner: postgres
--

CREATE TRIGGER trg_master_product_code BEFORE INSERT ON meta.master_product FOR EACH ROW EXECUTE FUNCTION meta.gen_master_product_code();


--
-- Name: master_sku trg_master_sku_code; Type: TRIGGER; Schema: meta; Owner: postgres
--

CREATE TRIGGER trg_master_sku_code BEFORE INSERT ON meta.master_sku FOR EACH ROW EXECUTE FUNCTION meta.gen_master_sku_code();


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
-- Name: anomaly_event anomaly_event_anomaly_type_fkey; Type: FK CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.anomaly_event
    ADD CONSTRAINT anomaly_event_anomaly_type_fkey FOREIGN KEY (anomaly_type) REFERENCES mart.anomaly_rule(rule_code);


--
-- Name: anomaly_event anomaly_event_parent_anomaly_event_id_fkey; Type: FK CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.anomaly_event
    ADD CONSTRAINT anomaly_event_parent_anomaly_event_id_fkey FOREIGN KEY (parent_anomaly_event_id) REFERENCES mart.anomaly_event(anomaly_event_id);


--
-- Name: diagnostic_result diagnostic_result_diagnostic_code_fkey; Type: FK CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.diagnostic_result
    ADD CONSTRAINT diagnostic_result_diagnostic_code_fkey FOREIGN KEY (diagnostic_code) REFERENCES mart.diagnostic_type(diagnostic_code);


--
-- Name: diagnostic_result diagnostic_result_source_anomaly_event_id_fkey; Type: FK CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.diagnostic_result
    ADD CONSTRAINT diagnostic_result_source_anomaly_event_id_fkey FOREIGN KEY (source_anomaly_event_id) REFERENCES mart.anomaly_event(anomaly_event_id);


--
-- Name: opportunity_event opportunity_event_opportunity_code_fkey; Type: FK CONSTRAINT; Schema: mart; Owner: postgres
--

ALTER TABLE ONLY mart.opportunity_event
    ADD CONSTRAINT opportunity_event_opportunity_code_fkey FOREIGN KEY (opportunity_code) REFERENCES mart.opportunity_type(opportunity_code);


--
-- Name: field_mapping fk_field_mapping_sheet; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.field_mapping
    ADD CONSTRAINT fk_field_mapping_sheet FOREIGN KEY (source_sheet_name) REFERENCES meta.source_sheet_mapping(source_sheet_name);


--
-- Name: master_product_alias master_product_alias_master_product_id_fkey; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_product_alias
    ADD CONSTRAINT master_product_alias_master_product_id_fkey FOREIGN KEY (master_product_id) REFERENCES meta.master_product(master_product_id);


--
-- Name: master_product master_product_merged_into_master_product_id_fkey; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_product
    ADD CONSTRAINT master_product_merged_into_master_product_id_fkey FOREIGN KEY (merged_into_master_product_id) REFERENCES meta.master_product(master_product_id);


--
-- Name: master_product master_product_product_line_id_fkey; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_product
    ADD CONSTRAINT master_product_product_line_id_fkey FOREIGN KEY (product_line_id) REFERENCES meta.product_line(product_line_id);


--
-- Name: master_sku_alias master_sku_alias_master_sku_id_fkey; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_sku_alias
    ADD CONSTRAINT master_sku_alias_master_sku_id_fkey FOREIGN KEY (master_sku_id) REFERENCES meta.master_sku(master_sku_id);


--
-- Name: master_sku master_sku_master_product_id_fkey; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.master_sku
    ADD CONSTRAINT master_sku_master_product_id_fkey FOREIGN KEY (master_product_id) REFERENCES meta.master_product(master_product_id);


--
-- Name: platform_product_mapping platform_product_mapping_master_product_id_fkey; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.platform_product_mapping
    ADD CONSTRAINT platform_product_mapping_master_product_id_fkey FOREIGN KEY (master_product_id) REFERENCES meta.master_product(master_product_id);


--
-- Name: platform_product_mapping platform_product_mapping_shop_id_fkey; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.platform_product_mapping
    ADD CONSTRAINT platform_product_mapping_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: platform_sku_mapping platform_sku_mapping_master_product_id_fkey; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.platform_sku_mapping
    ADD CONSTRAINT platform_sku_mapping_master_product_id_fkey FOREIGN KEY (master_product_id) REFERENCES meta.master_product(master_product_id);


--
-- Name: platform_sku_mapping platform_sku_mapping_master_sku_id_fkey; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.platform_sku_mapping
    ADD CONSTRAINT platform_sku_mapping_master_sku_id_fkey FOREIGN KEY (master_sku_id) REFERENCES meta.master_sku(master_sku_id);


--
-- Name: platform_sku_mapping platform_sku_mapping_shop_id_fkey; Type: FK CONSTRAINT; Schema: meta; Owner: postgres
--

ALTER TABLE ONLY meta.platform_sku_mapping
    ADD CONSTRAINT platform_sku_mapping_shop_id_fkey FOREIGN KEY (shop_id) REFERENCES meta.shop(shop_id);


--
-- Name: SCHEMA audit; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA audit TO ecommerce_importer;
GRANT USAGE ON SCHEMA audit TO agent_readonly;
GRANT USAGE ON SCHEMA audit TO ecommerce_masterdata_admin;


--
-- Name: SCHEMA core; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA core TO ecommerce_importer;
GRANT USAGE ON SCHEMA core TO ecommerce_masterdata_admin;


--
-- Name: SCHEMA mart; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA mart TO agent_readonly;


--
-- Name: SCHEMA meta; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA meta TO ecommerce_importer;
GRANT USAGE ON SCHEMA meta TO agent_readonly;
GRANT USAGE ON SCHEMA meta TO ecommerce_masterdata_admin;


--
-- Name: SCHEMA stg; Type: ACL; Schema: -; Owner: postgres
--

GRANT USAGE ON SCHEMA stg TO ecommerce_importer;


--
-- Name: FUNCTION _diag_account(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart._diag_account(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) FROM PUBLIC;


--
-- Name: FUNCTION _diag_carrier(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart._diag_carrier(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) FROM PUBLIC;


--
-- Name: FUNCTION _diag_category(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_category_level integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart._diag_category(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_category_level integer) FROM PUBLIC;


--
-- Name: FUNCTION _diag_product(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_id text, p_entity_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart._diag_product(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_entity_id text, p_entity_name text) FROM PUBLIC;


--
-- Name: FUNCTION _diag_scope(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart._diag_scope(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date, p_scope_key text) FROM PUBLIC;


--
-- Name: FUNCTION _diag_shop(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart._diag_shop(p_shop_name text, p_cs date, p_ce date, p_ps date, p_pe date) FROM PUBLIC;


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
-- Name: FUNCTION compare_advertising_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.compare_advertising_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.compare_advertising_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) TO agent_readonly;


--
-- Name: FUNCTION compare_business_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.compare_business_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.compare_business_period(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) TO agent_readonly;


--
-- Name: FUNCTION compare_platform_business(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.compare_platform_business(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.compare_platform_business(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) TO agent_readonly;


--
-- Name: FUNCTION decompose_master_product_by_shop_product(p_master_product_id bigint, p_start_date date, p_end_date date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.decompose_master_product_by_shop_product(p_master_product_id bigint, p_start_date date, p_end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.decompose_master_product_by_shop_product(p_master_product_id bigint, p_start_date date, p_end_date date) TO agent_readonly;


--
-- Name: FUNCTION decompose_platform_change_by_shop(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.decompose_platform_change_by_shop(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.decompose_platform_change_by_shop(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) TO agent_readonly;


--
-- Name: FUNCTION detect_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.detect_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text) FROM PUBLIC;


--
-- Name: FUNCTION detect_growth_opportunities(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.detect_growth_opportunities(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_shop_name text) FROM PUBLIC;


--
-- Name: FUNCTION diagnose_anomaly(p_anomaly_event_id bigint); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.diagnose_anomaly(p_anomaly_event_id bigint) FROM PUBLIC;


--
-- Name: FUNCTION diagnose_entity(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text, p_anomaly_event_id bigint); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.diagnose_entity(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text, p_anomaly_event_id bigint) FROM PUBLIC;


--
-- Name: FUNCTION format_percent_2(value_decimal numeric); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.format_percent_2(value_decimal numeric) FROM PUBLIC;


--
-- Name: FUNCTION generate_daily_action_items(p_platform_code text, p_start_date date, p_end_date date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.generate_daily_action_items(p_platform_code text, p_start_date date, p_end_date date) FROM PUBLIC;


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
-- Name: FUNCTION get_advertising_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_advertising_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_advertising_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text) TO agent_readonly;


--
-- Name: FUNCTION get_advertising_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_advertising_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_advertising_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_scope_key text) TO agent_readonly;


--
-- Name: FUNCTION get_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_entity_name text, p_severity text, p_status text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_entity_name text, p_severity text, p_status text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_anomalies(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_entity_name text, p_severity text, p_status text) TO agent_readonly;


--
-- Name: FUNCTION get_anomaly_summary(p_platform_code text, p_start_date date, p_end_date date, p_status text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_anomaly_summary(p_platform_code text, p_start_date date, p_end_date date, p_status text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_anomaly_summary(p_platform_code text, p_start_date date, p_end_date date, p_status text) TO agent_readonly;


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
-- Name: FUNCTION get_business_report(p_start_date date, p_end_date date); Type: ACL; Schema: mart; Owner: postgres
--

GRANT ALL ON FUNCTION mart.get_business_report(p_start_date date, p_end_date date) TO agent_readonly;


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
-- Name: FUNCTION get_daily_action_list(p_platform_code text, p_start_date date, p_end_date date, p_item_type text, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_daily_action_list(p_platform_code text, p_start_date date, p_end_date date, p_item_type text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_daily_action_list(p_platform_code text, p_start_date date, p_end_date date, p_item_type text, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION get_daily_business_brief(p_platform_code text, p_start_date date, p_end_date date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_daily_business_brief(p_platform_code text, p_start_date date, p_end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_daily_business_brief(p_platform_code text, p_start_date date, p_end_date date) TO agent_readonly;


--
-- Name: FUNCTION get_daily_opportunity_priorities(p_platform_code text, p_start_date date, p_end_date date, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_daily_opportunity_priorities(p_platform_code text, p_start_date date, p_end_date date, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_daily_opportunity_priorities(p_platform_code text, p_start_date date, p_end_date date, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION get_daily_risk_priorities(p_platform_code text, p_start_date date, p_end_date date, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_daily_risk_priorities(p_platform_code text, p_start_date date, p_end_date date, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_daily_risk_priorities(p_platform_code text, p_start_date date, p_end_date date, p_limit integer) TO agent_readonly;


--
-- Name: FUNCTION get_data_coverage(p_shop_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_data_coverage(p_shop_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_data_coverage(p_shop_name text) TO agent_readonly;


--
-- Name: FUNCTION get_diagnostic_entity_metrics(p_domain_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_diagnostic_entity_metrics(p_domain_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_diagnostic_entity_metrics(p_domain_key text) TO agent_readonly;


--
-- Name: FUNCTION get_diagnostic_result(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_status text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_diagnostic_result(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_status text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_diagnostic_result(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_status text) TO agent_readonly;


--
-- Name: FUNCTION get_diagnostic_snapshot(p_shop_name text, p_start_date date, p_end_date date, p_domain_key text, p_scope_key text, p_entity_id text, p_entity_name text, p_category_level integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_diagnostic_snapshot(p_shop_name text, p_start_date date, p_end_date date, p_domain_key text, p_scope_key text, p_entity_id text, p_entity_name text, p_category_level integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_diagnostic_snapshot(p_shop_name text, p_start_date date, p_end_date date, p_domain_key text, p_scope_key text, p_entity_id text, p_entity_name text, p_category_level integer) TO agent_readonly;


--
-- Name: FUNCTION get_diagnostic_supported_metrics(); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_diagnostic_supported_metrics() FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_diagnostic_supported_metrics() TO agent_readonly;


--
-- Name: FUNCTION get_entity_anomalies(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_entity_anomalies(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_entity_anomalies(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date) TO agent_readonly;


--
-- Name: FUNCTION get_entity_opportunity(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_entity_opportunity(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_entity_opportunity(p_platform_code text, p_domain_key text, p_entity_name text, p_start_date date, p_end_date date) TO agent_readonly;


--
-- Name: FUNCTION get_funnel_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_funnel_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_funnel_diagnosis(p_domain_key text, p_entity_name text, p_start_date date, p_end_date date, p_shop_name text, p_scope_key text) TO agent_readonly;


--
-- Name: FUNCTION get_growth_opportunities(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_opportunity_code text, p_min_level text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_growth_opportunities(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_opportunity_code text, p_min_level text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_growth_opportunities(p_platform_code text, p_start_date date, p_end_date date, p_domain_key text, p_opportunity_code text, p_min_level text) TO agent_readonly;


--
-- Name: FUNCTION get_master_product_members(p_master_product_id bigint); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_master_product_members(p_master_product_id bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_master_product_members(p_master_product_id bigint) TO agent_readonly;


--
-- Name: FUNCTION get_master_product_period_summary(p_master_product_id bigint, p_start_date date, p_end_date date, p_shop_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_master_product_period_summary(p_master_product_id bigint, p_start_date date, p_end_date date, p_shop_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_master_product_period_summary(p_master_product_id bigint, p_start_date date, p_end_date date, p_shop_name text) TO agent_readonly;


--
-- Name: FUNCTION get_masterdata_quality(p_start_date date, p_end_date date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_masterdata_quality(p_start_date date, p_end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_masterdata_quality(p_start_date date, p_end_date date) TO agent_readonly;


--
-- Name: FUNCTION get_opportunity_summary(p_platform_code text, p_start_date date, p_end_date date, p_status text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_opportunity_summary(p_platform_code text, p_start_date date, p_end_date date, p_status text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_opportunity_summary(p_platform_code text, p_start_date date, p_end_date date, p_status text) TO agent_readonly;


--
-- Name: FUNCTION get_platform_business_period_summary(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_platform_business_period_summary(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_platform_business_period_summary(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text) TO agent_readonly;


--
-- Name: FUNCTION get_platform_diagnostic_snapshot(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_platform_diagnostic_snapshot(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_platform_diagnostic_snapshot(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text) TO agent_readonly;


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
-- Name: FUNCTION get_product_line_members(p_product_line_name text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_product_line_members(p_product_line_name text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_product_line_members(p_product_line_name text) TO agent_readonly;


--
-- Name: FUNCTION get_product_line_period_summary(p_product_line_name text, p_start_date date, p_end_date date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_product_line_period_summary(p_product_line_name text, p_start_date date, p_end_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_product_line_period_summary(p_product_line_name text, p_start_date date, p_end_date date) TO agent_readonly;


--
-- Name: FUNCTION get_product_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_product_id text, p_product_name text, p_carrier_type text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_product_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_product_id text, p_product_name text, p_carrier_type text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_product_period_summary(p_shop_name text, p_start_date date, p_end_date date, p_product_id text, p_product_name text, p_carrier_type text) TO agent_readonly;


--
-- Name: FUNCTION get_shop_contribution(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.get_shop_contribution(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.get_shop_contribution(p_platform_code text, p_start_date date, p_end_date date, p_scope_key text, p_metric_key text) TO agent_readonly;


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
-- Name: FUNCTION rank_master_products(p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.rank_master_products(p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.rank_master_products(p_start_date date, p_end_date date, p_metric_key text, p_sort_by text, p_sort_direction text, p_limit integer) TO agent_readonly;


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
-- Name: FUNCTION resolve_diagnostic_period(p_period_key text, p_end_date date, p_current_days integer); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.resolve_diagnostic_period(p_period_key text, p_end_date date, p_current_days integer) FROM PUBLIC;


--
-- Name: FUNCTION resolve_master_product(p_platform_code text, p_shop_name text, p_platform_product_id text, p_biz_date date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.resolve_master_product(p_platform_code text, p_shop_name text, p_platform_product_id text, p_biz_date date) FROM PUBLIC;
GRANT ALL ON FUNCTION mart.resolve_master_product(p_platform_code text, p_shop_name text, p_platform_product_id text, p_biz_date date) TO agent_readonly;


--
-- Name: FUNCTION resolve_scope(p_scope character varying); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.resolve_scope(p_scope character varying) FROM PUBLIC;


--
-- Name: FUNCTION scope_daily(p_scope character varying, p_date_from date, p_date_to date); Type: ACL; Schema: mart; Owner: postgres
--

REVOKE ALL ON FUNCTION mart.scope_daily(p_scope character varying, p_date_from date, p_date_to date) FROM PUBLIC;


--
-- Name: TABLE ai_diagnosis_run; Type: ACL; Schema: audit; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE audit.ai_diagnosis_run TO ecommerce_importer;


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
-- Name: TABLE masterdata_change_log; Type: ACL; Schema: audit; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE audit.masterdata_change_log TO ecommerce_importer;
GRANT SELECT ON TABLE audit.masterdata_change_log TO agent_readonly;
GRANT SELECT,INSERT ON TABLE audit.masterdata_change_log TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE masterdata_change_log_change_id_seq; Type: ACL; Schema: audit; Owner: postgres
--

GRANT USAGE ON SEQUENCE audit.masterdata_change_log_change_id_seq TO ecommerce_masterdata_admin;


--
-- Name: TABLE douyin_account_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_account_daily TO ecommerce_importer;
GRANT SELECT ON TABLE core.douyin_account_daily TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE douyin_account_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_account_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_audience_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_audience_daily TO ecommerce_importer;
GRANT SELECT ON TABLE core.douyin_audience_daily TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE douyin_audience_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_audience_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_carrier_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_carrier_daily TO ecommerce_importer;
GRANT SELECT ON TABLE core.douyin_carrier_daily TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE douyin_carrier_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_carrier_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_category_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_category_daily TO ecommerce_importer;
GRANT SELECT ON TABLE core.douyin_category_daily TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE douyin_category_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_category_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_content_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_content_daily TO ecommerce_importer;
GRANT SELECT ON TABLE core.douyin_content_daily TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE douyin_content_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_content_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_deal_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_deal_daily TO ecommerce_importer;
GRANT SELECT ON TABLE core.douyin_deal_daily TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE douyin_deal_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_deal_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_price_band_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_price_band_daily TO ecommerce_importer;
GRANT SELECT ON TABLE core.douyin_price_band_daily TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE douyin_price_band_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_price_band_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_product_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_product_daily TO ecommerce_importer;
GRANT SELECT ON TABLE core.douyin_product_daily TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE douyin_product_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_product_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE douyin_terminal_daily; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE core.douyin_terminal_daily TO ecommerce_importer;
GRANT SELECT ON TABLE core.douyin_terminal_daily TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE douyin_terminal_daily_row_id_seq; Type: ACL; Schema: core; Owner: postgres
--

GRANT SELECT,USAGE ON SEQUENCE core.douyin_terminal_daily_row_id_seq TO ecommerce_importer;


--
-- Name: TABLE shop; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.shop TO ecommerce_importer;
GRANT SELECT ON TABLE meta.shop TO agent_readonly;
GRANT SELECT ON TABLE meta.shop TO ecommerce_masterdata_admin;


--
-- Name: TABLE analysis_metric_whitelist; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.analysis_metric_whitelist TO agent_readonly;


--
-- Name: TABLE anomaly_event; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.anomaly_event TO agent_readonly;


--
-- Name: TABLE anomaly_rule; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.anomaly_rule TO agent_readonly;


--
-- Name: TABLE daily_action_item; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.daily_action_item TO agent_readonly;


--
-- Name: TABLE diagnostic_result; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.diagnostic_result TO agent_readonly;


--
-- Name: TABLE diagnostic_type; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.diagnostic_type TO agent_readonly;


--
-- Name: TABLE mart_dimension_rule; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.mart_dimension_rule TO agent_readonly;


--
-- Name: TABLE metric_formula_rule; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.metric_formula_rule TO ecommerce_importer;


--
-- Name: TABLE opportunity_event; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.opportunity_event TO agent_readonly;


--
-- Name: TABLE opportunity_rule; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.opportunity_rule TO agent_readonly;


--
-- Name: TABLE opportunity_type; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.opportunity_type TO agent_readonly;


--
-- Name: TABLE priority_entity_weight; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.priority_entity_weight TO agent_readonly;


--
-- Name: TABLE master_product; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.master_product TO ecommerce_importer;
GRANT SELECT ON TABLE meta.master_product TO agent_readonly;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE meta.master_product TO ecommerce_masterdata_admin;


--
-- Name: TABLE platform_product_mapping; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.platform_product_mapping TO ecommerce_importer;
GRANT SELECT ON TABLE meta.platform_product_mapping TO agent_readonly;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE meta.platform_product_mapping TO ecommerce_masterdata_admin;


--
-- Name: TABLE product_mapping_conflicts; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.product_mapping_conflicts TO agent_readonly;


--
-- Name: TABLE product_line; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.product_line TO ecommerce_importer;
GRANT SELECT ON TABLE meta.product_line TO agent_readonly;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE meta.product_line TO ecommerce_masterdata_admin;


--
-- Name: TABLE stage3_expected_scope_map; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.stage3_expected_scope_map TO agent_readonly;


--
-- Name: TABLE unmapped_products; Type: ACL; Schema: mart; Owner: postgres
--

GRANT SELECT ON TABLE mart.unmapped_products TO agent_readonly;


--
-- Name: TABLE database_object_dictionary; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.database_object_dictionary TO ecommerce_importer;


--
-- Name: SEQUENCE database_object_dictionary_dictionary_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.database_object_dictionary_dictionary_id_seq TO ecommerce_masterdata_admin;


--
-- Name: TABLE field_mapping; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.field_mapping TO ecommerce_importer;


--
-- Name: SEQUENCE field_mapping_mapping_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.field_mapping_mapping_id_seq TO ecommerce_masterdata_admin;


--
-- Name: TABLE master_product_alias; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.master_product_alias TO ecommerce_importer;
GRANT SELECT ON TABLE meta.master_product_alias TO agent_readonly;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE meta.master_product_alias TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE master_product_alias_alias_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.master_product_alias_alias_id_seq TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE master_product_master_product_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.master_product_master_product_id_seq TO ecommerce_masterdata_admin;


--
-- Name: TABLE master_sku; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.master_sku TO ecommerce_importer;
GRANT SELECT ON TABLE meta.master_sku TO agent_readonly;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE meta.master_sku TO ecommerce_masterdata_admin;


--
-- Name: TABLE master_sku_alias; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.master_sku_alias TO ecommerce_importer;
GRANT SELECT ON TABLE meta.master_sku_alias TO agent_readonly;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE meta.master_sku_alias TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE master_sku_alias_alias_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.master_sku_alias_alias_id_seq TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE master_sku_master_sku_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.master_sku_master_sku_id_seq TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE metric_formula_rule_metric_rule_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.metric_formula_rule_metric_rule_id_seq TO ecommerce_masterdata_admin;


--
-- Name: TABLE platform; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.platform TO ecommerce_importer;
GRANT SELECT ON TABLE meta.platform TO agent_readonly;
GRANT SELECT ON TABLE meta.platform TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE platform_product_mapping_mapping_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.platform_product_mapping_mapping_id_seq TO ecommerce_masterdata_admin;


--
-- Name: TABLE platform_sku_mapping; Type: ACL; Schema: meta; Owner: postgres
--

GRANT SELECT ON TABLE meta.platform_sku_mapping TO ecommerce_importer;
GRANT SELECT ON TABLE meta.platform_sku_mapping TO agent_readonly;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE meta.platform_sku_mapping TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE platform_sku_mapping_mapping_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.platform_sku_mapping_mapping_id_seq TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE product_line_product_line_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.product_line_product_line_id_seq TO ecommerce_masterdata_admin;


--
-- Name: SEQUENCE shop_shop_id_seq; Type: ACL; Schema: meta; Owner: postgres
--

GRANT USAGE ON SEQUENCE meta.shop_shop_id_seq TO ecommerce_masterdata_admin;


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

