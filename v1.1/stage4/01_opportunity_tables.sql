-- ============================================================================
-- V1.1 阶段4｜增长机会发现与机会评分（多店兼容修订版）
-- 01_opportunity_tables.sql（机会类型 / 基准规则 / 机会事件）
-- ============================================================================
-- 只识别和评分增长机会候选；不生成每日行动、不做统一风险优先级、不做自动经营操作。
-- Opportunity Score = 当前确定性数据下的机会质量排序分，不是未来成功概率。
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. 机会类型（O01~O08）
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.opportunity_type;
CREATE TABLE mart.opportunity_type (
    opportunity_code text PRIMARY KEY,
    opportunity_name_cn text NOT NULL,
    description text,
    enabled boolean NOT NULL DEFAULT true
);
INSERT INTO mart.opportunity_type (opportunity_code, opportunity_name_cn, description) VALUES
    ('O01_SUSTAINED_GROWTH',              '持续增长',         '成交持续增长'),
    ('O02_CONVERSION_IMPROVEMENT',        '转化改善',         'CTR/CVR 改善 + 销售质量改善'),
    ('O03_TRAFFIC_SCALE_OPPORTUNITY',     '流量扩量信号',     '曝光偏低 + 转化高于同域 peer + 退款健康'),
    ('O04_HIGH_EFFICIENCY_AD_OPPORTUNITY','高效投放',         '投放效率高于 peer + 费比低于 peer + 规模达标'),
    ('O05_ORGANIC_GROWTH_OPPORTUNITY',    '自然增长信号',     '成交增长明显 + 投放不增长'),
    ('O06_HEALTHY_LOW_REFUND_GROWTH',     '低退款增长',       '增长 + 退款稳定/下降'),
    ('O07_CHANNEL_EXPANSION_OPPORTUNITY', '渠道扩量机会',     'scope/carrier/shop 渠道机会'),
    ('O08_CATEGORY_OR_PRODUCT_LINE_OPPORTUNITY','品线/类目机会','品线/类目机会（仅支持指标）')
ON CONFLICT (opportunity_code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. 评分维度权重 + Peer 基准规则（配置化）
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.opportunity_rule;
CREATE TABLE mart.opportunity_rule (
    rule_code          text PRIMARY KEY,          -- O01~O08
    weight_growth      numeric NOT NULL DEFAULT 20,
    weight_persistence numeric NOT NULL DEFAULT 20,
    weight_conversion  numeric NOT NULL DEFAULT 20,
    weight_refund      numeric NOT NULL DEFAULT 15,
    weight_ad_efficiency numeric NOT NULL DEFAULT 10,
    weight_materiality numeric NOT NULL DEFAULT 10,
    weight_contribution numeric NOT NULL DEFAULT 5,
    min_peer_count     integer NOT NULL DEFAULT 3,   -- 同域 peer 最少数量
    min_materiality    numeric NOT NULL DEFAULT 3000, -- 最小成交规模（低基数门槛）
    min_growth         numeric NOT NULL DEFAULT 0.15, -- 最小增长（相对）
    notes              text,
    created_at         timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE mart.opportunity_rule IS 'V1.1 机会规则：7 维权重（默认20/20/20/15/10/10/5）+ peer 最小数量 + 低基数门槛。';

INSERT INTO mart.opportunity_rule (rule_code, notes) VALUES
    ('O01_SUSTAINED_GROWTH', '持续增长：growth+persistence+materiality 为主'),
    ('O02_CONVERSION_IMPROVEMENT', '转化改善：conversion 权重高（CTR/CVR 同时改善）'),
    ('O03_TRAFFIC_SCALE_OPPORTUNITY', '流量扩量信号：conversion 高于 peer + 退款健康'),
    ('O04_HIGH_EFFICIENCY_AD_OPPORTUNITY', '高效投放：ad_efficiency 权重高 + 费比低于 peer'),
    ('O05_ORGANIC_GROWTH_OPPORTUNITY', '自然增长信号：growth 高 + 投放不增长'),
    ('O06_HEALTHY_LOW_REFUND_GROWTH', '低退款增长：growth 高 + refund 稳定/下降'),
    ('O07_CHANNEL_EXPANSION_OPPORTUNITY', '渠道扩量：scope/carrier/shop 增长+转化改善'),
    ('O08_CATEGORY_OR_PRODUCT_LINE_OPPORTUNITY', '品线/类目机会：品线持续增长（仅支持指标）')
ON CONFLICT (rule_code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. 机会事件表
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.opportunity_event;
CREATE TABLE mart.opportunity_event (
    opportunity_event_id  bigserial PRIMARY KEY,
    platform_code         text NOT NULL,
    shop_name             text,
    domain_key            text NOT NULL,
    entity_level          text NOT NULL,
    entity_id             text,
    entity_name           text,
    scope_key             text,
    master_product_id     text,
    product_line_id       text,
    opportunity_code      text REFERENCES mart.opportunity_type(opportunity_code),
    current_start_date    date NOT NULL,
    current_end_date      date NOT NULL,
    previous_start_date   date,
    previous_end_date     date,
    -- 数值与评分维度
    current_value         numeric,
    previous_value        numeric,
    relative_change       numeric,
    percentage_point_change numeric,
    growth_score          numeric,
    persistence_score     numeric,
    conversion_score      numeric,
    refund_score          numeric,
    ad_efficiency_score   numeric,
    materiality_score     numeric,
    contribution_score    numeric,
    opportunity_score     numeric NOT NULL,      -- 0-100 机会质量排序分（非成功概率）
    opportunity_level     text NOT NULL CHECK (opportunity_level IN ('LOW','MEDIUM','HIGH','STRONG')),
    available_weight      numeric NOT NULL,
    benchmark_pool        text,                  -- 同域 peer 池描述
    benchmark_peer_count  integer,
    benchmark_p50         numeric,
    benchmark_p75         numeric,
    -- 质量
    coverage_complete     boolean,
    mapping_complete      boolean,
    risk_flags            text,                  -- refund/ad_efficiency 等风险并存标记
    diagnostic_chain_id   text,
    status                text NOT NULL DEFAULT 'QUALIFIED'
        CHECK (status IN ('QUALIFIED','COVERAGE_INCOMPLETE','MAPPING_INCOMPLETE','INSUFFICIENT_PEERS',
                          'INSUFFICIENT_EVIDENCE','NEW_BASE_SIGNAL','LOW_BASE')),
    notes                 text,
    created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uk_opportunity_dedup ON mart.opportunity_event
    (platform_code, coalesce(shop_name,''), domain_key, coalesce(entity_id,''),
     coalesce(scope_key,''), opportunity_code, current_start_date, current_end_date);

COMMENT ON TABLE mart.opportunity_event IS
'V1.1 机会事件（机会质量排序分，非未来成功概率；幂等；COVERAGE/MAPPING/PEERS/WEIGHT 惩罚状态）。';

COMMIT;

\echo '=== 机会类型（8 类） ==='
SELECT opportunity_code, opportunity_name_cn FROM mart.opportunity_type ORDER BY opportunity_code;
