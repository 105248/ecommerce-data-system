# -*- coding: utf-8 -*-
"""数据库连接层：仅使用只读账号 agent_readonly。"""
import psycopg2
import psycopg2.extras
from contextlib import contextmanager

import config


class DatabaseError(Exception):
    """数据库层错误包装。"""


class QueryTimeoutError(DatabaseError):
    """查询超时。"""


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
        raise DatabaseError("数据库连接失败: {}".format(str(e).strip())) from e


@contextmanager
def get_conn():
    """短连接上下文（V1.0 数据量小，优先正确性，不引入连接池复杂度）。"""
    conn = _connect()
    try:
        yield conn
    finally:
        try:
            conn.close()
        except Exception:
            pass


def query(sql: str, params: tuple = ()):
    """执行只读 SQL，返回行列表（dict）。仅允许 SELECT。"""
    sql = sql.strip()
    if not sql.upper().startswith("SELECT") and not sql.upper().startswith("WITH"):
        raise DatabaseError("仅允许 SELECT 查询")
    try:
        with get_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(sql, params)
                rows = cur.fetchall()
                return [dict(r) for r in rows]
    except psycopg2.errors.QueryCanceled:
        raise QueryTimeoutError("查询超时(>{}ms)".format(config.STATEMENT_TIMEOUT_MS)) from None
    except psycopg2.Error as e:
        raise DatabaseError("查询失败: {}".format(str(e).strip())) from e
