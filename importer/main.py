# -*- coding: utf-8 -*-
"""抖音成交分析 Excel 自动导入程序 V1.0 - CLI 入口。

用法:
    python main.py --file "Excel路径" --shop-id 1 --dry-run   # 默认, 只校验
    python main.py --file "Excel路径" --shop-id 1 --commit    # 正式导入
"""
import argparse
import sys
import traceback
from pathlib import Path

import config
from database import Database
from import_service import ImportService
from logger import get_logger
from reconciliation import Reconciliation


def parse_args():
    p = argparse.ArgumentParser(description="抖音成交分析Excel导入程序")
    p.add_argument("--file", required=True, help="Excel文件路径")
    p.add_argument("--shop-id", type=int, default=config.DEFAULT_SHOP_ID, help="店铺ID")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true", default=True, help="仅校验不写入(默认)")
    g.add_argument("--commit", action="store_true", help="正式导入(写入/删除正式数据)")
    p.add_argument("--force", action="store_true", help="V1.0.1 受控覆盖：跳过SHA256重复文件检测（仅配合--commit）")
    args = p.parse_args()

    # 默认 dry-run
    if not args.commit:
        args.dry_run = True
    else:
        args.dry_run = False
    return args


def main():
    args = parse_args()
    logger = get_logger()

    # 文件存在性
    fpath = Path(args.file)
    if not fpath.exists():
        logger.error(f"文件不存在: {fpath}")
        sys.exit(1)

    logger.info("=" * 50)
    logger.info(f"文件: {fpath}")
    logger.info(f"店铺: shop_id={args.shop_id} | 模式: {'dry-run' if args.dry_run else 'COMMIT'}")
    logger.info("=" * 50)

    db = Database()
    try:
        db.connect()
        logger.info("数据库连接成功 (专用账号 ecommerce_importer)")

        service = ImportService(db, logger)
        shop = service.load_shop(args.shop_id)
        if not shop:
            logger.error(f"店铺 shop_id={args.shop_id} 不存在")
            sys.exit(2)
        logger.info(f"店铺: {shop['shop_name']} (平台={shop['platform_code']})")

        # 记录文件名到报告
        report_ctx = {"file_name": fpath.name}

        # 执行导入流程（commit 走事务写入，dry-run 只校验）
        if args.commit:
            logger.info("模式: COMMIT（正式导入，将写入/删除正式数据）")
            report = service.run_commit(str(fpath), args.shop_id, force=args.force)
        else:
            report = service.run(str(fpath), args.shop_id, dry_run=True)
        report["file"]["file_name"] = fpath.name

        # 生成报告
        rec = Reconciliation(report, args.dry_run)
        paths = rec.generate()
        logger.info(f"对账报告已生成:")
        logger.info(f"  JSON: {paths['json']}")
        logger.info(f"  TXT : {paths['txt']}")
        logger.info("")
        logger.info(f"最终结论: {report['final_verdict']}")
        for r in report.get("reasons", []):
            logger.info(f"  - {r}")

        # dry-run 或阻断时退出码
        if report["final_verdict"] == "禁止正式导入":
            sys.exit(3)
        if args.dry_run:
            logger.info("(dry-run 模式，未写入任何正式数据)")
            sys.exit(0)

    except Exception:
        logger.error("程序执行异常:")
        logger.error(traceback.format_exc())
        try:
            db.rollback()
        except Exception:
            pass
        sys.exit(99)
    finally:
        db.close()


if __name__ == "__main__":
    main()
