-- 阶段6.1: 18 Scope 最终一致性检查 (resolve_scope vs period_scope_rule) v2
\echo '===== 18 Scope 逐项比对 ====='
WITH scopes(scope_key) AS (
  VALUES ('全店'),('自营'),('合作'),('商品卡'),('短视频'),('直播'),('图文'),('其他'),
         ('自营商品卡'),('合作商品卡'),('自营短视频'),('合作短视频'),
         ('自营直播'),('合作直播'),('自营图文'),('合作图文'),('自营其他'),('合作其他')
)
SELECT s.scope_key,
       r1.sale_scope AS r1_sale_scope, r1.carrier_type AS r1_carrier, r1.ad_period AS r1_ad_period,
       r2.sale_scope AS r2_sale_scope, r2.carrier_type AS r2_carrier, r2.ad_period AS r2_ad_period,
       CASE WHEN r1.sale_scope = r2.sale_scope AND r1.carrier_type = r2.carrier_type AND r1.ad_period = r2.ad_period
            THEN 'OK' ELSE 'MISMATCH' END AS result
FROM scopes s
CROSS JOIN LATERAL mart.resolve_scope(s.scope_key) r1
CROSS JOIN LATERAL mart.period_scope_rule(s.scope_key) r2
ORDER BY s.scope_key;

\echo ''
\echo '===== 汇总 ====='
WITH scopes(scope_key) AS (
  VALUES ('全店'),('自营'),('合作'),('商品卡'),('短视频'),('直播'),('图文'),('其他'),
         ('自营商品卡'),('合作商品卡'),('自营短视频'),('合作短视频'),
         ('自营直播'),('合作直播'),('自营图文'),('合作图文'),('自营其他'),('合作其他')
)
SELECT count(*) AS total_scopes,
       count(*) FILTER (WHERE r1.sale_scope = r2.sale_scope AND r1.carrier_type = r2.carrier_type AND r1.ad_period = r2.ad_period) AS consistent,
       count(*) FILTER (WHERE r1.sale_scope IS DISTINCT FROM r2.sale_scope OR r1.carrier_type IS DISTINCT FROM r2.carrier_type OR r1.ad_period IS DISTINCT FROM r2.ad_period) AS inconsistent
FROM scopes s
CROSS JOIN LATERAL mart.resolve_scope(s.scope_key) r1
CROSS JOIN LATERAL mart.period_scope_rule(s.scope_key) r2;
