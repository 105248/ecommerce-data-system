# -*- coding: utf-8 -*-
"""生成中文可读层 V1.1 的字典填充 + 中文View 生成 SQL。

核心算法：
1. 字段有源表头且唯一 → column_name_cn = 原始表头, source=source_header, status=unique_source_header
2. 多源表头 → conflict_pending（本库已验证0冲突）
3. 技术字段（无源映射）→ 系统词典
4. 表名 → 中文View名称表
"""
import json
import subprocess
import os

# 管理密码从 mcp_server/.env 的 PG_ADMIN_PASSWORD 读取（禁止硬编码）
def _load_admin_pw():
    _env = {}
    try:
        with open(r'D:/ecommerce-data-system/mcp_server/.env', encoding='utf-8') as _f:
            for _l in _f:
                _l = _l.strip()
                if _l.startswith('PG_ADMIN_PASSWORD='):
                    return _l.split('=', 1)[1].strip()
    except Exception:
        pass
    return os.environ.get('PG_ADMIN_PASSWORD', '')
os.environ['PGPASSWORD'] = _load_admin_pw()
PSQL = [r'D:/pgsql16_fresh/pgsql/bin/psql.exe', '-U', 'postgres', '-h', '127.0.0.1', '-p', '5432', '-d', 'ecommerce_db', '-t', '-A', '-F', '\t']

def q(sql):
    r = subprocess.run(PSQL + ['-c', sql], capture_output=True, text=True, encoding='utf-8', errors='replace')
    return r.stdout

# ============ 1. 表中文名映射（文档表5+表6） ============
TABLE_CN = {
    ('core', 'douyin_deal_daily'): '抖音成交日报',
    ('core', 'douyin_carrier_daily'): '抖音载体日报',
    ('core', 'douyin_account_daily'): '抖音账号日报',
    ('core', 'douyin_content_daily'): '抖音内容日报',
    ('core', 'douyin_terminal_daily'): '抖音终端日报',
    ('core', 'douyin_category_daily'): '抖音类目日报',
    ('core', 'douyin_product_daily'): '抖音商品日报',
    ('core', 'douyin_price_band_daily'): '抖音价格带日报',
    ('core', 'douyin_audience_daily'): '抖音人群日报',
    ('meta', 'shop'): '店铺信息',
    ('meta', 'source_sheet_mapping'): '工作表映射规则',
    ('meta', 'field_mapping'): '字段映射规则',
    ('meta', 'metric_formula_rule'): '指标公式规则',
    ('meta', 'database_object_dictionary'): '数据库中英文字典',
    ('audit', 'import_batch'): '导入批次记录',
}

# ============ 2. 系统技术字段词典（文档表8） ============
SYSTEM_FIELDS = {
    'row_id': '数据行ID', 'shop_id': '店铺ID', 'batch_id': '导入批次ID',
    'biz_date': '日期', 'source_sheet_name': '源工作表名称',
    'source_row_number': '源文件行号', 'imported_at': '写入时间',
    'created_at': '创建时间', 'updated_at': '更新时间', 'enabled': '是否启用',
    'platform_code': '平台编码', 'shop_code': '店铺编码', 'shop_name': '店铺名称',
    'platform_shop_id': '平台店铺ID', 'sale_scope': '成交范围',
    'source_report_code': '源报表编码', 'source_sheet_code': '工作表编码',
    'target_schema': '目标Schema', 'target_table': '目标正式表',
    'sale_scope_override': '成交范围覆盖值', 'expected_column_count': '预期字段数',
    'sample_row_count': '参考样表行数', 'load_order': '导入顺序',
    'mapping_version': '映射版本', 'description': '说明',
    'source_column_order': '源字段顺序', 'source_column_name': '源中文字段名',
    'target_column_name': '目标英文字段名', 'target_column_name_cn': '目标字段中文名',
    'target_data_type': '目标数据类型', 'field_category': '字段类别',
    'aggregation_rule': '聚合规则', 'transform_rule': '转换规则',
    'value_unit': '数值单位', 'display_format': '展示格式',
    'display_decimal_places': '展示小数位', 'is_business_key': '业务键标记',
    'is_required_header': '必填表头标记', 'notes': '备注',
    'metric_rule_id': '指标规则ID', 'metric_category': '指标类别',
    'calculation_mode': '计算模式', 'formula_cn': '业务公式',
    'numerator_expression': '分子表达式', 'denominator_expression': '分母表达式',
    'multiplier': '计算倍率', 'single_row_formula': '单行公式',
    'period_formula_sql': '跨期SQL', 'zero_denominator_rule': '分母为0规则',
    'cross_period_recalculable': '跨期可重算', 'auto_use_allowed': '允许自动采用',
    'rule_status': '规则状态', 'display_order': '字段顺序',
    'visible_in_cn_view': '中文视图可见', 'source_file_name': '源文件名',
    'source_file_path': '源文件路径', 'file_sha256': '文件SHA256',
    'period_start': '周期开始', 'period_end': '周期结束',
    'import_mode': '导入模式', 'import_status': '导入状态',
    'source_row_count': '源文件行数', 'inserted_row_count': '写入行数',
    'error_message': '错误信息', 'dictionary_id': '字典ID',
    'object_name': '英文对象名', 'object_type': '对象类型',
    'object_name_cn': '中文对象名', 'column_name': '英文字段名',
    'column_name_cn': '中文字段名', 'chinese_name_source': '名称来源',
    'name_resolution_status': '解析状态', 'is_manual_override': '人工覆盖标记',
    'override_reason': '覆盖原因', 'business_definition': '业务含义',
    'source_platform': '来源平台', 'source_sheet_name_cn': '来源工作表',
    'source_field_name_cn': '原始中文表头', 'imported_row_count': '导入行数',
    'report_code': '报表编码',
}

# ============ 3. 从 field_mapping 提取字段级映射 ============
print('读取 field_mapping...')
rows_raw = q("""
SELECT fm.target_schema, fm.target_table, fm.target_column_name,
       fm.source_column_name, fm.source_sheet_name, fm.target_column_name_cn
FROM meta.field_mapping fm
WHERE fm.enabled = TRUE
ORDER BY fm.target_schema, fm.target_table, fm.target_column_name;
""")
# 按 (schema, table, column) 分组收集 variants
field_map = {}  # (schema,table,col) -> {sheet: header}
for line in rows_raw.strip().split('\n'):
    if not line.strip():
        continue
    parts = line.split('\t')
    if len(parts) < 6:
        continue
    ts, tt, tc, sc, sheet, tcn = parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]
    field_map.setdefault((ts, tt, tc), {})[sheet] = sc

print(f'字段映射组数: {len(field_map)}')

# ============ 4. 生成字典INSERT ============
dict_ins = []
view_field_data = {}  # (schema, table) -> [(col, cn, order)]

# 4a. core 9表 + meta/audit 表
all_tables = [(ts, tt) for ts, tt in TABLE_CN]
for ts, tt in all_tables:
    # 读表实际列（information_schema）
    cols_raw = q(f"""
        SELECT column_name, ordinal_position FROM information_schema.columns
        WHERE table_schema='{ts}' AND table_name='{tt}' ORDER BY ordinal_position;
    """)
    cols = []
    for line in cols_raw.strip().split('\n'):
        if line.strip():
            p = line.split('\t')
            if len(p) >= 2:
                cols.append((p[0], int(p[1])))
    # 表级记录
    cn_table = TABLE_CN[(ts, tt)]
    dict_ins.append({
        'schema': ts, 'obj': tt, 'otype': 'table', 'ocn': cn_table,
        'col': None, 'ccn': None, 'src': 'manual' if cn_table else 'system_dictionary',
        'status': 'manual_confirmed' if cn_table else 'system_field',
        'sheet': None, 'header': None, 'variants': None, 'biz': None,
    })
    # 字段级
    for col, ord_ in cols:
        key = (ts, tt, col)
        if key in field_map:
            variants = field_map[key]  # {sheet: header}
            headers = list(set(variants.values()))
            if len(headers) == 1:
                ccn, src, status = headers[0], 'source_header', 'unique_source_header'
            else:
                # 冲突（本库无）
                ccn, src, status = None, 'source_header', 'conflict_pending'
            dict_ins.append({
                'schema': ts, 'obj': tt, 'otype': 'column', 'ocn': None,
                'col': col, 'ccn': ccn, 'src': src, 'status': status,
                'sheet': None, 'header': None,
                'variants': json.dumps(variants, ensure_ascii=False),
                'biz': None,
            })
        else:
            # 技术字段 -> 系统词典
            ccn = SYSTEM_FIELDS.get(col, None)
            if ccn is None:
                ccn = col  # 兜底（不应发生）
            dict_ins.append({
                'schema': ts, 'obj': tt, 'otype': 'column', 'ocn': None,
                'col': col, 'ccn': ccn, 'src': 'system_dictionary', 'status': 'system_field',
                'sheet': None, 'header': None, 'variants': None, 'biz': None,
            })

# 4b. metric_formula_rule 的技术字段补充（numerator/denominator 中文名来自源映射）
print(f'字典记录数: {len(dict_ins)}')

# ============ 5. 生成 SQL ============
lines = []
lines.append('-- 中文可读层 V1.1：字典填充 + 中文View生成')
lines.append('BEGIN;')
lines.append('')

# 5a. 清空字典（重建，不删业务数据）
lines.append('TRUNCATE meta.database_object_dictionary;')
lines.append('')

# 5b. 字典INSERT
lines.append('-- 字典填充')
for d in dict_ins:
    def esc(v):
        if v is None:
            return 'NULL'
        return "'" + str(v).replace("'", "''") + "'"
    col = 'NULL' if d['col'] is None else esc(d['col'])
    ccn = 'NULL' if d['ccn'] is None else esc(d['ccn'])
    ocn = 'NULL' if d['ocn'] is None else esc(d['ocn'])
    variants = 'NULL' if d['variants'] is None else "'" + d['variants'].replace("'", "''") + "'::jsonb"
    biz = 'NULL' if d['biz'] is None else esc(d['biz'])
    lines.append(f"INSERT INTO meta.database_object_dictionary "
                 f"(schema_name, object_name, object_type, object_name_cn, column_name, column_name_cn, "
                 f"chinese_name_source, name_resolution_status, source_header_variants, business_definition, "
                 f"mapping_version, enabled) VALUES "
                 f"({esc(d['schema'])}, {esc(d['obj'])}, {esc(d['otype'])}, {ocn}, {col}, {ccn}, "
                 f"{esc(d['src'])}, {esc(d['status'])}, {variants}, {biz}, 'V1.1', TRUE);")
lines.append('')

# 5c. 中文View生成（用字典动态生成）
lines.append('-- 中文View生成（core 9 + meta 5 + audit 1）')
for ts, tt in TABLE_CN:
    cn_obj = TABLE_CN[(ts, tt)]
    # 收集该表的字段中文名（按 display_order 顺序 = ordinal）
    col_order = []
    for d in dict_ins:
        if d['schema'] == ts and d['obj'] == tt and d['otype'] == 'column' and d['col']:
            col_order.append((d['col'], d['ccn']))
    # 用 information_schema 排序
    col_order.sort(key=lambda x: next((o for o, c in cols if c == x[0]), 999))
    selects = []
    for i, (col, ccn) in enumerate(col_order):
        comma = ',' if i < len(col_order) - 1 else ''
        if ccn is None:
            # 冲突字段：注释占位（本库无）
            selects.append(f'    {col} AS "{col}(冲突待决)"{comma}')
        else:
            selects.append(f'    {col} AS "{ccn}"{comma}')
    view_sql = f'''CREATE OR REPLACE VIEW "中文数据"."{cn_obj}" AS
SELECT
{chr(10).join(selects)}
FROM {ts}.{tt};'''
    lines.append(view_sql)
    lines.append('')

lines.append('COMMIT;')

out_path = r'D:\ecommerce-data-system\sql\20_cn_views.sql'
with open(out_path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('SQL 已生成:', out_path)
print('行数:', len(lines))
