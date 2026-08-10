-- 阶段2最终专项验收
\echo ===== F1. product: 独立TOTAL ≠ 明细之和(证明未重建) =====
WITH total_all AS (
  SELECT user_pay_amount FROM mart.get_product_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',NULL,NULL,'全部') WHERE carrier_type='全部'
),
detail_sum AS (
  SELECT SUM(user_pay_amount) AS v FROM core.douyin_product_daily d
  JOIN meta.shop s ON s.shop_id=d.shop_id
  WHERE s.shop_name='弹动官方旗舰店' AND d.carrier_type IN ('商品卡','图文','直播','短视频','其他')
    AND d.biz_date BETWEEN '2026-06-01' AND '2026-06-30'
)
SELECT (SELECT user_pay_amount FROM total_all) AS fn_all,
       (SELECT v FROM detail_sum) AS detail_sum,
       round(((SELECT user_pay_amount FROM total_all) - (SELECT v FROM detail_sum))::numeric,2) AS diff,
       CASE WHEN abs((SELECT user_pay_amount FROM total_all) - (SELECT v FROM detail_sum)) > 100 THEN 'PASS(独立TOTAL未被重建)' ELSE 'FAIL' END AS verdict;

\echo ===== F2. category L1/L2/L3 各自独立 =====
SELECT category_level, count(*) AS 行数, SUM(user_pay_amount) AS 金额合计
FROM mart.get_category_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',1,NULL,NULL,NULL)
GROUP BY category_level
UNION ALL
SELECT category_level, count(*), SUM(user_pay_amount)
FROM mart.get_category_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',2,NULL,NULL,NULL)
GROUP BY category_level
UNION ALL
SELECT category_level, count(*), SUM(user_pay_amount)
FROM mart.get_category_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',3,NULL,NULL,NULL)
GROUP BY category_level;

\echo ===== F3. terminal: 整体 TOTAL =====
SELECT terminal_type, selling_type, user_pay_amount
FROM mart.get_terminal_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30')
WHERE terminal_type='整体' ORDER BY selling_type;

\echo ===== F4. carrier: special_overlap 存在性(30天, 前4) =====
SELECT sale_scope, carrier_type, account_channel, user_pay_amount
FROM mart.get_carrier_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30')
WHERE account_channel IN ('全域投放时段','标准+品牌投放')
ORDER BY user_pay_amount DESC LIMIT 4;

\echo ===== F5. account: 更多账号=合作桶 / 旗舰店=具体账号 =====
SELECT sale_scope, account_name, SUM(user_pay_amount) AS 支付金额
FROM mart.get_account_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30')
WHERE account_name IN ('弹动官方旗舰店','更多账号') OR account_name IS NULL
GROUP BY sale_scope, account_name ORDER BY sale_scope, account_name;

\echo ===== F6. metric_rule_v14 只读目录 =====
SELECT count(*) AS 规则数 FROM mart.metric_rule_v14;
SELECT count(*) FILTER (WHERE denominator_expression='settlement_amount') AS 剔除退款分母结算,
       count(*) FILTER (WHERE calculation_mode='source_only') AS source_only
FROM mart.metric_rule_v14;

\echo ===== F7. shop_name 输出(不含shop_id) =====
SELECT shop_name, user_pay_amount FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');
