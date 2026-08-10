-- ============================================================================
-- V1.1 阶段2｜异常检测引擎（多店兼容修订版）
-- 01_anomaly_tables.sql（规则表 + 事件表）
-- ============================================================================
-- 只回答：哪里异常 / 多严重 / 是否持续 / 业务影响多大。
-- 不做根因、不做机会、不做优先级、不做每日行动、不做 AI 自由判断。
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. 异常规则表（8 类，阈值可配置）
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.anomaly_rule;
CREATE TABLE mart.anomaly_rule (
    rule_code        text PRIMARY KEY,
    rule_name_cn     text NOT NULL,
    metric_key       text NOT NULL,          -- 触发指标
    metric_direction text NOT NULL CHECK (metric_direction IN ('DROP','RISE')),
    low_base_metric  text,                    -- 低基数判定指标（如 user_pay_amount）
    low_base_value   numeric DEFAULT 0,       -- 低基数阈值
    threshold_relative numeric,               -- 相对变化阈值（如 0.20 = 20%）
    threshold_pp     numeric,                 -- 百分点阈值（ratio 指标用）
    severity_base    numeric DEFAULT 40,      -- 基础严重度
    enabled          boolean NOT NULL DEFAULT true,
    notes            text,
    created_at       timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE mart.anomaly_rule IS 'V1.1 异常规则（8 类；base/阈值可配置；多店/主数据域可用独立 base）。';

INSERT INTO mart.anomaly_rule
    (rule_code, rule_name_cn, metric_key, metric_direction, low_base_metric, low_base_value,
     threshold_relative, threshold_pp, severity_base, notes) VALUES
    ('A01_SALES_DROP',              '成交下降',         'user_pay_amount', 'DROP', 'user_pay_amount', 5000,  0.20, NULL,  50, '本期成交较上期下降≥20%（低基数：上期或本期≥5000）'),
    ('A02_SALES_SPIKE',             '成交飙升',         'user_pay_amount', 'RISE', 'user_pay_amount', 5000,  0.30, NULL,  40, '成交较上期上升≥30%'),
    ('A03_TRAFFIC_DROP',            '流量下降',         'product_exposure_count', 'DROP', 'product_exposure_count', 10000, 0.30, NULL, 40, '曝光次数下降≥30%（低基数：曝光≥10000）'),
    ('A04_CLICK_RATE_DROP',         '点击率下降',       'exposure_to_click_rate_users', 'DROP', 'product_exposure_user_count', 1000, 0.20, 0.02, 40, '曝光点击率下降（低基数：曝光人数≥1000）'),
    ('A05_CONVERSION_DROP',         '转化率下降',       'click_to_transaction_rate_users', 'DROP', 'product_click_user_count', 100, 0.20, 0.02, 45, '点击成交率下降（低基数：点击人数≥100）'),
    ('A06_REFUND_DETERIORATION',    '退款恶化',         'refund_rate_pay_time', 'RISE', 'transaction_order_count', 50,  0.20, 0.02, 50, '退款率上升（低基数：订单≥50；百分点≥2pp 或相对≥20%）'),
    ('A07_AD_EFFICIENCY_DETERIORATION','投放效率恶化',  'ad_efficiency_shop_promoted', 'DROP', 'ad_spend_shop_promoted', 1000, 0.20, NULL, 45, '投放效率下降（低基数：消耗≥1000；效率不用百分点）'),
    ('A08_CONTRIBUTION_DROP',       '贡献下降',         'user_pay_amount', 'DROP', 'user_pay_amount', 5000,  0.20, NULL,  40, '贡献度下降（相对贡献变化≥20%，分母=domain内总额）')
ON CONFLICT (rule_code) DO UPDATE SET
    rule_name_cn = EXCLUDED.rule_name_cn, metric_key = EXCLUDED.metric_key,
    metric_direction = EXCLUDED.metric_direction, low_base_metric = EXCLUDED.low_base_metric,
    low_base_value = EXCLUDED.low_base_value, threshold_relative = EXCLUDED.threshold_relative,
    threshold_pp = EXCLUDED.threshold_pp, severity_base = EXCLUDED.severity_base;

-- ----------------------------------------------------------------------------
-- 2. 异常事件表
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS mart.anomaly_event;
CREATE TABLE mart.anomaly_event (
    anomaly_event_id      bigserial PRIMARY KEY,
    -- 实体定位
    platform_code         text NOT NULL,
    shop_name             text,               -- NULL = 平台整体
    domain_key            text NOT NULL,
    entity_level          text NOT NULL,      -- platform/shop/scope/master_product/shop_product/product_line/carrier/account/category
    entity_id             text,
    entity_name           text,
    scope_key             text,
    -- 指标与类型
    metric_key            text NOT NULL,
    anomaly_type          text NOT NULL REFERENCES mart.anomaly_rule(rule_code),
    -- 周期
    current_start_date    date NOT NULL,
    current_end_date      date NOT NULL,
    previous_start_date   date,
    previous_end_date     date,
    -- 数值
    current_value         numeric,
    previous_value        numeric,
    absolute_change       numeric,
    relative_change       numeric,
    percentage_point_change numeric,
    -- 低基数 / 影响
    low_base_value        numeric,
    materiality           numeric,           -- 影响金额（= 相对变化 × 本期值 近似）
    -- 持续性
    triggered_period_count integer NOT NULL DEFAULT 1,
    consecutive_day_count integer NOT NULL DEFAULT 1,
    -- 严重度
    severity              text NOT NULL DEFAULT 'LOW' CHECK (severity IN ('INFO','LOW','MEDIUM','HIGH','CRITICAL')),
    severity_score        numeric NOT NULL DEFAULT 0,
    -- 质量
    coverage_complete     boolean,
    shop_coverage_complete boolean,
    mapping_complete      boolean,
    data_quality_score    numeric NOT NULL DEFAULT 80,
    diagnostic_chain_key  text,
    -- 关联
    parent_anomaly_event_id bigint REFERENCES mart.anomaly_event(anomaly_event_id),
    -- 生命周期
    status                text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','RESOLVED','SUPPRESSED')),
    rule_version          text NOT NULL DEFAULT 'v1',
    notes                 text,
    created_at            timestamptz NOT NULL DEFAULT now()
);

-- 唯一键（幂等：同输入重复检测不新增重复事件）
CREATE UNIQUE INDEX uk_anomaly_event_dedup ON mart.anomaly_event
    (platform_code, coalesce(shop_name,''), domain_key, coalesce(entity_id,''),
     coalesce(scope_key,''), metric_key, anomaly_type, current_start_date, current_end_date, rule_version);

COMMENT ON TABLE mart.anomaly_event IS 'V1.1 异常事件（只记录"哪里异常/多严重/是否持续/影响多大"；唯一键防重复；生命周期 OPEN/RESOLVED/SUPPRESSED）。';

COMMIT;

\echo '=== 异常规则（8 类） ==='
SELECT rule_code, rule_name_cn, metric_key, metric_direction, low_base_value, threshold_relative FROM mart.anomaly_rule ORDER BY rule_code;
