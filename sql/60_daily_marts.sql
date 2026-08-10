-- mart V1.0 阶段1 第四部分：9个Daily Mart (普通VIEW)
BEGIN;

-- ============ 1. shop_daily ============
-- 严格固定: sale_scope=全部, carrier_type=全部, ad_period=不限; 粒度=店铺×日期, 每天唯一1行
CREATE OR REPLACE VIEW mart.shop_daily AS
SELECT
    s.shop_name,
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
    d.avg_item_amount
FROM core.douyin_deal_daily d
JOIN meta.shop s ON d.shop_id = s.shop_id
WHERE d.sale_scope = '全部'
  AND d.carrier_type = '全部'
  AND d.ad_period = '不限';

COMMENT ON VIEW mart.shop_daily IS '店铺每日总览：全店合法TOTAL口径(sale_scope=全部+carrier=全部+ad_period=不限)，粒度店铺×日期，每天唯一1行。';
COMMENT ON COLUMN mart.shop_daily.shop_name IS '店铺名称(对外统一显示，来源meta.shop)';
COMMENT ON COLUMN mart.shop_daily.user_pay_amount IS '用户支付金额。SUM';
COMMENT ON COLUMN mart.shop_daily.avg_customer_amount IS '客单价。非可加(不可直接求和或平均)';
COMMENT ON COLUMN mart.shop_daily.refund_rate_pay_time IS '退款率(支付时间)。非可加(比率原值0-1外可>1)';
COMMENT ON COLUMN mart.shop_daily.avg_item_amount IS '件单价。非可加';

-- ============ 2. carrier_daily ============
-- 只承担载体/渠道拆分与排名，不提供全店TOTAL
CREATE OR REPLACE VIEW mart.carrier_daily AS
SELECT
    s.shop_name,
    c.biz_date,
    c.sale_scope,
    c.carrier_type,
    c.account_channel,
    c.douyin_account_id,
    c.transaction_amount,
    c.user_pay_amount,
    c.settlement_amount,
    c.transaction_refund_amount_pay_time,
    c.refund_amount_pay_time,
    c.refund_rate_pay_time,
    c.ad_attributed_transaction_amount,
    c.ad_attributed_transaction_share,
    c.transaction_order_count,
    c.transaction_item_count,
    c.transaction_buyer_count,
    c.net_transaction_amount
FROM core.douyin_carrier_daily c
JOIN meta.shop s ON c.shop_id = s.shop_id;

COMMENT ON VIEW mart.carrier_daily IS '载体/渠道拆分与排名（不提供全店TOTAL；合作域明细+更多账号可SUM；全域投放时段/标准+品牌投放为special_overlap禁止与明细SUM）。';
COMMENT ON COLUMN mart.carrier_daily.account_channel IS '账号/渠道。更多账号=aggregate_bucket(合作剩余桶)；全域投放时段/标准+品牌投放=special_overlap(禁与明细SUM)；自营更多账号=待确认';
COMMENT ON COLUMN mart.carrier_daily.ad_attributed_transaction_share IS '投放贡献成交占比。非可加';

-- ============ 3. account_daily ============
-- 单账号分析/TOP账号/合作账号拆分；不提供全部账号/自营/全店总量
CREATE OR REPLACE VIEW mart.account_daily AS
SELECT
    s.shop_name,
    a.biz_date,
    a.sale_scope,
    a.account_name,
    a.account_type,
    a.transaction_amount,
    a.user_pay_amount,
    a.settlement_amount,
    a.transaction_refund_amount_pay_time,
    a.refund_amount_pay_time,
    a.refund_rate_pay_time,
    a.transaction_order_count,
    a.transaction_item_count,
    a.transaction_buyer_count,
    a.net_transaction_amount
FROM core.douyin_account_daily a
JOIN meta.shop s ON a.shop_id = s.shop_id;

COMMENT ON VIEW mart.account_daily IS '账号拆分/排名（单账号、TOP账号、合作账号拆分；不提供全部账号/自营总/全店总量，总量回deal_daily）。';
COMMENT ON COLUMN mart.account_daily.account_name IS '账号名称。更多账号=aggregate_bucket(合作剩余桶)；弹动官方旗舰店=自营具体账号';
COMMENT ON COLUMN mart.account_daily.refund_rate_pay_time IS '退款率(支付时间)。非可加';

-- ============ 4. content_daily ============
CREATE OR REPLACE VIEW mart.content_daily AS
SELECT
    s.shop_name,
    c.biz_date,
    c.selling_type,
    c.carrier_type,
    c.content_id,
    c.content_title,
    c.transaction_amount,
    c.user_pay_amount,
    c.settlement_amount,
    c.transaction_refund_amount_pay_time,
    c.refund_amount_pay_time,
    c.refund_rate_pay_time,
    c.transaction_order_count,
    c.transaction_item_count,
    c.transaction_buyer_count,
    c.net_transaction_amount
FROM core.douyin_content_daily c
JOIN meta.shop s ON c.shop_id = s.shop_id;

COMMENT ON VIEW mart.content_daily IS '单内容(直播间/短视频/图文)拆分；当前真实样本仅商品卡载体(自营/合作)，为其他载体预留不制造数据。';

-- ============ 5. terminal_daily ============
CREATE OR REPLACE VIEW mart.terminal_daily AS
SELECT
    s.shop_name,
    t.biz_date,
    t.terminal_type,
    t.selling_type,
    t.transaction_amount,
    t.user_pay_amount,
    t.settlement_amount,
    t.transaction_order_count,
    t.transaction_refund_amount_pay_time,
    t.refund_amount_pay_time,
    t.refund_rate_pay_time,
    t.transaction_item_count,
    t.transaction_refund_amount_refund_time
FROM core.douyin_terminal_daily t
JOIN meta.shop s ON t.shop_id = s.shop_id;

COMMENT ON VIEW mart.terminal_daily IS '终端拆分（terminal_type=整体为合法TOTAL优先用于总览；拆分时只取明细终端，禁止整体+明细一起SUM）。';

-- ============ 6. category_daily ============
-- 增加 category_level / is_total_row，按"全部"占位识别层级
CREATE OR REPLACE VIEW mart.category_daily AS
SELECT
    s.shop_name,
    c.biz_date,
    c.category_level_1 AS category_l1,
    c.category_level_2 AS category_l2,
    c.category_level_3 AS category_l3,
    c.category_level_4 AS category_l4,
    CASE
        WHEN c.category_level_4 IS NULL OR c.category_level_4 = '' OR c.category_level_4 = '全部' THEN
            CASE
                WHEN c.category_level_3 IS NULL OR c.category_level_3 = '' OR c.category_level_3 = '全部' THEN
                    CASE
                        WHEN c.category_level_2 IS NULL OR c.category_level_2 = '' OR c.category_level_2 = '全部' THEN 1
                        ELSE 2 END
                ELSE 3 END
        ELSE 4 END AS category_level,
    (c.category_level_4 = '全部' OR c.category_level_4 = '' OR c.category_level_4 IS NULL) AS is_total_row,
    c.user_pay_amount,
    c.avg_transaction_order_amount,
    c.click_to_transaction_rate_events,
    c.refund_amount_pay_time,
    c.refund_rate_pay_time
FROM core.douyin_category_daily c
JOIN meta.shop s ON c.shop_id = s.shop_id;

COMMENT ON VIEW mart.category_daily IS '类目拆分（含层级识别：category_level 1/2/3/4；is_total_row=是否父级占位行；不同层级禁止混SUM）。';
COMMENT ON COLUMN mart.category_daily.avg_transaction_order_amount IS '成交笔单价。非可加';
COMMENT ON COLUMN mart.category_daily.click_to_transaction_rate_events IS '商品点击-成交转化率(次数)。非可加';
COMMENT ON COLUMN mart.category_daily.refund_rate_pay_time IS '退款率(支付时间)。非可加';
COMMENT ON COLUMN mart.category_daily.category_level IS '类目层级：1=L1汇总行 2=L2 3=L3 4=L4明细。系统人工字典';
COMMENT ON COLUMN mart.category_daily.is_total_row IS '是否汇总行：由"全部"占位识别，为TRUE时是父级TOTAL。系统人工字典';

-- ============ 7. product_daily ============
CREATE OR REPLACE VIEW mart.product_daily AS
SELECT
    s.shop_name,
    p.biz_date,
    p.product_id,
    p.product_name,
    p.carrier_type,
    p.user_pay_amount,
    p.avg_transaction_order_amount,
    p.click_to_transaction_rate_events,
    p.refund_amount_pay_time,
    p.refund_rate_pay_time,
    p.smart_coupon_amount,
    p.platform_subsidy_amount
FROM core.douyin_product_daily p
JOIN meta.shop s ON p.shop_id = s.shop_id;

COMMENT ON VIEW mart.product_daily IS '商品拆分（carrier_type=全部为平台独立总口径，商品总览优先读取；商品卡+图文+直播+短视频禁止重建全部）。';
COMMENT ON COLUMN mart.product_daily.product_id IS '商品编号(ID类按文本)';
COMMENT ON COLUMN mart.product_daily.avg_transaction_order_amount IS '成交笔单价。非可加';
COMMENT ON COLUMN mart.product_daily.click_to_transaction_rate_events IS '商品点击-成交转化率(次数)。非可加';
COMMENT ON COLUMN mart.product_daily.refund_rate_pay_time IS '退款率(支付时间)。非可加';

-- ============ 8. price_band_daily ============
CREATE OR REPLACE VIEW mart.price_band_daily AS
SELECT
    s.shop_name,
    p.biz_date,
    p.price_band,
    p.user_pay_amount,
    p.avg_transaction_order_amount,
    p.click_to_transaction_rate_events
FROM core.douyin_price_band_daily p
JOIN meta.shop s ON p.shop_id = s.shop_id;

COMMENT ON VIEW mart.price_band_daily IS '价格带拆分（6个价格带已验证互斥，可安全SUM重建店铺总量diff=0.00）。';
COMMENT ON COLUMN mart.price_band_daily.avg_transaction_order_amount IS '成交笔单价。非可加';
COMMENT ON COLUMN mart.price_band_daily.click_to_transaction_rate_events IS '商品点击-成交转化率(次数)。非可加';

-- ============ 9. audience_daily ============
CREATE OR REPLACE VIEW mart.audience_daily AS
SELECT
    s.shop_name,
    a.biz_date,
    a.audience_type,
    a.carrier_type,
    a.user_pay_amount,
    a.transaction_buyer_count,
    a.avg_customer_amount,
    a.transaction_order_count,
    a.repeat_user_repeat_rate
FROM core.douyin_audience_daily a
JOIN meta.shop s ON a.shop_id = s.shop_id;

COMMENT ON VIEW mart.audience_daily IS '人群拆分（carrier_type=全部为合法TOTAL 60/60天验证；总览用全部，拆分用5载体明细，禁止TOTAL+DETAIL一起SUM）。';
COMMENT ON COLUMN mart.audience_daily.avg_customer_amount IS '客单价。非可加';
COMMENT ON COLUMN mart.audience_daily.repeat_user_repeat_rate IS '复购用户复购率。非可加';

COMMIT;

-- 验证
SELECT 'mart对象清单' AS info;
SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = 'mart' ORDER BY table_name;
