# V1.0.1: 重建 analysis_metric_whitelist 追加10条 (v2: 正则提取)
import subprocess, os, re

os.environ['PGPASSWORD'] = os.environ.get('PG_ADMIN_PASSWORD', '')
PSQL = [r'D:/pgsql16_fresh/pgsql/bin/psql.exe','-U','postgres','-h','127.0.0.1','-p','5432','-d','ecommerce_db','-t','-A']
TMP = r'D:/ecommerce-data-system/patches/v1.0.1/tests/_tmp.sql'
def q(sql):
    with open(TMP, 'w', encoding='utf-8') as f:
        f.write(sql)
    r = subprocess.run(PSQL+['-f',TMP], capture_output=True, text=True, encoding='utf-8', errors='replace')
    return r.stdout.strip()

viewdef = q("SELECT pg_get_viewdef('mart.analysis_metric_whitelist'::regclass);")

m = re.search(r'FROM \( VALUES (.*?)\)\) v\(', viewdef, re.S)
assert m, 'regex not match'
rows_part = m.group(1)  # 逗号分隔的 VALUES 行, 每行形如 ('business'::text,'user_pay_amount'::text,...)

new_rows = [
    "('advertising'::text,'ad_spend_shop_promoted'::text,'投放消耗(店铺被投)'::text,'additive'::text,false,false,'DESC'::text)",
    "('advertising'::text,'ad_spend_shop_bound'::text,'投放消耗(店铺绑定)'::text,'additive'::text,false,false,'DESC'::text)",
    "('advertising'::text,'ad_attributed_transaction_amount'::text,'投放贡献成交金额'::text,'additive'::text,false,false,'DESC'::text)",
    "('advertising'::text,'ad_attributed_transaction_share'::text,'投放贡献成交占比'::text,'ratio'::text,false,false,'DESC'::text)",
    "('advertising'::text,'ad_spend_rate_net_refund_shop_bound'::text,'投放费比(剔除退款、店铺绑定)'::text,'ratio'::text,false,false,'DESC'::text)",
    "('advertising'::text,'total_expense_rate_net_refund_shop_bound'::text,'综合费比(剔除退款、店铺绑定)'::text,'ratio'::text,false,false,'DESC'::text)",
    "('advertising'::text,'ad_efficiency_shop_promoted'::text,'投放效率(店铺被投)'::text,'efficiency'::text,false,false,'DESC'::text)",
    "('advertising'::text,'ad_efficiency_shop_bound'::text,'投放效率(店铺绑定)'::text,'efficiency'::text,false,false,'DESC'::text)",
    "('advertising'::text,'store_efficiency_shop_promoted'::text,'全店效率(店铺被投)'::text,'efficiency'::text,false,false,'DESC'::text)",
    "('advertising'::text,'store_efficiency_shop_bound'::text,'全店效率(店铺绑定)'::text,'efficiency'::text,false,false,'DESC'::text)",
]

all_rows = rows_part + ')' + ',\n    ' + ',\n    '.join(new_rows)

new_view = f"""CREATE OR REPLACE VIEW mart.analysis_metric_whitelist AS
SELECT domain_key, metric_key, metric_name_cn, value_type, rank_allowed, contribution_allowed, default_rank_direction
FROM ( VALUES {all_rows}) v(domain_key, metric_key, metric_name_cn, value_type, rank_allowed, contribution_allowed, default_rank_direction);"""

out = r'D:/ecommerce-data-system/patches/v1.0.1/03c2_whitelist_rebuild.sql'
with open(out, 'w', encoding='utf-8', newline='\n') as f:
    f.write(new_view)
print('已生成:', out, '| advertising 行:', new_view.count("'advertising'"))
