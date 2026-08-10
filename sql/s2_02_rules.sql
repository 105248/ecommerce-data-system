-- 阶段2探查2: calculation_mode 分布 + 96条规则清单
SELECT calculation_mode, rule_status, count(*)
FROM meta.metric_formula_rule
GROUP BY 1,2 ORDER BY 1,2;

\echo ====== 全部96条规则清单 ======
SELECT metric_rule_id AS id, target_table AS tbl, target_column_name AS col,
       target_column_name_cn AS col_cn, metric_category AS cat,
       calculation_mode AS mode, cross_period_recalculable AS recalc,
       auto_use_allowed AS auto, rule_status AS st,
       COALESCE(period_formula_sql, '-') AS period_sql
FROM meta.metric_formula_rule
ORDER BY target_table, metric_rule_id;
