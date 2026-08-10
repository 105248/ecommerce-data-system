# -*- coding: utf-8 -*-
"""数据仓储：查询/删除/插入 core 表与 import_batch，SHA256 重复检测。"""
import hashlib
from typing import Any, Dict, List, Optional

from database import Database


class Repository:
    def __init__(self, db: Database):
        self.db = db

    # ---------- 文件 SHA256 ----------
    @staticmethod
    def file_sha256(file_path: str) -> str:
        h = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        return h.hexdigest()

    def find_duplicate_batch(self, shop_id: int, file_sha256: str) -> Optional[Dict[str, Any]]:
        """查同店铺+同SHA256+历史success的批次。"""
        return self.db.query_one(
            """
            SELECT batch_id, source_file_name, imported_at, import_status
            FROM audit.import_batch
            WHERE shop_id = %s AND file_sha256 = %s AND import_status = 'success'
            ORDER BY batch_id DESC LIMIT 1
            """,
            (shop_id, file_sha256),
        )

    # ---------- import_batch ----------
    def create_batch(self, platform_code: str, shop_id: int, source_file_name: str,
                     source_file_path: str, file_sha256: str,
                     period_start: Optional[str], period_end: Optional[str],
                     import_mode: str, import_status: str = "processing",
                     source_row_count: Optional[int] = None) -> int:
        """创建批次记录，返回 batch_id。"""
        with self.db.cursor() as cur:
            cur.execute(
                """
                INSERT INTO audit.import_batch
                    (platform_code, shop_id, source_file_name, source_file_path,
                     file_sha256, period_start, period_end, import_mode, import_status,
                     source_row_count)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING batch_id
                """,
                (platform_code, shop_id, source_file_name, source_file_path,
                 file_sha256, period_start, period_end, import_mode, import_status,
                 source_row_count),
            )
            row = cur.fetchone()
            # cursor 为 RealDictCursor，返回 dict；兼容 tuple
            if isinstance(row, dict):
                return row["batch_id"]
            return row[0]

    def update_batch_status(self, batch_id: int, status: str,
                            inserted_rows: Optional[int] = None,
                            error_message: Optional[str] = None):
        sets = ["import_status = %s"]
        params: List[Any] = [status]
        if inserted_rows is not None:
            sets.append("inserted_row_count = %s")
            params.append(inserted_rows)
        if error_message is not None:
            sets.append("error_message = %s")
            params.append(error_message)
        params.append(batch_id)
        self.db.execute(
            f"UPDATE audit.import_batch SET {', '.join(sets)}, imported_at = CURRENT_TIMESTAMP "
            f"WHERE batch_id = %s",
            params,
        )

    # ---------- 表数据 ----------
    def count_existing(self, table: str, shop_id: int, date_min: str, date_max: str,
                       sale_scope: Optional[str] = None, schema: str = "core") -> int:
        """统计现有数据行数（按店铺+日期范围，可选叠加 sale_scope）。"""
        extra_sql = ""
        params: List[Any] = [shop_id, date_min, date_max]
        if sale_scope is not None:
            extra_sql = " AND sale_scope = %s"
            params.append(sale_scope)
        return self.db.query_one(
            f"SELECT COUNT(*) AS cnt FROM {schema}.{table} "
            f"WHERE shop_id = %s AND biz_date >= %s AND biz_date <= %s{extra_sql}",
            tuple(params),
        )["cnt"]

    def delete_period(self, table: str, shop_id: int, date_min: str, date_max: str,
                      sale_scope: Optional[str] = None, schema: str = "core") -> int:
        """删除指定店铺+日期范围（可选 sale_scope）的旧数据（replace_period 用）。"""
        extra_sql = ""
        params: List[Any] = [shop_id, date_min, date_max]
        if sale_scope is not None:
            extra_sql = " AND sale_scope = %s"
            params.append(sale_scope)
        return self.db.execute(
            f"DELETE FROM {schema}.{table} "
            f"WHERE shop_id = %s AND biz_date >= %s AND biz_date <= %s{extra_sql}",
            tuple(params),
        )

    def insert_rows(self, table: str, columns: List[str], rows: List[tuple],
                    schema: str = "core") -> int:
        """批量插入。rows 为与 columns 对齐的元组列表。"""
        if not rows:
            return 0
        placeholders = ", ".join(["%s"] * len(columns))
        sql = f"INSERT INTO {schema}.{table} ({', '.join(columns)}) VALUES ({placeholders})"
        with self.db.cursor() as cur:
            cur.executemany(sql, rows)
            return cur.rowcount

    # ---------- 业务键重复检查（写库前） ----------
    def get_business_key_columns(self, table: str, schema: str = "core") -> List[str]:
        """从唯一索引定义中提取业务唯一键列（排除 row_id 主键）。"""
        row = self.db.query_one(
            """
            SELECT pg_get_indexdef(i.oid) AS index_def
            FROM pg_index x
            JOIN pg_class i ON i.oid = x.indexrelid
            JOIN pg_class t ON t.oid = x.indrelid
            JOIN pg_namespace n ON n.oid = t.relnamespace
            WHERE n.nspname = %s AND t.relname = %s
              AND x.indisunique = true AND i.relname LIKE 'uk\\_%%' ESCAPE '\\'
            """,
            (schema, table),
        )
        if not row:
            return []
        # 解析 UNIQUE INDEX ... (col1, col2, ...) 中的列
        import re
        m = re.search(r"\(([^)]+)\)", row["index_def"])
        if not m:
            return []
        cols = [c.strip() for c in m.group(1).split(",")]
        return cols

    def find_duplicate_keys(self, table: str, key_columns: List[str],
                            rows: List[tuple]) -> List[Dict[str, Any]]:
        """检查待插入数据内部的重复业务键（同表内）。"""
        seen = {}
        dups = []
        for i, row in enumerate(rows):
            key = tuple(row[c] for c in key_columns) if isinstance(key_columns, list) else None
            if key is None:
                continue
            if key in seen:
                dups.append({"table": table, "key": key, "dup_rows": [seen[key], i]})
            else:
                seen[key] = i
        return dups
