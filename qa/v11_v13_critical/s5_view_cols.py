# -*- coding: utf-8 -*-
"""P2 清零②补：mart 正式视图列 193 COMMENT（复用词级映射）"""
import re, sys
from pathlib import Path
sys.path.insert(0, r"D:/ecommerce-data-system/mcp_server")
import psycopg2

_env = {}
for l in Path(r"D:/ecommerce-data-system/mcp_server/.env").read_text(encoding="utf-8").splitlines():
    l = l.strip()
    if l and "=" in l and not l.startswith("#"):
        k, _, v = l.partition("="); _env[k.strip()] = v.strip()
conn = psycopg2.connect(host="127.0.0.1", port=5432, dbname="ecommerce_db",
                        user="postgres", password=_env.get("PG_ADMIN_PASSWORD", ""), connect_timeout=5)
conn.set_session(readonly=True, autocommit=True)
cur = conn.cursor()
cur.execute("SELECT DISTINCT target_column_name, target_column_name_cn FROM meta.field_mapping WHERE target_column_name_cn IS NOT NULL")
dict_cn = {r[0]: r[1] for r in cur.fetchall()}

WORD = {
    "id": "ID", "code": "编码", "name": "名称", "cn": "中文", "key": "键", "domain": "业务域",
    "platform": "平台", "shop": "店铺", "metric": "指标", "entity": "实体", "level": "层级",
    "type": "类型", "status": "状态", "date": "日期", "start": "开始", "end": "结束",
    "current": "当前期", "previous": "上期", "value": "值", "amount": "金额", "count": "数量",
    "rate": "比率", "ratio": "比例", "score": "得分", "weight": "权重", "threshold": "阈值",
    "direction": "方向", "absolute": "绝对", "relative": "相对", "change": "变化",
    "percentage": "百分点", "point": "点", "consecutive": "连续", "day": "天",
    "coverage": "覆盖", "complete": "完整", "mapping": "映射", "aggregation": "聚合",
    "allowed": "允许", "enabled": "启用", "notes": "备注", "created_at": "创建时间",
    "updated_at": "更新时间", "occurred_at": "发生时间", "first_seen": "首次出现",
    "last_seen": "最近出现", "occurrence": "出现次数", "business": "业务", "impact": "影响",
    "action": "行动", "category": "类别", "group": "组", "dedupe": "去重", "chain": "链路",
    "diagnostic": "诊断", "anomaly": "异常", "opportunity": "机会", "priority": "优先级",
    "risk": "风险", "evidence": "证据", "funnel": "漏斗", "stage": "环节", "primary": "主",
    "confidence": "置信度", "benchmark": "基准", "peer": "同类", "pool": "池",
    "materiality": "重要性", "growth": "增长", "persistence": "持续", "conversion": "转化",
    "refund": "退款", "ad": "投放", "efficiency": "效率", "contribution": "贡献",
    "available": "可用", "min": "最小", "max": "最大", "source": "来源", "target": "目标",
    "valid": "有效", "from": "起始", "to": "截止", "exclude": "排除", "parent": "父级",
    "master": "主档", "product": "商品", "sku": "SKU", "line": "品线", "alias": "别名",
    "brand": "品牌", "item": "件", "order": "订单", "buyer": "买家", "user": "用户",
    "pay": "支付", "settlement": "结算", "transaction": "成交", "exposure": "曝光",
    "click": "点击", "question": "问题", "intent": "意图", "duration": "耗时", "error": "错误",
    "hash": "哈希", "description": "说明", "display": "展示", "strategic": "战略",
    "run": "运行", "period": "周期", "rule": "规则", "formula": "公式", "sheet": "工作表",
    "header": "表头", "row": "行", "batch": "批次", "file": "文件", "import": "导入",
    "scope": "经营口径", "carrier": "载体", "terminal": "终端", "audience": "人群",
    "category": "类目", "account": "账号", "content": "内容", "price": "价格", "band": "带",
    "sale": "销售", "expense": "费比", "spend": "消耗", "bound": "绑定", "promoted": "被投",
    "net": "净", "gross": "毛", "smart": "智能", "coupon": "优惠券", "subsidy": "补贴",
    "presale": "预售", "deposit": "定金", "commission": "佣金", "creator": "达人",
    "ship": "发货", "within": "内", "hour": "小时", "avg": "平均",
    "customer": "客单", "daily": "每日", "snapshot": "快照",
    "quality": "质量", "data": "数据", "store": "全店", "version": "版本",
    "mode": "模式", "owner": "归属", "grantee": "被授权人", "privilege": "权限",
    "schema": "模式", "object": "对象", "db": "数据库", "unique": "唯一",
    "json": "JSON", "path": "路径", "recalculable": "可重算", "cross": "跨",
    "higher": "越高", "better": "越好", "expected": "期望", "mapped": "已映射",
    "shop_count": "店铺数", "unmapped": "未映射", "member": "成员", "conflict": "冲突",
    "resolution": "解析", "whitelist": "白名单", "source_row": "来源行", "warehouse": "仓库",
    "merchant": "商家", "export": "导出", "total": "合计", "sum": "汇总",
    "avg_customer_amount": "客单价", "avg_item_amount": "件单价",
    "period": "期间", "unrecalculable": "不可重算", "metrics": "指标集",
}

def snake_to_cn(col):
    if col in dict_cn and dict_cn[col]:
        return dict_cn[col]
    if col in WORD:
        return WORD[col]
    parts = re.split(r"_", col)
    i = 0; words = []
    while i < len(parts):
        matched = None
        for j in range(len(parts), i, -1):
            cand = "_".join(parts[i:j])
            if cand in WORD:
                matched = WORD[cand]; i = j; break
        if matched:
            words.append(matched)
        else:
            p = parts[i]
            words.append(WORD[p] if p in WORD else p)
            i += 1
    return "".join(words)

# 取 mart 视图缺 COMMENT 列
cur.execute("""SELECT n.nspname AS schema, c.relname AS view, a.attname AS col, a.attnum
FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_attribute a ON a.attrelid=c.oid
WHERE n.nspname='mart' AND c.relkind='v' AND a.attnum>0 AND NOT a.attisdropped
  AND col_description(c.oid, a.attnum) IS NULL
ORDER BY c.relname, a.attnum""")
cols = cur.fetchall()
sql = ["-- P2 清零②补：mart 视图列 COMMENT"]
cnt = 0
for sch, view, col, attnum in cols:
    cn = snake_to_cn(col)
    sql.append("COMMENT ON COLUMN {}.{}.{} IS '{}';".format(sch, view, col, cn.replace("'", "''")))
    cnt += 1
out = Path(r"D:/ecommerce-data-system/qa/v11_v13_critical/t2_view_cols.sql")
out.write_text("\n".join(sql), encoding="utf-8")
print("mart 视图列 COMMENT:", cnt, "条")
print("样本:", [s for s in sql[1:6]])
conn.close()
