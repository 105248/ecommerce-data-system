-- category 父级行 vs 子级行 验证
SELECT '类目: L1父级 vs L2子级(06-10 个人护理)' AS info;
SELECT category_level_2, category_level_3, user_pay_amount
FROM core.douyin_category_daily
WHERE biz_date='2026-06-10' AND category_level_1='个人护理' AND category_level_2 IN ('全部','洗发护发')
ORDER BY category_level_2, category_level_3;

-- 类目父级行数量占比
SELECT '类目 含"全部"占位的行' AS info;
SELECT count(*) AS total_rows,
       count(*) FILTER (WHERE category_level_2='全部' OR category_level_2='') AS has_l2_all
FROM core.douyin_category_daily;

-- audience 全部30天匹配统计
SELECT '人群 30天匹配统计' AS info;
WITH total AS (
    SELECT biz_date, audience_type, SUM(user_pay_amount) AS amt FROM core.douyin_audience_daily
    WHERE carrier_type='全部' GROUP BY biz_date, audience_type
), parts AS (
    SELECT biz_date, audience_type, SUM(user_pay_amount) AS amt FROM core.douyin_audience_daily
    WHERE carrier_type IN ('商品卡','直播','短视频','图文','其他') GROUP BY biz_date, audience_type
)
SELECT count(*) AS total_days,
       count(*) FILTER (WHERE round(t.amt - p.amt, 2) = 0) AS match_days,
       count(*) FILTER (WHERE round(t.amt - p.amt, 2) != 0) AS mismatch_days,
       max(round(t.amt - p.amt, 2)) AS max_diff
FROM total t JOIN parts p USING (biz_date, audience_type);
