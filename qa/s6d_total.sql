-- 阶段6D: TOTAL/DETAIL 口径 + 类目层级 + Scope双规则
\echo ===== D1. deal: 全部 = 自营+合作 (30天, diff应0) =====
WITH s AS (
  SELECT sale_scope, SUM(user_pay_amount) AS v FROM core.douyin_deal_daily
  WHERE carrier_type='全部' AND ad_period='不限' AND biz_date BETWEEN '2026-06-01' AND '2026-06-30'
  GROUP BY sale_scope
)
SELECT (SELECT v FROM s WHERE sale_scope='全部') AS total_all,
       (SELECT v FROM s WHERE sale_scope='自营') + (SELECT v FROM s WHERE sale_scope='合作') AS self_plus_coop,
       round(((SELECT v FROM s WHERE sale_scope='全部') - ((SELECT v FROM s WHERE sale_scope='自营') + (SELECT v FROM s WHERE sale_scope='合作')))::numeric, 2) AS diff;

\echo ===== D2. deal: 全部载体 = 5载体之和 (30天, diff应0) =====
WITH c AS (
  SELECT carrier_type, SUM(user_pay_amount) AS v FROM core.douyin_deal_daily
  WHERE sale_scope='全部' AND ad_period='不限' AND biz_date BETWEEN '2026-06-01' AND '2026-06-30'
  GROUP BY carrier_type
)
SELECT (SELECT v FROM c WHERE carrier_type='全部') AS total_all,
       (SELECT SUM(v) FROM c WHERE carrier_type IN ('商品卡','直播','短视频','图文','其他')) AS carrier_sum,
       round(((SELECT v FROM c WHERE carrier_type='全部') - (SELECT SUM(v) FROM c WHERE carrier_type IN ('商品卡','直播','短视频','图文','其他')))::numeric, 2) AS diff;

\echo ===== D3. terminal: 整体 = 明细之和 (06-01, diff应0) =====
WITH t AS (
  SELECT terminal_type, SUM(user_pay_amount) AS v FROM core.douyin_terminal_daily
  WHERE selling_type='全部' AND biz_date='2026-06-01' GROUP BY terminal_type
)
SELECT (SELECT v FROM t WHERE terminal_type='整体') AS total,
       (SELECT SUM(v) FROM t WHERE terminal_type<>'整体') AS detail_sum,
       round(((SELECT v FROM t WHERE terminal_type='整体') - (SELECT SUM(v) FROM t WHERE terminal_type<>'整体'))::numeric, 2) AS diff;

\echo ===== D4. audience: carrier=全部 = 5载体之和 (06-01, diff应0) =====
WITH a AS (
  SELECT carrier_type, SUM(user_pay_amount) AS v FROM core.douyin_audience_daily
  WHERE biz_date='2026-06-01' GROUP BY carrier_type
)
SELECT (SELECT v FROM a WHERE carrier_type='全部') AS total,
       (SELECT SUM(v) FROM a WHERE carrier_type<>'全部') AS detail_sum,
       round(((SELECT v FROM a WHERE carrier_type='全部') - (SELECT SUM(v) FROM a WHERE carrier_type<>'全部'))::numeric, 2) AS diff;

\echo ===== D5. product: 全部 独立TOTAL ≠ 明细之和 (30天, diff应>0) =====
WITH p AS (
  SELECT carrier_type, SUM(user_pay_amount) AS v FROM core.douyin_product_daily
  WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30' GROUP BY carrier_type
)
SELECT (SELECT v FROM p WHERE carrier_type='全部') AS product_total,
       (SELECT SUM(v) FROM p WHERE carrier_type IN ('商品卡','图文','直播','短视频','其他')) AS detail_sum,
       round(((SELECT v FROM p WHERE carrier_type='全部') - (SELECT SUM(v) FROM p WHERE carrier_type IN ('商品卡','图文','直播','短视频','其他')))::numeric, 2) AS diff;

\echo ===== D6. 类目层级: L1/L2/L3 各自层级行数(不应混) =====
SELECT category_level, count(*) AS rows_cnt FROM mart.category_daily
WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30'
GROUP BY category_level ORDER BY 1;

\echo ===== D7. Scope双规则一致性 (12个共同scope) =====
DO $$
DECLARE s text; v1 text; v2 text; c1 text; c2 text; p1 text; p2 text; bad int := 0;
BEGIN
  FOREACH s IN ARRAY ARRAY['全店','自营','合作','商品卡','短视频','直播','图文','其他','自营商品卡','合作商品卡','自营短视频','合作短视频']
  LOOP
    SELECT r.sale_scope||'/'||r.carrier_type||'/'||r.ad_period INTO v1 FROM mart.resolve_scope(s) r;
    SELECT p.sale_scope||'/'||p.carrier_type||'/'||p.ad_period INTO v2 FROM mart.period_scope_rule(s) p;
    IF v1 <> v2 THEN
      RAISE NOTICE '不一致: %  resolve=% rule=%', s, v1, v2; bad := bad + 1;
    END IF;
  END LOOP;
  IF bad = 0 THEN RAISE NOTICE '✅ Scope双规则 12/12 完全一致'; ELSE RAISE NOTICE '❌ 不一致 % 个', bad; END IF;
END $$;
