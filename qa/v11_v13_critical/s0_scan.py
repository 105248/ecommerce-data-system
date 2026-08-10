# -*- coding: utf-8 -*-
"""阶段0：扫描实际对象，建立"测试项→实际对象"映射，输出 01_critical_logic_test_matrix.csv
只读查询 pg_catalog / information_schema / 正式表。"""
import psycopg2
import csv
import json
from psycopg2.extras import RealDictCursor
from pathlib import Path
from datetime import datetime

CONN = dict(host="127.0.0.1", port=5432, dbname="ecommerce_db",
            user="postgres", password=os.environ.get('PG_ADMIN_PASSWORD', ''))
conn = psycopg2.connect(**CONN, connect_timeout=5)
conn.set_session(readonly=True, autocommit=True)
cur = conn.cursor(cursor_factory=RealDictCursor)
OUT = Path(r"D:/ecommerce-data-system/qa/v11_v13_critical")
OUT.mkdir(parents=True, exist_ok=True)
now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

def q(sql):
    cur.execute(sql)
    return cur.fetchall()

snapshot = {}

# ===== 1. schema 对象 =====
snapshot["tables"] = q("""SELECT table_schema, table_name, 'TABLE' AS obj_type FROM information_schema.tables
    WHERE table_schema IN ('core','mart','meta','audit','中文数据') AND table_type='BASE TABLE' ORDER BY 1,2""")
snapshot["views"] = q("""SELECT table_schema, table_name, 'VIEW' AS obj_type FROM information_schema.views
    WHERE table_schema IN ('core','mart','meta','audit','中文数据') ORDER BY 1,2""")
snapshot["functions"] = q("""SELECT n.nspname AS table_schema, p.proname AS table_name, 'FUNCTION' AS obj_type,
    pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname IN ('core','mart','meta','audit') AND p.proname NOT LIKE 'pg_%' ORDER BY 1,2""")
snapshot["triggers"] = q("""SELECT n.nspname AS table_schema, t.tgname AS table_name, 'TRIGGER' AS obj_type
    FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname IN ('core','mart','meta','audit') AND NOT t.tgisinternal ORDER BY 1,2""")
snapshot["indexes"] = q("""SELECT schemaname AS table_schema, indexname AS table_name, 'INDEX' AS obj_type
    FROM pg_indexes WHERE schemaname IN ('core','mart','meta','audit') ORDER BY 1,2""")

# ===== 2. MCP whitelist =====
snapshot["whitelist"] = q("""SELECT metric_key, metric_name_cn, domain_key, value_type, rank_allowed, contribution_allowed
    FROM mart.analysis_metric_whitelist ORDER BY domain_key, metric_key""")

# ===== 3. 关键业务视图定义摘要 =====
snapshot["view_defs"] = q("""SELECT table_schema, table_name, left(view_definition, 200) AS def_head
    FROM information_schema.views
    WHERE table_schema='mart' AND table_name IN
    ('unmapped_products','product_mapping_conflicts','sku_mapping_conflicts','product_master_resolution','sku_master_resolution')
    ORDER BY table_name""")

# ===== 4. 平台/店铺/品线 =====
snapshot["shops"] = q("SELECT shop_id, shop_name, platform_code, enabled FROM meta.shop ORDER BY shop_id")
snapshot["platforms"] = q("SELECT platform_code, platform_name FROM meta.platform ORDER BY platform_code")
snapshot["product_lines"] = q("SELECT product_line_id, product_line_name, enabled FROM meta.product_line ORDER BY product_line_id")
snapshot["master_products"] = q("""SELECT count(*) AS n FROM meta.master_product""")
snapshot["mp_status"] = q("""SELECT mapping_status, count(*) AS n FROM meta.platform_product_mapping
    GROUP BY mapping_status ORDER BY 2 DESC""")

# ===== 5. 测试矩阵（30 专项 → 实际对象） =====
matrix = [
    # (TEST_ID, 专项, 检查点, 涉及对象, 验证方法, 期望)
    ("SP01","导入与覆盖","同店同日期重传/两店同日/7天覆盖3天/失败事务","importer.import_service + audit.import_batch + core.*_daily","只读查批次+唯一键+代码逻辑","另一店/非覆盖日期不变, 失败0半成品, 唯一键0重复"),
    ("SP02","51/61列兼容","成交概览/自营/合作 旧51列vs新61列","meta.field_mapping + core.douyin_deal_daily + raw_files Excel","Excel原值=Core 抽30行","0静默错位"),
    ("SP03","比例效率禁AVG","退款率/CTR/CVR/费比/效率 1/7/30天×单店/整体×6Scope","mart.get_business_period_summary + get_diagnostic_snapshot","正式结果 vs 错误AVG","正式≠AVG(非恒定样本)"),
    ("SP04","费比特殊口径","投放费比分子分母/综合费比/效率权重","mart.metric_formula_rule + metric_rule_v14","查公式定义+实测","SUM(消耗)/SUM(结算), weighted_source_ratio"),
    ("SP05","比例原值","0.0378/0.1972/1/9.625 不二次除100","core.*_daily 比例列","扫描疑似二次除100值","原始值保持"),
    ("SP06","18Scope恒等式","全部=自营+合作/载体/投放/终端","mart.get_business_period_summary ×18 scope","每店+整体+多日期段","金额差异=0"),
    ("SP07","抖音整体","platform=douyin+shop=NULL=两店汇总","mart.get_platform_business_summary + 100组","金额=两店SUM, 比例=重算≠AVG","跨店正确"),
    ("SP08","跨店人数语义","两店人数SUM不得叫唯一人数","meta.shop + mart 视图 + MCP描述 + ai system_prompt","查字段名/中文名/描述","非唯一人数命名"),
    ("SP09","Coverage门禁","两店完整/缺店/缺1天/单期不完整","platform 汇总函数 coverage 列","7场景","enabled/covered/missing/day完整性, 不触发假暴跌"),
    ("SP10","MasterProduct","CONFIRMED20/SUGGESTED5/UNMAPPED5/CONFLICT1","meta.platform_product_mapping + mart 汇总函数","查状态分布+汇总只含CONFIRMED","只用CONFIRMED"),
    ("SP11","ProductLine","鱼子酱/人参品线/新增品线免代码","meta.product_line + mart.get_product_line_members","查品线成员+未归属不塞其他","链路正确"),
    ("SP12","SKU边界","无SKU源返回SKU_SOURCE_NOT_AVAILABLE","中文数据.平台SKU映射/未归属SKU","查视图定义","状态码不伪造"),
    ("SP13","时间粒度","商品卡/视频/经营版/素材 DAILYvsSNAPSHOT","core 表 data_time_type/period 列","查字段+取值分布","快照不伪装日数据"),
    ("SP14","Snapshot状态机","9状态全覆盖+PREVIOUS_ZERO","mart.get_diagnostic_snapshot","构造/找样本","无除0/无伪造无限增长"),
    ("SP15","异常LowBase","低基数大变化 vs 高基数小变化","mart.detect_anomalies + anomaly_event","构造样本","低基数被抑制"),
    ("SP16","异常幂等","重复运行不重复插入","mart.anomaly_event 唯一键","重复调用","event key稳定"),
    ("SP17","诊断因果边界","定位不伪造因果","mart.diagnostic_result + AI模板","扫描模板/输出","无证据因果被禁"),
    ("SP18","变化拆解","负向分母=gross negatives","mart.get_change_decomposition","构造A-100/B-50/C+80","A=66.67% B=33.33%"),
    ("SP19","Opportunity权重","7维权重归一/available>=70%/Peer分池","mart.opportunity_rule + detect_growth_opportunities","查权重定义+实测","缺维归一, <70%不输出, 不分池"),
    ("SP20","Priority去重","diagnostic_chain_id收敛TOP5","mart.daily_action_item/priority_entity_weight","查chain_id分布","TOP5不被同一链占满"),
    ("SP21","风险机会并存","Risk与Opportunity同时存在","mart.opportunity_event + anomaly_event + priority","查同实体双类型","允许并存"),
    ("SP22","AI一致性","30问题 AI数字=MCP=DB","ai_layer + MCP","跑测试题","数字一致, 不自行SUM/AVG"),
    ("SP23","AI上下文路由","多店/MP/PL/Scope连续追问","ai_layer system_prompt + routing_rules","查路由规则","不串店串对象"),
    ("SP24","MCP安全","agent_readonly 不可写/DDL/任意core","pg_roles + ACL + SECURITY DEFINER","复查S2","最小权限"),
    ("SP25","接口唯一性","只调用ACTIVE+MART_PUBLIC","mart 对象状态+调用方","扫描LEGACY/DEPRECATED/双ACTIVE","唯一接口"),
    ("SP26","NULL不伪装0","source_only/SKU不可用/NO_DATA","函数返回 + 视图","查NULL/状态码","保留NULL/状态码"),
    ("SP27","中文展示","物理字段英文+COMMENT中文+中文View","information_schema.columns + COMMENT","抽查","规范一致"),
    ("SP28","F0.5准备","接口参数/返回/时间/Scope/Coverage/权限","MCP 54工具 + 文档","评估readiness","Backend只做API层"),
]

with (OUT / "01_critical_logic_test_matrix.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(["TEST_ID","专项","检查点","涉及对象/表","验证方法","期望结果","实际状态","发现等级","备注"])
    for row in matrix:
        w.writerow(list(row) + ["PLANNED", "", ""])

# 快照 JSON 供后续脚本复用
with (OUT / "_objects_snapshot.json").open("w", encoding="utf-8") as f:
    json.dump(snapshot, f, ensure_ascii=False, default=str)

print("===== 阶段0 对象扫描完成 =====")
print("表:", len(snapshot["tables"]), "视图:", len(snapshot["views"]), "函数:", len(snapshot["functions"]),
      "触发器:", len(snapshot["triggers"]), "索引:", len(snapshot["indexes"]))
print("whitelist:", len(snapshot["whitelist"]))
print("店铺:", [(s["shop_id"], s["shop_name"]) for s in snapshot["shops"]])
print("品线:", [p["product_line_name"] for p in snapshot["product_lines"]])
print("MP:", snapshot["master_products"][0]["n"], "映射状态:", {r["mapping_status"]: r["n"] for r in snapshot["mp_status"]})
print("矩阵行:", len(matrix))
print("输出:", OUT / "01_critical_logic_test_matrix.csv")
conn.close()
