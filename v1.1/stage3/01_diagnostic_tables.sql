-- ============================================================================
-- V1.1 阶段3｜问题定位与漏斗诊断（多店兼容修订版）
-- 01_diagnostic_tables.sql（诊断结果表 + 诊断类型）
-- ============================================================================
-- 只做数据层问题定位：层级拆解 / 漏斗拆解 / 贡献拆解 / 投放诊断 / 证据链。
-- 不做增长机会、不做每日行动、不做自动因果结论。
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. 诊断类型注册（D01~D08）
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.diagnostic_type;
CREATE TABLE mart.diagnostic_type (
    diagnostic_code text PRIMARY KEY,
    diagnostic_name_cn text NOT NULL,
    description text,
    enabled boolean NOT NULL DEFAULT true
);
INSERT INTO mart.diagnostic_type (diagnostic_code, diagnostic_name_cn, description) VALUES
    ('D01_SALES_DECLINE',              '成交下降',         '销售金额下降'),
    ('D02_TRAFFIC_DECLINE',            '流量下降',         '曝光下降'),
    ('D03_CLICK_FUNNEL_DECLINE',       '点击漏斗下降',     '曝光→点击环节下降'),
    ('D04_CONVERSION_FUNNEL_DECLINE',  '转化漏斗下降',     '点击→成交环节下降'),
    ('D05_REFUND_DETERIORATION',       '退款恶化',         '退款率上升'),
    ('D06_AD_EFFICIENCY_DECLINE',      '投放效率下降',     '投放效率下降'),
    ('D07_CONTRIBUTION_DECLINE',       '贡献下降',         '贡献占比下降'),
    ('D08_MULTI_FACTOR_DECLINE',       '多因素下降',       '多环节同时下降，不强制唯一根因')
ON CONFLICT (diagnostic_code) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. 诊断结果表
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.diagnostic_result;
CREATE TABLE mart.diagnostic_result (
    diagnostic_id          bigserial PRIMARY KEY,
    -- 实体定位
    platform_code          text NOT NULL,
    shop_name              text,
    domain_key             text NOT NULL,
    entity_level           text NOT NULL,
    entity_id              text,
    entity_name            text,
    scope_key              text,
    parent_entity          text,             -- 父实体（如 platform → shop 的 platform）
    master_product_id      text,             -- 主数据域对象
    product_line_id        text,
    -- 诊断
    diagnostic_code        text REFERENCES mart.diagnostic_type(diagnostic_code),
    primary_stage          text CHECK (primary_stage IN ('traffic','click','conversion','refund','advertising','mix','contribution','unknown')),
    diagnostic_status      text NOT NULL DEFAULT 'DIAGNOSED'
        CHECK (diagnostic_status IN ('DIAGNOSED','MULTI_FACTOR','INSUFFICIENT_EVIDENCE','NO_CONFIRMED_ANOMALY',
                                     'UNSUPPORTED_DOMAIN','UNSUPPORTED_DIAGNOSTIC_PATH','COVERAGE_INCOMPLETE','MAPPING_INCOMPLETE')),
    -- 周期与数值
    current_start_date     date NOT NULL,
    current_end_date       date NOT NULL,
    previous_start_date    date,
    previous_end_date      date,
    current_value          numeric,
    previous_value         numeric,
    absolute_change        numeric,
    relative_change        numeric,
    percentage_point_change numeric,
    -- 置信度与证据
    confidence_score       numeric NOT NULL DEFAULT 0,
    evidence_json          jsonb,            -- 只写事实：current/previous/change/rank/contribution/coverage/mapping/funnel
    path_json              jsonb,            -- 层级路径 [{domain, entity}]
    diagnostic_chain_id    text,             -- 问题链稳定 ID（跨层级关联）
    source_anomaly_event_id bigint REFERENCES mart.anomaly_event(anomaly_event_id),
    -- 质量
    coverage_complete      boolean,
    mapping_complete       boolean,
    notes                  text,
    created_at             timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE mart.diagnostic_result IS
'V1.1 诊断结果（数据层问题定位）：层级/漏斗/贡献/投放拆解 + 证据链 + 置信度 + 问题链。
evidence_json 只写事实，禁止未证实业务原因。';

COMMIT;

\echo '=== 诊断类型（8 类） ==='
SELECT diagnostic_code, diagnostic_name_cn FROM mart.diagnostic_type ORDER BY diagnostic_code;
