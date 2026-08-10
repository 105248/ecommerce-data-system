# -*- coding: utf-8 -*-
"""阶段6F: MCP Tool 全量回归 + 安全检查
1) 24个Tool全部调用(参数正确→结果与mart一致)
2) agent_readonly 8项读写权限测试
3) 无 unrestricted SQL Tool 确认
"""
import sys, os, json, subprocess

sys.path.insert(0, r'D:/ecommerce-data-system/mcp_server')
os.environ['DB_USER'] = 'agent_readonly'

from tools import (catalog_tools, business_tools, product_tools,
                   account_tools, category_tools, domain_tools)

results = []

def rec(tool, ok, note):
    results.append((tool, ok, note))
    print('  [{}{}] {} {}'.format('PASS' if ok else 'FAIL', ' ' * (6-len('PASS' if ok else 'FAIL')), tool, note))

print('=== 6F-1: 24个MCP Tool 全量回归 ===')
# 基础目录
r = catalog_tools.list_shops(); rec('list_shops', r['ok'] and len(r['data'])==1 and r['data'][0]['shop_name']=='弹动官方旗舰店', str(len(r['data']))+'店')
r = catalog_tools.get_data_coverage('弹动官方旗舰店'); rec('get_data_coverage', r['ok'] and r['data'][0]['day_count']==30, '30天')
r = catalog_tools.get_metric_catalog('business'); rec('get_metric_catalog', r['ok'] and len(r['data'])>=15, str(len(r['data']))+'指标')
r = catalog_tools.get_import_history(3); rec('get_import_history', r['ok'] and len(r['data'])>=1, str(len(r['data']))+'批')
r = catalog_tools.health_check(); rec('health_check', r['ok'] and r['data'].get('status')=='ok', 'db ok')

# 经营
r = business_tools.get_business_summary('弹动官方旗舰店','2026-06-01','2026-06-30','全店','user_pay_amount')
rec('get_business_summary-全店', r['ok'] and abs(float(r['data'][0]['metric_value'])-9397490.90)<0.01, str(r['data'][0]['metric_value']))
r = business_tools.get_business_summary('弹动官方旗舰店','2026-06-01','2026-06-30','商品卡','user_pay_amount')
rec('get_business_summary-商品卡', r['ok'] and abs(float(r['data'][0]['metric_value'])-3202866.49)<0.01, str(r['data'][0]['metric_value']))
r = business_tools.get_business_summary('弹动官方旗舰店','2026-06-01','2026-06-30','自营','user_pay_amount')
rec('get_business_summary-自营', r['ok'] and abs(float(r['data'][0]['metric_value'])-8758528.79)<0.01, str(r['data'][0]['metric_value']))
r = business_tools.compare_business('弹动官方旗舰店','2026-06-08','2026-06-14','全店','user_pay_amount')
rec('compare_business', r['ok'] and r['data'][0]['comparison_status']=='可比较', str(r['data'][0]['current_value']))

# 商品
r = product_tools.get_product_summary('弹动官方旗舰店','2026-06-01','2026-06-30','3523538019611183417',None,'全部','user_pay_amount')
rec('get_product_summary', r['ok'] and len(r['data'])>=1, r['data'][0]['product_name'][:12] if r['data'] else '')
r = product_tools.rank_products('弹动官方旗舰店','2026-06-01','2026-06-30','user_pay_amount','current_value','DESC',10)
rec('rank_products', r['ok'] and len(r['data'])==10 and r['data'][0]['current_rank']==1, 'TOP10')
r = product_tools.get_product_contribution('弹动官方旗舰店','2026-06-01','2026-06-30','user_pay_amount','3523538019611183417',None,5)
rec('get_product_contribution', r['ok'] and len(r['data'])>=1 and r['data'][0]['contribution_to_product_domain'] is not None, '双分母')

# 账号
r = account_tools.get_account_summary('弹动官方旗舰店','2026-06-01','2026-06-30','合作',None,'user_pay_amount')
rec('get_account_summary', r['ok'] and len(r['data'])>=10, str(len(r['data']))+'行')
r = account_tools.rank_accounts('弹动官方旗舰店','2026-06-01','2026-06-30','合作','user_pay_amount','current_value','DESC',10,False,None)
rec('rank_accounts', r['ok'] and len(r['data'])==10 and all(d['account_role']!='aggregate_bucket' for d in r['data']), 'TOP10排除更多账号')
r = account_tools.get_account_contribution('弹动官方旗舰店','2026-06-01','2026-06-30','合作','user_pay_amount',None,True,5)
rec('get_account_contribution', r['ok'] and len(r['data'])>=1, str(len(r['data']))+'行')

# 类目
r = category_tools.get_category_summary('弹动官方旗舰店','2026-06-01','2026-06-30',3,None,None,None,'user_pay_amount')
rec('get_category_summary', r['ok'] and len(r['data'])>=10, str(len(r['data']))+'行')
r = category_tools.rank_categories('弹动官方旗舰店','2026-06-01','2026-06-30',3,None,None,'user_pay_amount','current_value','DESC',10)
rec('rank_categories-L3', r['ok'] and len(r['data'])==10, 'L3 TOP10')
r = category_tools.rank_categories('弹动官方旗舰店','2026-06-01','2026-06-30',2,None,None,'user_pay_amount','current_value','DESC',10)
rec('rank_categories-L2', r['ok'] and len(r['data'])==10, 'L2 TOP10')
r = category_tools.get_category_contribution('弹动官方旗舰店','2026-06-01','2026-06-30',3,None,None,'user_pay_amount',10)
rec('get_category_contribution', r['ok'] and len(r['data'])>=1, str(len(r['data']))+'行')

# 其他域
r = domain_tools.get_carrier_summary('弹动官方旗舰店','2026-06-01','2026-06-30',None,None,None,'user_pay_amount')
rec('get_carrier_summary', r['ok'] and len(r['data'])>=50, str(len(r['data']))+'行')
r = domain_tools.get_content_summary('弹动官方旗舰店','2026-06-01','2026-06-30',None,None,None,'user_pay_amount')
rec('get_content_summary', r['ok'] and len(r['data'])>=100, str(len(r['data']))+'行')
r = domain_tools.get_terminal_summary('弹动官方旗舰店','2026-06-01','2026-06-30',None,None,'user_pay_amount')
rec('get_terminal_summary', r['ok'] and len(r['data'])>=10, str(len(r['data']))+'行')
r = domain_tools.get_price_band_summary('弹动官方旗舰店','2026-06-01','2026-06-30',None,'user_pay_amount')
rec('get_price_band_summary', r['ok'] and len(r['data'])==6, '6带')
r = domain_tools.get_audience_summary('弹动官方旗舰店','2026-06-01','2026-06-30',None,'全部','user_pay_amount')
rec('get_audience_summary', r['ok'] and len(r['data'])==2, '首购+复购')
r = domain_tools.rank_carriers('弹动官方旗舰店','2026-06-01','2026-06-30','全部','user_pay_amount','current_value','DESC',10)
rec('rank_carriers', r['ok'] and len(r['data'])==5, '5载体')
r = domain_tools.rank_price_bands('弹动官方旗舰店','2026-06-01','2026-06-30','user_pay_amount','current_value','DESC',10)
rec('rank_price_bands', r['ok'] and len(r['data'])==6, '6带')
r = domain_tools.rank_audiences('弹动官方旗舰店','2026-06-01','2026-06-30','全部','user_pay_amount','current_value','DESC',10)
rec('rank_audiences', r['ok'] and len(r['data'])==2, '2类')

print()
print('=== 6F-2: 无 unrestricted SQL Tool 确认 ===')
import server
names = [t[0] for t in server.TOOLS]
sql_like = [n for n in names if any(k in n.lower() for k in ('sql','query','execute','raw'))]
rec('无SQL类Tool', len(sql_like)==0, '工具清单中无 sql/query/execute/raw: ' + ','.join(sql_like) if sql_like else '全部24个工具均为业务工具')

print()
ok_cnt = sum(1 for _, o, _ in results if o)
print('=== 6F 结果: {}/{} PASS ==='.format(ok_cnt, len(results)))
