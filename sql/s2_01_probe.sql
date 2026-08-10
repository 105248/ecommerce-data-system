-- 阶段2探查1: V1.4 metric_formula_rule 表结构
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='meta' AND table_name='metric_formula_rule'
ORDER BY ordinal_position;

\echo ==== 规则分类字段取值分布 ====
SELECT rule_status, agg_type, count(*) 
FROM (
  SELECT rule_status, 
    CASE WHEN agg_type IS NOT NULL THEN agg_type ELSE '(null)' END AS agg_type
  FROM meta.metric_formula_rule
) t
GROUP BY 1,2 ORDER BY 1,2;
