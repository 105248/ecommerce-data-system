-- V1.0.1: metric_rule_v14 更新为含 V1.0.1 规则
DROP VIEW IF EXISTS mart.metric_rule_v14;
CREATE VIEW mart.metric_rule_v14 AS
SELECT target_schema, target_table, target_column_name_cn, target_column_name,
       metric_category, calculation_mode, formula_cn, numerator_expression,
       denominator_expression, multiplier, single_row_formula, period_formula_sql,
       zero_denominator_rule, cross_period_recalculable, auto_use_allowed,
       rule_status, display_format, mapping_version, notes, created_at,
       verification_method, verification_period, verification_result
FROM meta.metric_formula_rule
WHERE mapping_version IN ('V1.4', 'V1.0.1');

\echo '=== metric_rule_v14 条数 (应106) ==='
SELECT count(*) FROM mart.metric_rule_v14;
