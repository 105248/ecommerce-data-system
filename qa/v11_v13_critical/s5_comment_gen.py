# -*- coding: utf-8 -*-
"""P2 清零②：补 386 中文 COMMENT（4 表 + 24 中文视图 + 358 列）
规则：core 列用 field_mapping.target_column_name_cn（既有字典，禁止重译）；
V1.1/V1.3 新表列用英文 snake_case 词级映射生成业务中文；表/视图用业务中文。只 COMMENT，不改结构/数据。"""
import csv, re
from pathlib import Path

OUT = Path(r"D:/ecommerce-data-system/qa/v11_v13_critical")
# 1. field_mapping 既有字典（英文→中文）
import psycopg2
_env = {}
for _l in Path(r"D:/ecommerce-data-system/mcp_server/.env").read_text(encoding="utf-8").splitlines():
    _l = _l.strip()
    if _l and "=" in _l and not _l.startswith("#"):
        _k, _, _v = _l.partition("="); _env[_k.strip()] = _v.strip()
conn = psycopg2.connect(host="127.0.0.1", port=5432, dbname="ecommerce_db",
                        user="postgres", password=_env.get("PG_ADMIN_PASSWORD", ""), connect_timeout=5)
conn.set_session(readonly=True, autocommit=True)
cur = conn.cursor()
cur.execute("SELECT DISTINCT target_column_name, target_column_name_cn FROM meta.field_mapping WHERE target_column_name_cn IS NOT NULL")
dict_cn = {r[0]: r[1] for r in cur.fetchall()}
cur.close()

# 2. 词表（英文词 → 中文）
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
    "platform_": "平台", "ship": "发货", "within": "内", "hour": "小时", "avg": "平均",
    "customer": "客单", "cvr": "转化率", "ctr": "点击率", "daily": "每日", "snapshot": "快照",
    "quality": "质量", "data": "数据", "store": "全店", "issue": "问题", "version": "版本",
    "mode": "模式", "status_code": "状态码", "owner": "归属", "grantor": "授权人",
    "grantee": "被授权人", "privilege": "权限", "schema": "模式", "object": "对象",
    "db": "数据库", "unique": "唯一", "json": "JSON", "path": "路径", "source_": "来源",
    "recalculable": "可重算", "cross": "跨", "higher": "越高", "better": "越好",
    "entity_name_field": "实体名字段", "entity_id_field": "实体ID字段",
    "parent_dimension": "父级维度", "dimension": "维度", "value_cn": "中文值",
    "source_sheet": "来源工作表", "row_number": "行号", "imported_at": "导入时间",
    "note": "备注", "result": "结果", "run": "运行", "at": "时间", "occurred": "发生",
    "ms": "毫秒", "is_active": "是否启用", "suggestion": "建议", "severity": "严重度",
    "evidence_json": "证据链JSON", "path_json": "路径JSON", "parent_entity": "父实体",
    "scope_key": "经营口径", "diagnostic_chain_id": "诊断链路ID", "action_group_key": "行动组键",
    "dedupe_group_key": "去重组键", "benchmark_p50": "基准P50", "benchmark_p75": "基准P75",
    "benchmark_peer_count": "同类样本数", "benchmark_pool": "同类分池",
    "opportunity_score": "机会得分", "risk_priority_score": "风险优先级得分",
    "opportunity_priority_score": "机会优先级得分", "available_weight": "可用权重",
    "min_peer_count": "最小同类数", "min_materiality": "最小重要性", "min_growth": "最小增长率",
    "triggered_period_count": "触发周期数", "percentage_point_change": "百分点变化",
    "low_base_metric": "低基数指标", "low_base_value": "低基数阈值", "severity_score": "严重度得分",
    "diagnostic_chain_key": "诊断链路键", "parent_anomaly_event_id": "父异常事件ID",
    "rule_version": "规则版本", "mapping_complete": "映射完整", "data_quality_score": "数据质量得分",
    "current_value": "当前值", "previous_value": "上期值", "relative_change": "相对变化",
    "current_start_date": "当前期开始日期", "current_end_date": "当前期结束日期",
    "previous_start_date": "上期开始日期", "previous_end_date": "上期结束日期",
}

# 整词优先（长键先匹配）
def snake_to_cn(col):
    if col in dict_cn and dict_cn[col]:
        return dict_cn[col]
    if col in WORD:
        return WORD[col]
    # 贪婪最长前缀匹配
    parts = re.split(r"_", col)
    i = 0
    words = []
    while i < len(parts):
        # 尝试最长组合
        matched = None
        for j in range(len(parts), i, -1):
            cand = "_".join(parts[i:j])
            if cand in WORD:
                matched = WORD[cand]
                i = j
                break
        if matched:
            words.append(matched)
        else:
            p = parts[i]
            if p in ("is", "has"):
                words.append("是否")
            elif p in WORD:
                words.append(WORD[p])
            else:
                words.append(p)
            i += 1
    return "".join(words)

# 3. 表级 COMMENT（mart 4 表）
# 表级/视图级 COMMENT（mart 4 个 + 中文数据 24 视图）
TABLE_CN = {
    ("mart", "diagnostic_type", "TABLE"): "诊断类型字典（V1.1 诊断引擎：D01~D08 定位类型）",
    ("mart", "opportunity_type", "TABLE"): "机会类型字典（V1.1 机会引擎：O01~O08 机会类型）",
    ("mart", "metric_rule_v14", "VIEW"): "V1.4 指标公式规则（比例/费比/效率跨期重算口径，由正式函数引用）",
    ("mart", "priority_entity_weight", "TABLE"): "优先级实体权重配置（V1.1 风险/机会优先级评估）",
}
# 中文数据视图：COMMENT = 视图名
CN_VIEWS = ["人群构成分析", "价格带构成分析", "单载体内容分析", "品类构成分析", "商品构成分析",
            "字段映射规则", "导入批次记录", "工作表映射规则", "店铺信息", "店铺每日总览",
            "抖音人群日报", "抖音价格带日报", "抖音内容日报", "抖音商品日报", "抖音成交日报",
            "抖音类目日报", "抖音终端日报", "抖音账号日报", "抖音载体日报", "指标公式规则",
            "数据库中英文字典", "终端构成分析", "账号构成分析", "载体构成分析"]

# 4. 生成 COMMENT SQL
sql = ["-- P2 清零②：386 中文 COMMENT 补全（COMMENT ONLY）"]
sql.append("\\set ON_ERROR_STOP on")
n = 0
# 表级 mart（按 relkind 用 TABLE/VIEW）
for (s, o, kind), cn in TABLE_CN.items():
    kw = "VIEW" if kind == "VIEW" else "TABLE"
    sql.append('COMMENT ON {} {}.{} IS \'{}\';'.format(kw, s, o, cn.replace("'", "''")))
    n += 1
# 中文数据视图
for v in CN_VIEWS:
    sql.append('COMMENT ON VIEW 中文数据."{}" IS \'{}\';'.format(v, v.replace("'", "''")))
    n += 1
# 列级
rows = list(csv.DictReader(open(r"D:/ecommerce-data-system/convergence_final/08_comment_dictionary_gap.csv", encoding="utf-8-sig")))
col_cnt = 0
for r in rows:
    if "列" not in r["gap_type"]:
        continue
    s, o, c = r["schema_name"], r["object_name"], r["column_name"]
    cn = snake_to_cn(c)
    q = o if o == o else o  # 视图列与表列同样处理
    sql.append('COMMENT ON COLUMN {}.{}.{} IS \'{}（{}）\';'.format(s, o, c, cn.replace("'", "''"), s))
    col_cnt += 1
n += col_cnt

out_sql = OUT / "t2_comment_386.sql"
out_sql.write_text("\n".join(sql), encoding="utf-8")
print("生成 COMMENT 语句:", n, "条（表/视图", n - col_cnt, "列", col_cnt, "）")
print("SQL 文件:", out_sql)
# 抽样
sample = [s for s in sql if "COMMENT ON COLUMN" in s][:8]
for s in sample:
    print("  ", s)
conn.close()
