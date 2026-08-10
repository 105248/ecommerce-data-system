-- 验证父子汇总关系：全部 vs 明细
-- 1. sale_scope=全部, carrier=全部 是否 = carrier=商品卡+直播+短视频+图文+其他 之和
SELECT 'carrier父子验证(sale_scope=全部, ad_period=不限)' AS info;
WITH total AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt
    FROM core.douyin_deal_daily
    WHERE sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'
    GROUP BY biz_date
), parts AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt
    FROM core.douyin_deal_daily
    WHERE sale_scope='全部' AND carrier_type IN ('商品卡','直播','短视频','图文','其他') AND ad_period='不限'
    GROUP BY biz_date
)
SELECT t.biz_date, t.amt AS total_amt, p.amt AS parts_sum,
       round(t.amt - p.amt, 2) AS diff
FROM total t JOIN parts p USING (biz_date)
ORDER BY t.biz_date LIMIT 5;

-- 2. ad_period=不限 是否 = 全域+标准品牌+非投放 之和
SELECT 'ad_period父子验证(sale_scope=全部, carrier=全部)' AS info;
WITH total AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt
    FROM core.douyin_deal_daily
    WHERE sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'
    GROUP BY biz_date
), parts AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt
    FROM core.douyin_deal_daily
    WHERE sale_scope='全部' AND carrier_type='全部' AND ad_period IN ('全域投放时段','标准+品牌投放','非投放时段')
    GROUP BY biz_date
)
SELECT t.biz_date, t.amt AS total_amt, p.amt AS parts_sum,
       round(t.amt - p.amt, 2) AS diff
FROM total t JOIN parts p USING (biz_date)
ORDER BY t.biz_date LIMIT 5;

-- 3. sale_scope=全部 是否 = 自营+合作 之和
SELECT 'sale_scope父子验证(carrier=全部, ad_period=不限)' AS info;
WITH total AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt
    FROM core.douyin_deal_daily
    WHERE sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'
    GROUP BY biz_date
), parts AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt
    FROM core.douyin_deal_daily
    WHERE sale_scope IN ('自营','合作') AND carrier_type='全部' AND ad_period='不限'
    GROUP BY biz_date
)
SELECT t.biz_date, t.amt AS total_amt, p.amt AS parts_sum,
       round(t.amt - p.amt, 2) AS diff
FROM total t JOIN parts p USING (biz_date)
ORDER BY t.biz_date LIMIT 5;
