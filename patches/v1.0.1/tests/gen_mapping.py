# V1.0.1: 生成 61列 field_mapping 重建 SQL + core 加10字段 SQL
import subprocess, os, json

os.environ['PGPASSWORD'] = os.environ.get('PG_ADMIN_PASSWORD', '')
PSQL = [r'D:/pgsql16_fresh/pgsql/bin/psql.exe','-U','postgres','-h','127.0.0.1','-p','5432','-d','ecommerce_db','-t','-A','-F','|']
TMP = r'D:/ecommerce-data-system/patches/v1.0.1/tests/_tmp.sql'
def q(sql):
    with open(TMP, 'w', encoding='utf-8') as f:
        f.write(sql)
    r = subprocess.run(PSQL+['-f',TMP], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if r.returncode != 0:
        print('ERR:', r.stderr[:200])
    return r.stdout

# 1) 读旧映射 (前三张表 51列 V1.4)
old_map = {}
for sheet in ['成交概览','自营成交','合作成交']:
    out = q(f"SELECT source_column_name||'|'||COALESCE(target_schema,'')||'|'||COALESCE(target_table,'')||'|'||COALESCE(target_column_name,'')||'|'||COALESCE(target_data_type,'')||'|'||COALESCE(field_category,'')||'|'||COALESCE(aggregation_rule,'')||'|'||COALESCE(transform_rule,'')||'|'||COALESCE(value_unit,'')||'|'||COALESCE(display_format,'')||'|'||is_business_key||'|'||is_required_header FROM meta.field_mapping WHERE source_sheet_name='{sheet}' AND mapping_version='V1.4';")
    old_map[sheet] = {}
    for l in out.split('\n'):
        if not l.strip():
            continue
        parts = l.strip().split('|')
        old_map[sheet][parts[0]] = parts[1:]
    print(f'  旧映射 {sheet}: {len(old_map[sheet])} 条')

# 2) 新10字段定义
new10 = [
    # (中文表头, 英文字段, 类型, 字段类别, 聚合规则, 值单位, 展示格式)
    ('投放消耗(店铺被投)', 'ad_spend_shop_promoted', 'NUMERIC(20,2)', '投放指标-可加金额', 'SUM', '元', '金额'),
    ('投放消耗(店铺绑定)', 'ad_spend_shop_bound', 'NUMERIC(20,2)', '投放指标-可加金额', 'SUM', '元', '金额'),
    ('投放贡献成交金额', 'ad_attributed_transaction_amount', 'NUMERIC(20,2)', '投放指标-可加金额', 'SUM', '元', '金额'),
    ('投放贡献成交占比', 'ad_attributed_transaction_share', 'NUMERIC(18,8)', '投放指标-比例', 'weighted_source_ratio', '比率', '百分比'),
    ('投放费比(剔除退款、店铺绑定)', 'ad_spend_rate_net_refund_shop_bound', 'NUMERIC(18,8)', '投放指标-比例', 'weighted_source_ratio', '比率', '百分比'),
    ('综合费比(剔除退款、店铺绑定)', 'total_expense_rate_net_refund_shop_bound', 'NUMERIC(18,8)', '投放指标-比例', 'weighted_source_ratio', '比率', '百分比'),
    ('投放效率(店铺被投)', 'ad_efficiency_shop_promoted', 'NUMERIC(20,8)', '投放指标-效率', 'weighted_source_ratio', '倍数', '倍数'),
    ('投放效率(店铺绑定)', 'ad_efficiency_shop_bound', 'NUMERIC(20,8)', '投放指标-效率', 'weighted_source_ratio', '倍数', '倍数'),
    ('全店效率(店铺被投)', 'store_efficiency_shop_promoted', 'NUMERIC(20,8)', '投放指标-效率', 'weighted_source_ratio', '倍数', '倍数'),
    ('全店效率(店铺绑定)', 'store_efficiency_shop_bound', 'NUMERIC(20,8)', '投放指标-效率', 'weighted_source_ratio', '倍数', '倍数'),
]
new10_map = {h: (en, dt, cat, agg, unit, fmt) for h, en, dt, cat, agg, unit, fmt in new10}

# 3) 读新表头
headers = json.load(open(r'D:/ecommerce-data-system/patches/v1.0.1/tests/new_headers.json', encoding='utf-8'))

# 4) 生成 INSERT SQL
lines = ['-- V1.0.1: 前三张成交表 61列完整重建 field_mapping', 'BEGIN;', '']
sheet_code = {'成交概览':'S1','自营成交':'S2','合作成交':'S3'}
for sheet in ['成交概览','自营成交','合作成交']:
    hdr = headers[sheet]['headers']
    lines.append(f'-- {sheet} ({len(hdr)}列)')
    lines.append(f"DELETE FROM meta.field_mapping WHERE source_sheet_name='{sheet}' AND mapping_version='V1.4';")
    for i, h in enumerate(hdr, 1):
        if h in new10_map:
            en, dt, cat, agg, unit, fmt = new10_map[h]
            tgt = 'core.douyin_deal_daily'
            tgt_col = en
            biz = 'FALSE'; req = 'TRUE'
        elif h in old_map[sheet]:
            meta = old_map[sheet][h]  # [schema, table, col, type, cat, agg, tr, unit, fmt, biz, req]
            tgt = meta[0] + '.' + meta[1]
            tgt_col = meta[2]
            dt = meta[3]; cat = meta[4]; agg = meta[5]; unit = meta[8]; fmt = meta[9]
            biz = meta[9]; req = meta[10]
            tr = meta[6]
        else:
            print(f'  ⚠️ {sheet} 位置{i} "{h}" 无旧映射且非新字段!')
            continue
        esc = h.replace("'", "''")
        tr_sql = tr if h not in new10_map else ''
        lines.append(f"INSERT INTO meta.field_mapping (source_sheet_name, source_sheet_code, source_column_order, source_column_name, target_schema, target_table, target_column_name, target_column_name_cn, target_data_type, field_category, aggregation_rule, transform_rule, value_unit, display_format, is_business_key, is_required_header, mapping_version, enabled) VALUES ('{sheet}', '{sheet_code[sheet]}', {i}, '{esc}', '{tgt.split('.')[0]}', '{tgt.split('.')[1]}', '{tgt_col}', '{esc}', '{dt}', '{cat}', '{agg}', '{tr_sql}', '{unit}', '{fmt}', {biz}, {req}, 'V1.0.1', TRUE);")
    lines.append('')
lines.append('COMMIT;')

out = r'D:/ecommerce-data-system/patches/v1.0.1/01_schema_mapping_patch.sql'
with open(out, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(lines))
print(f'\nfield_mapping 重建 SQL 已生成: {out} ({len(lines)}行)')

# 5) 生成 core 加列 SQL
ddl = ['-- V1.0.1: core.douyin_deal_daily 新增10投放字段', 'BEGIN;', '']
for h, en, dt, cat, agg, unit, fmt in new10:
    ddl.append(f"ALTER TABLE core.douyin_deal_daily ADD COLUMN IF NOT EXISTS {en} {dt};")
    ddl.append(f"COMMENT ON COLUMN core.douyin_deal_daily.{en} IS '{h} (V1.0.1新增, 类别:{cat}, 聚合:{agg})';")
    ddl.append('')
ddl.append('COMMIT;')
out2 = r'D:/ecommerce-data-system/patches/v1.0.1/01b_core_add10.sql'
with open(out2, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(ddl))
print(f'core 加10字段 SQL 已生成: {out2} ({len(ddl)}行)')
