# -*- coding: utf-8 -*-
"""阶段6G: AI层数字一致性终极测试
30个自然语言问题 → 对应Tool → 数字 → 反向核验 core 合法SQL
验证: AI最终数字 = MCP数字 = mart Function = core合法SQL
"""
import sys, os, json, subprocess

sys.path.insert(0, r'D:/ecommerce-data-system/mcp_server')
os.environ['DB_USER'] = 'agent_readonly'

from tools import business_tools, product_tools, account_tools, category_tools, domain_tools, catalog_tools

os.environ['PGPASSWORD'] = os.environ.get('PG_ADMIN_PASSWORD', '')
PSQL = [r'D:/pgsql16_fresh/pgsql/bin/psql.exe','-U','postgres','-h','127.0.0.1','-p','5432','-d','ecommerce_db','-t','-A']
def q(sql):
    tmp = r'D:/ecommerce-data-system/qa/_tmp_q.sql'
    open(tmp,'w',encoding='utf-8').write(sql)
    r = subprocess.run(PSQL+['-f',tmp], capture_output=True, text=True, encoding='utf-8', errors='replace')
    return r.stdout.strip()

SHOP = '弹动官方旗舰店'
results = []

def check(qid, question, mcp_val, core_sql, tol=0.01):
    try:
        m = float(mcp_val)
    except (TypeError, ValueError):
        m = None
    try:
        c = float(core_sql)
    except (TypeError, ValueError):
        c = None
    ok = m is not None and c is not None and abs(m - c) < tol
    results.append((qid, ok, question))
    print('  [{}{}] #{:02d} {}: MCP={} core={}'.format('PASS' if ok else 'FAIL', ' ' * (6-len('PASS' if ok else 'FAIL')), qid, question, mcp_val, core_sql))

TOTAL_FILTER = "sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'"

print('=== 6G: 30个自然语言问题 数字一致性终极测试 (AI/MCP = core) ===')

# 1-6: 各scope 30天
for i, (scope, expect_filter) in enumerate([
    ('全店', TOTAL_FILTER),
    ('自营', "sale_scope='自营' AND carrier_type='全部' AND ad_period='不限'"),
    ('合作', "sale_scope='合作' AND carrier_type='全部' AND ad_period='不限'"),
    ('商品卡', "sale_scope='全部' AND carrier_type='商品卡' AND ad_period='不限'"),
    ('短视频', "sale_scope='全部' AND carrier_type='短视频' AND ad_period='不限'"),
    ('合作短视频', "sale_scope='合作' AND carrier_type='短视频' AND ad_period='不限'"),
], 1):
    r = business_tools.get_business_summary(SHOP, '2026-06-01', '2026-06-30', scope, 'user_pay_amount')
    core = q("SELECT SUM(user_pay_amount) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30' AND {}".format(expect_filter))
    check(i, scope+'成交', r['data'][0]['metric_value'], core)

# 7: 单日
r = business_tools.get_business_summary(SHOP, '2026-06-12', '2026-06-12', '全店', 'user_pay_amount')
core = q("SELECT SUM(user_pay_amount) FROM core.douyin_deal_daily WHERE biz_date='2026-06-12' AND " + TOTAL_FILTER)
check(7, '6月12日全店', r['data'][0]['metric_value'], core)

# 8: 最近7天
r = business_tools.get_business_summary(SHOP, '2026-06-24', '2026-06-30', '全店', 'user_pay_amount')
core = q("SELECT SUM(user_pay_amount) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-24' AND '2026-06-30' AND " + TOTAL_FILTER)
check(8, '最近7天', r['data'][0]['metric_value'], core)

# 9: 环比本期
r = business_tools.compare_business(SHOP, '2026-06-08', '2026-06-14', '全店', 'user_pay_amount')
core = q("SELECT SUM(user_pay_amount) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-08' AND '2026-06-14' AND " + TOTAL_FILTER)
check(9, '环比本期', r['data'][0]['current_value'], core)
core = q("SELECT SUM(user_pay_amount) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-07' AND " + TOTAL_FILTER)
check(9, '环比上期', r['data'][0]['previous_value'], core)

# 11-14: 比例指标
r = business_tools.get_business_summary(SHOP, '2026-06-01', '2026-06-30', '全店', 'refund_rate_pay_time')
core = q("SELECT SUM(refund_amount_pay_time)/NULLIF(SUM(user_pay_amount),0) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30' AND " + TOTAL_FILTER)
check(11, '6月退款率', r['data'][0]['metric_value'], core, 0.000001)
r = business_tools.get_business_summary(SHOP, '2026-06-01', '2026-06-30', '全店', 'avg_customer_amount')
core = q("SELECT SUM(user_pay_amount)/NULLIF(SUM(transaction_buyer_count),0) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30' AND " + TOTAL_FILTER)
check(12, '6月客单价', r['data'][0]['metric_value'], core, 0.0001)
r = business_tools.get_business_summary(SHOP, '2026-06-01', '2026-06-30', '全店', 'avg_item_amount')
core = q("SELECT SUM(user_pay_amount)/NULLIF(SUM(transaction_item_count),0) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30' AND " + TOTAL_FILTER)
check(13, '6月件单价', r['data'][0]['metric_value'], core, 0.0001)
r = business_tools.get_business_summary(SHOP, '2026-06-01', '2026-06-30', '全店', 'click_to_transaction_rate_users')
core = q("SELECT SUM(transaction_buyer_count)/NULLIF(SUM(product_click_user_count),0) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30' AND " + TOTAL_FILTER)
check(14, '6月点击成交转化率', r['data'][0]['metric_value'], core, 0.000001)

# 16-18: 商品排名TOP3
r = product_tools.rank_products(SHOP, '2026-06-01', '2026-06-30', 'user_pay_amount', 'current_value', 'DESC', 3)
core = q("SELECT product_id FROM core.douyin_product_daily WHERE carrier_type='全部' AND biz_date BETWEEN '2026-06-01' AND '2026-06-30' GROUP BY product_id ORDER BY SUM(user_pay_amount) DESC LIMIT 1")
check(16, '商品TOP1', r['data'][0]['product_id'], core)  # 文本ID比对(非数值)
results[-1] = (results[-1][0], r['data'][0]['product_id'] == core, results[-1][2])
print('  [{}] #16 商品TOP1: MCP={} core={}'.format('PASS' if r['data'][0]['product_id']==core else 'FAIL', r['data'][0]['product_id'], core))

# 20: 商品贡献
r = product_tools.get_product_contribution(SHOP, '2026-06-01', '2026-06-30', 'user_pay_amount', '3523538019611183417', None, 5)
core = q("SELECT SUM(user_pay_amount) FROM core.douyin_product_daily WHERE product_id='3523538019611183417' AND carrier_type='全部' AND biz_date BETWEEN '2026-06-01' AND '2026-06-30'")
check(17, '商品A金额', r['data'][0]['numerator_value'], core, 0.1)
core = q("SELECT SUM(user_pay_amount) FROM core.douyin_product_daily WHERE carrier_type='全部' AND biz_date BETWEEN '2026-06-01' AND '2026-06-30'")
check(18, '商品域分母', r['data'][0]['product_domain_total'], core, 0.1)

# 22: 账号排名
r = account_tools.rank_accounts(SHOP, '2026-06-16', '2026-06-30', '合作', 'user_pay_amount', 'current_value', 'DESC', 5, False, None)
core = q("SELECT account_name FROM core.douyin_account_daily WHERE sale_scope='合作' AND account_name<>'更多账号' AND biz_date BETWEEN '2026-06-16' AND '2026-06-30' GROUP BY account_name ORDER BY SUM(user_pay_amount) DESC LIMIT 1")
print('  [{}] #22 合作账号TOP1: MCP={} core={}'.format('PASS' if r['data'][0]['account_name']==core else 'FAIL', r['data'][0]['account_name'], core))
results.append((22, r['data'][0]['account_name']==core, '合作账号TOP1'))

# 25: 账号贡献(更多账号)
r = account_tools.get_account_contribution(SHOP, '2026-06-01', '2026-06-30', '合作', 'user_pay_amount', '更多账号', True, 1)
core = q("SELECT SUM(user_pay_amount) FROM core.douyin_account_daily WHERE sale_scope='合作' AND account_name='更多账号' AND biz_date BETWEEN '2026-06-01' AND '2026-06-30'")
check(25, '更多账号金额', r['data'][0]['numerator_value'], core, 0.1)

# 26-27: 类目
r = category_tools.rank_categories(SHOP, '2026-06-16', '2026-06-30', 3, None, None, 'user_pay_amount', 'current_value', 'DESC', 3)
core = q("SELECT category_level_3 FROM core.douyin_category_daily WHERE category_level_2<>'全部' AND category_level_3<>'全部' AND category_level_4='全部' AND biz_date BETWEEN '2026-06-16' AND '2026-06-30' GROUP BY category_level_3 ORDER BY SUM(user_pay_amount) DESC LIMIT 1")
print('  [{}] #26 三级类目TOP1: MCP={} core={}'.format('PASS' if r['data'][0]['category_l3']==core else 'FAIL', r['data'][0]['category_l3'], core))
results.append((26, r['data'][0]['category_l3']==core, '三级类目TOP1'))

# 29: 商品卡占全店
import database
rows = database.query("SELECT * FROM mart.get_business_contribution(%s,%s::date,%s::date,%s,%s)",
                      (SHOP,'2026-06-01','2026-06-30','商品卡','user_pay_amount'))
core = q("SELECT (SELECT SUM(user_pay_amount) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30' AND sale_scope='全部' AND carrier_type='商品卡' AND ad_period='不限')/(SELECT SUM(user_pay_amount) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-30' AND "+TOTAL_FILTER+")")
check(29, '商品卡占全店', rows[0]['contribution_rate'], core, 0.000001)

# 32: 人群
r = domain_tools.get_audience_summary(SHOP, '2026-06-01', '2026-06-30', None, '全部', 'user_pay_amount')
core = q("SELECT SUM(user_pay_amount) FROM core.douyin_audience_daily WHERE carrier_type='全部' AND audience_type='复购' AND biz_date BETWEEN '2026-06-01' AND '2026-06-30'")
check(30, '复购人群金额', next(d['user_pay_amount'] for d in r['data'] if d['audience_type']=='复购'), core, 0.1)

ok = sum(1 for _, o, _ in results if o)
print('\n=== 6G 数字一致性: {}/{} PASS ==='.format(ok, len(results)))
