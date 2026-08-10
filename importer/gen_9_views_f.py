# -*- coding: utf-8 -*-
"""重建9张业务中文View: JOIN meta.shop 显示店铺名称。
用 -f 文件方式执行 psql（-c 传中文参数不可靠）。
"""
import subprocess
import os
import tempfile

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
    """用临时文件方式执行查询（避免 -c 中文参数问题）。"""
    with tempfile.NamedTemporaryFile('w', suffix='.sql', delete=False, encoding='utf-8') as f:
        f.write(sql)
        tmp = f.name
    try:
        r = subprocess.run(PSQL + ['-f', tmp], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=30)
        if r.returncode != 0:
            print('ERR:', r.stderr[:200])
        return r.stdout
    finally:
        try:
            os.unlink(tmp)
        except OSError:
            pass

BUSINESS = [
    ('core', 'douyin_deal_daily', '抖音成交日报'),
    ('core', 'douyin_carrier_daily', '抖音载体日报'),
    ('core', 'douyin_account_daily', '抖音账号日报'),
    ('core', 'douyin_content_daily', '抖音内容日报'),
    ('core', 'douyin_terminal_daily', '抖音终端日报'),
    ('core', 'douyin_category_daily', '抖音类目日报'),
    ('core', 'douyin_product_daily', '抖音商品日报'),
    ('core', 'douyin_price_band_daily', '抖音价格带日报'),
    ('core', 'douyin_audience_daily', '抖音人群日报'),
]

lines = ['-- 重建9张业务中文View: JOIN meta.shop 显示店铺名称', 'BEGIN;', '']
for ts, tt, cn in BUSINESS:
    cols_raw = q("SELECT column_name FROM information_schema.columns "
                 "WHERE table_schema='{}' AND table_name='{}' ORDER BY ordinal_position;".format(ts, tt))
    cols = [c.strip() for c in cols_raw.strip().split('\n') if c.strip()]
    sel = []
    for col in cols:
        if col == 'shop_id':
            sel.append('    s.shop_name AS "店铺名称"')
            continue
        r = q("SELECT column_name_cn FROM meta.database_object_dictionary "
              "WHERE schema_name='{}' AND object_name='{}' AND column_name='{}' "
              "AND enabled=TRUE LIMIT 1;".format(ts, tt, col))
        ccn = r.strip()
        if not ccn:
            print('WARN: {} {} 无中文名, 用英文兜底'.format(tt, col))
            ccn = col
        sel.append('    t.{} AS "{}"'.format(col, ccn))
    lines.append('DROP VIEW IF EXISTS "中文数据"."{}";'.format(cn))
    lines.append('CREATE VIEW "中文数据"."{}" AS'.format(cn))
    lines.append('SELECT')
    lines.append(',\n'.join(sel))
    lines.append('FROM {}.{} t'.format(ts, tt))
    lines.append('JOIN meta.shop s ON t.shop_id = s.shop_id;')
    lines.append('')

lines.append('COMMIT;')
out = r'D:/ecommerce-data-system/sql/39_rebuild_9_business.sql'
with open(out, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
print('生成:', out, '行数:', len(lines))
