-- 更新字典: core各表 shop_id 的显示改为 shop_name
BEGIN;

-- 1. 字典更新: shop_id 记录改为显示 shop_name（来源 system_dictionary，覆盖ID显示为名称）
UPDATE meta.database_object_dictionary
SET column_name = 'shop_name',
    column_name_cn = '店铺名称',
    chinese_name_source = 'system_dictionary',
    name_resolution_status = 'system_field',
    updated_at = CURRENT_TIMESTAMP
WHERE object_type = 'column'
  AND column_name = 'shop_id'
  AND schema_name = 'core';

-- import_batch 的 shop_id 同样改
UPDATE meta.database_object_dictionary
SET column_name = 'shop_name',
    column_name_cn = '店铺名称',
    chinese_name_source = 'system_dictionary',
    name_resolution_status = 'system_field',
    updated_at = CURRENT_TIMESTAMP
WHERE object_type = 'column'
  AND column_name = 'shop_id'
  AND schema_name = 'audit'
  AND object_name = 'import_batch';

-- 2. 重建中文 View（shop_id -> shop_name）
CREATE OR REPLACE VIEW "中文数据"."抖音成交日报" AS
SELECT
    row_id AS "数据行ID",
    shop_name AS "店铺名称",
    biz_date AS "日期",
    sale_scope AS "成交范围",
    carrier_type AS "载体类型",
    ad_period AS "投放时段",
    user_pay_amount AS "用户支付金额",
    net_user_pay_amount_pay_time AS "退款后用户支付金额(支付时间)",
    smart_coupon_amount AS "智能优惠券金额",
    net_smart_coupon_amount_pay_time AS "退款后智能优惠券金额(支付时间)",
    platform_subsidy_amount AS "平台补贴金额",
    transaction_order_count AS "成交订单数",
    transaction_buyer_count AS "成交人数",
    avg_customer_amount AS "客单价",
    transaction_amount AS "成交金额",
    net_transaction_amount AS "净成交金额",
    refund_amount_refund_time AS "退款金额(退款时间)",
    transaction_refund_amount_refund_time AS "成交退款金额(退款时间)",
    refund_order_count_refund_time AS "退款订单数(退款时间)",
    refund_rate_pay_time AS "退款率(支付时间)",
    refund_amount_pay_time AS "退款金额(支付时间)",
    transaction_refund_amount_pay_time AS "成交退款金额(支付时间)",
    refund_order_count_pay_time AS "退款订单数(支付时间)",
    product_exposure_user_count AS "商品曝光人数",
    product_click_user_count AS "商品点击人数",
    exposure_to_click_rate_users AS "商品曝光-点击转化率(人数)",
    click_to_transaction_rate_users AS "商品点击-成交转化率(人数)",
    exposure_to_transaction_rate_users AS "商品曝光-成交转化率(人数)",
    user_pay_amount_per_1000_exposures AS "千次曝光用户支付金额",
    product_exposure_count AS "商品曝光次数",
    product_click_count AS "商品点击次数",
    exposure_to_click_rate_events AS "商品曝光-点击转化率(次数)",
    click_to_transaction_rate_events AS "商品点击-成交转化率(次数)",
    exposure_to_transaction_rate_events AS "商品曝光-成交转化率(次数)",
    shipped_user_pay_amount_ship_time AS "发货用户支付金额(发货时间)",
    ship_within_2_days_rate AS "两日内发货率",
    settlement_amount AS "结算金额",
    settlement_amount_refund_time AS "结算金额(退款时间)",
    settlement_amount_7d AS "7日结算金额",
    settlement_amount_14d AS "14日结算金额",
    net_creator_subsidy_amount_pay_time AS "退款后达人补贴金额(支付时间)",
    creator_subsidy_amount AS "达人补贴金额",
    presale_deposit_amount AS "预售定金",
    transaction_item_count AS "成交件数",
    avg_item_amount AS "件单价",
    net_transaction_order_count AS "净成交订单量",
    pre_shipment_refund_rate_pay_time AS "发货前退款率(支付时间)",
    unreceived_refund_rate_pay_time AS "未收货退款率(支付时间)",
    received_refund_rate_pay_time AS "已收货退款率(支付时间)",
    received_return_refund_rate_pay_time AS "已收货退货退款率(支付时间)",
    one_hour_transaction_refund_amount_pay_time AS "1小时成交退款金额(支付时间)",
    one_hour_refund_order_count_pay_time AS "1小时退款订单数(支付时间)",
    one_hour_refund_rate_pay_time AS "1小时成交退款率(支付时间)",
    net_platform_subsidy_amount_pay_time AS "退款后电商平台补贴金额(支付时间)",
    batch_id AS "导入批次ID",
    source_sheet_name AS "源工作表名称",
    source_row_number AS "源文件行号",
    imported_at AS "写入时间"
FROM core.douyin_deal_daily;

COMMIT;
