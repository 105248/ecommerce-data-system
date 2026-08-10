-- ============================================================================
-- V1.1 阶段1｜经营指标诊断基础层
-- 01_diagnostic_foundation.sql
-- ----------------------------------------------------------------------------
-- 内容：
--   1. mart.diagnostic_metric_rule   诊断指标注册表（31 条）
--   2. mart.diagnostic_entity_rule   诊断对象注册表（7 域，product_line=disabled）
--   3. mart.diagnostic_period_rule   诊断周期规则表（1d/3d/7d/14d/30d/custom）
--   4. mart.resolve_diagnostic_period 周期解析函数
--   5. mart.get_diagnostic_supported_metrics 指标目录
--   6. mart.get_diagnostic_entity_metrics    域指标清单
-- ----------------------------------------------------------------------------
-- 原则：本阶段只注册/登记，不做异常判定；不创建 anomaly/opportunity/priority 事件表。
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. 诊断指标注册表
-- ============================================================================
DROP TABLE IF EXISTS mart.diagnostic_metric_rule;

CREATE TABLE mart.diagnostic_metric_rule (
    metric_key                  text PRIMARY KEY,
    metric_name_cn              text NOT NULL,
    metric_group                text NOT NULL,        -- 成交/流量/售后/投放
    source_domain               text NOT NULL,        -- 指标底层来源域
    metric_type                 text NOT NULL CHECK (metric_type IN ('amount','count','average','ratio','efficiency')),
    display_format              text NOT NULL,        -- 金额/0.00%/0.00/整数
    cross_period_recalculable   boolean NOT NULL DEFAULT true,
    diagnostic_enabled          boolean NOT NULL DEFAULT true,
    higher_is_better            boolean NOT NULL DEFAULT true,
    supports_percentage_point   boolean NOT NULL DEFAULT false,
    supports_rank               boolean NOT NULL DEFAULT false,
    supports_contribution       boolean NOT NULL DEFAULT false,
    source_rule_reference       text,                 -- 引用 meta.metric_formula_rule 或 direct_sum
    notes                       text,
    created_at                  timestamptz NOT NULL DEFAULT now(),
    updated_at                  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE mart.diagnostic_metric_rule IS 'V1.1 诊断指标注册表：登记可稳定跨期比较的诊断指标及属性（类型/方向/可重算/排名/贡献），不做异常判定。';

-- 指标种子（31 条）
-- source_rule_reference 引用 meta.metric_formula_rule.metric_rule_id（deal 域 26 条中存在的规则），纯 SUM 字段标 direct_sum
INSERT INTO mart.diagnostic_metric_rule
    (metric_key, metric_name_cn, metric_group, source_domain, metric_type, display_format,
     cross_period_recalculable, diagnostic_enabled, higher_is_better, supports_percentage_point,
     supports_rank, supports_contribution, source_rule_reference, notes)
VALUES
    -- ---------- 成交类（8） ----------
    ('user_pay_amount',                '用户支付金额',           '成交', 'deal', 'amount', '金额', true, true, true,  false, true, true,  'direct_sum', '成交核心金额；白名单 business/product/account/carrier/category 可排名'),
    ('transaction_amount',             '成交金额',               '成交', 'deal', 'amount', '金额', true, true, true,  false, true, true,  'direct_sum', '订单口径成交金额'),
    ('settlement_amount',              '结算金额',               '成交', 'deal', 'amount', '金额', true, true, true,  false, true, false, 'direct_sum', '退款后结算口径'),
    ('transaction_order_count',        '成交订单数',             '成交', 'deal', 'count',  '整数', true, true, true,  false, true, false, 'direct_sum', ''),
    ('transaction_buyer_count',        '成交人数',               '成交', 'deal', 'count',  '整数', true, true, true,  false, true, false, 'direct_sum', '对应任务文档 transaction_user_count'),
    ('transaction_item_count',         '成交件数',               '成交', 'deal', 'count',  '整数', true, true, true,  false, true, false, 'direct_sum', ''),
    ('avg_customer_amount',            '客单价',                 '成交', 'deal', 'average','0.00', true, true, true,  false, true, false, 'mfr_avg_customer_amount', 'SUM(用户支付)/NULLIF(SUM(成交人数),0)'),
    ('avg_item_amount',                '件单价',                 '成交', 'deal', 'average','0.00', true, true, true,  false, true, false, 'mfr_avg_item_amount', 'SUM(用户支付)/NULLIF(SUM(成交件数),0)'),
    -- ---------- 流量/漏斗类（10） ----------
    ('product_exposure_user_count',    '商品曝光人数',           '流量', 'deal', 'count',  '整数', true, true, true,  false, false, false, 'direct_sum', ''),
    ('product_click_user_count',       '商品点击人数',           '流量', 'deal', 'count',  '整数', true, true, true,  false, false, false, 'direct_sum', ''),
    ('exposure_to_click_rate_users',   '商品曝光-点击转化率(人数)','流量','deal', 'ratio',  '0.00%', true, true, true, true, true, false, 'mfr_exposure_to_click_rate_users', 'SUM(点击人数)/NULLIF(SUM(曝光人数),0)'),
    ('click_to_transaction_rate_users','商品点击-成交转化率(人数)','流量','deal','ratio',  '0.00%', true, true, true, true, true, false, 'mfr_click_to_transaction_rate_users', 'SUM(成交人数)/NULLIF(SUM(点击人数),0)'),
    ('exposure_to_transaction_rate_users','商品曝光-成交转化率(人数)','流量','deal','ratio','0.00%', true, true, true, true, false, false, 'mfr_exposure_to_transaction_rate_users', 'SUM(成交人数)/NULLIF(SUM(曝光人数),0)'),
    ('product_exposure_count',         '商品曝光次数',           '流量', 'deal', 'count',  '整数', true, true, true,  false, false, false, 'direct_sum', ''),
    ('product_click_count',            '商品点击次数',           '流量', 'deal', 'count',  '整数', true, true, true,  false, false, false, 'direct_sum', ''),
    ('exposure_to_click_rate_events',  '商品曝光-点击转化率(次数)','流量','deal','ratio',  '0.00%', true, true, true, true, false, false, 'mfr_exposure_to_click_rate_events', 'SUM(点击次数)/NULLIF(SUM(曝光次数),0)'),
    ('click_to_transaction_rate_events','商品点击-成交转化率(次数)','流量','deal','ratio','0.00%', true, true, true, true, false, false, 'mfr_click_to_transaction_rate_events', 'SUM(成交订单数)/NULLIF(SUM(点击次数),0)'),
    ('exposure_to_transaction_rate_events','商品曝光-成交转化率(次数)','流量','deal','ratio','0.00%', true, true, true, true, false, false, 'mfr_exposure_to_transaction_rate_events', 'SUM(成交订单数)/NULLIF(SUM(曝光次数),0)'),
    -- ---------- 售后类（3） ----------
    ('transaction_refund_amount_pay_time','成交退款金额(支付时间)','售后','deal','amount','金额', true, true, false, false, false, false, 'direct_sum', ''),
    ('refund_amount_pay_time',         '退款金额(支付时间)',     '售后', 'deal', 'amount', '金额', true, true, false, false, true, true,  'direct_sum', ''),
    ('refund_rate_pay_time',           '退款率(支付时间)',       '售后', 'deal', 'ratio',  '0.00%', true, true, false, true, true, false, 'mfr_refund_rate_pay_time', 'SUM(退款金额)/NULLIF(SUM(用户支付),0)；越高越差'),
    -- ---------- 投放类（10） ----------
    ('ad_spend_shop_promoted',         '投放消耗(店铺被投)',     '投放', 'deal', 'amount', '金额', true, true, false, false, false, false, 'mfr_ad_spend_shop_promoted', ''),
    ('ad_spend_shop_bound',            '投放消耗(店铺绑定)',     '投放', 'deal', 'amount', '金额', true, true, false, false, false, false, 'mfr_ad_spend_shop_bound', ''),
    ('ad_attributed_transaction_amount','投放贡献成交金额',      '投放', 'deal', 'amount', '金额', true, true, true,  false, false, false, 'mfr_ad_attributed_transaction_amount', ''),
    ('ad_attributed_transaction_share','投放贡献成交占比',       '投放', 'deal', 'ratio',  '0.00%', true, true, true, true, false, false, 'mfr_ad_attributed_transaction_share', 'SUM(投放贡献成交)/NULLIF(SUM(成交金额),0)'),
    ('ad_spend_rate_net_refund_shop_bound','投放费比(剔除退款、店铺绑定)','投放','deal','ratio','0.00%', true, true, false, true, false, false, 'mfr_ad_spend_rate_net_refund_shop_bound', 'SUM(投放消耗绑定)/NULLIF(SUM(结算金额),0)；越高越差'),
    ('total_expense_rate_net_refund_shop_bound','综合费比(剔除退款、店铺绑定)','投放','deal','ratio','0.00%', true, true, false, true, false, false, 'mfr_total_expense_rate_net_refund_shop_bound', '加权源比率；越高越差'),
    ('ad_efficiency_shop_promoted',    '投放效率(店铺被投)',     '投放', 'deal', 'efficiency','0.00', true, true, true,  false, false, false, 'mfr_ad_efficiency_shop_promoted', 'SUM(效率*消耗)/NULLIF(SUM(消耗),0)；倍数'),
    ('ad_efficiency_shop_bound',       '投放效率(店铺绑定)',     '投放', 'deal', 'efficiency','0.00', true, true, true,  false, false, false, 'mfr_ad_efficiency_shop_bound', 'SUM(效率*消耗)/NULLIF(SUM(消耗),0)；倍数'),
    ('store_efficiency_shop_promoted', '全店效率(店铺被投)',     '投放', 'deal', 'efficiency','0.00', true, true, true,  false, false, false, 'mfr_store_efficiency_shop_promoted', 'SUM(效率*消耗)/NULLIF(SUM(消耗),0)；倍数'),
    ('store_efficiency_shop_bound',    '全店效率(店铺绑定)',     '投放', 'deal', 'efficiency','0.00', true, true, true,  false, false, false, 'mfr_store_efficiency_shop_bound', 'SUM(效率*消耗)/NULLIF(SUM(消耗),0)；倍数');

-- ============================================================================
-- 2. 诊断对象注册表
-- ============================================================================
DROP TABLE IF EXISTS mart.diagnostic_entity_rule;

CREATE TABLE mart.diagnostic_entity_rule (
    domain_key            text PRIMARY KEY,
    domain_name_cn        text NOT NULL,
    enabled               boolean NOT NULL DEFAULT true,
    entity_id_field       text,          -- 该域对象唯一标识字段（core 列名或语义）
    entity_name_field     text,          -- 展示名称字段
    supports_rank         boolean NOT NULL DEFAULT false,
    supports_contribution boolean NOT NULL DEFAULT false,
    supports_scope        boolean NOT NULL DEFAULT false,
    source_object         text NOT NULL,
    notes                 text
);

COMMENT ON TABLE mart.diagnostic_entity_rule IS 'V1.1 诊断对象注册表：登记首批智能诊断业务域及对象能力（排名/贡献/Scope）。';

INSERT INTO mart.diagnostic_entity_rule
    (domain_key, domain_name_cn, enabled, entity_id_field, entity_name_field,
     supports_rank, supports_contribution, supports_scope, source_object, notes)
VALUES
    ('shop',         '店铺整体',   true,  'shop_id',       'shop_name',       false, false, false, 'core.douyin_deal_daily',        '单店整体（全店 TOTAL），无排名/贡献/Scope'),
    ('scope',        '经营Scope',  true,  'scope_key',     'scope_name_cn',   false, true,  true,  'core.douyin_deal_daily',        '18 个经营 Scope，贡献=占全店比重'),
    ('product',      '商品',       true,  'product_id',    'product_name',    true,  true,  false, 'core.douyin_product_daily',     'carrier=全部 独立 TOTAL，不通过载体明细重建'),
    ('carrier',      '载体',       true,  'carrier_type',  'carrier_type',    true,  false, true,  'core.douyin_carrier_daily',     '载体拆分/排名，不做全店 TOTAL'),
    ('account',      '账号',       true,  'account_name',  'account_name',    true,  true,  true,  'core.douyin_account_daily',     '账号拆分；更多账号=合作聚合桶'),
    ('category',     '类目',       true,  'category_key',  'category_name',   true,  true,  false, 'core.douyin_category_daily',    '默认 L3 粒度'),
    ('product_line', '品线',       false, NULL,            NULL,              false, false, false, 'unavailable',                    'V1.0.2 品线未通过，标记 disabled');

-- ============================================================================
-- 3. 诊断周期规则表
-- ============================================================================
DROP TABLE IF EXISTS mart.diagnostic_period_rule;

CREATE TABLE mart.diagnostic_period_rule (
    period_key    text PRIMARY KEY,
    period_name_cn text NOT NULL,
    current_days  integer,        -- custom 为 NULL
    previous_rule text NOT NULL DEFAULT 'EQUAL_PRECEDING',
    notes         text
);

COMMENT ON TABLE mart.diagnostic_period_rule IS 'V1.1 诊断周期规则：当前周期与等长前置对比周期。previous_end = current_start - 1。';

INSERT INTO mart.diagnostic_period_rule (period_key, period_name_cn, current_days, previous_rule, notes) VALUES
    ('1d',    '单日',      1,  'EQUAL_PRECEDING', '当前1天 vs 紧邻前1天'),
    ('3d',    '最近3天',   3,  'EQUAL_PRECEDING', '当前3天 vs 紧邻前3天'),
    ('7d',    '最近7天',   7,  'EQUAL_PRECEDING', '当前7天 vs 紧邻前7天'),
    ('14d',   '最近14天',  14, 'EQUAL_PRECEDING', '当前14天 vs 紧邻前14天'),
    ('30d',   '最近30天',  30, 'EQUAL_PRECEDING', '当前30天 vs 紧邻前30天'),
    ('custom','自定义',    NULL, 'EQUAL_PRECEDING', '用户指定天数，等长前置');

-- ============================================================================
-- 4. 周期解析函数
-- ============================================================================
DROP FUNCTION IF EXISTS mart.resolve_diagnostic_period(text, date, integer);

CREATE FUNCTION mart.resolve_diagnostic_period(
    p_period_key text,
    p_end_date date,
    p_current_days integer DEFAULT NULL
) RETURNS TABLE (
    current_start_date date,
    current_end_date   date,
    previous_start_date date,
    previous_end_date  date,
    current_days       integer
)
LANGUAGE plpgsql
STABLE
AS $function$
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
$function$;

COMMENT ON FUNCTION mart.resolve_diagnostic_period(text,date,integer) IS 'V1.1 诊断周期解析：等长前置对比。previous_end = current_start - 1。';

-- ============================================================================
-- 5. 支持的诊断指标目录
-- ============================================================================
DROP FUNCTION IF EXISTS mart.get_diagnostic_supported_metrics();

CREATE FUNCTION mart.get_diagnostic_supported_metrics()
RETURNS TABLE (
    metric_key text, metric_name_cn text, metric_group text,
    metric_type text, display_format text,
    cross_period_recalculable boolean, diagnostic_enabled boolean,
    higher_is_better boolean, supports_percentage_point boolean,
    supports_rank boolean, supports_contribution boolean,
    source_rule_reference text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
    SELECT metric_key, metric_name_cn, metric_group, metric_type, display_format,
           cross_period_recalculable, diagnostic_enabled, higher_is_better,
           supports_percentage_point, supports_rank, supports_contribution,
           source_rule_reference
    FROM mart.diagnostic_metric_rule
    ORDER BY metric_group, metric_key;
$function$;

COMMENT ON FUNCTION mart.get_diagnostic_supported_metrics() IS 'V1.1 支持的诊断指标目录（全部已注册且 diagnostic_enabled=true 的指标）。';

-- ============================================================================
-- 6. 域-指标支持矩阵（固定口径，随各 core 表字段而定）
-- ============================================================================
DROP FUNCTION IF EXISTS mart.get_diagnostic_entity_metrics(text);

CREATE FUNCTION mart.get_diagnostic_entity_metrics(p_domain_key text)
RETURNS TABLE (
    domain_key text, metric_key text, metric_name_cn text,
    metric_group text, metric_type text, display_format text,
    diagnostic_enabled boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, mart, core, meta, audit
AS $function$
    WITH domain_support AS (
        SELECT 'shop' AS dk, metric_key FROM mart.diagnostic_metric_rule WHERE diagnostic_enabled
        UNION ALL SELECT 'scope', metric_key FROM mart.diagnostic_metric_rule WHERE diagnostic_enabled
        UNION ALL SELECT 'product', metric_key FROM mart.diagnostic_metric_rule
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
$function$;

COMMENT ON FUNCTION mart.get_diagnostic_entity_metrics(text) IS 'V1.1 指定诊断域支持的指标清单（按各 core 表实际字段能力限定）。';

COMMIT;
