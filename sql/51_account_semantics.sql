-- 账号构成: account_name='弹动官方旗舰店' 行 vs 明细之和
SELECT '账号 弹动官方旗舰店 vs 其他账号 数值关系' AS info;
WITH total AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt FROM core.douyin_account_daily
    WHERE account_name = '弹动官方旗舰店' AND sale_scope = '自营' GROUP BY biz_date
), parts AS (
    SELECT biz_date, SUM(user_pay_amount) AS amt FROM core.douyin_account_daily
    WHERE account_name != '弹动官方旗舰店' AND sale_scope = '自营' GROUP BY biz_date
)
SELECT t.biz_date, round(t.amt - p.amt, 2) AS diff FROM total t JOIN parts p USING (biz_date) LIMIT 3;

-- 账号 account_name='更多账号' 语义
SELECT '账号 更多账号 行' AS info;
SELECT sale_scope, account_type, count(*) AS cnt FROM core.douyin_account_daily
WHERE account_name = '更多账号' GROUP BY sale_scope, account_type;

-- 单载体: selling_type 自营/合作 + carrier 都是商品卡?
SELECT '单载体 粒度确认' AS info;
SELECT selling_type, carrier_type, count(DISTINCT content_id) AS contents, count(*) AS rows_cnt
FROM core.douyin_content_daily GROUP BY selling_type, carrier_type ORDER BY selling_type;
