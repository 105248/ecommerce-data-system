-- 载体 account_channel 语义确认
-- 1. account_channel 与 sale_scope 关系
SELECT 'account_channel 中疑似汇总值 与 sale_scope' AS info;
SELECT sale_scope, account_channel, count(*) AS cnt
FROM core.douyin_carrier_daily
WHERE account_channel IN ('其他','更多账号','全域投放时段','标准+品牌投放','弹动官方旗舰店')
GROUP BY sale_scope, account_channel ORDER BY account_channel, sale_scope;

-- 2. account_channel 值里是否含 ad_period 类值(全域投放时段/标准+品牌投放/非投放时段)
SELECT 'account_channel 与 ad_period 类值' AS info;
SELECT account_channel, count(*) AS cnt
FROM core.douyin_carrier_daily
WHERE account_channel IN ('全域投放时段','标准+品牌投放','非投放时段','不限')
GROUP BY account_channel;

-- 3. 载体表是否存在 ad_period 维度字段?
SELECT '载体表 ad_period 字段存在性' AS info;
SELECT count(*) AS cnt FROM information_schema.columns
WHERE table_schema='core' AND table_name='douyin_carrier_daily' AND column_name='ad_period';

-- 4. 载体表是否含 carrier=全部 汇总行
SELECT '载体 carrier=全部' AS info;
SELECT sale_scope, count(*) AS cnt FROM core.douyin_carrier_daily WHERE carrier_type='全部' GROUP BY sale_scope;
