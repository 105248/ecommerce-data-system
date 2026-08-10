SELECT rule_status, count(*) AS cnt
FROM meta.metric_formula_rule
GROUP BY rule_status
ORDER BY cnt DESC;
