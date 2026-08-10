# V1.0.1: 重建 get_business_period_summary 追加10个投放指标列
src = open(r'D:/ecommerce-data-system/patches/v1.0.1/tests/fn_business.txt', encoding='utf-8').read()

# 1) RETURNS TABLE: 在 net_platform_subsidy_amount_pay_time numeric 后插入10列
old_ret = 'one_hour_refund_rate_pay_time numeric, net_platform_subsidy_amount_pay_time numeric, unrecalculable_metrics text[])'
new_ret = ('one_hour_refund_rate_pay_time numeric, net_platform_subsidy_amount_pay_time numeric, '
           'ad_spend_shop_promoted numeric, ad_spend_shop_bound numeric, ad_attributed_transaction_amount numeric, '
           'ad_attributed_transaction_share numeric, ad_spend_rate_net_refund_shop_bound numeric, '
           'total_expense_rate_net_refund_shop_bound numeric, ad_efficiency_shop_promoted numeric, '
           'ad_efficiency_shop_bound numeric, store_efficiency_shop_promoted numeric, store_efficiency_shop_bound numeric, '
           'unrecalculable_metrics text[])')
assert old_ret in src, 'RETURNS pattern not found'
src = src.replace(old_ret, new_ret)

# 2) SELECT 列表: 在 SUM(d.net_platform_subsidy_amount_pay_time), 后加10个表达式
old_sel = '''        SUM(d.net_platform_subsidy_amount_pay_time),
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[]'''
new_sel = '''        SUM(d.net_platform_subsidy_amount_pay_time),
        SUM(d.ad_spend_shop_promoted),
        SUM(d.ad_spend_shop_bound),
        SUM(d.ad_attributed_transaction_amount),
        SUM(d.ad_attributed_transaction_amount) / NULLIF(SUM(d.transaction_amount), 0),
        SUM(d.ad_spend_shop_bound) / NULLIF(SUM(d.settlement_amount), 0),
        SUM(d.total_expense_rate_net_refund_shop_bound * d.settlement_amount) / NULLIF(SUM(d.settlement_amount), 0),
        SUM(d.ad_efficiency_shop_promoted * d.ad_spend_shop_promoted) / NULLIF(SUM(d.ad_spend_shop_promoted), 0),
        SUM(d.ad_efficiency_shop_bound * d.ad_spend_shop_bound) / NULLIF(SUM(d.ad_spend_shop_bound), 0),
        SUM(d.store_efficiency_shop_promoted * d.ad_spend_shop_promoted) / NULLIF(SUM(d.ad_spend_shop_promoted), 0),
        SUM(d.store_efficiency_shop_bound * d.ad_spend_shop_bound) / NULLIF(SUM(d.ad_spend_shop_bound), 0),
        CASE WHEN p_start_date = p_end_date THEN ARRAY[]::text[]'''
assert old_sel in src, 'SELECT pattern not found'
src = src.replace(old_sel, new_sel)

out = r'D:/ecommerce-data-system/patches/v1.0.1/03a_business_fn_10col.sql'
with open(out, 'w', encoding='utf-8', newline='\n') as f:
    f.write('-- V1.0.1: 重建 get_business_period_summary (+10投放指标列)\n')
    f.write('DROP FUNCTION IF EXISTS mart.get_business_period_summary(text,date,date,text);\n')
    f.write(src)
print('已生成:', out)
print('校验: ad_spend 出现', src.count('ad_spend_shop_promoted'), '次 | 新返回列', src.count('store_efficiency_shop_bound numeric'))
