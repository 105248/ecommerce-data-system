# -*- coding: utf-8 -*-
"""F1.0.2 智能刷新链 Job：导入成功后手动/定时触发 V1.1 批处理
流程：detect_anomalies → diagnose_entity(异常实体) → detect_growth_opportunities → generate_daily_action_items
特性：幂等（uk_anomaly_event_dedup 唯一索引去重）/ run_id / 起止时间 / 事实+智能日期 / 失败停止不吞异常 / 运行日志进 audit.intelligence_run_log
用法：python refresh_intelligence.py [--start YYYY-MM-DD] [--end YYYY-MM-DD] [--shop 店名] [--domain 域]
"""
import argparse
import os
import sys
import time
import traceback
import uuid
from datetime import date, datetime, timedelta
from pathlib import Path

# DB 凭据：写库函数（detect/diagnose/opportunity/action）仅授权 postgres（WRITE_JOB_FUNCTION 隔离）
# → Job 使用管理凭据（项目根 mcp_server/.env 的 PG_ADMIN_*），不得使用只读角色执行写库
_PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent  # workspace/jobs → 项目根
_MCP_ENV = _PROJECT_ROOT / "mcp_server" / ".env"


def _load_env(path: Path):
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                v = v.strip()
                if v:  # 仅写入非空值，避免空串覆盖默认
                    os.environ[k.strip()] = v


_load_env(_MCP_ENV)

try:
    import psycopg2
except ImportError:
    sys.exit("缺少 psycopg2，请先安装")


def _conn():
    # 写库 Job 强制管理员身份（PG_ADMIN_*），忽略只读 DB_USER
    return psycopg2.connect(
        host=os.getenv("PG_HOST") or os.getenv("DB_HOST") or "127.0.0.1",
        port=int(os.getenv("PG_PORT") or os.getenv("DB_PORT") or "5432"),
        dbname=os.getenv("PG_DB") or os.getenv("DB_NAME") or "ecommerce_db",
        user=os.getenv("PG_ADMIN_USER") or "postgres",
        password=os.getenv("PG_ADMIN_PASSWORD") or "",
        connect_timeout=5,
    )


def log_run(conn, run_id, status, detail, started, finished):
    """运行日志写入 audit.intelligence_run_log（F1.0.2 新建对象；不存在则自动创建）。"""
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS audit.intelligence_run_log (
                run_id text PRIMARY KEY,
                triggered_at timestamptz NOT NULL,
                finished_at timestamptz,
                status text NOT NULL,            -- RUNNING / SUCCESS / FAILED
                fact_max_date date,
                anomaly_max_date date,
                diagnosis_max_date date,
                opportunity_max_date date,
                action_max_date date,
                detail text
            )"""
        )
        conn.commit()
        cur.execute("SELECT max(biz_date) FROM core.douyin_deal_daily")
        f = cur.fetchone()[0]
        cur.execute("SELECT max(current_start_date) FROM mart.anomaly_event"); a = cur.fetchone()[0]
        cur.execute("SELECT max(current_start_date) FROM mart.diagnostic_result"); d = cur.fetchone()[0]
        cur.execute("SELECT max(current_start_date) FROM mart.opportunity_event"); o = cur.fetchone()[0]
        cur.execute("SELECT max(current_start_date) FROM mart.daily_action_item"); ac = cur.fetchone()[0]
        cur.execute(
            "INSERT INTO audit.intelligence_run_log(run_id, triggered_at, finished_at, status, fact_max_date, anomaly_max_date, diagnosis_max_date, opportunity_max_date, action_max_date, detail) "
            "VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) "
            "ON CONFLICT (run_id) DO UPDATE SET status=EXCLUDED.status, finished_at=EXCLUDED.finished_at, detail=EXCLUDED.detail",
            (run_id, started, finished, status, f, a, d, o, ac, detail))
        conn.commit()


def main():
    ap = argparse.ArgumentParser(description="F1.0.2 智能刷新链")
    ap.add_argument("--start", help="检测起始日期 YYYY-MM-DD（默认：事实最大日期前 6 天）")
    ap.add_argument("--end", help="检测结束日期 YYYY-MM-DD（默认：事实最大日期）")
    ap.add_argument("--shop", help="店铺名（默认 NULL=全部店铺）")
    ap.add_argument("--domain", default="shop", help="域（默认 shop；可多次用逗号分隔）")
    args = ap.parse_args()

    conn = _conn()
    run_id = "F1.0.2-{}".format(uuid.uuid4().hex[:8])
    started = datetime.now()
    log_run(conn, run_id, "RUNNING", "开始", started, None)

    try:
        with conn.cursor() as cur:
            cur.execute("SELECT max(biz_date) FROM core.douyin_deal_daily")
            fact_max = cur.fetchone()[0]
            if fact_max is None:
                raise RuntimeError("core.douyin_deal_daily 无数据")
            end = date.fromisoformat(args.end) if args.end else fact_max
            start = date.fromisoformat(args.start) if args.start else end - timedelta(days=6)
            print("[{}] 检测区间 {} ~ {}".format(run_id, start, end))
            domains = [x.strip() for x in args.domain.split(",") if x.strip()]

            # 1) 异常检测（幂等：uk_anomaly_event_dedup）
            for dm in domains:
                cur.execute("SELECT mart.detect_anomalies(%s,%s::date,%s::date,%s,%s)",
                            ("douyin", start, end, dm, args.shop))
                n1 = cur.fetchone()[0]
                conn.commit()
                print("  detect_anomalies[{}]: {} 事件".format(dm, n1))

            # 2) 对未诊断异常做实体诊断
            cur.execute("""
                SELECT anomaly_event_id, domain_key, entity_name, current_start_date, current_end_date, shop_name, scope_key
                FROM mart.anomaly_event
                WHERE diagnostic_chain_key IS NULL
                  AND current_start_date BETWEEN %s::date AND %s::date
                ORDER BY anomaly_event_id LIMIT 500
            """, (start, end))
            pending = cur.fetchall()
            diagnosed = 0
            for ev_id, dm, ent, cs, ce, shop, scope in pending:
                try:
                    cur.execute("SELECT mart.diagnose_entity(%s,%s,%s::date,%s::date,%s,%s,%s)",
                                (dm, ent, cs, ce, shop, scope or "全店", ev_id))
                    conn.commit()
                    diagnosed += 1
                except Exception as ex:
                    conn.rollback()
                    print("    诊断失败 ev={} {}: {}".format(ev_id, ent, ex)[:150])
            print("  诊断: {}/{}".format(diagnosed, len(pending)))

            # 3) 机会检测
            for dm in domains:
                cur.execute("SELECT mart.detect_growth_opportunities(%s,%s::date,%s::date,%s,%s)",
                            ("douyin", start, end, dm, args.shop))
                n2 = cur.fetchone()[0]
                conn.commit()
                print("  detect_growth_opportunities[{}]: {} 事件".format(dm, n2))

            # 4) 优先级 / Action 生成
            cur.execute("SELECT mart.generate_daily_action_items(%s,%s::date,%s::date)",
                        ("douyin", start, end))
            n3 = cur.fetchone()[0]
            conn.commit()
            print("  generate_daily_action_items: {} 项".format(n3))

        finished = datetime.now()
        log_run(conn, run_id, "SUCCESS", "完成", started, finished)
        print("[{}] 成功，耗时 {:.1f}s".format(run_id, (finished - started).total_seconds()))
    except Exception:
        finished = datetime.now()
        try:
            conn.rollback()  # 清掉 aborted 事务，否则 log_run 无法写
        except Exception:
            pass
        log_run(conn, run_id, "FAILED", traceback.format_exc()[-2000:], started, finished)
        conn.close()
        raise  # 不吞异常
    finally:
        if conn and conn.closed == 0:
            conn.close()


if __name__ == "__main__":
    main()
