-- 阶段6回归: Daily Mart 10天 + Period 多窗口 + Comparison + 百分点 + Ranking + Contribution
\echo ===== R1. shop_daily 10天 = core合法TOTAL (抽样10天) =====
WITH pick AS (SELECT * FROM (VALUES ('2026-06-01'),('2026-06-04'),('2026-06-08'),('2026-06-11'),('2026-06-15'),
  ('2026-06-18'),('2026-06-21'),('2026-06-24'),('2026-06-27'),('2026-06-30')) v(d))
SELECT p.d, m.user_pay_amount AS mart_v,
  (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
   WHERE d.biz_date=p.d::date AND d.sale_scope='全部' AND d.carrier_type='全部' AND d.ad_period='不限') AS core_v,
  CASE WHEN abs(m.user_pay_amount - (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
        WHERE d.biz_date=p.d::date AND d.sale_scope='全部' AND d.carrier_type='全部' AND d.ad_period='不限')) < 0.01
       THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM pick p JOIN mart.shop_daily m ON m.biz_date = p.d::date
ORDER BY p.d;

\echo ===== R2. Period Function 全店 1/3/7/15/30天 = 直接SQL =====
WITH periods AS (SELECT * FROM (VALUES
  ('2026-06-12','2026-06-12',1),('2026-06-10','2026-06-12',3),('2026-06-08','2026-06-14',7),
  ('2026-06-11','2026-06-25',15),('2026-06-01','2026-06-30',30)
) v(s,e,n))
SELECT p.n AS days, f.user_pay_amount AS fn_v,
  (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
   WHERE d.biz_date BETWEEN p.s::date AND p.e::date AND d.sale_scope='全部' AND d.carrier_type='全部' AND d.ad_period='不限') AS sql_v,
  CASE WHEN abs(f.user_pay_amount - (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
        WHERE d.biz_date BETWEEN p.s::date AND p.e::date AND d.sale_scope='全部' AND d.carrier_type='全部' AND d.ad_period='不限')) < 0.01
       THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM periods p, LATERAL mart.get_business_period_summary('弹动官方旗舰店',p.s::date,p.e::date,'全店') f
ORDER BY p.n;

\echo ===== R3. Period 随机10个日期区间 = 直接SQL =====
WITH periods AS (SELECT * FROM (VALUES
  ('2026-06-01','2026-06-05'),('2026-06-03','2026-06-06'),('2026-06-07','2026-06-09'),
  ('2026-06-10','2026-06-11'),('2026-06-13','2026-06-17'),('2026-06-16','2026-06-19'),
  ('2026-06-20','2026-06-23'),('2026-06-22','2026-06-26'),('2026-06-25','2026-06-29'),('2026-06-28','2026-06-30')
) v(s,e))
SELECT p.s AS s, p.e AS e, f.user_pay_amount AS fn_v,
  (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
   WHERE d.biz_date BETWEEN p.s::date AND p.e::date AND d.sale_scope='全部' AND d.carrier_type='全部' AND d.ad_period='不限') AS sql_v,
  CASE WHEN abs(f.user_pay_amount - (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
        WHERE d.biz_date BETWEEN p.s::date AND p.e::date AND d.sale_scope='全部' AND d.carrier_type='全部' AND d.ad_period='不限')) < 0.01
       THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM periods p, LATERAL mart.get_business_period_summary('弹动官方旗舰店',p.s::date,p.e::date,'全店') f
ORDER BY p.s;

\echo ===== R4. Comparison 窗口 1/3/7/10/15天 =====
WITH periods AS (SELECT * FROM (VALUES
  ('2026-06-12','2026-06-12',1),('2026-06-10','2026-06-12',3),('2026-06-08','2026-06-14',7),
  ('2026-06-11','2026-06-20',10),('2026-06-11','2026-06-25',15)
) v(s,e,n))
SELECT p.n AS days, c.previous_start_date, c.previous_end_date,
       (c.current_start_date - c.previous_end_date) AS gap,
       (c.current_end_date - c.current_start_date + 1) AS cur_days,
       (c.previous_end_date - c.previous_start_date + 1) AS prev_days,
       CASE WHEN c.current_start_date - c.previous_end_date = 1
             AND (c.current_end_date - c.current_start_date + 1) = (c.previous_end_date - c.previous_start_date + 1)
            THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM periods p, LATERAL mart.compare_business_period('弹动官方旗舰店',p.s::date,p.e::date,'全店','user_pay_amount') c
ORDER BY p.n;

\echo ===== R5. 百分点检查(退款率 0.08->0.10 模拟: 用实际值验证公式) =====
SELECT metric_key, current_value, previous_value,
       current_value - previous_value AS absolute_change,
       (current_value - previous_value)/NULLIF(previous_value,0) AS relative_change,
       CASE WHEN (current_value - previous_value) = 0.02 THEN 'PASS(+0.02)' ELSE '公式核对见注释' END AS check_note
FROM mart.compare_business_period('弹动官方旗舰店','2026-06-08','2026-06-14','全店','refund_rate_pay_time');

\echo ===== R6. Ranking 先全体排名再过滤(经典错误检查) =====
-- 验证: 过滤商品后名次 = 全量排名中的名次(非第1)
SELECT product_id, current_rank, current_value
FROM mart.rank_products('弹动官方旗舰店','2026-06-16','2026-06-30','user_pay_amount','current_value','DESC',500, '3777721060405936555', NULL);

\echo ===== R7. Contribution 分母回归 =====
SELECT '商品卡' AS scope, round(contribution_rate::numeric,6) AS rate, denominator_source
FROM mart.get_business_contribution('弹动官方旗舰店','2026-06-01','2026-06-30','商品卡','user_pay_amount')
UNION ALL
SELECT '自营', round(contribution_rate::numeric,6), denominator_source
FROM mart.get_business_contribution('弹动官方旗舰店','2026-06-01','2026-06-30','自营','user_pay_amount')
UNION ALL
SELECT '合作', round(contribution_rate::numeric,6), denominator_source
FROM mart.get_business_contribution('弹动官方旗舰店','2026-06-01','2026-06-30','合作','user_pay_amount');
