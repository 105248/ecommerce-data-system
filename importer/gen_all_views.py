# -*- coding: utf-8 -*-
"""重建全部中文View: shop_id -> shop_name (DROP+CREATE)。"""
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
    if r.returncode != 0:
        print('ERR:', r.stderr[:200])
    return r.stdout

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

lines = ['-- 重建全部中文View: shop_id -> shop_name (DROP+CREATE)', 'BEGIN;', '']
for (ts, tt), cn in TABLE_CN.items():
    cols_raw = q("SELECT column_name FROM information_schema.columns "
                 "WHERE table_schema='{}' AND table_name='{}' ORDER BY ordinal_position;".format(ts, tt))
    cols = [c.strip() for c in cols_raw.strip().split('\n') if c.strip()]
    sel = []
    for col in cols:
        if col == 'shop_name':
            ccn, disp = '店铺名称', 'shop_name'
        elif col == 'shop_id':
            if tt == 'shop':
                ccn, disp = '店铺ID', 'shop_id'
            else:
                ccn, disp = '店铺名称', 'shop_name'
        else:
            r = q("SELECT column_name_cn FROM meta.database_object_dictionary "
                  "WHERE schema_name='{}' AND object_name='{}' AND column_name='{}' "
                  "AND enabled=TRUE LIMIT 1;".format(ts, tt, col))
            ccn = r.strip() or col
            disp = col
        sel.append('    {} AS "{}"'.format(disp, ccn))
    lines.append('DROP VIEW IF EXISTS "中文数据"."{}";'.format(cn))
    lines.append('CREATE VIEW "中文数据"."{}" AS'.format(cn))
    lines.append('SELECT')
    lines.append(',\n'.join(sel))
    lines.append('FROM {}.{};'.format(ts, tt))
    lines.append('')
lines.append('COMMIT;')

out = r'D:/ecommerce-data-system/sql/30_rebuild_all_cn_views.sql'
with open(out, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('SQL生成:', out, '行数:', len(lines))
