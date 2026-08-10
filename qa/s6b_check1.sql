-- 核实 deal 06-01 TOTAL 行
SELECT biz_date, sale_scope, carrier_type, ad_period, user_pay_amount
FROM core.douyin_deal_daily
WHERE biz_date='2026-06-01' AND sale_scope='全部' AND carrier_type='全部' AND ad_period='不限';
