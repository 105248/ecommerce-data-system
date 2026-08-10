# -*- coding: utf-8 -*-
"""生成 V1.4 SQL：修正12条剔除退款公式分母 + 47条升级确认 + 版本标记。"""
import re

SRC = r'C:/Users/EDY/Desktop/数据库/01_抖音成交分析_11工作表字段映射与正式表_V1.3.sql'
DST = r'C:/Users/EDY/Desktop/数据库/01_抖音成交分析_11工作表字段映射与正式表_V1.4.sql'

with open(SRC, encoding='utf-8-sig') as f:
    lines = f.readlines()

# 12 条剔除退款规则的目标列名（4 个指标 × 3 张表）
FIX_TARGETS = {
    ('douyin_carrier_daily', 'ad_spend_rate_net_refund_shop_promoted'),
    ('douyin_carrier_daily', 'ad_spend_rate_net_refund_shop_bound'),
    ('douyin_carrier_daily', 'total_expense_rate_net_refund_shop_bound'),
    ('douyin_carrier_daily', 'total_expense_rate_net_refund_shop_promoted'),
    ('douyin_account_daily', 'ad_spend_rate_net_refund_shop_promoted'),
    ('douyin_account_daily', 'ad_spend_rate_net_refund_shop_bound'),
    ('douyin_account_daily', 'total_expense_rate_net_refund_shop_bound'),
    ('douyin_account_daily', 'total_expense_rate_net_refund_shop_promoted'),
    ('douyin_content_daily', 'ad_spend_rate_net_refund_shop_promoted'),
    ('douyin_content_daily', 'ad_spend_rate_net_refund_shop_bound'),
    ('douyin_content_daily', 'total_expense_rate_net_refund_shop_bound'),
    ('douyin_content_daily', 'total_expense_rate_net_refund_shop_promoted'),
}

fix_count = 0
confirm_count = 0
version_count = 0
in_formula_insert = False
cur_table = None
cur_col = None

out_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    stripped = line.strip()

    # 版本标记
    new_line = line.replace('V1.3', 'V1.4')
    if new_line != line:
        version_count += 1

    # 跟踪 INSERT 上下文（metric_formula_rule 的 VALUES 行）
    # 行格式: ('core', 'douyin_carrier_daily', '中文', 'target_col', ..., 'net_transaction_amount', ...)
    m = re.match(r"^\('core', '(\w+)', '([^']+)', '(\w+)', '比例指标',", stripped)
    if m:
        cur_table = m.group(1)
        cur_col = m.group(3)
        # 该行是剔除退款公式且含 net_transaction_amount
        if (cur_table, cur_col) in FIX_TARGETS and 'net_transaction_amount' in stripped:
            # 1) 业务公式中文: 净成交金额 -> 结算金额
            new_line = new_line.replace(' ÷ 净成交金额', ' ÷ 结算金额')
            # 2) 分母字段: 'net_transaction_amount' -> 'settlement_amount' (第8个字段位置)
            # 3) 单行公式
            new_line = new_line.replace('/ NULLIF(net_transaction_amount, 0)', '/ NULLIF(settlement_amount, 0)')
            new_line = new_line.replace('/NULLIF(net_transaction_amount, 0)', '/NULLIF(settlement_amount, 0)')
            # 4) 跨期SQL
            new_line = new_line.replace('NULLIF(SUM(net_transaction_amount), 0)', 'NULLIF(SUM(settlement_amount), 0)')
            # 5) 分母字段值
            # 精确替换 'net_transaction_amount' 为 'settlement_amount' (只在该公式行)
            new_line = new_line.replace("'net_transaction_amount'", "'settlement_amount'")
            # 6) notes 说明
            new_line = new_line.replace('V1.3以净成交金额作为剔除退款后的候选分母；首轮对账确认后再自动采用。',
                                        'V1.4反算确认剔除退款分母为结算金额（退款后口径），已通过首轮对账。')
            new_line = new_line.replace('剔除退款分母暂按净成交金额登记；首轮对账确认后再自动采用。',
                                        'V1.4反算确认剔除退款分母为结算金额（退款后口径），已通过首轮对账。')
            fix_count += 1

    # 状态升级: 待首轮对账确认 -> 已确认（首轮对账通过）
    if "'待首轮对账确认'" in stripped:
        new_line = new_line.replace("'待首轮对账确认'", "'已确认（首轮对账通过）'")
        confirm_count += 1

    out_lines.append(new_line)
    i += 1

with open(DST, 'w', encoding='utf-8-sig') as f:
    f.writelines(out_lines)

print('剔除退款公式修正: %d 条' % fix_count)
print('状态升级为已确认: %d 条' % confirm_count)
print('版本标记更新: %d 处' % version_count)
print()
print('V1.4 SQL 已生成:', DST)

# 验证
with open(DST, encoding='utf-8-sig') as f:
    content = f.read()
print()
print('=== 验证 ===')
print('仍含 net_transaction_amount 的剔除退款行:',
      sum(1 for t, c in FIX_TARGETS if re.search(rf"'{t}', '[^']+', '{c}',", content) and "net_transaction_amount" in
          content[content.find(rf"'{c}'"):content.find(rf"'{c}'")+600]))
print('settlement_amount 出现次数:', content.count('settlement_amount'))
print('V1.4 标记数:', content.count('V1.4'))
print('残留 待首轮对账确认:', content.count('待首轮对账确认'))
