# -*- coding: utf-8 -*-
"""mart V1.0 Stage4 MCP Server（stdio 只读数据服务）。

职责边界：
- 只做：参数校验 → 调用已验收的 mart Function → 限制行数 → 结构化返回。
- 不做：自行 AVG 比例 / SUM 父子 TOTAL / 重算 V1.4 / 重建商品 TOTAL / 任意 SQL。
- 数据库账号：agent_readonly（只读）。
"""
import json
import logging
import time
from datetime import datetime

import mcp.server.stdio
import mcp.types as types
from mcp.server import NotificationOptions, Server
from mcp.server.models import InitializationOptions

import config
import database
import schemas
from tools import (account_tools, business_tools, catalog_tools,
                   category_tools, domain_tools, product_tools)

# ---------------- 日志 ----------------
LOG_DIR = config.LOG_DIR
LOG_DIR.mkdir(parents=True, exist_ok=True)
log_file = LOG_DIR / "mcp_server.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s|%(levelname)s|%(message)s",
    handlers=[logging.FileHandler(log_file, encoding="utf-8"), logging.StreamHandler()],
)
logger = logging.getLogger("mart_mcp")

server = Server("mart-mcp-server")


# ---------------- 工具注册表 ----------------
# 每个工具: (名称, 描述, handler, 参数schema)
def _register_tools():
    tools = []

    def add(name, description, handler, schema):
        tools.append((name, description, handler, schema))

    # 基础目录
    add("list_shops", "列出可用店铺（shop_name）。",
        lambda a: catalog_tools.list_shops(), {})
    add("get_data_coverage", "返回店铺数据覆盖范围（min/max日期、天数、行数）。",
        lambda a: catalog_tools.get_data_coverage(a.get("shop_name")),
        {"shop_name": {"type": "string", "description": "店铺名，缺省=全部"}})
    add("get_metric_catalog", "返回分析指标目录（domain/metric_key/中文名/类型/是否可排名/可贡献度）。",
        lambda a: catalog_tools.get_metric_catalog(a.get("domain_key")),
        {"domain_key": {"type": "string", "description": "业务域: business/product/account/carrier/category/price_band/audience，缺省=全部"}})
    add("get_import_history", "返回最近导入批次历史（只读必要字段）。",
        lambda a: catalog_tools.get_import_history(a.get("limit")),
        {"limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})
    add("health_check", "MCP 服务健康检查（数据库连通+白名单可读）。",
        lambda a: catalog_tools.health_check(), {})

    # 经营总览 / 环比
    add("get_business_summary", "高频经营总览：按经营范围(全店/自营/合作/商品卡/短视频等)汇总任意区间。比例与均值已由数据库按V1.4跨期重算，客户端不要再次AVG。",
        lambda a: business_tools.get_business_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("scope_key", "全店"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string", "description": "店铺名，缺省=全部店铺"},
         "start_date": {"type": "string", "description": "开始日期 YYYY-MM-DD"},
         "end_date": {"type": "string", "description": "结束日期 YYYY-MM-DD"},
         "scope_key": {"type": "string", "description": "经营语义: 全店/自营/合作/商品卡/短视频/直播/图文/其他/组合", "default": "全店"},
         "metric_key": {"type": "string", "description": "指标，见 get_metric_catalog", "default": "user_pay_amount"}})
    add("compare_business", "环比：本期N天 vs 紧邻前N天。比例同时返回相对变化率与百分点变化。",
        lambda a: business_tools.compare_business(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("scope_key", "全店"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string", "description": "店铺名"},
         "start_date": {"type": "string", "description": "本期开始日期 YYYY-MM-DD"},
         "end_date": {"type": "string", "description": "本期结束日期 YYYY-MM-DD"},
         "scope_key": {"type": "string", "description": "经营语义", "default": "全店"},
         "metric_key": {"type": "string", "description": "指标", "default": "user_pay_amount"}})

    # 商品
    add("get_product_summary", "商品汇总。默认 carrier_type='全部'（平台独立TOTAL），不通过各载体明细重建。",
        lambda a: product_tools.get_product_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("product_id"), a.get("product_name"), a.get("carrier_type", "全部"),
            a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "product_id": {"type": "string", "description": "商品ID(文本)"},
         "product_name": {"type": "string", "description": "商品名称"},
         "carrier_type": {"type": "string", "description": "载体，缺省/全部=平台独立TOTAL", "default": "全部"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("rank_products", "商品排名/增长/下降/排名变化。排名使用 product carrier=全部 平台独立TOTAL；过滤商品时先全量排名再过滤。",
        lambda a: product_tools.rank_products(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("metric_key", "user_pay_amount"), a.get("sort_by", "current_value"),
            a.get("sort_direction", "DESC"), a.get("limit", 20),
            a.get("product_id"), a.get("product_name")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "description": "current_value/absolute_change/relative_change/rank_change", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20},
         "product_id": {"type": "string"}, "product_name": {"type": "string"}})
    add("get_product_contribution", "商品贡献度：同时返回 product 域占比与全店占比（双分母，平台口径差异不强制相等）。",
        lambda a: product_tools.get_product_contribution(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("metric_key", "user_pay_amount"), a.get("product_id"),
            a.get("product_name"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "product_id": {"type": "string"}, "product_name": {"type": "string"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})

    # 账号
    add("get_account_summary", "账号汇总。'更多账号'=合作聚合桶(aggregate_bucket)，不是具体达人；不用于回答全店/自营总成交。",
        lambda a: account_tools.get_account_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("sale_scope"), a.get("account_name"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "sale_scope": {"type": "string", "enum": ["自营", "合作"]}, "account_name": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("rank_accounts", "账号排名。默认排除 aggregate_bucket（更多账号），避免把聚合桶当具体达人排名。",
        lambda a: account_tools.rank_accounts(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("sale_scope", "合作"), a.get("metric_key", "user_pay_amount"),
            a.get("sort_by", "current_value"), a.get("sort_direction", "DESC"),
            a.get("limit", 20), a.get("include_aggregate_bucket", False), a.get("account_name")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "sale_scope": {"type": "string", "enum": ["自营", "合作"], "default": "合作"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20},
         "include_aggregate_bucket": {"type": "boolean", "default": False},
         "account_name": {"type": "string"}})
    add("get_account_contribution", "账号贡献度：分母来自 deal 权威 scope/全店 TOTAL；自营覆盖缺口在 coverage_note 说明。",
        lambda a: account_tools.get_account_contribution(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("sale_scope", "合作"), a.get("metric_key", "user_pay_amount"),
            a.get("account_name"), a.get("include_aggregate_bucket", True), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "sale_scope": {"type": "string", "enum": ["自营", "合作"], "default": "合作"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "account_name": {"type": "string"},
         "include_aggregate_bucket": {"type": "boolean", "default": True},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})

    # 类目
    add("get_category_summary", "类目汇总。必须明确 category_level(1/2/3/4)，禁止跨层级混合。",
        lambda a: category_tools.get_category_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("category_level", 3), a.get("category_l1"), a.get("category_l2"),
            a.get("category_l3"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "category_level": {"type": "integer", "enum": [1, 2, 3, 4], "default": 3},
         "category_l1": {"type": "string"}, "category_l2": {"type": "string"}, "category_l3": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("rank_categories", "类目排名：强制同一 category_level 内比较，L1/L2/L3 父子层级绝不混排。",
        lambda a: category_tools.rank_categories(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("category_level", 3), a.get("category_l1"), a.get("category_l2"),
            a.get("metric_key", "user_pay_amount"), a.get("sort_by", "current_value"),
            a.get("sort_direction", "DESC"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "category_level": {"type": "integer", "enum": [1, 2, 3, 4], "default": 3},
         "category_l1": {"type": "string"}, "category_l2": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})
    add("get_category_contribution", "类目贡献度：同时返回类目域占比与全店占比（双分母，允许平台口径差异）。",
        lambda a: category_tools.get_category_contribution(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("category_level", 3), a.get("category_l1"), a.get("category_l2"),
            a.get("metric_key", "user_pay_amount"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "category_level": {"type": "integer", "enum": [1, 2, 3, 4], "default": 3},
         "category_l1": {"type": "string"}, "category_l2": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})

    # 其他域
    add("get_carrier_summary", "载体/渠道汇总（拆分/排名用，不承担全店TOTAL；special_overlap 行不与明细混SUM）。",
        lambda a: domain_tools.get_carrier_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("sale_scope"), a.get("carrier_type"), a.get("account_channel"),
            a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "sale_scope": {"type": "string"}, "carrier_type": {"type": "string"}, "account_channel": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("get_content_summary", "内容汇总（当前真实样本仅验证商品卡载体）。",
        lambda a: domain_tools.get_content_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("selling_type"), a.get("carrier_type"), a.get("content_id"),
            a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "selling_type": {"type": "string"}, "carrier_type": {"type": "string"}, "content_id": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("get_terminal_summary", "终端汇总：terminal_type='整体' 为合法TOTAL（总览优先取），拆分只取具体终端，禁止整体+明细混SUM。",
        lambda a: domain_tools.get_terminal_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("terminal_type"), a.get("selling_type"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "terminal_type": {"type": "string"}, "selling_type": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("get_price_band_summary", "价格带汇总：6 带已验证互斥，可安全 SUM 重建店铺总量。",
        lambda a: domain_tools.get_price_band_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("price_band"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "price_band": {"type": "string"}, "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("get_audience_summary", "人群汇总：carrier_type='全部' 为合法TOTAL（总览优先），拆分只用5个明细载体，禁止全部+明细混SUM。",
        lambda a: domain_tools.get_audience_summary(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("audience_type"), a.get("carrier_type", "全部"), a.get("metric_key", "user_pay_amount")),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "audience_type": {"type": "string"}, "carrier_type": {"type": "string", "default": "全部"},
         "metric_key": {"type": "string", "default": "user_pay_amount"}})
    add("rank_carriers", "载体排名：使用 deal 合法 TOTAL Scope（商品卡/短视频/直播/图文/其他），不通过账号渠道明细重建。",
        lambda a: domain_tools.rank_carriers(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("sale_scope", "全部"), a.get("metric_key", "user_pay_amount"),
            a.get("sort_by", "current_value"), a.get("sort_direction", "DESC"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "sale_scope": {"type": "string", "enum": ["全部", "自营", "合作"], "default": "全部"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})
    add("rank_price_bands", "价格带排名：6 带互斥可直接比较。",
        lambda a: domain_tools.rank_price_bands(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("metric_key", "user_pay_amount"), a.get("sort_by", "current_value"),
            a.get("sort_direction", "DESC"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})
    add("rank_audiences", "人群排名：默认 carrier_type='全部'（合法TOTAL），禁止 TOTAL+明细载体混排。",
        lambda a: domain_tools.rank_audiences(
            a.get("shop_name"), a.get("start_date"), a.get("end_date"),
            a.get("carrier_type", "全部"), a.get("metric_key", "user_pay_amount"),
            a.get("sort_by", "current_value"), a.get("sort_direction", "DESC"), a.get("limit", 20)),
        {"shop_name": {"type": "string"}, "start_date": {"type": "string"}, "end_date": {"type": "string"},
         "carrier_type": {"type": "string", "default": "全部"},
         "metric_key": {"type": "string", "default": "user_pay_amount"},
         "sort_by": {"type": "string", "default": "current_value"},
         "sort_direction": {"type": "string", "enum": ["ASC", "DESC"], "default": "DESC"},
         "limit": {"type": "integer", "minimum": 1, "maximum": 100, "default": 20}})

    return tools


TOOLS = _register_tools()
TOOL_MAP = {name: (desc, handler, schema) for name, desc, handler, schema in TOOLS}


def _to_text_result(obj):
    return types.TextContent(type="text", text=json.dumps(obj, ensure_ascii=False, default=str))


@server.list_tools()
async def list_tools() -> list[types.Tool]:
    return [
        types.Tool(
            name=name,
            description=desc,
            inputSchema={
                "type": "object",
                "properties": schema,
            },
        )
        for name, desc, _handler, schema in TOOLS
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict):
    t0 = time.time()
    entry = TOOL_MAP.get(name)
    if entry is None:
        return [_to_text_result(schemas.err(name, "UNKNOWN_TOOL", "未知工具"))]
    desc, handler, _schema = entry
    try:
        result = handler(arguments or {})
        ok_flag = bool(result.get("ok"))
        error_type = result.get("error_type")
    except schemas.ArgError as e:
        result = schemas.err(name, e.error_type, str(e))
        ok_flag, error_type = False, e.error_type
    except database.DatabaseError as e:
        result = schemas.err(name, "DB_ERROR", str(e))
        ok_flag, error_type = False, "DB_ERROR"
    except Exception as e:  # noqa: BLE001
        logger.exception("tool %s 内部异常", name)
        result = schemas.err(name, "INTERNAL_ERROR", "内部错误，请查看日志")
        ok_flag, error_type = False, "INTERNAL_ERROR"

    duration_ms = int((time.time() - t0) * 1000)
    row_count = len(result.get("data", [])) if isinstance(result.get("data"), list) else 0
    logger.info("%s|tool=%s|args=%s|duration_ms=%d|row_count=%d|ok=%s|error=%s",
                datetime.now().isoformat(), name,
                json.dumps(arguments or {}, ensure_ascii=False)[:200],
                duration_ms, row_count, ok_flag, error_type)
    return [_to_text_result(result)]


async def main():
    async with mcp.server.stdio.stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            InitializationOptions(
                server_name="mart-mcp-server",
                server_version="1.0.0",
                capabilities=server.get_capabilities(
                    notification_options=NotificationOptions(),
                    experimental_capabilities={},
                ),
            ),
        )


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
