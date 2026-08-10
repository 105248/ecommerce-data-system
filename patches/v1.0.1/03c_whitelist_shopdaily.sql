-- V1.0.1: analysis_metric_whitelist + shop_daily 更新
BEGIN;

-- 1. 白名单加 10 条 (domain_key=advertising; 排名/贡献度暂不扩展)
INSERT INTO mart.analysis_metric_whitelist
(domain_key, metric_key, metric_name_cn, value_type, rank_allowed, contribution_allowed, default_rank_direction)
VALUES
('advertising','ad_spend_shop_promoted','投放消耗(店铺被投)','amount',FALSE,FALSE,NULL),
('advertising','ad_spend_shop_bound','投放消耗(店铺绑定)','amount',FALSE,FALSE,NULL),
('advertising','ad_attributed_transaction_amount','投放贡献成交金额','amount',FALSE,FALSE,NULL),
('advertising','ad_attributed_transaction_share','投放贡献成交占比','ratio',FALSE,FALSE,NULL),
('advertising','ad_spend_rate_net_refund_shop_bound','投放费比(剔除退款、店铺绑定)','ratio',FALSE,FALSE,NULL),
('advertising','total_expense_rate_net_refund_shop_bound','综合费比(剔除退款、店铺绑定)','ratio',FALSE,FALSE,NULL),
('advertising','ad_efficiency_shop_promoted','投放效率(店铺被投)','efficiency',FALSE,FALSE,NULL),
('advertising','ad_efficiency_shop_bound','投放效率(店铺绑定)','efficiency',FALSE,FALSE,NULL),
('advertising','store_efficiency_shop_promoted','全店效率(店铺被投)','efficiency',FALSE,FALSE,NULL),
('advertising','store_efficiency_shop_bound','全店效率(店铺绑定)','efficiency',FALSE,FALSE,NULL);

-- 2. shop_daily 追加 10 个投放字段 (CREATE OR REPLACE 允许末尾加列)
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

COMMIT;

\echo '=== 白名单总数 (应49) ==='
SELECT count(*) FROM mart.analysis_metric_whitelist;
\echo '=== 新10条 ==='
SELECT domain_key, metric_key, value_type FROM mart.analysis_metric_whitelist WHERE domain_key='advertising' ORDER BY metric_key;
\echo '=== shop_daily 列数 (应27) ==='
SELECT count(*) FROM information_schema.columns WHERE table_schema='mart' AND table_name='shop_daily';
