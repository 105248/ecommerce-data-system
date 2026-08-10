# -*- coding: utf-8 -*-
"""重建中文View：shop_id 列替换为 shop_name（店铺名称）。"""
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

# 表名映射
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
    ('audit', 'import_batch'): '导入批次记录',
}

# 从字典取每表的字段中文名（按 ordinal 排序）
lines = ['-- 重建中文View: shop_id -> shop_name']
lines.append('BEGIN;')

for (ts, tt), cn in TABLE_CN.items():
    # 读物理列
    cols_raw = q(f"SELECT column_name, ordinal_position FROM information_schema.columns WHERE table_schema='{ts}' AND table_name='{tt}' ORDER BY ordinal_position;")
    cols = []
    for line in cols_raw.strip().split('\n'):
        if line.strip():
            p = line.split('\t')
            if len(p) >= 2:
                cols.append((p[0], int(p[1])))
    # 从字典取中文名
    selects = []
    for col, ord_ in cols:
        # 查询字典中文名
        r = q(f"SELECT column_name_cn FROM meta.database_object_dictionary WHERE schema_name='{ts}' AND object_name='{tt}' AND column_name='{col}' AND enabled=TRUE LIMIT 1;")
        ccn = r.strip()
        if not ccn:
            ccn = col
        # shop_id 特判 -> 显示 shop_name
        if col == 'shop_id':
            ccn = '店铺名称'
            col = 'shop_name'
        selects.append(f'    {col} AS "{ccn}"')
    view = f'''CREATE OR REPLACE VIEW "中文数据"."{cn}" AS
SELECT
{',\n'.join(selects)}
FROM {ts}.{tt};'''
    lines.append(view)
    lines.append('')

lines.append('COMMIT;')

out = r'D:\ecommerce-data-system\sql\28_rebuild_cn_views.sql'
with open(out, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('SQL 已生成:', out)
