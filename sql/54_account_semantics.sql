-- 问题2: account_daily 语义
-- 1. account_name='弹动官方旗舰店' 行明细
SELECT '弹动官方旗舰店 行' AS info;
SELECT sale_scope, account_type, count(*) AS cnt, round(SUM(user_pay_amount),2) AS amt
FROM core.douyin_account_daily
WHERE account_name = '弹动官方旗舰店'
GROUP BY sale_scope, account_type;

-- 2. 更多账号 行
SELECT '更多账号 行' AS info;
SELECT sale_scope, account_type, count(*) AS cnt, round(SUM(user_pay_amount),2) AS amt
FROM core.douyin_account_daily
WHERE account_name = '更多账号'
GROUP BY sale_scope, account_type;

-- 3. account_type 空值 对应
SELECT 'account_type空值 明细' AS info;
SELECT sale_scope, account_name, account_type, count(*) AS cnt, round(SUM(user_pay_amount),2) AS amt
FROM core.douyin_account_daily
WHERE account_type = ''
GROUP BY sale_scope, account_name, account_type ORDER BY sale_scope, amt DESC LIMIT 10;

-- 4. 自营: 全部账号明细之和 vs 弹动官方旗舰店行
SELECT '自营账号 明细vs旗舰店行' AS info;
WITH detail_sum AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt FROM core.douyin_account_daily
    WHERE sale_scope='自营' AND account_name != '弹动官方旗舰店'
    GROUP BY biz_date
), shop_row AS (
    SELECT biz_date, user_pay_amount AS samt FROM core.douyin_account_daily
    WHERE sale_scope='自营' AND account_name='弹动官方旗舰店'
), deal_ref AS (
    SELECT biz_date, user_pay_amount AS damt FROM core.douyin_deal_daily
    WHERE sale_scope='自营' AND carrier_type='全部' AND ad_period='不限'
)
SELECT d.biz_date, s.samt AS shop_row, ds.amt AS detail_sum, d.damt AS deal_ref,
       round(s.samt + ds.amt - d.damt, 2) AS diff_sum_vs_deal
FROM deal_ref d JOIN shop_row s USING (biz_date) JOIN detail_sum ds USING (biz_date)
ORDER BY d.biz_date LIMIT 5;

-- 5. 合作: 明细+更多账号 vs deal_ref
SELECT '合作账号 明细+更多账号 vs deal' AS info;
WITH detail_sum AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt FROM core.douyin_account_daily
    WHERE sale_scope='合作' AND account_name != '更多账号'
    GROUP BY biz_date
), bucket AS (
    SELECT biz_date, user_pay_amount AS bamt FROM core.douyin_account_daily
    WHERE sale_scope='合作' AND account_name='更多账号'
), deal_ref AS (
    SELECT biz_date, user_pay_amount AS damt FROM core.douyin_deal_daily
    WHERE sale_scope='合作' AND carrier_type='全部' AND ad_period='不限'
)
SELECT d.biz_date, b.bamt, ds.amt, d.damt,
       round(b.bamt + ds.amt - d.damt, 2) AS diff
FROM deal_ref d JOIN bucket b USING (biz_date) JOIN detail_sum ds USING (biz_date)
ORDER BY d.biz_date LIMIT 5;
