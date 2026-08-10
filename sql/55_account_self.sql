-- 自营账号明细构成
SELECT '自营账号全部account' AS info;
SELECT account_name, account_type, count(*) AS cnt, round(SUM(user_pay_amount),2) AS amt
FROM core.douyin_account_daily
WHERE sale_scope = '自营'
GROUP BY account_name, account_type ORDER BY amt DESC;

-- 自营: 旗舰店行 vs deal 自营总额
SELECT '自营旗舰店行 vs deal自营总额' AS info;
WITH shop_row AS (
    SELECT biz_date, user_pay_amount AS samt FROM core.douyin_account_daily
    WHERE sale_scope='自营' AND account_name='弹动官方旗舰店'
), deal_ref AS (
    SELECT biz_date, user_pay_amount AS damt FROM core.douyin_deal_daily
    WHERE sale_scope='自营' AND carrier_type='全部' AND ad_period='不限'
)
SELECT s.biz_date, s.samt AS shop_row, d.damt AS deal_ref, round(s.samt - d.damt, 2) AS diff
FROM shop_row s JOIN deal_ref d USING (biz_date)
ORDER BY s.biz_date LIMIT 3;
