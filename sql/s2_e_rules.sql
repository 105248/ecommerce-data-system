-- 阶段2验收E: V1.4规则调用 + 剔除退款分母 + 商品卡专项 + 各域规则
\echo ===== E1. V1.4: 12条剔除退款 denominator=settlement_amount =====
SELECT count(*) AS 剔除退款规则数,
       count(*) FILTER (WHERE denominator_expression='settlement_amount') AS 分母结算金额数,
       count(*) FILTER (WHERE denominator_expression='net_transaction_amount') AS 残留净成交金额数
FROM meta.metric_formula_rule
WHERE target_column_name LIKE '%net_refund%';

\echo ===== E2. 商品卡专项: 30天 商品卡 =====
SELECT f.scope_key, f.user_pay_amount AS fn_pay, f.avg_customer_amount AS 客单价,
       (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
        JOIN meta.shop sh ON d.shop_id=sh.shop_id
        WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='商品卡'
          AND d.ad_period='不限' AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30') AS sql_pay,
       CASE WHEN abs(f.user_pay_amount - (SELECT SUM(d.user_pay_amount) FROM core.douyin_deal_daily d
                JOIN meta.shop sh ON d.shop_id=sh.shop_id
                WHERE sh.shop_name='弹动官方旗舰店' AND d.sale_scope='全部' AND d.carrier_type='商品卡'
                  AND d.ad_period='不限' AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30')) < 0.01
            THEN 'PASS' ELSE 'FAIL' END AS verdict
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','商品卡') f;

\echo ===== E3. carrier 合作域: 明细+更多账号 = 合作载体总额(30天) =====
WITH coop AS (
  SELECT account_channel, user_pay_amount
  FROM mart.get_carrier_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','合作')
),
detail AS (SELECT SUM(user_pay_amount) AS d FROM coop WHERE account_channel != '更多账号'),
agg AS (SELECT SUM(user_pay_amount) AS a FROM coop WHERE account_channel = '更多账号'),
total AS (SELECT SUM(user_pay_amount) AS t FROM coop)
SELECT d.d AS 明细和, a.a AS 更多账号, t.t AS 合作载体总额,
       CASE WHEN abs(d.d + a.a - t.t) < 0.01 THEN 'PASS(互斥可SUM)' ELSE 'FAIL' END AS verdict
FROM detail d, agg a, total t;

\echo ===== E4. terminal: 整体 TOTAL 行存在(30天, 前4) =====
SELECT terminal_type, selling_type, user_pay_amount
FROM mart.get_terminal_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30')
WHERE terminal_type='整体' ORDER BY selling_type;

\echo ===== E5. audience: TOTAL(全部) + 明细不混(30天) =====
SELECT a.carrier_type, SUM(a.user_pay_amount) AS 支付金额,
       (SELECT SUM(user_pay_amount) FROM core.douyin_audience_daily
        WHERE carrier_type='全部' AND biz_date BETWEEN '2026-06-01' AND '2026-06-30') AS 全部行,
       CASE WHEN a.carrier_type='全部' THEN 'TOTAL' ELSE 'DETAIL' END AS 类型
FROM mart.get_audience_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30') a
GROUP BY a.carrier_type ORDER BY 1;

\echo ===== E6. product: 独立TOTAL未被明细重建(30天) =====
SELECT p.carrier_type, SUM(p.user_pay_amount) AS 支付金额
FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30') p
GROUP BY p.carrier_type;

\echo ===== E7. category: L1/L2/L3 各层级行数(30天) =====
SELECT category_level, count(*) AS 行数 FROM mart.category_daily
WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30'
GROUP BY category_level ORDER BY 1;

\echo ===== E8. core 总行数 =====
SELECT (SELECT count(*) FROM core.douyin_deal_daily)+(SELECT count(*) FROM core.douyin_carrier_daily)
 +(SELECT count(*) FROM core.douyin_account_daily)+(SELECT count(*) FROM core.douyin_content_daily)
 +(SELECT count(*) FROM core.douyin_terminal_daily)+(SELECT count(*) FROM core.douyin_category_daily)
 +(SELECT count(*) FROM core.douyin_product_daily)+(SELECT count(*) FROM core.douyin_price_band_daily)
 +(SELECT count(*) FROM core.douyin_audience_daily) AS core_total;
