# -*- coding: utf-8 -*-
"""数据库连接管理。"""
import psycopg2
import psycopg2.extras

import config


class Database:
    """封装 PostgreSQL 连接，支持事务上下文。"""

    def __init__(self):
        self.conn = None

    def connect(self):
        if self.conn is None or self.conn.closed:
            self.conn = psycopg2.connect(
                host=config.DB_HOST,
                port=config.DB_PORT,
                dbname=config.DB_NAME,
                user=config.DB_USER,
                password=config.DB_PASSWORD,
                connect_timeout=10,
            )
            self.conn.autocommit = False
        return self.conn

    def close(self):
        if self.conn and not self.conn.closed:
            self.conn.close()
        self.conn = None

    def cursor(self, name=None):
        return self.conn.cursor(name=name, cursor_factory=psycopg2.extras.RealDictCursor)

    def commit(self):
        self.conn.commit()

    def rollback(self):
        self.conn.rollback()

    def query_all(self, sql, params=None):
        """只读查询，返回 dict 列表。"""
        with self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params or ())
            return cur.fetchall()

    def query_one(self, sql, params=None):
        rows = self.query_all(sql, params)
        return rows[0] if rows else None

    def execute(self, sql, params=None):
        with self.conn.cursor() as cur:
            cur.execute(sql, params or ())
            return cur.rowcount
