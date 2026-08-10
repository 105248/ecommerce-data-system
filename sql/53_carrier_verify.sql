-- 验证: 合作×短视频 更多账号 与 明细关系
-- 1. 更多账号值 vs 该组合总额(deal_daily对应) 对比
SELECT '合作×短视频: 更多账号 vs 明细求和' AS info;
WITH detail_sum AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt FROM core.douyin_carrier_daily
    WHERE sale_scope='合作' AND carrier_type='短视频' AND account_channel != '更多账号'
    GROUP BY biz_date
), bucket AS (
    SELECT biz_date, user_pay_amount AS bamt FROM core.douyin_carrier_daily
    WHERE sale_scope='合作' AND carrier_type='短视频' AND account_channel='更多账号'
), deal_ref AS (
    SELECT biz_date, user_pay_amount AS damt FROM core.douyin_deal_daily
    WHERE sale_scope='合作' AND carrier_type='短视频' AND ad_period='不限'
)
SELECT d.biz_date, b.bamt AS more_bucket, ds.amt AS detail_sum, d.damt AS deal_ref_amount,
       round(b.bamt + ds.amt - d.damt, 2) AS diff_detail_plus_bucket_vs_deal,
       round(ds.amt - d.damt, 2) AS diff_detail_vs_deal
FROM deal_ref d
JOIN bucket b USING (biz_date)
JOIN detail_sum ds USING (biz_date)
ORDER BY d.biz_date LIMIT 5;

-- 2. 自营×商品卡: 全域投放时段/标准+品牌投放/其他 与 弹动官方旗舰店 关系
SELECT '自营×商品卡 channel语义' AS info;
SELECT account_channel, count(*) AS cnt, round(SUM(user_pay_amount),2) AS amt
FROM core.douyin_carrier_daily
WHERE sale_scope='自营' AND carrier_type='商品卡'
GROUP BY account_channel ORDER BY amt DESC LIMIT 10;
