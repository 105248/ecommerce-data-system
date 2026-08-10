-- mart V1.0 阶段1 第六部分：中文可读层同步（mart View → 中文数据）
-- shop_name → 店铺名称；治理字段用系统人工字典
BEGIN;

-- 店铺每日总览
DROP VIEW IF EXISTS "中文数据"."店铺每日总览";
CREATE VIEW "中文数据"."店铺每日总览" AS
SELECT
    shop_name AS "店铺名称",
    biz_date AS "日期",
    user_pay_amount AS "用户支付金额",
    net_user_pay_amount_pay_time AS "退款后用户支付金额(支付时间)",
    smart_coupon_amount AS "智能优惠券金额",
    platform_subsidy_amount AS "平台补贴金额",
    transaction_order_count AS "成交订单数",
    transaction_buyer_count AS "成交人数",
    avg_customer_amount AS "客单价",
    transaction_amount AS "成交金额",
    net_transaction_amount AS "净成交金额",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    settlement_amount AS "结算金额",
    creator_subsidy_amount AS "达人补贴金额",
    transaction_item_count AS "成交件数",
    avg_item_amount AS "件单价"
FROM mart.shop_daily;

-- 载体构成分析
DROP VIEW IF EXISTS "中文数据"."载体构成分析";
CREATE VIEW "中文数据"."载体构成分析" AS
SELECT
    shop_name AS "店铺名称",
    biz_date AS "日期",
    sale_scope AS "成交范围",
    carrier_type AS "载体类型",
    account_channel AS "账号/渠道",
    douyin_account_id AS "抖音号",
    transaction_amount AS "成交金额",
    user_pay_amount AS "用户支付金额",
    settlement_amount AS "结算金额",
    transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    ad_attributed_transaction_amount AS "投放贡献成交金额",
    ad_attributed_transaction_share AS "投放贡献成交占比",
    transaction_order_count AS "成交订单数",
    transaction_item_count AS "成交件数",
    transaction_buyer_count AS "成交人数",
    net_transaction_amount AS "净成交金额"
FROM mart.carrier_daily;

-- 账号构成分析
DROP VIEW IF EXISTS "中文数据"."账号构成分析";
CREATE VIEW "中文数据"."账号构成分析" AS
SELECT
    shop_name AS "店铺名称",
    biz_date AS "日期",
    sale_scope AS "成交范围",
    account_name AS "账号名称",
    account_type AS "账号类型",
    transaction_amount AS "成交金额",
    user_pay_amount AS "用户支付金额",
    settlement_amount AS "结算金额",
    transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    transaction_order_count AS "成交订单数",
    transaction_item_count AS "成交件数",
    transaction_buyer_count AS "成交人数",
    net_transaction_amount AS "净成交金额"
FROM mart.account_daily;

-- 单载体内容分析
DROP VIEW IF EXISTS "中文数据"."单载体内容分析";
CREATE VIEW "中文数据"."单载体内容分析" AS
SELECT
    shop_name AS "店铺名称",
    biz_date AS "日期",
    selling_type AS "售卖类型",
    carrier_type AS "载体类型",
    content_id AS "内容ID",
    content_title AS "标题/名称",
    transaction_amount AS "成交金额",
    user_pay_amount AS "用户支付金额",
    settlement_amount AS "结算金额",
    transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    transaction_order_count AS "成交订单数",
    transaction_item_count AS "成交件数",
    transaction_buyer_count AS "成交人数",
    net_transaction_amount AS "净成交金额"
FROM mart.content_daily;

-- 终端构成分析
DROP VIEW IF EXISTS "中文数据"."终端构成分析";
CREATE VIEW "中文数据"."终端构成分析" AS
SELECT
    shop_name AS "店铺名称",
    biz_date AS "日期",
    terminal_type AS "终端类型",
    selling_type AS "售卖类型",
    transaction_amount AS "成交金额",
    user_pay_amount AS "用户支付金额",
    settlement_amount AS "结算金额",
    transaction_order_count AS "成交订单数",
    transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    transaction_item_count AS "成交件数",
    transaction_refund_amount_refund_time AS "成交退款金额(退款时间)"
FROM mart.terminal_daily;

-- 品类构成分析
DROP VIEW IF EXISTS "中文数据"."品类构成分析";
CREATE VIEW "中文数据"."品类构成分析" AS
SELECT
    shop_name AS "店铺名称",
    biz_date AS "日期",
    category_l1 AS "一级类目",
    category_l2 AS "二级类目",
    category_l3 AS "三级类目",
    category_l4 AS "四级类目",
    category_level AS "类目层级",
    is_total_row AS "是否汇总行",
    user_pay_amount AS "用户支付金额",
    avg_transaction_order_amount AS "成交笔单价",
    click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)"
FROM mart.category_daily;

-- 商品构成分析
DROP VIEW IF EXISTS "中文数据"."商品构成分析";
CREATE VIEW "中文数据"."商品构成分析" AS
SELECT
    shop_name AS "店铺名称",
    biz_date AS "日期",
    product_id AS "商品编号",
    product_name AS "商品名称",
    carrier_type AS "载体类型",
    user_pay_amount AS "用户支付金额",
    avg_transaction_order_amount AS "成交笔单价",
    click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    smart_coupon_amount AS "智能优惠券金额",
    platform_subsidy_amount AS "电商平台补贴金额"
FROM mart.product_daily;

-- 价格带构成分析
DROP VIEW IF EXISTS "中文数据"."价格带构成分析";
CREATE VIEW "中文数据"."价格带构成分析" AS
SELECT
    shop_name AS "店铺名称",
    biz_date AS "日期",
    price_band AS "价格带",
    user_pay_amount AS "用户支付金额",
    avg_transaction_order_amount AS "成交笔单价",
    click_to_transaction_rate_events AS "商品点击-成交转化率(次数)"
FROM mart.price_band_daily;

-- 人群构成分析
DROP VIEW IF EXISTS "中文数据"."人群构成分析";
CREATE VIEW "中文数据"."人群构成分析" AS
SELECT
    shop_name AS "店铺名称",
    biz_date AS "日期",
    audience_type AS "人群类型",
    carrier_type AS "载体类型",
    user_pay_amount AS "用户支付金额",
    transaction_buyer_count AS "成交人数",
    avg_customer_amount AS "客单价",
    transaction_order_count AS "成交订单数",
    repeat_user_repeat_rate AS "复购用户复购率"
FROM mart.audience_daily;

COMMIT;

-- 验证
SELECT table_name FROM information_schema.views
WHERE table_schema = '中文数据' ORDER BY table_name;
