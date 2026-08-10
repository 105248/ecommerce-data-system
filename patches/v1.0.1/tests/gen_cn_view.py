# V1.0.1: 从 core 物理列 + 中文字典 完整重建 抖音成交日报 中文View
import subprocess, os

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
PSQL = [r'D:/pgsql16_fresh/pgsql/bin/psql.exe','-U','postgres','-h','127.0.0.1','-p','5432','-d','ecommerce_db','-t','-A','-F','|']
TMP = r'D:/ecommerce-data-system/patches/v1.0.1/tests/_tmp.sql'
def q(sql):
    with open(TMP, 'w', encoding='utf-8') as f:
        f.write(sql)
    r = subprocess.run(PSQL+['-f',TMP], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if r.returncode != 0:
        print('ERR:', r.stderr[:150])
    return r.stdout

# 1) core 物理列 (按顺序)
cols_raw = q("SELECT column_name FROM information_schema.columns WHERE table_schema='core' AND table_name='douyin_deal_daily' ORDER BY ordinal_position;")
cols = [c.strip() for c in cols_raw.split('\n') if c.strip()]
print('物理列数:', len(cols))

# 2) 每列中文名 (字典优先, 特判)
sel = []
for col in cols:
    if col == 'shop_id':
        sel.append('    s.shop_name AS "店铺名称"')
        continue
    cn = q("SELECT column_name_cn FROM meta.database_object_dictionary WHERE schema_name='core' AND object_name='douyin_deal_daily' AND column_name='{}' AND enabled=TRUE LIMIT 1;".format(col)).strip()
    if not cn:
        # 兜底: 系统字段
        fallback = {'row_id':'数据行ID','batch_id':'导入批次ID','source_sheet_name':'源工作表名称','source_row_number':'源文件行号','imported_at':'写入时间','sale_scope':'成交范围','biz_date':'日期','shop_name':'店铺名称'}
        cn = fallback.get(col, col)
    sel.append('    t.{} AS "{}"'.format(col, cn))

view_sql = """DROP VIEW IF EXISTS "中文数据"."抖音成交日报";
CREATE VIEW "中文数据"."抖音成交日报" AS
SELECT
{}
FROM core.douyin_deal_daily t
JOIN meta.shop s ON t.shop_id = s.shop_id;""".format(',\n'.join(sel))

out = r'D:/ecommerce-data-system/patches/v1.0.1/04_cn_view_patch.sql'
with open(out, 'w', encoding='utf-8', newline='\n') as f:
    f.write(view_sql + '\n')
print('已生成:', out, '| 列数:', len(sel))
# 校验: 10新字段存在
for c in ['ad_spend_shop_promoted','store_efficiency_shop_bound']:
    print('  含', c, ':', any(c in s for s in sel))
