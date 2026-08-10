# -*- coding: utf-8 -*-
"""抖音日报/周报模板 V1.0 —— 数据导出脚本。

从 ecommerce_db 调用 mart.get_business_report() 导出 2026-06 全月
三板块×六行明细（含投放费比分子 ad_bound），生成 HTML 页面内嵌 JSON。

用法（使用隔离 venv，见 README）：
    python export_report_data.py
"""
import json
import os
import sys
from datetime import date, timedelta
from pathlib import Path

import psycopg2
import psycopg2.extras

BASE = Path(__file__).resolve().parent

# 连接参数：优先 .env（与 mcp_server 一致），可被环境变量覆盖
def _load_env(path: Path):
    env = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            env[k.strip()] = v.strip()
    return env


def main():
    env = _load_env(BASE.parents[1] / "mcp_server" / ".env")
    conn = psycopg2.connect(
        host=os.getenv("DB_HOST", env.get("DB_HOST", "127.0.0.1")),
        port=int(os.getenv("DB_PORT", env.get("DB_PORT", "5432"))),
        dbname=os.getenv("DB_NAME", env.get("DB_NAME", "ecommerce_db")),
        user=os.getenv("DB_USER", env.get("DB_USER", "agent_readonly")),
        password=os.getenv("DB_PASSWORD", env.get("DB_PASSWORD", "")),
        connect_timeout=10,
    )
    conn.set_session(readonly=True, autocommit=True)

    start = date(2026, 6, 1)
    end = date(2026, 6, 30)

    days = []
    payload = {}
    with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        d = start
        while d <= end:
            cur.execute(
                "SELECT section, business_type, user_pay_amount, refund_amount, "
                "settlement_amount, refund_rate, ad_spend, ad_fee_rate, ad_bound "
                "FROM mart.get_business_report(%s::date, %s::date)",
                (d, d),
            )
            rows = []
            for r in cur.fetchall():
                rows.append({
                    "s": r["section"],
                    "t": r["business_type"],
                    "up": float(r["user_pay_amount"] or 0),
                    "rf": float(r["refund_amount"] or 0),
                    "st": float(r["settlement_amount"] or 0),
                    "rr": None if r["refund_rate"] is None else float(r["refund_rate"]),
                    "sp": float(r["ad_spend"] or 0),
                    "fr": None if r["ad_fee_rate"] is None else float(r["ad_fee_rate"]),
                    "ab": float(r["ad_bound"] or 0),
                })
            if len(rows) != 18:
                raise SystemExit("ERROR: {} 行数异常 {}".format(d, len(rows)))
            payload[d.isoformat()] = rows
            days.append(d.isoformat())
            d += timedelta(days=1)

    out = {
        "generated_at": date.today().isoformat(),
        "min_date": days[0],
        "max_date": days[-1],
        "dates": days,
        "data": payload,
    }
    out_dir = BASE / "html" / "data"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / "report_data.json"
    out_path.write_text(json.dumps(out, ensure_ascii=False), encoding="utf-8")
    print("导出完成: {} ({} 天 × 18 行 = {} 行)".format(out_path, len(days), len(days) * 18))


if __name__ == "__main__":
    main()
