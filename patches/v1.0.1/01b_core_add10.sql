-- V1.0.1: core.douyin_deal_daily 新增10投放字段
BEGIN;

ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS ad_spend_shop_promoted NUMERIC(20,2);
COMMENT ON COLUMN core.douyin_deal_daily.ad_spend_shop_promoted IS '投放消耗(店铺被投) (V1.0.1新增, 类别:投放指标-可加金额, 聚合:SUM)';

ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS ad_spend_shop_bound NUMERIC(20,2);
COMMENT ON COLUMN core.douyin_deal_daily.ad_spend_shop_bound IS '投放消耗(店铺绑定) (V1.0.1新增, 类别:投放指标-可加金额, 聚合:SUM)';

ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS ad_attributed_transaction_amount NUMERIC(20,2);
COMMENT ON COLUMN core.douyin_deal_daily.ad_attributed_transaction_amount IS '投放贡献成交金额 (V1.0.1新增, 类别:投放指标-可加金额, 聚合:SUM)';

ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS ad_attributed_transaction_share NUMERIC(18,8);
COMMENT ON COLUMN core.douyin_deal_daily.ad_attributed_transaction_share IS '投放贡献成交占比 (V1.0.1新增, 类别:投放指标-比例, 聚合:weighted_source_ratio)';

ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS ad_spend_rate_net_refund_shop_bound NUMERIC(18,8);
COMMENT ON COLUMN core.douyin_deal_daily.ad_spend_rate_net_refund_shop_bound IS '投放费比(剔除退款、店铺绑定) (V1.0.1新增, 类别:投放指标-比例, 聚合:weighted_source_ratio)';

ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS total_expense_rate_net_refund_shop_bound NUMERIC(18,8);
COMMENT ON COLUMN core.douyin_deal_daily.total_expense_rate_net_refund_shop_bound IS '综合费比(剔除退款、店铺绑定) (V1.0.1新增, 类别:投放指标-比例, 聚合:weighted_source_ratio)';

ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS ad_efficiency_shop_promoted NUMERIC(20,8);
COMMENT ON COLUMN core.douyin_deal_daily.ad_efficiency_shop_promoted IS '投放效率(店铺被投) (V1.0.1新增, 类别:投放指标-效率, 聚合:weighted_source_ratio)';

ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS ad_efficiency_shop_bound NUMERIC(20,8);
COMMENT ON COLUMN core.douyin_deal_daily.ad_efficiency_shop_bound IS '投放效率(店铺绑定) (V1.0.1新增, 类别:投放指标-效率, 聚合:weighted_source_ratio)';

ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS store_efficiency_shop_promoted NUMERIC(20,8);
COMMENT ON COLUMN core.douyin_deal_daily.store_efficiency_shop_promoted IS '全店效率(店铺被投) (V1.0.1新增, 类别:投放指标-效率, 聚合:weighted_source_ratio)';

ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS store_efficiency_shop_bound NUMERIC(20,8);
COMMENT ON COLUMN core.douyin_deal_daily.store_efficiency_shop_bound IS '全店效率(店铺绑定) (V1.0.1新增, 类别:投放指标-效率, 聚合:weighted_source_ratio)';

COMMIT;