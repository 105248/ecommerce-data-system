-- 阶段2测试: 全店 30天
SELECT shop_name, day_count, scope_key, sale_scope, carrier_type, ad_period,
       user_pay_amount, transaction_amount, transaction_order_count,
       avg_customer_amount, avg_item_amount, refund_rate_pay_time,
       user_pay_amount_per_1000_exposures, source_only_note
FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店');
