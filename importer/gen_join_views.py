# -*- coding: utf-8 -*-
"""重建全部中文View：shop_id -> JOIN meta.shop 显示 shop_name (DROP+CREATE)。
架构：底层保留 shop_id；人工层通过 JOIN meta.shop 显示实时店铺名称。
"""
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

# 业务 View（需要 JOIN meta.shop 显示店铺名称）
BUSINESS_VIEWS = {
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
# 主数据 View（保留 ID/编码/名称 原样）
MASTER_VIEWS = {
    ('meta', 'shop'): '店铺信息',
    ('meta', 'source_sheet_mapping'): '工作表映射规则',
    ('meta', 'field_mapping'): '字段映射规则',
    ('meta', 'metric_formula_rule'): '指标公式规则',
    ('meta', 'database_object_dictionary'): '数据库中英文字典',
}

lines = ['-- 重建中文View: 业务表 JOIN meta.shop 显示店铺名称 (DROP+CREATE)',
         '-- shop_name -> 店铺名称 固定系统映射, 不查源字段字典', 'BEGIN;', '']

def build_view(ts, tt, cn, is_business):
    cols_raw = q("SELECT column_name FROM information_schema.columns "
                 "WHERE table_schema='{}' AND table_name='{}' ORDER BY ordinal_position;".format(ts, tt))
    cols = [c.strip() for c in cols_raw.strip().split('\n') if c.strip()]
    sel = []
    for col in cols:
        prefix = 't.' if is_business else ''
        if is_business and col == 'shop_id':
            sel.append('    s.shop_name AS "店铺名称"')
            continue
        if col == 'shop_name':
            sel.append('    shop_name AS "店铺名称"')
            continue
        r = q("SELECT column_name_cn FROM meta.database_object_dictionary "
              "WHERE schema_name='{}' AND object_name='{}' AND column_name='{}' "
              "AND enabled=TRUE LIMIT 1;".format(ts, tt, col))
        ccn = r.strip()
        if not ccn:
            print('WARN: {} {} 无中文名, 用英文兜底'.format(tt, col))
            ccn = col
        sel.append('    {}{} AS "{}"'.format(prefix, col, ccn))
    lines.append('DROP VIEW IF EXISTS "中文数据"."{}";'.format(cn))
    lines.append('CREATE VIEW "中文数据"."{}" AS'.format(cn))
    lines.append('SELECT')
    lines.append(',\n'.join(sel))
    if is_business:
        lines.append('FROM {}.{} t'.format(ts, tt))
        lines.append('JOIN meta.shop s ON t.shop_id = s.shop_id;')
    else:
        lines.append('FROM {}.{};'.format(ts, tt))
    lines.append('')

for (ts, tt), cn in BUSINESS_VIEWS.items():
    build_view(ts, tt, cn, True)
for (ts, tt), cn in MASTER_VIEWS.items():
    build_view(ts, tt, cn, False)

lines.append('COMMIT;')
out = r'D:/ecommerce-data-system/sql/33_rebuild_cn_views_join.sql'
with open(out, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('SQL生成:', out, '行数:', len(lines))
