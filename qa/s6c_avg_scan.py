# -*- coding: utf-8 -*-
"""6C补充: AVG扫描(搜索mart层/代码中错误的AVG日比例) + source_only专项"""
import subprocess, os, re, sys

os.environ['PGPASSWORD'] = os.environ.get('PG_ADMIN_PASSWORD', '')
PSQL = [r'D:/pgsql16_fresh/pgsql/bin/psql.exe','-U','postgres','-h','127.0.0.1','-p','5432','-d','ecommerce_db','-t','-A']
def q(sql):
    tmp = r'D:/ecommerce-data-system/qa/_tmp_q.sql'
    open(tmp,'w',encoding='utf-8').write(sql)
    r = subprocess.run(PSQL+['-f',tmp], capture_output=True, text=True, encoding='utf-8', errors='replace')
    return r.stdout.strip()

print('=== 6C-1: mart层函数源码中的 AVG( 使用 ===')
srcs = q("SELECT p.proname || '|' || pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='mart' AND p.prokind='f'")
bad_avg = []
for line in srcs.split(chr(10)):
    if not line.strip(): continue
    name, _, body = line.partition('|')
    for m in re.finditer(r'AVG\(\s*(\w+)', body):
        col = m.group(1)
        if any(k in col for k in ('rate','ratio','share','avg_','customer','item','amount_per')):
            bad_avg.append((name, col))
if bad_avg:
    print('❌ 发现可疑AVG:')
    for n, c in bad_avg: print('  ', n, '->', c)
else:
    print('✅ 无 AVG(比例/均值) 可疑使用')

print()
print('=== 6C-2: MCP Python 源码中自算指标(sum/avg/ratio) ===')
mcp_dir = r'D:/ecommerce-data-system/mcp_server'
hits = []
for root, _, files in os.walk(mcp_dir):
    if 'tests' in root: continue
    for f in files:
        if not f.endswith('.py'): continue
        path = os.path.join(root, f)
        for i, line in enumerate(open(path, encoding='utf-8'), 1):
            s = line.strip()
            if re.search(r'\b(sum|avg|average)\(', s, re.I) and 'SELECT' not in s.upper():
                hits.append((os.path.relpath(path, mcp_dir), i, s))
            if re.search(r'\bratio\s*=|_rate\s*=\s*[a-z_]+/[a-z_]+', s, re.I):
                hits.append((os.path.relpath(path, mcp_dir), i, s))
if hits:
    print('⚠️ 命中(需人工确认是否在重算数据库职责指标):')
    for p, i, s in hits[:20]: print('  ', p, ':', i, ':', s[:100])
else:
    print('✅ MCP Python 无自算指标代码')

print()
print('=== 6C-3: source_only 单日有值/多日NULL ===')
# deal 两日发货率: 单日
r1 = q("SELECT ship_within_2_days_rate::text FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-12','2026-06-12','全店')")
r2 = q("SELECT CASE WHEN ship_within_2_days_rate IS NULL THEN 'NULL' ELSE 'NOT_NULL' END FROM mart.get_business_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店')")
print('  单日(06-12):', r1, '(应有值)')
print('  多日(30天):', r2, '(应NULL)')
# category 成交笔单价(缺基础字段)
r3 = q("SELECT CASE WHEN avg_transaction_order_amount IS NULL THEN 'NULL' ELSE 'NOT_NULL' END FROM mart.get_category_period_summary('弹动官方旗舰店','2026-06-01','2026-06-01',3,NULL,NULL,NULL) LIMIT 1")
r4 = q("SELECT CASE WHEN avg_transaction_order_amount IS NULL THEN 'NULL' ELSE 'NOT_NULL' END FROM mart.get_category_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',3,NULL,NULL,NULL) LIMIT 1")
print('  category成交笔单价 单日:', r3, '(应有值) 多日:', r4, '(应NULL)')
# audience 复购率
r5 = q("SELECT CASE WHEN repeat_user_repeat_rate IS NULL THEN 'NULL' ELSE 'NOT_NULL' END FROM mart.get_audience_period_summary('弹动官方旗舰店','2026-06-01','2026-06-01',NULL,'全部') LIMIT 1")
r6 = q("SELECT CASE WHEN repeat_user_repeat_rate IS NULL THEN 'NULL' ELSE 'NOT_NULL' END FROM mart.get_audience_period_summary('弹动官方旗舰店','2026-06-01','2026-06-30',NULL,'全部') LIMIT 1")
print('  audience复购率 单日:', r5, '(应有值) 多日:', r6, '(应NULL)')

print()
print('=== 6C-4: source_only 白名单/代码无 COALESCE(...,0) 或 SUM(source_only) ===')
# 检查V1.4中 source_only 规则是否被当作可重算
src = q("SELECT count(*) FROM meta.metric_formula_rule WHERE calculation_mode='source_only' AND cross_period_recalculable=TRUE")
print('  source_only且跨期可重算(应为0):', src)
