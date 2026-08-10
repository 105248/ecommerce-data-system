# V1.0.1: 中文层 11 表覆盖核对 (missing_in_core / missing_in_chinese_view = 0)
import subprocess, os, json

os.environ['PGPASSWORD'] = os.environ.get('PG_ADMIN_PASSWORD', '')
PSQL = [r'D:/pgsql16_fresh/pgsql/bin/psql.exe','-U','postgres','-h','127.0.0.1','-p','5432','-d','ecommerce_db','-t','-A','-F','|']
TMP = r'D:/ecommerce-data-system/patches/v1.0.1/tests/_tmp.sql'
def q(sql):
    with open(TMP, 'w', encoding='utf-8') as f:
        f.write(sql)
    r = subprocess.run(PSQL+['-f',TMP], capture_output=True, text=True, encoding='utf-8', errors='replace')
    return r.stdout

# 中文View 映射 (表名 -> 中文View名)
cn_view = {
    'douyin_deal_daily': '抖音成交日报',
    'douyin_carrier_daily': '抖音载体日报',
    'douyin_account_daily': '抖音账号日报',
    'douyin_content_daily': '抖音内容日报',
    'douyin_terminal_daily': '抖音终端日报',
    'douyin_category_daily': '抖音类目日报',
    'douyin_product_daily': '抖音商品日报',
    'douyin_price_band_daily': '抖音价格带日报',
    'douyin_audience_daily': '抖音人群日报',
}
# sheet -> (core表, 中文View名)
sheet_target = {
    '成交概览': ('douyin_deal_daily', '抖音成交日报'),
    '自营成交': ('douyin_deal_daily', '抖音成交日报'),
    '合作成交': ('douyin_deal_daily', '抖音成交日报'),
    '载体构成': ('douyin_carrier_daily', '抖音载体日报'),
    '账号构成': ('douyin_account_daily', '抖音账号日报'),
    '单载体构成': ('douyin_content_daily', '抖音内容日报'),
    '终端构成': ('douyin_terminal_daily', '抖音终端日报'),
    '品类构成': ('douyin_category_daily', '抖音类目日报'),
    '商品构成': ('douyin_product_daily', '抖音商品日报'),
    '价格带构成': ('douyin_price_band_daily', '抖音价格带日报'),
    '人群构成': ('douyin_audience_daily', '抖音人群日报'),
}

new_headers = json.load(open(r'D:/ecommerce-data-system/patches/v1.0.1/tests/new_headers.json', encoding='utf-8'))

all_ok = True
print('=== 中文层 11 表覆盖核对 ===')
for sheet, (core_tbl, cn_view) in sheet_target.items():
    src_headers = new_headers[sheet]['headers']
    # mapping: 该sheet的 source_column_name -> target_column_name (V1.4+V1.0.1)
    map_out = q("SELECT source_column_name||'|'||target_column_name FROM meta.field_mapping WHERE source_sheet_name='{}' AND mapping_version IN ('V1.4','V1.0.1');".format(sheet))
    hdr_map = {}
    for l in map_out.split('\n'):
        if l.strip():
            s, t = l.strip().split('|')
            hdr_map.setdefault(s, t)
    # core 字段
    core_cols = set(q("SELECT column_name FROM information_schema.columns WHERE table_schema='core' AND table_name='{}';".format(core_tbl)).split())
    # 中文View 字段
    cn_cols = set(q("SELECT column_name FROM information_schema.columns WHERE table_schema='中文数据' AND table_name='{}';".format(cn_view)).split())

    missing_core = []
    missing_cn = []
    for h in src_headers:
        tgt = hdr_map.get(h)
        if tgt is None:
            continue
        if tgt not in core_cols:
            missing_core.append('{}(->{})'.format(h, tgt))
        cn_name = h  # 中文View 列名 = 源表头
        if cn_name not in cn_cols:
            missing_cn.append(h)
    status = '✅' if not missing_core and not missing_cn else '❌'
    if missing_core or missing_cn:
        all_ok = False
    print('  {} {}: 源{}列 映射{} | missing_in_core={} | missing_in_chinese_view={}'.format(
        status, sheet, len(src_headers), len(hdr_map), missing_core or 0, missing_cn or 0))

print()
print('=== 汇总:', '全部通过 ✅' if all_ok else '存在缺失 ❌', '===')

# 成交主表中文View 10 新字段抽查
print()
print('=== 抖音成交日报 中文View 10投放字段 ===')
out = q("SELECT string_agg(column_name, ',') FROM information_schema.columns WHERE table_schema='中文数据' AND table_name='抖音成交日报' AND column_name IN ('投放消耗(店铺被投)','投放消耗(店铺绑定)','投放贡献成交金额','投放贡献成交占比','投放费比(剔除退款、店铺绑定)','综合费比(剔除退款、店铺绑定)','投放效率(店铺被投)','投放效率(店铺绑定)','全店效率(店铺被投)','全店效率(店铺绑定)');")
print(' ', out)
