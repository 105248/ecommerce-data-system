# -*- coding: utf-8 -*-
"""
gen_08_comment_gap.py
生成 08_comment_dictionary_gap.csv
- 缺表/视图 COMMENT
- 缺列 COMMENT
- 列注释含英文（中文化不足）
- 列名含中文（命名违规）
"""
import csv
import re
import psycopg2

ENV_FILE = r"D:\ecommerce-data-system\mcp_server\.env"
OUT = r"D:\ecommerce-data-system\convergence_final\08_comment_dictionary_gap.csv"


def load_env(path):
    cfg = {}
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            cfg[k.strip()] = v.strip()
    return cfg


def main():
    cfg = load_env(ENV_FILE)
    conn = psycopg2.connect(host=cfg["DB_HOST"], port=cfg["DB_PORT"], dbname=cfg["DB_NAME"],
                            user=cfg["DB_USER"], password=cfg["DB_PASSWORD"])
    cur = conn.cursor()
    gaps = []

    # 1. 缺表/视图 COMMENT
    cur.execute("""
        SELECT n.nspname, c.relname, c.relkind
        FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname IN ('core','meta','audit','mart') AND c.relkind IN ('r','v','m')
          AND obj_description(c.oid,'pg_class') IS NULL
        ORDER BY 1,2
    """)
    for sch, name, kind in cur.fetchall():
        gaps.append([sch, name, "TABLE/VIEW", "缺表级COMMENT", "", "", "P2"])

    # 2. 缺列 COMMENT
    cur.execute("""
        SELECT n.nspname, c.relname, a.attname
        FROM pg_class c
        JOIN pg_namespace n ON n.oid=c.relnamespace
        JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
        WHERE n.nspname IN ('core','meta','audit','mart') AND c.relkind='r'
          AND col_description(c.oid, a.attnum) IS NULL
        ORDER BY 1,2,3
    """)
    for sch, tbl, col in cur.fetchall():
        gaps.append([sch, tbl, "COLUMN", "缺列COMMENT", col, "", "P2"])

    # 3. 列名含中文（命名违规，应 snake_case）
    cur.execute("""
        SELECT n.nspname, c.relname, a.attname
        FROM pg_class c
        JOIN pg_namespace n ON n.oid=c.relnamespace
        JOIN pg_attribute a ON a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped
        WHERE n.nspname IN ('core','meta','audit','mart') AND c.relkind='r'
          AND a.attname ~ '[一-龥]'
        ORDER BY 1,2,3
    """)
    for sch, tbl, col in cur.fetchall():
        gaps.append([sch, tbl, "COLUMN", "列名含中文(应snake_case)", col, "", "P2"])

    # 4. 表名含中文（物理层违规）
    cur.execute("""
        SELECT n.nspname, c.relname
        FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname IN ('core','meta','audit','mart') AND c.relkind IN ('r','v','m')
          AND c.relname ~ '[一-龥]'
        ORDER BY 1,2
    """)
    for sch, name in cur.fetchall():
        gaps.append([sch, name, "TABLE/VIEW", "物理名含中文(应snake_case)", "", "", "P2"])

    # 5. 中文数据 schema 表级 COMMENT 覆盖率检查
    cur.execute("""
        SELECT n.nspname, c.relname
        FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname='中文数据' AND c.relkind='v'
          AND obj_description(c.oid,'pg_class') IS NULL
        ORDER BY 2
    """)
    for sch, name in cur.fetchall():
        gaps.append([sch, name, "VIEW", "中文查看层缺表级COMMENT", "", "", "P2"])

    with open(OUT, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["schema_name", "object_name", "object_type", "gap_type", "column_name",
                    "suggestion", "severity"])
        for g in gaps:
            w.writerow(g)

    from collections import Counter
    kinds = Counter(g[3] for g in gaps)
    print("gap 总数:", len(gaps))
    print("按类型:", dict(kinds))
    print("CSV:", OUT)
    conn.close()


if __name__ == "__main__":
    main()
