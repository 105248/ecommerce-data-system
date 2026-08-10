-- R5b: 百分点逻辑人工验证(用SQL手工构造 0.08 -> 0.10 验证展示规则)
SELECT 0.10 - 0.08 AS absolute_change_raw,  -- 0.02 (原始比率差)
       (0.10 - 0.08) * 100 AS percentage_point,  -- 2.00 个百分点
       (0.10 - 0.08)/0.08 AS relative_change,  -- 0.25 = 25%
       CASE WHEN 0.10 - 0.08 = 0.02 THEN 'PASS: 展示为+2个百分点, 相对+25%' ELSE 'FAIL' END AS verdict;
