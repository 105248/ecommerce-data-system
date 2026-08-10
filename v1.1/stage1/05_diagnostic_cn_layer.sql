-- ============================================================================
-- V1.1 阶段1｜经营指标诊断基础层
-- 05_diagnostic_cn_layer.sql（中文数据层）
-- ============================================================================
-- 新增中文 View：
--   中文数据.诊断指标规则
--   中文数据.诊断对象规则
--   中文数据.诊断周期规则
--   中文数据.经营诊断快照（快照 View：默认最近 7 天 × 店铺整体，供人工查看）
-- ============================================================================

DROP VIEW IF EXISTS 中文数据.诊断指标规则;
CREATE VIEW 中文数据.诊断指标规则 AS
SELECT metric_key          AS 指标编码,
       metric_name_cn      AS 指标名称,
       metric_group        AS 指标分组,
       source_domain       AS 来源域,
       metric_type         AS 指标类型,
       display_format      AS 展示格式,
       cross_period_recalculable AS 可跨期重算,
       diagnostic_enabled  AS 诊断启用,
       higher_is_better    AS 越高越好,
       supports_percentage_point AS 支持百分点,
       supports_rank       AS 支持排名,
       supports_contribution AS 支持贡献度,
       source_rule_reference AS 规则引用,
       notes               AS 备注
FROM mart.diagnostic_metric_rule;

DROP VIEW IF EXISTS 中文数据.诊断对象规则;
CREATE VIEW 中文数据.诊断对象规则 AS
SELECT domain_key         AS 分析域编码,
       domain_name_cn     AS 分析域名称,
       enabled            AS 启用,
       entity_id_field    AS 对象编号字段,
       entity_name_field  AS 对象名称字段,
       supports_rank      AS 支持排名,
       supports_contribution AS 支持贡献度,
       supports_scope     AS 支持Scope,
       source_object      AS 底层来源,
       notes              AS 备注
FROM mart.diagnostic_entity_rule;

DROP VIEW IF EXISTS 中文数据.诊断周期规则;
CREATE VIEW 中文数据.诊断周期规则 AS
SELECT period_key       AS 周期编码,
       period_name_cn   AS 周期名称,
       current_days     AS 当前周期天数,
       previous_rule    AS 对比规则,
       notes            AS 备注
FROM mart.diagnostic_period_rule;

DROP VIEW IF EXISTS 中文数据.经营诊断快照;
CREATE VIEW 中文数据.经营诊断快照 AS
SELECT shop_name          AS 店铺名称,
       domain_name_cn     AS 分析域,
       entity_id          AS 对象编号,
       entity_name        AS 对象名称,
       scope_key          AS 经营范围,
       metric_name_cn     AS 指标名称,
       metric_group       AS 指标分组,
       metric_type        AS 指标类型,
       current_start_date AS 本期开始,
       current_end_date   AS 本期结束,
       previous_start_date AS 上期开始,
       previous_end_date  AS 上期结束,
       current_value      AS 本期值,
       previous_value     AS 上期值,
       absolute_change    AS 绝对变化,
       relative_change    AS 相对变化,
       percentage_point_change AS 百分点变化,
       current_rank       AS 本期排名,
       previous_rank      AS 上期排名,
       rank_change        AS 排名变化,
       current_contribution AS 本期贡献度,
       previous_contribution AS 上期贡献度,
       contribution_change AS 贡献度变化,
       current_coverage_days AS 本期覆盖天数,
       previous_coverage_days AS 上期覆盖天数,
       data_status        AS 数据状态,
       notes              AS 备注
FROM mart.get_diagnostic_snapshot('弹动官方旗舰店',
       (SELECT max(biz_date) - 6 FROM core.douyin_deal_daily),
       (SELECT max(biz_date) FROM core.douyin_deal_daily),
       'shop');

COMMENT ON VIEW 中文数据.诊断指标规则 IS 'V1.1 诊断指标注册表（中文）。';
COMMENT ON VIEW 中文数据.诊断对象规则 IS 'V1.1 诊断对象注册表（中文）。';
COMMENT ON VIEW 中文数据.诊断周期规则 IS 'V1.1 诊断周期规则（中文）。';
COMMENT ON VIEW 中文数据.经营诊断快照 IS 'V1.1 经营诊断快照（默认最近7天×店铺整体，中文列）。';
