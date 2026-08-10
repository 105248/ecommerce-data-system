# -*- coding: utf-8 -*-
"""
gen_01_inventory.py  生成 01_database_object_inventory.csv
- 完整对象盘点（表/视图/物化视图/序列/索引/约束/触发器/函数/过程）
- 依赖（引用谁）与被依赖（谁引用我）
- 职责分类（11类）+ 生命周期分类（6类）
只读 SELECT，无任何写操作。
"""
import csv
import os
import re
import sys

import psycopg2

ENV_FILE = r"D:\ecommerce-data-system\mcp_server\.env"


def load_env(path):
    cfg = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
    return cfg


def get_conn():
    cfg = load_env(ENV_FILE)
    return psycopg2.connect(
        host=cfg["DB_HOST"], port=cfg["DB_PORT"], dbname=cfg["DB_NAME"],
        user=cfg["DB_USER"], password=cfg["DB_PASSWORD"], connect_timeout=10,
    )


SKIP_SCHEMAS = ("pg_catalog", "information_schema")


def main():
    conn = get_conn()
    cur = conn.cursor()
    # 用超级用户视角读全部目录
    cur.execute("SET ROLE postgres") if False else None

    # ---- 1. 表/视图/物化视图/序列/外部表 ----
    cur.execute("""
        SELECT n.nspname, c.relname, c.relkind,
               pg_get_userbyid(c.relowner),
               COALESCE(obj_description(c.oid,'pg_class'),''),
               CASE WHEN c.relkind IN ('r','p','m') THEN c.reltuples::bigint ELSE NULL END
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind IN ('r','p','v','m','S','f')
          AND n.nspname NOT IN ('pg_catalog','information_schema')
          AND n.nspname NOT LIKE 'pg_toast%' AND n.nspname NOT LIKE 'pg_temp%'
        ORDER BY 1, c.relkind, 2
    """)
    relkind_map = {'r': 'TABLE', 'p': 'TABLE_PARTITIONED', 'v': 'VIEW', 'm': 'MATERIALIZED_VIEW',
                   'S': 'SEQUENCE', 'f': 'FOREIGN_TABLE'}
    objects = []
    for schema, name, kind, owner, comment, rows in cur.fetchall():
        objects.append({
            "schema": schema, "name": name,
            "type": relkind_map.get(kind, 'RELKIND_' + kind),
            "owner": owner, "comment": comment or "", "rows": rows,
        })

    # ---- 2. 函数/过程 ----
    cur.execute("""
        SELECT n.nspname, p.proname,
               CASE p.prokind WHEN 'f' THEN 'FUNCTION' WHEN 'p' THEN 'PROCEDURE'
                    WHEN 'a' THEN 'AGGREGATE' ELSE 'FUNCTION' END,
               pg_get_userbyid(p.proowner),
               COALESCE(obj_description(p.oid,'pg_proc'),''),
               pg_get_function_identity_arguments(p.oid),
               p.prosrc
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname NOT IN ('pg_catalog','information_schema')
          AND n.nspname NOT LIKE 'pg_toast%'
          AND p.prokind IN ('f','p')
        ORDER BY 1, 2
    """)
    funcs = []
    for schema, name, ftype, owner, comment, args, src in cur.fetchall():
        funcs.append({
            "schema": schema, "name": name, "type": ftype, "owner": owner,
            "comment": comment or "", "args": args, "src": src or "",
        })
        objects.append({
            "schema": schema, "name": name, "type": ftype, "owner": owner,
            "comment": comment or "", "rows": None, "args": args, "src": src or "",
        })

    # ---- 3. 触发器/索引/约束（非表主对象，仅统计+明细）----
    cur.execute("""
        SELECT n.nspname, t.tgname, 'TRIGGER', pg_get_userbyid(c.relowner),
               'table=' || c.relname
        FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE NOT t.tgisinternal
          AND n.nspname NOT IN ('pg_catalog','information_schema')
        ORDER BY 1,2
    """)
    triggers = cur.fetchall()
    cur.execute("""
        SELECT n.nspname, ic.relname, 'INDEX', pg_get_userbyid(ic.relowner),
               'table=' || t.relname || ';def=' || pg_get_indexdef(ix.indexrelid)
        FROM pg_index ix
        JOIN pg_class ic ON ic.oid = ix.indexrelid
        JOIN pg_class t ON t.oid = ix.indrelid
        JOIN pg_namespace n ON n.oid = ic.relnamespace
        WHERE n.nspname NOT IN ('pg_catalog','information_schema')
          AND NOT ix.indisprimary
        ORDER BY 1,2
    """)
    indexes = cur.fetchall()
    cur.execute("""
        SELECT n.nspname, con.conname,
               CASE con.contype WHEN 'p' THEN 'CONSTRAINT_PRIMARY_KEY'
                    WHEN 'f' THEN 'CONSTRAINT_FOREIGN_KEY'
                    WHEN 'u' THEN 'CONSTRAINT_UNIQUE'
                    WHEN 'c' THEN 'CONSTRAINT_CHECK' ELSE 'CONSTRAINT' END,
               pg_get_userbyid(c.relowner),
               'table=' || c.relname || ';def=' || pg_get_constraintdef(con.oid)
        FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = con.connamespace
        WHERE n.nspname NOT IN ('pg_catalog','information_schema')
          AND con.contype IN ('p','f','u','c')
        ORDER BY 1,2
    """)
    constraints = cur.fetchall()

    # ---- 4. 依赖：视图→底层（经 pg_rewrite，去重列级）----
    cur.execute("""
        SELECT DISTINCT onsp.nspname, oc.relname, dn.nspname, dc.relname
        FROM pg_depend d
        JOIN pg_rewrite rw ON rw.oid = d.objid
        JOIN pg_class oc ON oc.oid = rw.ev_class
        JOIN pg_namespace onsp ON onsp.oid = oc.relnamespace
        JOIN pg_class dc ON dc.oid = d.refobjid
        JOIN pg_namespace dn ON dn.oid = dc.relnamespace
        WHERE d.deptype = 'n' AND oc.relkind IN ('v','m')
          AND dc.relkind IN ('r','v','m','S','f')
          AND onsp.nspname NOT IN ('pg_catalog','information_schema')
          AND dn.nspname NOT IN ('pg_catalog','information_schema')
    """)
    view_deps = cur.fetchall()  # (view_schema, view_name, dep_schema, dep_name)

    # 函数依赖：正则提取 prosrc 中的 schema.table / table 引用
    all_relations = {}
    for obj in objects:
        if obj["type"] in ("TABLE", "VIEW", "MATERIALIZED_VIEW", "FOREIGN_TABLE", "TABLE_PARTITIONED"):
            all_relations.setdefault(obj["schema"], set()).add(obj["name"])

    def extract_func_deps(src, schema):
        deps = set()
        if not src:
            return deps
        # schema.table 显式引用
        for m in re.finditer(r'(?:(?:[\u4e00-\u9fa5_a-zA-Z0-9]+)\.)?([a-z_][a-z0-9_]*)', src):
            pass
        # 显式 schema.obj
        for m in re.finditer(r'([a-zA-Z_][a-zA-Z0-9_]*|\u4e2d\u6587\u6570\u636e)\.([a-zA-Z_][a-zA-Z0-9_]*)', src):
            s, o = m.group(1), m.group(2)
            if s in all_relations and o in all_relations[s]:
                deps.add((s, o))
        # 无 schema 前缀的表名（本 schema 内）
        for m in re.finditer(r'\bFROM\s+([a-z_][a-z0-9_]*)|\bJOIN\s+([a-z_][a-z0-9_]*)|\bINTO\s+([a-z_][a-z0-9_]*)|\bUPDATE\s+([a-z_][a-z0-9_]*)', src, re.I):
            for g in m.groups():
                if g and g in all_relations.get(schema, set()):
                    deps.add((schema, g))
        return deps

    # 构建 依赖映射 + 被依赖映射
    dep_map = {}      # (schema,name) -> set((dep_schema, dep_name))
    dep_map_rev = {}  # (dep_schema,dep_name) -> set((schema,name)) 被谁依赖
    for obj in objects:
        key = (obj["schema"], obj["name"])
        dep_map.setdefault(key, set())
    for vs, vn, ds, dn in view_deps:
        key = (vs, vn)
        if key in dep_map:
            dep_map[key].add((ds, dn))
            dep_map_rev.setdefault((ds, dn), set()).add(key)
    for f in funcs:
        key = (f["schema"], f["name"])
        for ds, dn in extract_func_deps(f["src"], f["schema"]):
            dep_map.setdefault(key, set()).add((ds, dn))
            dep_map_rev.setdefault((ds, dn), set()).add(key)

    # ---- 5. 职责分类 ----
    def classify(obj):
        s, t, n = obj["schema"], obj["type"], obj["name"]
        if s == "core":
            return "CORE_FACT"
        if s == "stg":
            return "RAW/STAGING"
        if s == "audit":
            return "AUDIT"
        if s == "meta":
            if n in ("field_mapping", "metric_formula_rule", "source_sheet_mapping",
                     "database_object_dictionary", "platform"):
                return "RULE_META" if n not in ("platform",) else "MASTER_DATA"
            if n.startswith("master_") or n in ("product_line", "shop", "platform",
                                                 "platform_product_mapping", "platform_sku_mapping",
                                                 "master_product_alias", "master_sku_alias"):
                return "MASTER_DATA"
            if "audit" in n or n.startswith("audit_"):
                return "AUDIT"
            return "MASTER_DATA"
        if s == "中文数据":
            return "CHINESE_VIEW"
        if s == "mart":
            if t == "VIEW":
                if n in ("analysis_metric_whitelist", "stage3_expected_scope_map",
                         "product_mapping_conflicts", "unmapped_products",
                         "product_master_resolution", "sku_mapping_conflicts", "sku_master_resolution",
                         "metric_rule_v14"):
                    return "MART_PUBLIC"
                return "MART_PUBLIC"
            if t in ("FUNCTION", "PROCEDURE"):
                if n.startswith("_diag") or n in ("assert_period", "assert_rank_args",
                                                  "previous_period", "resolve_diagnostic_period",
                                                  "period_scope_rule", "resolve_scope",
                                                  "scope_daily", "format_percent_2"):
                    return "MART_INTERNAL"
                if n.startswith(("get_", "rank_", "compare_", "detect_", "diagnose_",
                                 "decompose_", "resolve_", "check_", "generate_",
                                 "get_daily_")):
                    return "MART_PUBLIC"
                if n in ("anomaly_rule", "anomaly_event", "opportunity_rule", "opportunity_event",
                         "diagnostic_type", "diagnostic_result", "daily_action_item"):
                    pass
                return "MART_PUBLIC"
            if t == "TABLE":
                if n in ("anomaly_event", "anomaly_rule", "opportunity_event", "opportunity_rule",
                         "opportunity_type", "diagnostic_result", "diagnostic_type",
                         "daily_action_item", "priority_entity_weight", "mart_dimension_rule",
                         "diagnostic_entity_rule", "diagnostic_metric_rule", "diagnostic_period_rule"):
                    return "AI_INTELLIGENCE"
                return "MART_INTERNAL"
            return "MART_PUBLIC"
        if s == "public":
            return "UNKNOWN"
        return "UNKNOWN"

    # ---- 6. 生命周期分类 ----
    def lifecycle(obj):
        s, t, n = obj["schema"], obj["type"], obj["name"]
        if t == "SEQUENCE":
            return "INTERNAL"  # 序列是表附属基础设施
        if s == "core":
            return "ACTIVE"
        if s == "audit":
            return "ACTIVE"
        if s == "meta":
            if t in ("FUNCTION", "PROCEDURE"):
                return "INTERNAL"  # 主数据审计/码生成/中文刷新函数
            return "ACTIVE"
        if s == "中文数据":
            return "ACTIVE"  # 人工查看层
        if s == "mart":
            if t == "TABLE":
                return "ACTIVE"
            if t == "VIEW":
                return "ACTIVE"
            if t in ("FUNCTION", "PROCEDURE"):
                if n.startswith("_diag"):
                    return "INTERNAL"
                return "ACTIVE"
        if s == "stg":
            return "REVIEW"
        return "REVIEW"

    # ---- 7. 汇总 CSV ----
    out_csv = r"D:\ecommerce-data-system\convergence_final\01_database_object_inventory.csv"
    with open(out_csv, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["schema_name", "object_name", "object_type", "owner", "comment",
                    "estimated_rows", "responsibility", "lifecycle",
                    "dependencies", "dependents"])
        for obj in objects:
            key = (obj["schema"], obj["name"])
            deps = sorted(dep_map.get(key, set()))
            deps_str = ";".join(f"{d[0]}.{d[1]}" for d in deps)
            deps_rev = sorted(dep_map_rev.get(key, set()))
            deps_rev_str = ";".join(f"{d[0]}.{d[1]}" for d in deps_rev)
            w.writerow([obj["schema"], obj["name"], obj["type"], obj["owner"],
                        obj["comment"], obj["rows"],
                        classify(obj), lifecycle(obj), deps_str, deps_rev_str])

    # ---- 8. 附加：触发器/索引/约束 统计（不占行）----
    stat_lines = []
    stat_lines.append(f"TRIGGERS={len(triggers)}")
    stat_lines.append(f"INDEXES_NONPK={len(indexes)}")
    stat_lines.append(f"CONSTRAINTS={len(constraints)}")
    print(" | ".join(stat_lines))
    print(f"TOTAL_OBJECTS={len(objects)}")
    print(f"CSV={out_csv}")
    conn.close()


if __name__ == "__main__":
    main()
