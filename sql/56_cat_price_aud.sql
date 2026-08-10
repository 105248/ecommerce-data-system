-- 问题3: category_daily 类目层级
-- 1. 样例行: 看每行落在哪一级
SELECT '类目路径样例' AS info;
SELECT biz_date, category_level_1, category_level_2, category_level_3, category_level_4,
       user_pay_amount
FROM core.douyin_category_daily
WHERE biz_date = '2026-06-10'
ORDER BY category_level_1, category_level_2, category_level_3, category_level_4 LIMIT 20;

-- 2. 每行类目级别判断: 哪些列非空
SELECT '类目级别分布' AS info;
SELECT
    CASE WHEN category_level_4 IS NOT NULL AND category_level_4 != '' THEN 'L4'
         WHEN category_level_3 IS NOT NULL AND category_level_3 != '' THEN 'L3'
         WHEN category_level_2 IS NOT NULL AND category_level_2 != '' THEN 'L2'
         ELSE 'L1' END AS level,
    count(*) AS cnt
FROM core.douyin_category_daily
GROUP BY 1 ORDER BY 1;

-- 3. 父子类目并存检测
SELECT '父级+子级并存检测(L1汇总 vs L2明细)' AS info;
SELECT category_level_1,
       count(*) FILTER (WHERE category_level_2 = '' OR category_level_2 IS NULL) AS l1_only_rows,
       count(*) FILTER (WHERE category_level_2 != '' AND category_level_2 IS NOT NULL) AS l2_plus_rows
FROM core.douyin_category_daily
GROUP BY category_level_1 ORDER BY category_level_1;

-- 问题4: price_band 与 deal 一致性
SELECT '价格带SUM vs deal店铺TOTAL' AS info;
WITH pb_sum AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt FROM core.douyin_price_band_daily GROUP BY biz_date
), deal_ref AS (
    SELECT biz_date, user_pay_amount AS damt FROM core.douyin_deal_daily
    WHERE sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'
)
SELECT p.biz_date, round(p.amt,2) AS pb_sum, d.damt AS deal_ref, round(p.amt - d.damt, 2) AS diff
FROM pb_sum p JOIN deal_ref d USING (biz_date)
ORDER BY p.biz_date LIMIT 5;

-- 问题5: audience carrier=全部 父子
SELECT '人群 carrier=全部 vs 明细' AS info;
WITH total AS (
    SELECT biz_date, audience_type, SUM(user_pay_amount) AS amt FROM core.douyin_audience_daily
    WHERE carrier_type='全部' GROUP BY biz_date, audience_type
), parts AS (
    SELECT biz_date, audience_type, SUM(user_pay_amount) AS amt FROM core.douyin_audience_daily
    WHERE carrier_type IN ('商品卡','直播','短视频','图文','其他') GROUP BY biz_date, audience_type
)
SELECT t.biz_date, t.audience_type, round(t.amt - p.amt, 2) AS diff,
       CASE WHEN round(t.amt - p.amt, 2) = 0 THEN 'OK' ELSE 'MISMATCH' END AS status
FROM total t JOIN parts p USING (biz_date, audience_type)
ORDER BY t.audience_type, t.biz_date LIMIT 8;
