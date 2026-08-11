# -*- coding: utf-8 -*-
"""F0.5 Backend 数据库访问层：只调用正式白名单 Function/视图（growth_workspace_reader 最小权限）
Backend 禁止自行计算经营指标；全部确定性结果来自 PostgreSQL。"""
import time
import psycopg2
import psycopg2.extras
from contextlib import contextmanager

import config


class BackendDBError(Exception):
    """数据库错误包装。"""


def _connect():
    try:
        conn = psycopg2.connect(
            host=config.DB_HOST,
            port=config.DB_PORT,
            dbname=config.DB_NAME,
            user=config.DB_USER,
            password=config.DB_PASSWORD,
            connect_timeout=5,
            options="-c statement_timeout={}".format(config.STATEMENT_TIMEOUT_MS),
        )
        conn.set_session(readonly=True, autocommit=True)
        return conn
    except psycopg2.Error as e:
        raise BackendDBError("数据库连接失败: {}".format(str(e).strip())) from e


@contextmanager
def get_conn():
    conn = _connect()
    try:
        yield conn
    finally:
        try:
            conn.close()
        except Exception:
            pass


def query(sql: str, params: tuple = ()):
    """执行白名单查询，返回行列表(dict)。仅允许 SELECT/WITH。"""
    sql = sql.strip()
    if not sql.upper().startswith("SELECT") and not sql.upper().startswith("WITH"):
        raise BackendDBError("仅允许 SELECT 查询")
    t0 = time.time()
    try:
        with get_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(sql, params)
                rows = cur.fetchall()
                return [dict(r) for r in rows], (time.time() - t0) * 1000
    except psycopg2.errors.QueryCanceled:
        raise BackendDBError("查询超时(>{}ms)".format(config.STATEMENT_TIMEOUT_MS)) from None
    except psycopg2.Error as e:
        raise BackendDBError("查询失败: {}".format(str(e).strip())) from e


def health_check_db():
    """ready 检查：DB 连通 + 关键白名单函数可执行。"""
    try:
        rows, _ = query("SELECT count(*) AS n FROM meta.shop")
        rows2, _ = query(
            "SELECT user_pay_amount FROM mart.get_business_period_summary(%s, %s::date, %s::date, %s)",
            ("弹动官方旗舰店", "2026-06-30", "2026-06-30", "全店"),
        )
        return {"database": "OK", "shop_count": rows[0]["n"],
                "sample_function": "OK", "sample_value": rows2[0]["user_pay_amount"]}
    except Exception as e:
        return {"database": "ERROR", "detail": str(e)[:80]}


# ===== F1.1 目标写库（growth_workspace_target_writer 最小权限：仅 meta.business_target 增改查） =====
def execute_write(sql: str, params: tuple = ()):
    """执行目标表写操作（INSERT/UPDATE，禁止 DELETE/DDL）。返回影响行数。"""
    sql = sql.strip()
    up = sql.upper()
    if not (up.startswith("INSERT") or up.startswith("UPDATE")):
        raise BackendDBError("仅允许 INSERT/UPDATE（目标管理；删除用 enabled=false 软删）")
    t0 = time.time()
    try:
        conn = psycopg2.connect(
            host=config.DB_HOST, port=config.DB_PORT, dbname=config.DB_NAME,
            user=config.TARGET_WRITER_USER, password=config.TARGET_WRITER_PASSWORD,
            connect_timeout=5, options="-c statement_timeout={}".format(config.STATEMENT_TIMEOUT_MS),
        )
        try:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                n = cur.rowcount
            conn.commit()
            return n, (time.time() - t0) * 1000
        finally:
            conn.close()
    except psycopg2.Error as e:
        raise BackendDBError("目标写库失败: {}".format(str(e).strip())) from e
