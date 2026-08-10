# V1.0.1: MCP 投放工具 vs core 直接 SQL 数字一致性 (15题核心)
import subprocess, os, sys

sys.path.insert(0, r'D:/ecommerce-data-system/mcp_server')
os.environ['PGPASSWORD'] = os.environ.get('PG_ADMIN_PASSWORD', '')
PSQL = [r'D:/pgsql16_fresh/pgsql/bin/psql.exe','-U','postgres','-h','127.0.0.1','-p','5432','-d','ecommerce_db','-t','-A','-F','|']
TMP = r'D:/ecommerce-data-system/patches/v1.0.1/tests/_tmp.sql'
def q(sql):
    with open(TMP, 'w', encoding='utf-8') as f:
        f.write(sql)
    r = subprocess.run(PSQL+['-f',TMP], capture_output=True, text=True, encoding='utf-8', errors='replace')
    return r.stdout.strip()

from tools import advertising_tools

results = []
def check(name, mcp_val, core_val, tol=0.01):
    ok = mcp_val is not None and core_val not in ('', 'None') and abs(float(mcp_val) - float(core_val)) < tol
    results.append((name, ok, mcp_val, core_val))
    print('  [{}] {}: MCP={} core={}'.format('PASS' if ok else 'FAIL', name, mcp_val, core_val))

SCOPE_SQL = {
    '全店': "sale_scope='全部' AND carrier_type='全部' AND ad_period='不限'",
    '自营': "sale_scope='自营' AND carrier_type='全部' AND ad_period='不限'",
    '合作': "sale_scope='合作' AND carrier_type='全部' AND ad_period='不限'",
    '商品卡': "sale_scope='全部' AND carrier_type='商品卡' AND ad_period='不限'",
    '短视频': "sale_scope='全部' AND carrier_type='短视频' AND ad_period='不限'",
}

# 1. 全店30天 10指标
r = advertising_tools.get_advertising_summary('弹动官方旗舰店', '2026-06-01', '2026-06-30', '全店')
print('=== 1. 6月全店投放表现 (10指标) ===')
assert r['ok']
metrics = {m['metric_key']: m['metric_value'] for m in r['data']['metrics']}
where = SCOPE_SQL['全店']
core = q("SELECT sum(ad_spend_shop_promoted), sum(ad_spend_shop_bound), sum(ad_attributed_transaction_amount), sum(ad_attributed_transaction_amount)/NULLIF(sum(transaction_amount),0), sum(ad_spend_shop_bound)/NULLIF(sum(settlement_amount),0), sum(total_expense_rate_net_refund_shop_bound*settlement_amount)/NULLIF(sum(settlement_amount),0), sum(ad_efficiency_shop_promoted*ad_spend_shop_promoted)/NULLIF(sum(ad_spend_shop_promoted),0), sum(ad_efficiency_shop_bound*ad_spend_shop_bound)/NULLIF(sum(ad_spend_shop_bound),0), sum(store_efficiency_shop_promoted*ad_spend_shop_promoted)/NULLIF(sum(ad_spend_shop_promoted),0), sum(store_efficiency_shop_bound*ad_spend_shop_bound)/NULLIF(sum(ad_spend_shop_bound),0) FROM core.douyin_deal_daily WHERE {};".format(where))
cv = core.split('|')
names = ['ad_spend_shop_promoted','ad_spend_shop_bound','ad_attributed_transaction_amount','ad_attributed_transaction_share','ad_spend_rate_net_refund_shop_bound','total_expense_rate_net_refund_shop_bound','ad_efficiency_shop_promoted','ad_efficiency_shop_bound','store_efficiency_shop_promoted','store_efficiency_shop_bound']
for i, k in enumerate(names):
    check('全店30天 '+k, metrics.get(k), cv[i])

# 2. 各 scope 投放消耗(被投)
print()
print('=== 2. 各Scope投放消耗(被投) ===')
for scope, w in SCOPE_SQL.items():
    r = advertising_tools.get_advertising_summary('弹动官方旗舰店', '2026-06-01', '2026-06-30', scope)
    m = {x['metric_key']: x['metric_value'] for x in r['data']['metrics']}
    cv = q("SELECT sum(ad_spend_shop_promoted) FROM core.douyin_deal_daily WHERE {};".format(w))
    check('{} 投放消耗被投'.format(scope), m.get('ad_spend_shop_promoted'), cv)

# 3. 环比 06-16~30 vs 06-01~15
print()
print('=== 3. 最近15天投放环比 (06-16~30 vs 06-01~15) ===')
c = advertising_tools.compare_advertising('弹动官方旗舰店', '2026-06-16', '2026-06-30', '全店')
assert c['ok']
cmp_map = {x['metric_key']: x for x in c['data']['metrics']}
core_cur = q("SELECT sum(ad_spend_shop_bound) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-16' AND '2026-06-30' AND {};".format(SCOPE_SQL['全店']))
core_prev = q("SELECT sum(ad_spend_shop_bound) FROM core.douyin_deal_daily WHERE biz_date BETWEEN '2026-06-01' AND '2026-06-15' AND {};".format(SCOPE_SQL['全店']))
check('环比 投放消耗绑定 current', cmp_map['ad_spend_shop_bound']['current_value'], core_cur)
check('环比 投放消耗绑定 previous', cmp_map['ad_spend_shop_bound']['previous_value'], core_prev)
# 效率环比无百分点
eff = cmp_map['ad_efficiency_shop_promoted']
print('  投放效率(被投)环比: current={} prev={} abs={} rel={} pp={} (efficiency无pp={})'.format(
    eff['current_value'], eff['previous_value'], eff['absolute_change'], eff['relative_change'], eff['percentage_point_change'], eff['percentage_point_change'] is None))

print()
ok_all = sum(1 for x in results if x[1])
print('=== 汇总: {}/{} PASS ==='.format(ok_all, len(results)))
for n, ok, m, c in results:
    if not ok:
        print('  ❌ {}: MCP={} core={}'.format(n, m, c))
