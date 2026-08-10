-- mart V1.0 阶段1 第一部分+第二部分：mart Schema + mart_dimension_rule
BEGIN;

-- 1. mart Schema
CREATE SCHEMA IF NOT EXISTS mart;
COMMENT ON SCHEMA mart IS '经营分析层：由core标准化日报组织为稳定可组合的经营查询接口。';

-- 2. 维度治理表
CREATE TABLE IF NOT EXISTS mart.mart_dimension_rule (
    rule_id             BIGSERIAL PRIMARY KEY,
    source_schema       VARCHAR(50) NOT NULL DEFAULT 'core',
    source_table        VARCHAR(100) NOT NULL,
    dimension_name      VARCHAR(100) NOT NULL,
    dimension_value     VARCHAR(200) NOT NULL,
    rule_type           VARCHAR(30) NOT NULL,  -- total/detail/independent_total/aggregate_bucket/special_overlap/hierarchy_total/unknown
    parent_dimension    VARCHAR(100),
    parent_value        VARCHAR(200),
    aggregation_allowed BOOLEAN NOT NULL DEFAULT TRUE,
    preferred_total     BOOLEAN NOT NULL DEFAULT FALSE,
    scope_role          VARCHAR(30) NOT NULL DEFAULT 'detail',  -- total/detail/special
    rule_status         VARCHAR(30) NOT NULL DEFAULT '已确认',
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_dim_rule UNIQUE (source_schema, source_table, dimension_name, dimension_value)
);

COMMENT ON TABLE mart.mart_dimension_rule IS 'mart维度治理表：登记TOTAL/DETAIL/独立口径/禁止汇总规则，供Scope Resolver和Daily Mart使用。';

-- 3. 登记阶段0/0.5已确认规则
INSERT INTO mart.mart_dimension_rule
    (source_table, dimension_name, dimension_value, rule_type, parent_dimension, parent_value,
     aggregation_allowed, preferred_total, scope_role, rule_status, notes)
VALUES
-- deal_daily
('douyin_deal_daily', 'sale_scope', '全部', 'total', NULL, NULL, TRUE, TRUE, 'total', '已确认', '合法TOTAL：=自营+合作(diff=0.00)'),
('douyin_deal_daily', 'sale_scope', '自营', 'detail', 'sale_scope', '全部', TRUE, FALSE, 'detail', '已确认', '明细层级'),
('douyin_deal_daily', 'sale_scope', '合作', 'detail', 'sale_scope', '全部', TRUE, FALSE, 'detail', '已确认', '明细层级'),
('douyin_deal_daily', 'carrier_type', '全部', 'total', NULL, NULL, TRUE, TRUE, 'total', '已确认', '合法TOTAL：=5载体之和(diff=0.00)'),
('douyin_deal_daily', 'carrier_type', '商品卡', 'detail', 'carrier_type', '全部', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_deal_daily', 'carrier_type', '直播', 'detail', 'carrier_type', '全部', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_deal_daily', 'carrier_type', '短视频', 'detail', 'carrier_type', '全部', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_deal_daily', 'carrier_type', '图文', 'detail', 'carrier_type', '全部', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_deal_daily', 'carrier_type', '其他', 'detail', 'carrier_type', '全部', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_deal_daily', 'ad_period', '不限', 'total', NULL, NULL, TRUE, TRUE, 'total', '已确认', '合法TOTAL：=3时段之和(diff=0.00)'),
('douyin_deal_daily', 'ad_period', '全域投放时段', 'detail', 'ad_period', '不限', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_deal_daily', 'ad_period', '标准+品牌投放', 'detail', 'ad_period', '不限', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_deal_daily', 'ad_period', '非投放时段', 'detail', 'ad_period', '不限', TRUE, FALSE, 'detail', '已确认', '明细'),
-- terminal_daily
('douyin_terminal_daily', 'terminal_type', '整体', 'total', NULL, NULL, TRUE, TRUE, 'total', '已确认', '合法TOTAL：=4终端之和(diff=0.00)'),
('douyin_terminal_daily', 'terminal_type', '抖音', 'detail', 'terminal_type', '整体', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_terminal_daily', 'terminal_type', '抖音极速版', 'detail', 'terminal_type', '整体', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_terminal_daily', 'terminal_type', '红果短剧', 'detail', 'terminal_type', '整体', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_terminal_daily', 'terminal_type', '其他', 'detail', 'terminal_type', '整体', TRUE, FALSE, 'detail', '已确认', '明细'),
-- product_daily (独立口径!)
('douyin_product_daily', 'carrier_type', '全部', 'independent_total', NULL, NULL, TRUE, TRUE, 'total', '已确认', '独立TOTAL：≠明细之和(约1万/日差)，禁止明细重建'),
('douyin_product_daily', 'carrier_type', '商品卡', 'detail', 'carrier_type', '全部', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_product_daily', 'carrier_type', '图文', 'detail', 'carrier_type', '全部', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_product_daily', 'carrier_type', '直播', 'detail', 'carrier_type', '全部', TRUE, FALSE, 'detail', '已确认', '明细'),
('douyin_product_daily', 'carrier_type', '短视频', 'detail', 'carrier_type', '全部', TRUE, FALSE, 'detail', '已确认', '明细'),
-- audience_daily
('douyin_audience_daily', 'carrier_type', '全部', 'total', NULL, NULL, TRUE, TRUE, 'total', '已确认', '合法TOTAL：60/60天匹配diff=0'),
-- account_daily
('douyin_account_daily', 'account_name', '更多账号', 'aggregate_bucket', NULL, NULL, TRUE, FALSE, 'detail', '已确认', '合作剩余桶：明细+更多账号=合作总额(diff=0.00)'),
('douyin_account_daily', 'account_name', '弹动官方旗舰店', 'detail', NULL, NULL, TRUE, FALSE, 'detail', '已确认', '自营官方账号：具体账号，非total'),
-- carrier_daily
('douyin_carrier_daily', 'account_channel', '更多账号', 'aggregate_bucket', NULL, NULL, TRUE, FALSE, 'detail', '已确认', '合作剩余桶：明细+更多账号=deal对应总额(diff=0.00)'),
('douyin_carrier_daily', 'account_channel', '全域投放时段', 'special_overlap', 'carrier_type', '商品卡', FALSE, FALSE, 'special', '已确认', 'TOTAL行(自营×商品卡305万)：禁止与其明细同时SUM'),
('douyin_carrier_daily', 'account_channel', '标准+品牌投放', 'special_overlap', 'carrier_type', '商品卡', FALSE, FALSE, 'special', '已确认', 'TOTAL行(自营×商品卡)：禁止与其明细同时SUM'),
('douyin_carrier_daily', 'account_channel', '其他', 'aggregate_bucket', NULL, NULL, TRUE, FALSE, 'detail', '已确认', '独立剩余桶(自营×商品卡30行)'),
('douyin_carrier_daily', 'account_name', '更多账号', 'aggregate_bucket', NULL, NULL, TRUE, FALSE, 'detail', '待确认', '自营更多账号语义未最终确认，不自动汇总')
ON CONFLICT (source_schema, source_table, dimension_name, dimension_value)
DO UPDATE SET rule_type = EXCLUDED.rule_type,
              aggregation_allowed = EXCLUDED.aggregation_allowed,
              preferred_total = EXCLUDED.preferred_total,
              scope_role = EXCLUDED.scope_role,
              rule_status = EXCLUDED.rule_status,
              notes = EXCLUDED.notes;

COMMIT;

-- 验证
SELECT rule_type, count(*) AS cnt
FROM mart.mart_dimension_rule
GROUP BY rule_type ORDER BY cnt DESC;
