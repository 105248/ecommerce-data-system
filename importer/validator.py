# -*- coding: utf-8 -*-
"""数据校验：表头检查、字段映射、日期/数值/百分比/ID 转换与异常收集。"""
from typing import Any, Dict, List, Optional

from models import FieldMapping, SheetData, SheetMapping
from transformer import (is_percent_field, normalize_percent, parse_date,
                         to_bigint, to_numeric, to_text_id)


class Validator:
    def __init__(self):
        self.error_stats = {
            "date_errors": 0,
            "numeric_errors": 0,
            "percent_errors": 0,
            "id_errors": 0,
            "null_key_errors": 0,
            "unknown_fields": 0,
        }
        self.errors: List[Dict[str, Any]] = []  # 明细

    def validate_headers(self, sheet: SheetMapping, headers: List[str]) -> Dict[str, Any]:
        """表头与预期字段对比。"""
        expected = [f.source_column_name for f in self._current_fields] if hasattr(self, "_current_fields") else []
        # 由调用方传入预期字段
        return {
            "missing": [],
            "extra": [],
            "actual_count": len(headers),
            "expected_count": sheet.expected_column_count,
        }

    def transform_row(self, sheet: SheetMapping, fields: List[FieldMapping],
                      headers: List[str], raw_row: tuple,
                      source_row_number: int) -> Optional[Dict[str, Any]]:
        """将原始行转换为目标列 dict。失败/异常记录到 errors。"""
        # 表头 -> 列索引
        col_index = {h: i for i, h in enumerate(headers) if h}
        result: Dict[str, Any] = {}
        row_errors: List[str] = []

        for fm in fields:
            src_col = fm.source_column_name
            idx = col_index.get(src_col)
            if idx is None:
                if fm.is_required_header:
                    row_errors.append(f"缺字段:{src_col}")
                continue
            raw_val = raw_row[idx] if idx < len(raw_row) else None
            target = fm.target_column_name

            # 按目标数据类型转换
            try:
                result[target] = self._convert_value(fm, src_col, raw_val, source_row_number)
            except Exception as e:
                self.error_stats["numeric_errors"] += 1
                self.errors.append({
                    "sheet": sheet.source_sheet_name, "row": source_row_number,
                    "column": src_col, "value": str(raw_val), "reason": f"转换异常:{e}",
                })

        # 附加业务字段（由调用方补充：shop_id/biz_date/sale_scope/batch_id 等）
        return result

    def convert_value(self, fm: FieldMapping, raw_val: Any, sheet: str, row_no: int) -> Any:
        """按字段元数据转换单个值。"""
        # 比例/率字段：原值保存（比率值，允许 >1，如 9.625=962.50%）
        if is_percent_field(fm.source_column_name, fm.field_category) or fm.value_unit == "percent":
            val = normalize_percent(raw_val)
            if val is None and raw_val is not None and str(raw_val).strip() != "":
                self.error_stats["percent_errors"] += 1
                self.errors.append({
                    "sheet": sheet, "row": row_no,
                    "column": fm.source_column_name, "value": str(raw_val),
                    "reason": "百分比值无法解析为数值",
                })
            return val

        dtype = (fm.target_data_type or "").lower()
        # ID 类（含 id 关键字或目标类型 varchar 且源名含 id）
        if self._is_id_field(fm):
            # V1.2 规则：ID 类业务键空白统一转空字符串（保证业务键稳定，避免 NOT NULL 冲突）
            if raw_val is None or str(raw_val).strip() == "":
                if fm.is_business_key or fm.field_category in ("标识字段", "维度字段"):
                    return ""
                return None
            val = to_text_id(raw_val)
            if val is None:
                self.error_stats["id_errors"] += 1
                self.errors.append({
                    "sheet": sheet, "row": row_no,
                    "column": fm.source_column_name, "value": str(raw_val), "reason": "ID转换失败",
                })
            return val

        if "numeric" in dtype or "decimal" in dtype:
            return to_numeric(raw_val)
        if "bigint" in dtype or "int" in dtype:
            return to_bigint(raw_val)
        if "date" in dtype:
            d = parse_date(raw_val)
            if d is None and raw_val is not None and str(raw_val).strip() != "":
                self.error_stats["date_errors"] += 1
                self.errors.append({
                    "sheet": sheet, "row": row_no,
                    "column": fm.source_column_name, "value": str(raw_val), "reason": "日期无法解析",
                })
            return d
        # 文本
        if raw_val is None or str(raw_val).strip() == "":
            # V1.2 规则：维度/业务键字段（VARCHAR）空白统一转空字符串以保证业务键稳定；
            # 非业务键文本空白转 NULL
            if fm.field_category in ("维度字段", "标识字段") or fm.is_business_key:
                return ""
            return None
        return str(raw_val).strip()

    @staticmethod
    def _is_id_field(fm: FieldMapping) -> bool:
        src = fm.source_column_name
        tgt = fm.target_column_name
        if "id" in tgt.lower() and tgt.lower() not in ("row_id", "shop_id", "batch_id", "biz_date"):
            return True
        return "编号" in src or "ID" in src
