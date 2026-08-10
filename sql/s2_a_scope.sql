-- 阶段2验收A: 12+ Scope 30天 与直接SQL合法过滤完全一致
WITH scopes AS (
  SELECT * FROM (VALUES
    ('全店'),('自营'),('合作'),('商品卡'),('短视频'),('直播'),('图文'),('其他'),
    ('自营商品卡'),('合作商品卡'),('自营短视频'),('合作短视频')
  ) v(scope_key)
),
fn_result AS (
  SELECT r.scope_key, r.user_pay_amount AS fn_amount, r.transaction_amount AS fn_txn
  FROM scopes s, LATERAL (
    SELECT scope_key, user_pay_amount, transaction_amount
    FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30', s.scope_key)
  ) r
),
sql_result AS (
  SELECT r.scope_key,
    (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
     JOIN meta.shop sh ON d.shop_id=sh.shop_id
     WHERE sh.shop_name='弹动官方旗舰店'
       AND d.sale_scope=rs.sale_scope AND d.carrier_type=rs.carrier_type
       AND d.ad_period=rs.ad_period AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30') AS sql_amount
  FROM scopes r, LATERAL mart.resolve_scope(r.scope_key) rs
)
SELECT f.scope_key,
       f.fn_amount AS fn_user_pay,
       s.sql_amount AS sql_user_pay,
       round((f.fn_amount - s.sql_amount)::numeric, 2) AS diff,
       CASE WHEN abs(f.fn_amount - s.sql_amount) < 0.01 THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM fn_result f JOIN sql_result s USING (scope_key)
ORDER BY f.scope_key;
