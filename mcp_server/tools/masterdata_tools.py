# -*- coding: utf-8 -*-
"""V1.3 Stage3 主数据只读 Tools：list_master_products / get_master_product_members / resolve_master_product / list_product_lines / get_product_line_members / get_unmapped_products / get_mapping_conflicts"""
import database
import schemas


def list_master_products(product_line_name=None, status=None):
    """公司 Master Product 清单（可按品线/状态过滤）。"""
    sql = ("SELECT mp.master_product_id, mp.master_product_code, mp.master_product_name, "
           "mp.brand_name, pl.product_line_name, mp.product_status, mp.enabled, "
           "(SELECT count(*) FROM meta.platform_product_mapping m WHERE m.master_product_id=mp.master_product_id AND m.enabled AND m.mapping_status='CONFIRMED') AS confirmed_mapping_count "
           "FROM meta.master_product mp LEFT JOIN meta.product_line pl ON pl.product_line_id=mp.product_line_id "
           "WHERE 1=1")
    params = []
    if product_line_name:
        sql += " AND pl.product_line_name = %s"; params.append(product_line_name)
    if status:
        sql += " AND mp.product_status = %s"; params.append(status)
    sql += " ORDER BY mp.master_product_id"
    rows = database.query(sql, tuple(params))
    if not rows:
        return schemas.err("list_master_products", "NO_DATA", "无 Master Product")
    return schemas.ok("list_master_products", rows)


def get_master_product_members(master_product_id=None, master_product_code=None):
    """Master Product 跨店成员（平台/店铺/平台商品ID/状态/有效期）。"""
    if not master_product_id and not master_product_code:
        raise schemas.ArgError("INVALID_ARGUMENT", "需提供 master_product_id 或 master_product_code")
    if master_product_code:
        rows0 = database.query("SELECT master_product_id FROM meta.master_product WHERE master_product_code=%s", (master_product_code,))
        if not rows0:
            raise schemas.ArgError("UNKNOWN_MASTER_PRODUCT", "未知公司商品编码 '{}'".format(master_product_code))
        master_product_id = rows0[0]["master_product_id"]
    rows = database.query("SELECT * FROM mart.get_master_product_members(%s)", (master_product_id,))
    if not rows:
        return schemas.err("get_master_product_members", "NO_DATA", "该 Master Product 无映射成员")
    return schemas.ok("get_master_product_members", rows)


def resolve_master_product(platform_code="douyin", shop_name=None, platform_product_id=None, biz_date=None):
    """查商品归属：平台+店铺+平台商品ID+业务日期 → Master Product/品线/状态。"""
    if not shop_name or not platform_product_id:
        raise schemas.ArgError("INVALID_ARGUMENT", "需提供 shop_name 与 platform_product_id")
    schemas.check_shop(shop_name)
    rows = database.query(
        "SELECT * FROM mart.resolve_master_product(%s,%s,%s,%s::date)",
        (platform_code, shop_name, platform_product_id, biz_date or "2026-06-30"))
    if not rows:
        return schemas.err("resolve_master_product", "UNMAPPED",
                           "该商品（{}｜{}）当前无有效 CONFIRMED 映射".format(shop_name, platform_product_id))
    return schemas.ok("resolve_master_product", rows)


def list_product_lines():
    """品线清单。"""
    rows = database.query("SELECT product_line_code, product_line_name, enabled, display_order FROM meta.product_line ORDER BY display_order")
    if not rows:
        return schemas.err("list_product_lines", "NO_DATA", "无品线")
    return schemas.ok("list_product_lines", rows)


def get_product_line_members(product_line_name=None):
    """品线成员（品线 → Master Product → 映射数/店铺覆盖）。"""
    if not product_line_name:
        raise schemas.ArgError("INVALID_ARGUMENT", "需提供 product_line_name")
    rows = database.query("SELECT * FROM mart.get_product_line_members(%s)", (product_line_name,))
    if not rows:
        return schemas.err("get_product_line_members", "NO_DATA", "品线无成员")
    return schemas.ok("get_product_line_members", rows)


def get_unmapped_products(limit=50):
    """未归属商品（按近30天GMV降序，帮助决定处理优先级）。"""
    rows = database.query("SELECT * FROM mart.unmapped_products ORDER BY 近30天成交金额 DESC LIMIT %s", (limit,))
    if not rows:
        return schemas.err("get_unmapped_products", "NO_DATA", "无不映射商品")
    return schemas.ok("get_unmapped_products", rows)


def get_mapping_conflicts():
    """商品映射冲突。"""
    rows = database.query("SELECT * FROM mart.product_mapping_conflicts")
    if not rows:
        return schemas.ok("get_mapping_conflicts", [], {"note": "无冲突"})
    return schemas.ok("get_mapping_conflicts", rows)
