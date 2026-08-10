# -*- coding: utf-8 -*-
"""字段映射加载：从数据库 meta.source_sheet_mapping / meta.field_mapping 动态读取。
418 条映射不硬编码在 Python 中。"""
from typing import Dict, List

from database import Database
from models import FieldMapping, SheetMapping


class MappingLoader:
    def __init__(self, db: Database):
        self.db = db
        self.sheets: Dict[str, SheetMapping] = {}
        self.fields: Dict[str, List[FieldMapping]] = {}

    def load_all(self):
        """加载所有启用的工作表映射和字段映射。"""
        # 1. 工作表映射
        rows = self.db.query_all(
            """
            SELECT source_sheet_name, source_sheet_code, target_schema, target_table,
                   sale_scope_override, expected_column_count, load_order, enabled
            FROM meta.source_sheet_mapping
            WHERE enabled = TRUE
            ORDER BY load_order
            """
        )
        self.sheets = {}
        for r in rows:
            self.sheets[r["source_sheet_name"]] = SheetMapping(
                source_sheet_name=r["source_sheet_name"],
                source_sheet_code=r["source_sheet_code"],
                target_schema=r["target_schema"],
                target_table=r["target_table"],
                sale_scope_override=r["sale_scope_override"],
                expected_column_count=r["expected_column_count"],
                load_order=r["load_order"],
                enabled=r["enabled"],
            )

        # 2. 字段映射
        frows = self.db.query_all(
            """
            SELECT source_sheet_name, source_column_order, source_column_name,
                   target_column_name, target_data_type, field_category,
                   aggregation_rule, value_unit, display_format,
                   is_business_key, is_required_header
            FROM meta.field_mapping
            WHERE enabled = TRUE
            ORDER BY source_sheet_name, source_column_order
            """
        )
        self.fields = {}
        for r in frows:
            fm = FieldMapping(
                source_sheet_name=r["source_sheet_name"],
                source_column_order=r["source_column_order"],
                source_column_name=r["source_column_name"],
                target_column_name=r["target_column_name"],
                target_data_type=r["target_data_type"],
                field_category=r["field_category"],
                aggregation_rule=r["aggregation_rule"],
                value_unit=r["value_unit"],
                display_format=r["display_format"],
                is_business_key=r["is_business_key"],
                is_required_header=r["is_required_header"],
            )
            self.fields.setdefault(fm.source_sheet_name, []).append(fm)

        return self

    def get_sheet(self, name: str) -> SheetMapping:
        return self.sheets.get(name)

    def get_fields(self, sheet_name: str) -> List[FieldMapping]:
        return self.fields.get(sheet_name, [])

    def summary(self):
        return {k: len(v) for k, v in self.fields.items()}
