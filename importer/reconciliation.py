# -*- coding: utf-8 -*-
"""中文对账报告：生成 JSON + 中文 TXT 报告。"""
import json
from datetime import datetime
from pathlib import Path
from typing import Dict, Any

import config


class Reconciliation:
    def __init__(self, report: Dict[str, Any], dry_run: bool):
        self.report = report
        self.dry_run = dry_run

    def generate(self) -> Dict[str, str]:
        """生成报告文件，返回 {json_path, txt_path}。"""
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        fname = self.report["file"].get("file_name", "unknown")
        shop = self.report["file"].get("shop_name", "shop")
        mode = "dryrun" if self.dry_run else "commit"

        base = f"{ts}_{shop}_{mode}"
        json_path = config.LOG_DIR / f"{base}.json"
        txt_path = config.LOG_DIR / f"{base}.txt"

        # JSON
        json_path.write_text(
            json.dumps(self.report, ensure_ascii=False, indent=2, default=str),
            encoding="utf-8",
        )

        # 中文 TXT
        txt = self._render_txt()
        txt_path.write_text(txt, encoding="utf-8")

        return {"json": str(json_path), "txt": str(txt_path)}

    def _render_txt(self) -> str:
        f = self.report["file"]
        lines = []
        lines.append("=" * 60)
        lines.append("抖音成交分析 Excel 导入对账报告")
        lines.append(f"模式: {'dry-run(仅校验)' if self.dry_run else 'commit(正式导入)'}")
        lines.append("=" * 60)
        lines.append("【文件信息】")
        lines.append(f"  店铺: {f.get('shop_name')} (shop_id={f.get('shop_id')}, 平台={f.get('platform_code')})")
        lines.append(f"  文件: {f.get('file_name')}")
        lines.append(f"  路径: {f.get('path')}")
        lines.append(f"  SHA256: {self.report.get('file_sha256')}")
        dup = self.report.get("duplicate")
        lines.append(f"  重复文件: {'是(历史批次' + str(dup['batch_id']) + ')' if dup else '否'}")
        lines.append("")
        lines.append("【11张工作表】")
        for s in self.report["sheets"]:
            lines.append(f"  ── {s['sheet']} ──")
            lines.append(f"     存在: {'是' if s['exists'] else '否'} | 预期字段: {s['expected_columns']} | 实际字段: {s['actual_columns']}")
            lines.append(f"     缺失字段: {s['missing_fields'] if s['missing_fields'] else '无'}")
            lines.append(f"     新增字段: {s['extra_fields'] if s['extra_fields'] else '无'}")
            lines.append(f"     原始行数: {s['raw_rows']} | 有效行数: {s['valid_rows']} | 空白行: {s['blank_rows']}")
            lines.append(f"     日期范围: {s['date_min']} ~ {s['date_max']}")
            lines.append(f"     转换异常: {len(s['errors'])}")
            lines.append(f"     重复业务键: {s.get('dup_key_count', 0)}")
            if s.get("dup_examples"):
                lines.append(f"     重复示例: {s['dup_examples'][:2]}")
            lines.append(f"     预计写入: {s['valid_rows']} 行")
        lines.append("")
        lines.append(f"  重复业务键合计: {self.report.get('dup_key_total', 0)}")
        lines.append("")
        lines.append("【数据转换统计】")
        es = self.report.get("error_stats", {})
        lines.append(f"  日期异常: {es.get('date_errors', 0)}")
        lines.append(f"  数值异常: {es.get('numeric_errors', 0)}")
        lines.append(f"  百分比异常: {es.get('percent_errors', 0)}")
        lines.append(f"  ID异常: {es.get('id_errors', 0)}")
        lines.append(f"  未知字段: {es.get('unknown_fields', 0)}")
        lines.append("")
        lines.append("【最终结果】")
        lines.append(f"  >>> {self.report['final_verdict']}")
        if self.report.get("reasons"):
            lines.append("  原因:")
            for r in self.report["reasons"]:
                lines.append(f"    - {r}")
        lines.append("=" * 60)
        return "\n".join(lines)
