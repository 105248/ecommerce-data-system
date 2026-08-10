-- 查 whitelist 中比例/效率类指标
\pset pager off
SELECT domain_key, metric_key, metric_name_cn, value_type
FROM mart.analysis_metric_whitelist
WHERE value_type LIKE '%RATIO%' OR value_type LIKE '%RATE%' OR metric_name_cn LIKE '%率%' OR metric_name_cn LIKE '%占比%' OR metric_name_cn LIKE '%费比%' OR metric_name_cn LIKE '%效率%'
ORDER BY domain_key, metric_key;
