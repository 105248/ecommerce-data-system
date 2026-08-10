-- 确认 L2 类目真实数量
SELECT count(DISTINCT (category_level_1, category_level_2)) AS l2_count
FROM core.douyin_category_daily
WHERE biz_date='2026-06-01'
  AND category_level_2 <> '全部' AND category_level_3 = '全部' AND category_level_4 = '全部';
