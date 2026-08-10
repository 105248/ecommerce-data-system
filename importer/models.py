# -*- coding: utf-8 -*-
"""数据模型定义。"""

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class SheetMapping:
    """一张源工作表的映射规则（来自 meta.source_sheet_mapping）。"""
    source_sheet_name: str
    source_sheet_code: str
    target_table: str
    target_schema: str = "core"
    sale_scope_override: Optional[str] = None
    expected_column_count: int = 0
    load_order: int = 0
    enabled: bool = True


@dataclass
class FieldMapping:
    """一个源字段的映射规则（来自 meta.field_mapping）。"""
    source_sheet_name: str
    source_column_order: int
    source_column_name: str
    target_column_name: str
    target_data_type: str
    field_category: str
    aggregation_rule: str
    value_unit: str = "number"
    display_format: Optional[str] = None
    is_business_key: bool = False
    is_required_header: bool = True


@dataclass
class SheetData:
    """Excel 读取 + 转换后的一张工作表数据。"""
    sheet_name: str
    headers: List[str]
    rows: List[Dict[str, Any]]  # 已转换为目标列名的行数据
    raw_row_count: int = 0
    valid_row_count: int = 0
    blank_row_count: int = 0
    date_min: Optional[str] = None
    date_max: Optional[str] = None
    errors: List[Dict[str, str]] = field(default_factory=list)
    duplicates: List[Dict[str, Any]] = field(default_factory=list)
