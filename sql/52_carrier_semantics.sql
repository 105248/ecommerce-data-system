-- 问题1: carrier_daily account_channel 语义
-- 1. 各 sale_scope × carrier_type 下的 channel 明细(非汇总桶)
SELECT '各scope×carrier的channel类型分布' AS info;
SELECT sale_scope, carrier_type,
       count(DISTINCT account_channel) AS channels,
       count(*) AS rows_cnt,
       count(*) FILTER (WHERE account_channel IN ('更多账号','其他')) AS bucket_rows
FROM core.douyin_carrier_daily
GROUP BY sale_scope, carrier_type ORDER BY sale_scope, carrier_type;

-- 2. 汇总桶在哪些 scope×carrier 出现
SELECT '汇总桶出现位置' AS info;
SELECT sale_scope, carrier_type, account_channel, count(*) AS cnt
FROM core.douyin_carrier_daily
WHERE account_channel IN ('更多账号','其他','全域投放时段','标准+品牌投放','弹动官方旗舰店')
GROUP BY sale_scope, carrier_type, account_channel ORDER BY sale_scope, carrier_type, account_channel;

-- 3. 某日某组合: 明细互斥性验证 (取2026-06-10, 合作×短视频)
SELECT '样例: 2026-06-10 合作×短视频 全部channel' AS info;
SELECT account_channel, user_pay_amount
FROM core.douyin_carrier_daily
WHERE biz_date='2026-06-10' AND sale_scope='合作' AND carrier_type='短视频'
ORDER BY account_channel;

-- 4. 更多账号 是否与具体账号重叠 (合作×短视频 06-10)
SELECT '更多账号 vs 具体账号重叠检查' AS info;
SELECT '更多账号' AS chk, count(*) AS rows_cnt FROM core.douyin_carrier_daily
WHERE biz_date='2026-06-10' AND sale_scope='合作' AND carrier_type='短视频' AND account_channel='更多账号';
