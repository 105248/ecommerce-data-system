# -*- coding: utf-8 -*-
"""
gen_03_interface_catalog.py
生成：
- 03_official_database_interface_catalog.md
- 03_official_database_interface_catalog.json
- 04_database_public_interface_whitelist.json

接口 = 数据库正式公共对象（ACTIVE + MART_PUBLIC / MASTER_DATA 只读），
依据 MCP 实际使用 + F0.5 HTTP API 计划。
"""
import json
import os
import re
import psycopg2

ENV_FILE = r"D:\ecommerce-data-system\mcp_server\.env"
OUT_DIR = r"D:\ecommerce-data-system\convergence_final"


def load_env(path):
    cfg = {}
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
    return cfg


def get_conn():
    cfg = load_env(ENV_FILE)
    return psycopg2.connect(host=cfg["DB_HOST"], port=cfg["DB_PORT"], dbname=cfg["DB_NAME"],
                            user=cfg["DB_USER"], password=cfg["DB_PASSWORD"])


# ---- MCP 工具 → 数据库对象映射（实测自 tools/*.py） ----
# (mcp_tool, [db_refs...])
MCP_TOOL_REFS = {
    "list_shops": [("meta", "shop")],
    "get_data_coverage": [("mart", "get_data_coverage")],
    "get_metric_catalog": [("mart", "analysis_metric_whitelist")],
    "get_import_history": [("audit", "import_batch")],
    "health_check": [("mart", "analysis_metric_whitelist")],
    "get_business_summary": [("mart", "get_business_period_summary"), ("mart", "analysis_metric_whitelist")],
    "compare_business": [("mart", "compare_business_period")],
    "get_business_report": [("mart", "get_business_report")],
    "get_diagnostic_snapshot": [("mart", "get_diagnostic_snapshot"), ("mart", "get_platform_diagnostic_snapshot")],
    "get_diagnostic_supported_metrics": [("mart", "get_diagnostic_supported_metrics")],
    "get_daily_risk_priorities": [("mart", "get_daily_risk_priorities")],
    "get_daily_opportunity_priorities": [("mart", "get_daily_opportunity_priorities")],
    "get_daily_action_list": [("mart", "get_daily_action_list")],
    "get_daily_business_brief": [("mart", "get_daily_business_brief")],
    "get_growth_opportunities": [("mart", "get_growth_opportunities")],
    "get_entity_opportunity": [("mart", "get_entity_opportunity")],
    "get_opportunity_summary": [("mart", "get_opportunity_summary")],
    "get_diagnostic_result": [("mart", "get_diagnostic_result")],
    "get_entity_diagnosis": [("mart", "get_diagnostic_result")],
    "get_funnel_diagnosis": [("mart", "get_funnel_diagnosis")],
    "get_anomalies": [("mart", "get_anomalies")],
    "get_anomaly_summary": [("mart", "get_anomaly_summary")],
    "get_entity_anomalies": [("mart", "get_entity_anomalies")],
    "get_advertising_summary": [("mart", "get_advertising_period_summary")],
    "get_advertising_diagnosis": [("mart", "get_advertising_diagnosis")],
    "compare_advertising": [("mart", "compare_advertising_period")],
    "get_platform_business_summary": [("mart", "get_platform_business_period_summary")],
    "compare_platform_business": [("mart", "compare_platform_business")],
    "get_shop_contribution": [("mart", "get_shop_contribution")],
    "decompose_platform_change_by_shop": [("mart", "decompose_platform_change_by_shop")],
    "get_account_summary": [("mart", "get_account_period_summary")],
    "get_account_contribution": [("mart", "get_account_contribution")],
    "rank_accounts": [("mart", "rank_accounts")],
    "get_audience_summary": [("mart", "get_audience_period_summary")],
    "rank_audiences": [("mart", "rank_audiences")],
    "get_carrier_summary": [("mart", "get_carrier_period_summary")],
    "rank_carriers": [("mart", "rank_carriers")],
    "get_category_summary": [("mart", "get_category_period_summary")],
    "get_category_contribution": [("mart", "get_category_contribution")],
    "rank_categories": [("mart", "rank_categories")],
    "get_content_summary": [("mart", "get_content_period_summary")],
    "get_price_band_summary": [("mart", "get_price_band_period_summary")],
    "rank_price_bands": [("mart", "rank_price_bands")],
    "get_product_summary": [("mart", "get_product_period_summary")],
    "get_product_contribution": [("mart", "get_product_contribution")],
    "rank_products": [("mart", "rank_products")],
    "get_terminal_summary": [("mart", "get_terminal_period_summary")],
    "get_mapping_conflicts": [("mart", "product_mapping_conflicts")],
    "get_unmapped_products": [("mart", "unmapped_products")],
    "list_master_products": [("meta", "master_product"), ("meta", "platform_product_mapping")],
    "get_master_product_members": [("mart", "get_master_product_members"), ("meta", "master_product")],
    "list_product_lines": [("meta", "product_line")],
    "resolve_master_product": [("mart", "resolve_master_product")],
    "get_change_decomposition": [("mart", "decompose_master_product_by_shop_product"),
                                 ("mart", "decompose_platform_change_by_shop")],
}

# ---- 业务域标注 ----
DOMAIN_MAP = {
    "business": "经营总览", "advertising": "投放", "platform": "平台整体",
    "diagnostic": "诊断", "anomaly": "异常", "opportunity": "机会",
    "priority": "优先级/行动项", "masterdata": "主数据", "catalog": "基础目录",
    "account": "账号", "audience": "人群", "carrier": "载体", "category": "类目",
    "content": "内容", "price_band": "价格带", "product": "商品", "terminal": "终端",
}


def db_domain(schema, name):
    if schema == "meta":
        return "masterdata"
    if schema == "audit":
        return "catalog"
    if name.startswith("get_daily") or name in ("get_daily_action_list", "get_daily_business_brief"):
        return "priority"
    if "anomal" in name:
        return "anomaly"
    if "opportun" in name:
        return "opportunity"
    if "diagnos" in name or "funnel" in name:
        return "diagnostic"
    if "advertis" in name:
        return "advertising"
    if "platform" in name:
        return "platform"
    if "account" in name:
        return "account"
    if "audience" in name:
        return "audience"
    if "carrier" in name:
        return "carrier"
    if "category" in name:
        return "category"
    if "content" in name:
        return "content"
    if "price_band" in name:
        return "price_band"
    if "product" in name or "master_product" in name:
        return "product"
    if "terminal" in name:
        return "terminal"
    if "business" in name or name in ("analysis_metric_whitelist",):
        return "business"
    if "unmapped" in name or "mapping_conflict" in name or "metric_catalog" in name or name == "get_metric_catalog":
        return "catalog"
    if name in ("get_data_coverage", "get_import_history", "health_check"):
        return "catalog"
    return "catalog"


# ---- HTTP 准备状态 ----
def http_status(schema, name):
    if schema == "audit" and name == "import_batch":
        return "HTTP_NOT_REQUIRED"
    if name in ("health_check", "get_import_history", "get_metric_catalog"):
        return "HTTP_READY"
    if name in ("get_daily_business_brief", "get_daily_risk_priorities",
                "get_daily_opportunity_priorities", "get_daily_action_list"):
        return "HTTP_READY"
    # 函数式接口默认 wrapper（参数序列化）
    return "HTTP_NEEDS_WRAPPER"


def main():
    conn = get_conn()
    cur = conn.cursor()
    # 拉取函数参数
    cur.execute("""
        SELECT n.nspname, p.proname, pg_get_function_identity_arguments(p.oid),
               COALESCE(obj_description(p.oid,'pg_proc'),''),
               pg_get_function_result(p.oid)
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname IN ('mart','meta') AND p.prokind IN ('f','p')
    """)
    func_meta = {}
    for sch, name, args, comment, result in cur.fetchall():
        func_meta[(sch, name)] = {"args": args, "comment": comment, "result": result}

    interfaces = {}  # key=(schema, name) -> dict
    for mcp_tool, refs in sorted(MCP_TOOL_REFS.items()):
        for sch, name in refs:
            key = (sch, name)
            if key not in interfaces:
                fm = func_meta.get(key, {})
                interfaces[key] = {
                    "interface_code": f"{sch}.{name}",
                    "schema": sch,
                    "object_name": name,
                    "object_type": "FUNCTION" if (sch, name) in func_meta else "TABLE/VIEW",
                    "business_domain": db_domain(sch, name),
                    "parameters": fm.get("args", ""),
                    "return_fields": fm.get("result", "TABLE (multi-col)"),
                    "time_semantics": "区间聚合(等长环比由compare_*提供)" if not name.startswith(("rank_", "get_data_coverage", "get_import_history", "list_", "get_metric_catalog", "health_check", "get_mapping_conflicts", "get_unmapped_products", "resolve_master_product", "get_master_product_members", "get_product_line_members")) else "即时查询",
                    "scope_semantics": "店铺/平台+Scope解析(全店/自营/合作/载体)" if name.startswith(("get_", "rank_", "compare_")) else "主数据查询",
                    "coverage_behavior": "依赖core数据覆盖,缺失店铺返回NULL/0" if name.startswith(("get_", "rank_")) else "N/A",
                    "security_role": "agent_readonly",
                    "used_by_mcp": True,
                    "planned_for_http_api": True,
                    "http_status": http_status(sch, name),
                    "status": "ACTIVE",
                }
    conn.close()

    # ---- 输出 JSON ----
    catalog_list = sorted(interfaces.values(), key=lambda x: (x["schema"], x["object_name"]))
    json_path = os.path.join(OUT_DIR, "03_official_database_interface_catalog.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(catalog_list, f, ensure_ascii=False, indent=2)

    # ---- 白名单 JSON（接口代码列表 + HTTP 状态） ----
    whitelist = {
        "version": "V1.0",
        "purpose": "数据库最终架构收口：MCP 与未来 Backend API 唯一正式公共接口白名单",
        "consumer_policy": "仅允许消费 ACTIVE + MART_PUBLIC / MASTER_DATA 只读对象；检测/生成类(写库)不列入白名单",
        "interface_count": len(catalog_list),
        "interfaces": [{
            "interface_code": it["interface_code"],
            "schema": it["schema"],
            "object_name": it["object_name"],
            "object_type": it["object_type"],
            "business_domain": it["business_domain"],
            "used_by_mcp": it["used_by_mcp"],
            "planned_for_http_api": it["planned_for_http_api"],
            "http_status": it["http_status"],
            "status": it["status"],
        } for it in catalog_list],
    }
    wl_path = os.path.join(OUT_DIR, "04_database_public_interface_whitelist.json")
    with open(wl_path, "w", encoding="utf-8") as f:
        json.dump(whitelist, f, ensure_ascii=False, indent=2)

    # ---- 输出 MD ----
    md = []
    md.append("# 03｜正式数据库接口目录（Official Database Interface Catalog）\n")
    md.append("> 数据库最终架构收口｜封版版 V1.0｜唯一正式公共接口目录")
    md.append("> 消费方：MCP（现行）+ Backend API（F0.5 计划）。接口状态默认 ACTIVE。\n")
    md.append(f"**接口总数：{len(catalog_list)}**\n")
    md.append("| interface_code | schema | object_type | business_domain | parameters | security_role | used_by_mcp | http_status | status |")
    md.append("|---|---|---|---|---|---|---|---|---|")
    for it in catalog_list:
        md.append(f"| {it['interface_code']} | {it['schema']} | {it['object_type']} | {it['business_domain']} | "
                  f"{it['parameters'][:80]} | {it['security_role']} | {'✅' if it['used_by_mcp'] else '—'} | "
                  f"{it['http_status']} | {it['status']} |")
    md_path = os.path.join(OUT_DIR, "03_official_database_interface_catalog.md")
    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(md))

    print(f"interfaces={len(catalog_list)}")
    print(f"MD={md_path}")
    print(f"JSON={json_path}")
    print(f"WHITELIST={wl_path}")


if __name__ == "__main__":
    main()
