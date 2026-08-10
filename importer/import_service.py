# -*- coding: utf-8 -*-
"""导入服务：编排 Excel 读取、映射、校验、转换，dry-run 或 commit 事务。"""
import traceback
from datetime import date
from typing import Any, Dict, List, Optional

from database import Database
from excel_reader import ExcelReader
from mapping_loader import MappingLoader
from models import FieldMapping, SheetMapping
from repository import Repository
from transformer import parse_date
from validator import Validator

# V1.0.1: 前三张成交表新增的10个可选投放字段 (legacy_51 兼容: 缺失时允许导入并置NULL)
OPTIONAL_NEW_HEADERS = {
    "投放消耗(店铺被投)", "投放消耗(店铺绑定)", "投放贡献成交金额", "投放贡献成交占比",
    "投放费比(剔除退款、店铺绑定)", "综合费比(剔除退款、店铺绑定)",
    "投放效率(店铺被投)", "投放效率(店铺绑定)", "全店效率(店铺被投)", "全店效率(店铺绑定)",
}


class ImportService:
    def __init__(self, db: Database, logger):
        self.db = db
        self.logger = logger
        self.repo = Repository(db)
        self.mapping = MappingLoader(db).load_all()
        self.validator = Validator()
        self.shop_info: Optional[Dict[str, Any]] = None

    # ---------- 公共 ----------
    def load_shop(self, shop_id: int) -> Optional[Dict[str, Any]]:
        self.shop_info = self.db.query_one(
            "SELECT shop_id, platform_code, shop_code, shop_name FROM meta.shop WHERE shop_id = %s",
            (shop_id,),
        )
        return self.shop_info

    # ---------- 单表处理 ----------
    def process_sheet(self, sheet: SheetMapping, reader: ExcelReader,
                      headers_expected: List[FieldMapping],
                      shop_id: int, batch_id: Optional[int]) -> Dict[str, Any]:
        """读取+校验+转换一张工作表，返回统计与转换后行数据。"""
        result = {
            "sheet": sheet.source_sheet_name,
            "target_table": sheet.target_table,
            "exists": sheet.source_sheet_name in reader.sheet_names(),
            "expected_columns": sheet.expected_column_count,
            "actual_columns": 0,
            "missing_fields": [],
            "extra_fields": [],
            "raw_rows": 0,
            "valid_rows": 0,
            "blank_rows": 0,
            "date_min": None,
            "date_max": None,
            "errors": [],
            "rows": [],  # 转换后的 dict 列表
        }

        if not result["exists"]:
            return result

        ws = reader.wb[sheet.source_sheet_name]
        rows_iter = ws.iter_rows(values_only=True)
        try:
            header_row = next(rows_iter)
        except StopIteration:
            # 空 sheet（0 行，连表头都没有，如 1-3 月个护店"单载体构成"）→ 跳过，视为该表本月无数据
            result["note"] = "empty_sheet_skipped"
            return result
        headers = [str(c).strip() if c is not None else "" for c in header_row]
        result["actual_columns"] = len([h for h in headers if h])
        nonempty_headers = [h for h in headers if h]
        expected_names = [f.source_column_name for f in headers_expected]
        result["missing_fields"] = [n for n in expected_names if n not in nonempty_headers]
        result["extra_fields"] = [h for h in nonempty_headers if h not in expected_names]

        # V1.0.1: 重复表头检测 (schema drift 防护)
        seen_hdr = {}
        result["duplicate_headers"] = []
        for h in nonempty_headers:
            if h in seen_hdr:
                result["duplicate_headers"].append(h)
            seen_hdr[h] = True

        # V1.0.1: legacy_51 / current_61 兼容判定 (仅前三张成交表)
        # P0-06 修复：严格按"实际有效列数 + 缺失新字段集合"判定，禁止 52~60 列异常文件被误放行
        result["schema_profile"] = "current_61"
        result["schema_drift_reason"] = ""
        if sheet.source_sheet_name in ("成交概览", "自营成交", "合作成交"):
            actual_cols = len(nonempty_headers)
            missing_set = set(result["missing_fields"])
            optional_set = set(OPTIONAL_NEW_HEADERS)
            if not result["missing_fields"] and not result["extra_fields"] and actual_cols == 61:
                result["schema_profile"] = "current_61"          # 严格 61 列
            elif missing_set == optional_set and actual_cols == 51 and not result["extra_fields"]:
                result["schema_profile"] = "legacy_51"           # 严格 51 列（恰好缺 10 个新字段）
            else:
                result["schema_profile"] = "SCHEMA_DRIFT"        # 52~60 / 62+ 等未确认结构 → 阻止
                result["schema_drift_reason"] = "实际 {} 列（期望 51 legacy 或 61 current），缺失 {} / 多余 {}".format(
                    actual_cols, sorted(missing_set - optional_set)[:5] or list(missing_set)[:5], result["extra_fields"][:5])
            result["missing_fields_core"] = [n for n in result["missing_fields"] if n not in OPTIONAL_NEW_HEADERS]

        col_index = {h: i for i, h in enumerate(headers) if h}
        sale_scope = sheet.sale_scope_override  # 三表合一用
        result["sale_scope"] = sale_scope

        # 迭代数据行（表头已被上面 next() 消耗，循环从第 2 行开始）
        row_no = 1  # Excel 行号（表头为第1行）
        for raw in rows_iter:
            row_no += 1
            result["raw_rows"] += 1
            if all(c is None or str(c).strip() == "" for c in raw):
                result["blank_rows"] += 1
                continue

            # 日期（第一列通常是日期）
            date_col = col_index.get("日期")
            biz_date = None
            if date_col is not None and date_col < len(raw):
                biz_date = parse_date(raw[date_col])
                if biz_date is None:
                    self.validator.error_stats["date_errors"] += 1
                    self.validator.errors.append({
                        "sheet": sheet.source_sheet_name, "row": row_no,
                        "column": "日期", "value": str(raw[date_col]), "reason": "日期无法解析",
                    })
                    continue  # 阻止该行
            if biz_date is None:
                continue

            # 转换所有映射字段
            row_data: Dict[str, Any] = {"shop_id": shop_id, "biz_date": biz_date}
            if sale_scope:
                row_data["sale_scope"] = sale_scope
            if batch_id:
                row_data["batch_id"] = batch_id
            row_data["source_sheet_name"] = sheet.source_sheet_name
            row_data["source_row_number"] = row_no

            for fm in headers_expected:
                idx = col_index.get(fm.source_column_name)
                if idx is None or idx >= len(raw):
                    continue
                raw_val = raw[idx]
                try:
                    val = self.validator.convert_value(fm, raw_val, sheet.source_sheet_name, row_no)
                except Exception as e:
                    val = None
                    self.validator.error_stats["numeric_errors"] += 1
                    self.validator.errors.append({
                        "sheet": sheet.source_sheet_name, "row": row_no,
                        "column": fm.source_column_name, "value": str(raw_val),
                        "reason": f"转换异常:{e}",
                    })
                if val is not None:
                    row_data[fm.target_column_name] = val
            result["rows"].append(row_data)
            result["valid_rows"] += 1
            # 日期范围
            ds = biz_date.isoformat()
            result["date_min"] = ds if result["date_min"] is None else min(result["date_min"], ds)
            result["date_max"] = ds if result["date_max"] is None else max(result["date_max"], ds)

        result["errors"] = [e for e in self.validator.errors if e.get("sheet") == sheet.source_sheet_name]
        return result

    # ---------- 主流程 ----------
    def run(self, file_path: str, shop_id: int, dry_run: bool) -> Dict[str, Any]:
        """主入口：读取、校验、转换、报告。dry_run=True 不写正式数据。"""
        report: Dict[str, Any] = {
            "file": {"path": file_path},
            "sheets": [],
            "file_sha256": "",
            "duplicate": None,
            "total_rows": 0,
            "total_valid": 0,
            "final_verdict": "禁止正式导入",
            "reasons": [],
        }

        # 店铺
        shop = self.load_shop(shop_id)
        if not shop:
            report["reasons"].append(f"店铺 shop_id={shop_id} 不存在")
            return report
        report["file"].update({
            "shop_name": shop["shop_name"],
            "shop_id": shop["shop_id"],
            "platform_code": shop["platform_code"],
        })

        # SHA256 重复检测
        sha = self.repo.file_sha256(file_path)
        report["file_sha256"] = sha
        dup = self.repo.find_duplicate_batch(shop_id, sha)
        if dup:
            report["duplicate"] = {"batch_id": dup["batch_id"], "file": dup["source_file_name"],
                                   "imported_at": str(dup["imported_at"])}
            report["reasons"].append("SHA256 完全重复文件（历史导入成功）")

        # 读取 Excel
        reader = ExcelReader(file_path).open()
        try:
            # P2-06：未知额外工作表检测（平台新增 sheet 不允许静默忽略）
            expected_sheets = set(self.mapping.sheets.keys())
            actual_sheets = set(reader.sheet_names())
            unknown_sheets = sorted(actual_sheets - expected_sheets)
            if unknown_sheets:
                report["unknown_sheets"] = unknown_sheets
                report["reasons"].append("发现未知额外工作表: {}".format(unknown_sheets))
            for sheet_name, sheet in self.mapping.sheets.items():
                fields = self.mapping.get_fields(sheet_name)
                result = self.process_sheet(sheet, reader, fields, shop_id, None if dry_run else 0)
                report["sheets"].append(result)
                report["total_rows"] += result["raw_rows"]
                report["total_valid"] += result["valid_rows"]
        finally:
            reader.close()

        # 汇总错误
        total_errors = sum(len(s.get("errors", [])) for s in report["sheets"])
        report["error_stats"] = dict(self.validator.error_stats)

        # 业务键重复检查（按正式表唯一索引定义）
        dup_total = 0
        for s in report["sheets"]:
            if not s.get("exists") or not s.get("rows"):
                s["dup_key_count"] = 0
                continue
            key_cols = self.repo.get_business_key_columns(s.get("target_table", ""))
            s["business_key_columns"] = key_cols
            if not key_cols:
                s["dup_key_count"] = 0
                continue
            # 检查待插入行内部重复
            seen = {}
            dup_count = 0
            dup_examples = []
            for row in s["rows"]:
                key = tuple(str(row.get(c, "")) for c in key_cols)
                if key in seen:
                    dup_count += 1
                    if len(dup_examples) < 5:
                        dup_examples.append({"key": dict(zip(key_cols, key)),
                                             "rows": [seen[key], row.get("source_row_number")]})
                else:
                    seen[key] = row.get("source_row_number")
            s["dup_key_count"] = dup_count
            s["dup_examples"] = dup_examples
            dup_total += dup_count
        report["dup_key_total"] = dup_total

        # 判定
        block_reasons = []
        for s in report["sheets"]:
            if not s["exists"]:
                block_reasons.append(f"缺工作表:{s['sheet']}")
            # P0-06：51/61 之外的结构（52~60/62+ 列）必须阻止，禁止按 legacy_51 放行
            if s.get("schema_profile") == "SCHEMA_DRIFT":
                block_reasons.append(f"{s['sheet']}结构异常(SCHEMA_DRIFT):{s.get('schema_drift_reason','')}")
            # V1.0.1: legacy_51 兼容——成交表缺失恰好10个新字段时允许；其余缺失阻止
            miss = s.get("missing_fields_core", s["missing_fields"])
            if miss:
                block_reasons.append(f"{s['sheet']}缺字段:{miss}")
            if s["extra_fields"]:
                block_reasons.append(f"{s['sheet']}未知新字段:{s['extra_fields']}")
            if s.get("duplicate_headers"):
                block_reasons.append(f"{s['sheet']}重复表头:{s['duplicate_headers']}")
            if s["errors"]:
                block_reasons.append(f"{s['sheet']}有{len(s['errors'])}条转换异常")
            if s.get("dup_key_count", 0) > 0:
                block_reasons.append(f"{s['sheet']}有{s['dup_key_count']}条重复业务键")
        if total_errors > 0:
            block_reasons.append(f"共{total_errors}条转换异常")
        if dup_total > 0:
            block_reasons.append(f"共{dup_total}条重复业务键")
        if report.get("unknown_sheets"):
            block_reasons.append(f"发现未知额外工作表:{report['unknown_sheets']}（需人工确认，禁止静默忽略）")
        if report["duplicate"]:
            block_reasons.append("检测到重复文件")

        if block_reasons and dry_run:
            report["final_verdict"] = "禁止正式导入"
            report["reasons"] = block_reasons
        elif block_reasons and not dry_run:
            report["final_verdict"] = "禁止正式导入"
            report["reasons"] = block_reasons
        else:
            report["final_verdict"] = "可以正式导入"
            report["reasons"] = []

        return report

    # ---------- commit 正式导入 ----------
    def run_commit(self, file_path: str, shop_id: int, dry_run: bool = False, force: bool = False) -> Dict[str, Any]:
        """正式导入：单事务内 先删旧数据(按各表实际日期范围) → 插入新数据 → 行数核对 → COMMIT。
        任意步骤失败 → ROLLBACK → 正式数据恢复 → 批次标记 failed。
        force=True (V1.0.1): 受控覆盖——跳过 SHA256 重复文件检测。"""
        # 先做完整校验（复用 run 的校验逻辑，只取校验结果不写入）
        report = self.run(file_path, shop_id, dry_run=True)
        if force:
            # V1.0.1 受控覆盖：忽略重复文件阻止，其余校验仍生效
            report["reasons"] = [r for r in report["reasons"] if r != "检测到重复文件"]
            if not report["reasons"]:
                report["final_verdict"] = "可以正式导入"
        if report["final_verdict"] != "可以正式导入":
            report["commit_result"] = "已阻止"
            report["reasons"].append("校验未通过，禁止正式导入")
            return report

        shop = report["file"]
        sha = report["file_sha256"]
        self.logger.info("校验通过，开始正式导入...")

        # 文件总日期范围
        all_dates = [s["date_min"] for s in report["sheets"] if s.get("date_min")] + \
                    [s["date_max"] for s in report["sheets"] if s.get("date_max")]
        period_start = min(all_dates) if all_dates else None
        period_end = max(all_dates) if all_dates else None

        batch_id = None
        try:
            # 1. 创建 processing 批次
            file_name = file_path.split("\\")[-1].split("/")[-1]
            source_row_count = report.get("total_rows", 0)
            batch_id = self.repo.create_batch(
                platform_code=shop["platform_code"], shop_id=shop_id,
                source_file_name=file_name,
                source_file_path=file_path, file_sha256=sha,
                period_start=period_start, period_end=period_end,
                import_mode="replace_period", import_status="processing",
                source_row_count=source_row_count,
            )
            self.logger.info(f"批次创建: batch_id={batch_id}")
            self.db.commit()  # 批次独立提交，确保失败时可追踪

            # 2. 单事务：删旧 + 插新
            self.db.conn.autocommit = False
            total_inserted = 0
            for s in report["sheets"]:
                table = s.get("target_table", "")
                if not table or not s.get("exists") or not s.get("date_min"):
                    continue
                # 该表实际日期范围作为删除依据（每表独立；三表合一场景带 sale_scope 细分）
                scope = s.get("sale_scope") if table == "douyin_deal_daily" else None
                del_count = self.repo.delete_period(
                    table, shop_id, s["date_min"], s["date_max"], sale_scope=scope)
                self.logger.info(f"  {table}: 删除 {del_count} 行旧数据 [{s['date_min']}~{s['date_max']}] scope={scope}")

                # 组装插入行
                if s.get("rows"):
                    # 给每行补 batch_id（run 校验阶段 batch_id 为 None）
                    rows = s["rows"]
                    for r in rows:
                        r["batch_id"] = batch_id
                    # 所有可能列
                    all_cols = set()
                    for r in rows:
                        all_cols.update(r.keys())
                    # 保证必填列顺序
                    fixed = ["shop_id", "biz_date", "batch_id", "source_sheet_name", "source_row_number"]
                    columns = [c for c in fixed if c in all_cols] + \
                              [c for c in sorted(all_cols - set(fixed)) if c not in fixed]
                    # 转换为元组
                    tuples = [tuple(r.get(c) for c in columns) for r in rows]
                    ins_count = self.repo.insert_rows(table, columns, tuples)
                    total_inserted += ins_count
                    self.logger.info(f"  {table}: 插入 {ins_count} 行")

            # 3. 行数核对
            verify_ok = True
            for s in report["sheets"]:
                table = s.get("target_table", "")
                if not table or not s.get("exists") or not s.get("date_min"):
                    continue
                expect = s.get("valid_rows", 0)
                scope = s.get("sale_scope") if table == "douyin_deal_daily" else None
                actual = self.repo.count_existing(
                    table, shop_id, s["date_min"], s["date_max"], sale_scope=scope)
                if actual != expect:
                    verify_ok = False
                    self.logger.error(f"  行数核对失败: {table} 期望{expect} 实际{actual}")
                    report.setdefault("verify_errors", []).append(
                        f"{table}: 期望{expect} 实际{actual}")
            if not verify_ok:
                raise RuntimeError("数据库行数核对失败")

            # 4. COMMIT
            self.db.commit()
            report["commit_result"] = "成功"
            report["batch_id"] = batch_id
            report["inserted_total"] = total_inserted
            self.repo.update_batch_status(batch_id, "success", inserted_rows=total_inserted)
            self.db.commit()
            self.logger.info(f"✅ COMMIT 成功: batch_id={batch_id}, 共插入 {total_inserted} 行")

        except Exception as e:
            # 5. 失败 → ROLLBACK → 批次 failed
            try:
                self.db.rollback()
            except Exception:
                pass
            report["commit_result"] = "失败"
            report["batch_id"] = batch_id
            report["final_verdict"] = "禁止正式导入"
            report.setdefault("reasons", []).append(f"导入失败已回滚: {e}")
            if batch_id:
                try:
                    self.repo.update_batch_status(batch_id, "failed", error_message=str(e))
                    self.db.commit()
                except Exception:
                    pass
            self.logger.error(f"❌ 导入失败已回滚: {e}")
            self.logger.error(traceback.format_exc())

        return report

