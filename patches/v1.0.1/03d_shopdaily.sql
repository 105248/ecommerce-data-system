-- V1.0.1: shop_daily 追加10投放字段
CREATE OR REPLACE VIEW mart.shop_daily AS
SELECT s.shop_name,
     d.biz_date,
     d.user_pay_amount,
     d.net_user_pay_amount_pay_time,
     d.smart_coupon_amount,
     d.platform_subsidy_amount,
     d.transaction_order_count,
     d.transaction_buyer_count,
     d.avg_customer_amount,
     d.transaction_amount,
     d.net_transaction_amount,
     d.refund_amount_pay_time,
     d.refund_rate_pay_time,
     d.settlement_amount,
     d.creator_subsidy_amount,
     d.transaction_item_count,
     d.avg_item_amount,
     d.ad_spend_shop_promoted,
     d.ad_spend_shop_bound,
     d.ad_attributed_transaction_amount,
     d.ad_attributed_transaction_share,
     d.ad_spend_rate_net_refund_shop_bound,
     d.total_expense_rate_net_refund_shop_bound,
     d.ad_efficiency_shop_promoted,
     d.ad_efficiency_shop_bound,
     d.store_efficiency_shop_promoted,
     d.store_efficiency_shop_bound
FROM core.douyin_deal_daily d
JOIN meta.shop s ON d.shop_id = s.shop_id
WHERE d.sale_scope = '全部' AND d.carrier_type = '全部' AND d.ad_period = '不限';

\echo '=== shop_daily 列数 (应27) ==='
SELECT count(*) FROM information_schema.columns WHERE table_schema='mart' AND table_name='shop_daily';

\echo ''
\echo '=== metric_rule_v14 是否存在 ==='
SELECT to_regclass('mart.metric_rule_v14') AS exists;
