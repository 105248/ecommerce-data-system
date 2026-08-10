-- ============================================================================
-- PostgreSQL mart经营分析层 V1.0
-- 阶段3：环比 + 排名 + 贡献度分析
-- 版本：Stage3 V1.0
-- 基线：阶段2官方实施版（9个Period Function + assert_period + period_scope_rule + metric_rule_v14）
--
-- 锁定原则：
-- 1. 环比 = 本期N天 vs 紧邻之前N天；不允许自行改成同比/月环比。
-- 2. 比例指标同时返回绝对变化、相对变化率、百分点变化；百分点变化存原始比率差。
-- 3. 排名默认 user_pay_amount；其他指标必须来自白名单，禁止任意字段名拼SQL。
-- 4. 贡献度分母按业务域权威TOTAL，不强行统一；同时明确分母来源。
-- 5. 多个职责清晰的小Function，不建立万能分析Function。
-- 6. 本脚本只创建/替换 mart 层对象，不修改 core/meta/audit 业务数据。
-- ============================================================================

BEGIN;
CREATE SCHEMA IF NOT EXISTS mart;

-- ----------------------------------------------------------------------------
-- A. 前置条件检查
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_cnt bigint;
BEGIN
    IF to_regprocedure('mart.assert_period(date,date)') IS NULL THEN
        RAISE EXCEPTION '缺少阶段2函数 mart.assert_period(date,date)。';
    END IF;
    IF to_regprocedure('mart.period_scope_rule(text)') IS NULL THEN
        RAISE EXCEPTION '缺少阶段2函数 mart.period_scope_rule(text)。';
    END IF;
    IF to_regprocedure('mart.get_business_period_summary(text,date,date,text)') IS NULL THEN
        RAISE EXCEPTION '缺少阶段2函数 mart.get_business_period_summary。';
    END IF;
    IF to_regprocedure('mart.get_product_period_summary(text,date,date,text,text,text)') IS NULL THEN
        RAISE EXCEPTION '缺少阶段2商品Period Function。';
    END IF;
    IF to_regprocedure('mart.get_account_period_summary(text,date,date,text,text)') IS NULL THEN
        RAISE EXCEPTION '缺少阶段2账号Period Function。';
    END IF;
    IF to_regprocedure('mart.get_category_period_summary(text,date,date,integer,text,text,text)') IS NULL THEN
        RAISE EXCEPTION '缺少阶段2类目Period Function。';
    END IF;
    IF to_regprocedure('mart.get_price_band_period_summary(text,date,date,text)') IS NULL THEN
        RAISE EXCEPTION '缺少阶段2价格带Period Function。';
    END IF;
    IF to_regprocedure('mart.get_audience_period_summary(text,date,date,text,text)') IS NULL THEN
        RAISE EXCEPTION '缺少阶段2人群Period Function。';
    END IF;
    IF to_regclass('mart.metric_rule_v14') IS NULL THEN
        RAISE EXCEPTION '缺少阶段2只读目录 mart.metric_rule_v14。';
    END IF;

    SELECT COUNT(*) INTO v_cnt FROM mart.metric_rule_v14 WHERE mapping_version='V1.4';
    IF v_cnt <> 96 THEN
        RAISE EXCEPTION 'mart.metric_rule_v14 数量异常：实际%，期望96。', v_cnt;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- B. 分析指标白名单：后续MCP只能从这里选择指标，不接受任意字段名
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW mart.analysis_metric_whitelist AS
SELECT * FROM (VALUES
    -- domain, metric_key, 中文名, value_type, rank_allowed, contribution_allowed, default_direction
    ('business','user_pay_amount','用户支付金额','additive',TRUE,TRUE,'DESC'),
    ('business','transaction_amount','成交金额','additive',TRUE,TRUE,'DESC'),
    ('business','refund_amount_pay_time','退款金额(支付时间)','additive',TRUE,TRUE,'DESC'),
    ('business','settlement_amount','结算金额','additive',TRUE,FALSE,'DESC'),
    ('business','transaction_order_count','成交订单数','additive',TRUE,FALSE,'DESC'),
    ('business','transaction_buyer_count','成交人数','additive',TRUE,FALSE,'DESC'),
    ('business','transaction_item_count','成交件数','additive',TRUE,FALSE,'DESC'),
    ('business','avg_customer_amount','客单价','average',TRUE,FALSE,'DESC'),
    ('business','avg_item_amount','件单价','average',TRUE,FALSE,'DESC'),
    ('business','refund_rate_pay_time','退款率(支付时间)','ratio',TRUE,FALSE,'ASC'),
    ('business','exposure_to_click_rate_users','商品曝光-点击转化率(人数)','ratio',TRUE,FALSE,'DESC'),
    ('business','click_to_transaction_rate_users','商品点击-成交转化率(人数)','ratio',TRUE,FALSE,'DESC'),
    ('business','exposure_to_transaction_rate_users','商品曝光-成交转化率(人数)','ratio',TRUE,FALSE,'DESC'),
    ('business','exposure_to_click_rate_events','商品曝光-点击转化率(次数)','ratio',TRUE,FALSE,'DESC'),
    ('business','click_to_transaction_rate_events','商品点击-成交转化率(次数)','ratio',TRUE,FALSE,'DESC'),
    ('business','exposure_to_transaction_rate_events','商品曝光-成交转化率(次数)','ratio',TRUE,FALSE,'DESC'),
    ('business','user_pay_amount_per_1000_exposures','千次曝光用户支付金额','average',TRUE,FALSE,'DESC'),

    ('product','user_pay_amount','用户支付金额','additive',TRUE,TRUE,'DESC'),
    ('product','refund_amount_pay_time','退款金额(支付时间)','additive',TRUE,TRUE,'DESC'),
    ('product','refund_rate_pay_time','退款率(支付时间)','ratio',TRUE,FALSE,'ASC'),

    ('account','user_pay_amount','用户支付金额','additive',TRUE,TRUE,'DESC'),
    ('account','transaction_amount','成交金额','additive',TRUE,TRUE,'DESC'),
    ('account','refund_amount_pay_time','退款金额(支付时间)','additive',TRUE,TRUE,'DESC'),
    ('account','refund_rate_pay_time','退款率(支付时间)','ratio',TRUE,FALSE,'ASC'),
    ('account','transaction_order_count','成交订单数','additive',TRUE,FALSE,'DESC'),
    ('account','transaction_buyer_count','成交人数','additive',TRUE,FALSE,'DESC'),
    ('account','avg_customer_amount','客单价','average',TRUE,FALSE,'DESC'),

    ('carrier','user_pay_amount','用户支付金额','additive',TRUE,TRUE,'DESC'),
    ('carrier','transaction_amount','成交金额','additive',TRUE,TRUE,'DESC'),
    ('carrier','refund_amount_pay_time','退款金额(支付时间)','additive',TRUE,TRUE,'DESC'),
    ('carrier','refund_rate_pay_time','退款率(支付时间)','ratio',TRUE,FALSE,'ASC'),

    ('category','user_pay_amount','用户支付金额','additive',TRUE,TRUE,'DESC'),
    ('category','refund_amount_pay_time','退款金额(支付时间)','additive',TRUE,TRUE,'DESC'),
    ('category','refund_rate_pay_time','退款率(支付时间)','ratio',TRUE,FALSE,'ASC'),

    ('price_band','user_pay_amount','用户支付金额','additive',TRUE,TRUE,'DESC'),

    ('audience','user_pay_amount','用户支付金额','additive',TRUE,TRUE,'DESC'),
    ('audience','transaction_buyer_count','成交人数','additive',TRUE,TRUE,'DESC'),
    ('audience','transaction_order_count','成交订单数','additive',TRUE,TRUE,'DESC'),
    ('audience','avg_customer_amount','客单价','average',TRUE,FALSE,'DESC')
) AS v(domain_key, metric_key, metric_name_cn, value_type, rank_allowed, contribution_allowed, default_rank_direction);

COMMENT ON VIEW mart.analysis_metric_whitelist IS
'阶段3分析指标白名单。排名/贡献/环比禁止接受任意字段名；value_type=ratio时可计算百分点变化。';

-- ----------------------------------------------------------------------------
-- C. 上一期：本期N天 vs 紧邻之前N天
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.previous_period(
    p_start_date date,
    p_end_date date
)
RETURNS TABLE(
    current_start_date date,
    current_end_date date,
    day_count integer,
    previous_start_date date,
    previous_end_date date
)
LANGUAGE plpgsql
IMMUTABLE
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

COMMENT ON FUNCTION mart.previous_period(date,date) IS
'阶段3固定环比窗口：本期N天，对比紧邻之前N天。';

-- ----------------------------------------------------------------------------
-- D. 通用排名参数校验
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.assert_rank_args(
    p_domain_key text,
    p_metric_key text,
    p_sort_by text,
    p_sort_direction text,
    p_limit integer
)
RETURNS void
LANGUAGE plpgsql
STABLE
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

-- ----------------------------------------------------------------------------
-- E. 阶段3A：经营总览环比
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.compare_business_period(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_scope_key text,
    p_metric_key text DEFAULT 'user_pay_amount'
)
RETURNS TABLE(
    shop_name text,
    scope_key text,
    metric_key text,
    metric_name_cn text,
    value_type text,
    current_start_date date,
    current_end_date date,
    previous_start_date date,
    previous_end_date date,
    current_value numeric,
    previous_value numeric,
    absolute_change numeric,
    relative_change numeric,
    percentage_point_change numeric,
    current_coverage_complete boolean,
    previous_coverage_complete boolean,
    comparison_status text
)
LANGUAGE plpgsql
STABLE
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

COMMENT ON FUNCTION mart.compare_business_period(text,date,date,text,text) IS
'阶段3A经营环比：固定N天vs紧邻前N天；ratio同时返回percentage_point_change（原始比率差，如0.02=2个百分点）。';

-- ----------------------------------------------------------------------------
-- F. 排名函数：商品
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.rank_products(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_metric_key text DEFAULT 'user_pay_amount',
    p_sort_by text DEFAULT 'current_value',
    p_sort_direction text DEFAULT 'DESC',
    p_limit integer DEFAULT 20,
    p_product_id text DEFAULT NULL,
    p_product_name text DEFAULT NULL
)
RETURNS TABLE(
    shop_name text,
    product_id text,
    product_name text,
    metric_key text,
    metric_name_cn text,
    value_type text,
    current_start_date date,
    current_end_date date,
    previous_start_date date,
    previous_end_date date,
    current_value numeric,
    previous_value numeric,
    absolute_change numeric,
    relative_change numeric,
    percentage_point_change numeric,
    current_rank bigint,
    previous_rank bigint,
    rank_change bigint
)
LANGUAGE plpgsql
STABLE
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

-- ----------------------------------------------------------------------------
-- G. 排名函数：账号（默认排除“更多账号”等aggregate_bucket，避免把桶当达人）
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.rank_accounts(
    p_shop_name text,
    p_start_date date,
    p_end_date date,
    p_sale_scope text DEFAULT NULL,
    p_metric_key text DEFAULT 'user_pay_amount',
    p_sort_by text DEFAULT 'current_value',
    p_sort_direction text DEFAULT 'DESC',
    p_limit integer DEFAULT 20,
    p_include_aggregate_bucket boolean DEFAULT FALSE,
    p_account_name text DEFAULT NULL
)
RETURNS TABLE(
    shop_name text,sale_scope text,account_name text,account_type text,douyin_account_id text,row_semantic text,
    metric_key text,metric_name_cn text,value_type text,
    current_start_date date,current_end_date date,previous_start_date date,previous_end_date date,
    current_value numeric,previous_value numeric,absolute_change numeric,relative_change numeric,percentage_point_change numeric,
    current_rank bigint,previous_rank bigint,rank_change bigint
)
LANGUAGE plpgsql STABLE AS $$
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

-- ----------------------------------------------------------------------------
-- H. 排名函数：载体（使用deal权威TOTAL，不使用carrier_daily重建全店）
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.rank_carriers(
    p_shop_name text,p_start_date date,p_end_date date,p_sale_scope text DEFAULT '全部',
    p_metric_key text DEFAULT 'user_pay_amount',p_sort_by text DEFAULT 'current_value',p_sort_direction text DEFAULT 'DESC',p_limit integer DEFAULT 20
)
RETURNS TABLE(
    shop_name text,sale_scope text,carrier_type text,metric_key text,metric_name_cn text,value_type text,
    current_start_date date,current_end_date date,previous_start_date date,previous_end_date date,
    current_value numeric,previous_value numeric,absolute_change numeric,relative_change numeric,percentage_point_change numeric,current_rank bigint,previous_rank bigint,rank_change bigint
)
LANGUAGE plpgsql STABLE AS $$
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

-- ----------------------------------------------------------------------------
-- I. 排名函数：类目（同一category_level内部排名，父子绝不混排）
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.rank_categories(
    p_shop_name text,p_start_date date,p_end_date date,p_category_level integer DEFAULT 3,
    p_category_l1 text DEFAULT NULL,p_category_l2 text DEFAULT NULL,
    p_metric_key text DEFAULT 'user_pay_amount',p_sort_by text DEFAULT 'current_value',p_sort_direction text DEFAULT 'DESC',p_limit integer DEFAULT 20
)
RETURNS TABLE(
    shop_name text,category_level integer,category_l1 text,category_l2 text,category_l3 text,category_l4 text,
    metric_key text,metric_name_cn text,value_type text,current_start_date date,current_end_date date,previous_start_date date,previous_end_date date,
    current_value numeric,previous_value numeric,absolute_change numeric,relative_change numeric,percentage_point_change numeric,current_rank bigint,previous_rank bigint,rank_change bigint
)
LANGUAGE plpgsql STABLE AS $$
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

-- ----------------------------------------------------------------------------
-- J. 排名函数：价格带
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.rank_price_bands(
    p_shop_name text,p_start_date date,p_end_date date,p_metric_key text DEFAULT 'user_pay_amount',p_sort_by text DEFAULT 'current_value',p_sort_direction text DEFAULT 'DESC',p_limit integer DEFAULT 20
)
RETURNS TABLE(shop_name text,price_band text,metric_key text,metric_name_cn text,current_start_date date,current_end_date date,previous_start_date date,previous_end_date date,current_value numeric,previous_value numeric,absolute_change numeric,relative_change numeric,current_rank bigint,previous_rank bigint,rank_change bigint)
LANGUAGE plpgsql STABLE AS $$
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

-- ----------------------------------------------------------------------------
-- K. 排名函数：人群
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.rank_audiences(
    p_shop_name text,p_start_date date,p_end_date date,p_carrier_type text DEFAULT '全部',p_metric_key text DEFAULT 'user_pay_amount',p_sort_by text DEFAULT 'current_value',p_sort_direction text DEFAULT 'DESC',p_limit integer DEFAULT 20
)
RETURNS TABLE(shop_name text,audience_type text,carrier_type text,metric_key text,metric_name_cn text,value_type text,current_start_date date,current_end_date date,previous_start_date date,previous_end_date date,current_value numeric,previous_value numeric,absolute_change numeric,relative_change numeric,percentage_point_change numeric,current_rank bigint,previous_rank bigint,rank_change bigint)
LANGUAGE plpgsql STABLE AS $$
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

-- ----------------------------------------------------------------------------
-- L. 阶段3C：经营范围贡献度（分母固定deal全店权威TOTAL）
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_business_contribution(
    p_shop_name text,p_start_date date,p_end_date date,p_scope_key text,p_metric_key text DEFAULT 'user_pay_amount'
)
RETURNS TABLE(shop_name text,scope_key text,metric_key text,metric_name_cn text,numerator_value numeric,denominator_value numeric,denominator_source text,contribution_rate numeric)
LANGUAGE plpgsql STABLE AS $$
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

-- ----------------------------------------------------------------------------
-- M. 商品贡献度：同时给商品域贡献度与全店贡献度，明确两种分母不强行相等
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_product_contribution(
    p_shop_name text,p_start_date date,p_end_date date,p_metric_key text DEFAULT 'user_pay_amount',p_product_id text DEFAULT NULL,p_product_name text DEFAULT NULL,p_limit integer DEFAULT 100
)
RETURNS TABLE(shop_name text,product_id text,product_name text,metric_key text,metric_name_cn text,numerator_value numeric,product_domain_total numeric,contribution_to_product_domain numeric,store_total numeric,contribution_to_store numeric,denominator_note text)
LANGUAGE plpgsql STABLE AS $$
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

-- ----------------------------------------------------------------------------
-- N. 账号贡献度：分母使用deal权威scope TOTAL；自营账号覆盖不完整时明确提示
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_account_contribution(
    p_shop_name text,p_start_date date,p_end_date date,p_sale_scope text,p_metric_key text DEFAULT 'user_pay_amount',p_account_name text DEFAULT NULL,p_include_aggregate_bucket boolean DEFAULT TRUE,p_limit integer DEFAULT 100
)
RETURNS TABLE(shop_name text,sale_scope text,account_name text,row_semantic text,metric_key text,metric_name_cn text,numerator_value numeric,scope_total numeric,contribution_to_scope numeric,store_total numeric,contribution_to_store numeric,coverage_note text)
LANGUAGE plpgsql STABLE AS $$
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

-- ----------------------------------------------------------------------------
-- O. 类目贡献度：分母按同一category_level域；同时给全店占比并明确平台差异
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mart.get_category_contribution(
    p_shop_name text,p_start_date date,p_end_date date,p_category_level integer DEFAULT 3,p_category_l1 text DEFAULT NULL,p_category_l2 text DEFAULT NULL,p_metric_key text DEFAULT 'user_pay_amount',p_limit integer DEFAULT 100
)
RETURNS TABLE(shop_name text,category_level integer,category_l1 text,category_l2 text,category_l3 text,category_l4 text,metric_key text,metric_name_cn text,numerator_value numeric,category_level_total numeric,contribution_to_category_level numeric,store_total numeric,contribution_to_store numeric,denominator_note text)
LANGUAGE plpgsql STABLE AS $$
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

-- ----------------------------------------------------------------------------
-- P. Scope映射一致性基线快照（供WorkBuddy与后续MCP前检查）
--    注意：阶段1 resolve_scope() 的真实签名由本机对象决定，本脚本不盲猜调用签名。
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW mart.stage3_expected_scope_map AS
SELECT * FROM (VALUES
 ('全店','全部','全部','不限'),('自营','自营','全部','不限'),('合作','合作','全部','不限'),
 ('商品卡','全部','商品卡','不限'),('短视频','全部','短视频','不限'),('直播','全部','直播','不限'),('图文','全部','图文','不限'),('其他','全部','其他','不限'),
 ('自营商品卡','自营','商品卡','不限'),('合作商品卡','合作','商品卡','不限'),('自营短视频','自营','短视频','不限'),('合作短视频','合作','短视频','不限'),
 ('自营直播','自营','直播','不限'),('合作直播','合作','直播','不限'),('自营图文','自营','图文','不限'),('合作图文','合作','图文','不限'),
 ('自营其他','自营','其他','不限'),('合作其他','合作','其他','不限')
) v(scope_key,sale_scope,carrier_type,ad_period);

COMMENT ON VIEW mart.stage3_expected_scope_map IS
'阶段3固定Scope基线。WorkBuddy执行时须按本机阶段1 resolve_scope真实签名，将其与period_scope_rule逐条对比18/18一致；本脚本不猜测阶段1函数签名。';

-- ----------------------------------------------------------------------------
-- Q. COMMENT
-- ----------------------------------------------------------------------------
COMMENT ON FUNCTION mart.rank_products(text,date,date,text,text,text,integer,text,text) IS '商品排名/增长/下降/排名变化；默认carrier=全部的平台独立TOTAL；过滤商品时先全量排名再过滤，保留真实名次。';
COMMENT ON FUNCTION mart.rank_accounts(text,date,date,text,text,text,text,integer,boolean,text) IS '账号排名；默认排除aggregate_bucket，避免把更多账号聚合桶当具体账号。';
COMMENT ON FUNCTION mart.rank_carriers(text,date,date,text,text,text,text,integer) IS '载体排名；使用deal合法TOTAL Scope，避免carrier_daily层级重叠。';
COMMENT ON FUNCTION mart.rank_categories(text,date,date,integer,text,text,text,text,text,integer) IS '类目排名；强制同一category_level内比较，父子层级不混排。';
COMMENT ON FUNCTION mart.rank_price_bands(text,date,date,text,text,text,integer) IS '价格带排名；6个价格带已验证互斥。';
COMMENT ON FUNCTION mart.rank_audiences(text,date,date,text,text,text,text,integer) IS '人群排名；默认carrier=全部合法TOTAL。';
COMMENT ON FUNCTION mart.get_business_contribution(text,date,date,text,text) IS '经营范围贡献度；分母固定deal全店权威TOTAL。';
COMMENT ON FUNCTION mart.get_product_contribution(text,date,date,text,text,text,integer) IS '商品贡献度；同时返回product域占比与全店占比，明确分母口径。';
COMMENT ON FUNCTION mart.get_account_contribution(text,date,date,text,text,text,boolean,integer) IS '账号贡献度；分母使用deal权威scope TOTAL，自营覆盖缺口明确提示。';
COMMENT ON FUNCTION mart.get_category_contribution(text,date,date,integer,text,text,text,integer) IS '类目贡献度；类目层级域分母与deal全店分母同时返回，不强行统一平台口径。';

COMMIT;

-- ============================================================================
-- 阶段3执行后建议验收SQL（只读）
-- ============================================================================
-- 1) 核对本期N天 vs 紧邻前N天：
-- SELECT * FROM mart.previous_period('2026-06-08','2026-06-14');
-- 期望上期：2026-06-01 ~ 2026-06-07。
--
-- 2) 全店用户支付金额环比：
-- SELECT * FROM mart.compare_business_period('弹动官方旗舰店','2026-06-08','2026-06-14','全店','user_pay_amount');
--
-- 3) 退款率百分点变化：
-- SELECT * FROM mart.compare_business_period('弹动官方旗舰店','2026-06-08','2026-06-14','全店','refund_rate_pay_time');
-- percentage_point_change=0.02 表示 +2个百分点（展示层乘100）。
--
-- 4) 商品TOP20：
-- SELECT * FROM mart.rank_products('弹动官方旗舰店','2026-06-08','2026-06-14','user_pay_amount','current_value','DESC',20,NULL,NULL);
--
-- 5) 商品增长最快：
-- SELECT * FROM mart.rank_products('弹动官方旗舰店','2026-06-08','2026-06-14','user_pay_amount','relative_change','DESC',20,NULL,NULL);
--
-- 6) 商品下降最大：
-- SELECT * FROM mart.rank_products('弹动官方旗舰店','2026-06-08','2026-06-14','user_pay_amount','relative_change','ASC',20,NULL,NULL);
--
-- 7) 某商品排名变化：传product_id，函数先全量排名再过滤，不把该商品错误排名为1。
--
-- 8) 商品卡对全店贡献：
-- SELECT * FROM mart.get_business_contribution('弹动官方旗舰店','2026-06-01','2026-06-30','商品卡','user_pay_amount');
--
-- 9) 商品贡献度：
-- SELECT * FROM mart.get_product_contribution('弹动官方旗舰店','2026-06-01','2026-06-30','user_pay_amount',NULL,NULL,20);
--
-- 10) 类目贡献度：
-- SELECT * FROM mart.get_category_contribution('弹动官方旗舰店','2026-06-01','2026-06-30',3,NULL,NULL,'user_pay_amount',20);
--
-- 11) 数据保护：core仍应18809行；V1.4仍96条；12条剔除退款分母仍为settlement_amount。
