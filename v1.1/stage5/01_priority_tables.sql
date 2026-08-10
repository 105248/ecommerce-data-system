-- ============================================================================
-- V1.1 阶段5｜经营优先级与每日行动清单（多店兼容修订版）
-- 01_priority_tables.sql（实体战略权重 + 每日行动项表）
-- ============================================================================
-- 只消费 Stage2/3/4 已产生的确定性事件 → 风险优先级 / 机会优先级 / 每日行动清单。
-- 不重新发明异常/诊断/机会分，不执行真实经营动作。
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. 实体战略权重（strategic weight 只影响优先级，不改变事实）
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.priority_entity_weight;
CREATE TABLE mart.priority_entity_weight (
    entity_level  text PRIMARY KEY,
    strategic_weight numeric NOT NULL DEFAULT 1.0,
    enabled       boolean NOT NULL DEFAULT true,
    notes         text,
    created_at    timestamptz NOT NULL DEFAULT now()
);
INSERT INTO mart.priority_entity_weight (entity_level, strategic_weight, notes) VALUES
    ('platform',        1.2, '平台整体战略权重略高'),
    ('shop',            1.0, ''),
    ('scope',           0.9, ''),
    ('master_product',  0.8, ''),
    ('product_line',    0.8, ''),
    ('shop_product',    0.7, ''),
    ('carrier',         0.8, ''),
    ('account',         0.6, ''),
    ('category',        0.7, '')
ON CONFLICT (entity_level) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. 每日行动项表
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.daily_action_item;
CREATE TABLE mart.daily_action_item (
    action_item_id        bigserial PRIMARY KEY,
    -- 定位
    platform_code         text NOT NULL,
    shop_name             text,
    entity_level          text NOT NULL,
    domain_key            text NOT NULL,
    entity_id             text,
    entity_name           text,
    scope_key             text,
    master_product_id     text,
    product_line_id       text,
    -- 类型与分数（risk / opportunity 分开，禁止混成一个总分）
    item_type             text NOT NULL CHECK (item_type IN ('RISK','OPPORTUNITY','WATCH')),
    source_anomaly_code   text,
    source_opportunity_code text,
    risk_priority_score   numeric,
    opportunity_priority_score numeric,
    risk_level            text CHECK (risk_level IN ('P1_URGENT','P2_HIGH','P3_MEDIUM','P4_LOW')),
    opportunity_level     text CHECK (opportunity_level IN ('O1_STRONG','O2_HIGH','O3_MEDIUM','O4_WATCH')),
    action_category       text NOT NULL,
    -- 周期
    current_start_date    date NOT NULL,
    current_end_date      date NOT NULL,
    -- 业务影响
    business_impact       numeric,
    impact_source         text,          -- stage3_impact / negative_impact_share / direct_delta / unavailable
    -- 质量
    coverage_complete     boolean,
    mapping_complete      boolean,
    diagnostic_chain_id   text,
    action_group_key      text,
    dedupe_group_key      text,
    -- 生命周期
    status                text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','WATCHING','RESOLVED','EXPIRED')),
    first_seen_date       date NOT NULL DEFAULT CURRENT_DATE,
    last_seen_date        date NOT NULL DEFAULT CURRENT_DATE,
    occurrence_count      integer NOT NULL DEFAULT 1,
    notes                 text,
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_daily_action_item_date ON mart.daily_action_item (current_end_date, item_type, status);
CREATE UNIQUE INDEX uk_daily_action_dedup ON mart.daily_action_item
    (platform_code, coalesce(shop_name,''), domain_key, coalesce(entity_id,''), item_type,
     coalesce(source_anomaly_code,''), coalesce(source_opportunity_code,''), current_start_date, current_end_date);

COMMENT ON TABLE mart.daily_action_item IS
'V1.1 每日行动项：只消费 Stage2/3/4 事件；risk/opportunity 独立优先级；chain 去重（同链仅 1 主卡）；冷却=更新原卡；禁止自动动作。';

COMMIT;

\echo '=== 实体战略权重 ==='
SELECT entity_level, strategic_weight FROM mart.priority_entity_weight ORDER BY strategic_weight DESC;
