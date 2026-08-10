-- 补充验证
-- 1. 终端: 整体 vs 其他终端 父子关系
SELECT '终端 整体 vs 明细(selling_type=全部)' AS info;
WITH total AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt FROM core.douyin_terminal_daily
    WHERE terminal_type='整体' AND selling_type='全部' GROUP BY biz_date
), parts AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt FROM core.douyin_terminal_daily
    WHERE terminal_type IN ('抖音','抖音极速版','红果短剧','其他') AND selling_type='全部' GROUP BY biz_date
)
SELECT t.biz_date, round(t.amt - p.amt, 2) AS diff FROM total t JOIN parts p USING (biz_date) LIMIT 3;

-- 2. 商品构成: carrier=全部 vs 明细
SELECT '商品 全部 vs 明细' AS info;
WITH total AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt FROM core.douyin_product_daily
    WHERE carrier_type='全部' GROUP BY biz_date
), parts AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt FROM core.douyin_product_daily
    WHERE carrier_type IN ('商品卡','图文','直播','短视频') GROUP BY biz_date
)
SELECT t.biz_date, round(t.amt - p.amt, 2) AS diff FROM total t JOIN parts p USING (biz_date) LIMIT 3;

-- 3. 载体构成: 各 carrier 下 account_channel 是否含"其他/更多账号"汇总
SELECT '载体 account_channel 汇总值' AS info;
SELECT account_channel, count(*) AS cnt FROM core.douyin_carrier_daily
WHERE account_channel IN ('其他','更多账号','弹动官方旗舰店','全域投放时段','标准+品牌投放')
GROUP BY account_channel ORDER BY 1;

-- 4. 每日各维度组合数量 (deal_daily 一天多少行)
SELECT 'deal_daily 每日组合数' AS info;
SELECT biz_date, count(*) AS combos FROM core.douyin_deal_daily
GROUP BY biz_date ORDER BY biz_date LIMIT 3;

-- 5. 载体构成 account_channel 的 distinct 数
SELECT '载体 account_channel distinct' AS info;
SELECT count(DISTINCT account_channel) AS cnt FROM core.douyin_carrier_daily;
