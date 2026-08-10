# V1.0.1: 旧表头(51列V1.4) vs 最新表头(61列) 差异报告
import subprocess, os, json

os.environ['PGPASSWORD'] = os.environ.get('PG_ADMIN_PASSWORD', '')
PSQL = [r'D:/pgsql16_fresh/pgsql/bin/psql.exe','-U','postgres','-h','127.0.0.1','-p','5432','-d','ecommerce_db','-t','-A','-F','|']
TMP = r'D:/ecommerce-data-system/patches/v1.0.1/tests/_tmp.sql'
def q(sql):
    with open(TMP, 'w', encoding='utf-8') as f:
        f.write(sql)
    r = subprocess.run(PSQL+['-f',TMP], capture_output=True, text=True, encoding='utf-8', errors='replace')
    return r.stdout

new_headers = json.load(open(r'D:/ecommerce-data-system/patches/v1.0.1/tests/new_headers.json', encoding='utf-8'))

# 从 field_mapping 重建旧51列顺序 (V1.4 column_position)
print('=== 旧表头(V1.4 field_mapping column_position) vs 最新61列 ===')
for sheet in ['成交概览', '自营成交', '合作成交']:
    out = q(f"SELECT source_column_name FROM meta.field_mapping WHERE source_sheet_name='{sheet}' AND mapping_version='V1.4' ORDER BY source_column_order;")
    old_hdr = [l.strip() for l in out.split('\n') if l.strip()]
    new_hdr = new_headers[sheet]['headers']
    print(f'--- {sheet}: 旧={len(old_hdr)}列 新={len(new_hdr)}列 ---')
    # 位置差异: 逐位置对比
    moved = []
    for i, nh in enumerate(new_hdr[:51], 1):  # 前51位置
        oh = old_hdr[i-1] if i-1 < len(old_hdr) else '(缺)'
        if nh != oh:
            moved.append(f'  位置{i}: 旧"{oh}" 新"{nh}"')
    if moved:
        print(f'  前51位差异 {len(moved)} 处:')
        for m in moved[:40]:
            print(m)
    else:
        print('  前51位顺序完全一致')
    # 新增10列
    extra = new_hdr[51:]
    print(f'  新增(52-61): {extra}')

print()
print('=== 8张其他表: 表头 vs field_mapping 核对 ===')
sheet_map = {'载体构成':'载体构成','账号构成':'账号构成','单载体构成':'单载体构成','终端构成':'终端构成',
             '品类构成':'品类构成','商品构成':'商品构成','价格带构成':'价格带构成','人群构成':'人群构成'}
for sheet in sheet_map:
    out = q(f"SELECT source_column_name FROM meta.field_mapping WHERE source_sheet_name='{sheet}' AND mapping_version='V1.4';")
    mapped = set(l.strip() for l in out.split('\n') if l.strip())
    new_hdr = set(new_headers[sheet]['headers'])
    only_new = new_hdr - mapped
    print(f'  {sheet}: 源{len(new_hdr)}列 映射{len(mapped)} | 未映射源字段: {only_new if only_new else "无 ✅"}')
