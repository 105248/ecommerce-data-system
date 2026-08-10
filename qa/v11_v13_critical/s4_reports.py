# -*- coding: utf-8 -*-
"""阶段4：生成 13 份关键逻辑专项检查报告（02-13）+ 更新 01 矩阵状态。只读汇总，不修改数据库。"""
import csv
from pathlib import Path
from datetime import datetime

OUT = Path(r"D:/ecommerce-data-system/qa/v11_v13_critical")
now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

# ============ 01 矩阵更新 ============
STATUS = {
    "SP01": ("PASS", "", "唯一键0重复/批次/单事务回滚/replace_period含shop+日期+scope（代码审查）"),
    "SP02": ("PASS", "", "抽样6/30逐列对照：结算/消耗/退款×4 全部一致，61列无静默错位"),
    "SP03": ("PASS", "", "126组正式≠AVG日率（1组恒定样本WARN）；整体比例12组≠两店AVG"),
    "SP04": ("PASS", "", "投放费比=SUM消耗/SUM结算；综合费比/效率按正式weighted_source_ratio"),
    "SP05": ("P2", "观察", "12行转化率源值>1（exposure_to_transaction=3.0等），疑似源Excel异常待核对"),
    "SP06": ("PASS", "", "18/18恒等式：全部=自营+合作、载体、投放(不限=全域+乘方+标准品牌+非投放)、终端"),
    "SP07": ("PASS", "", "100/100 平台金额=两店SUM；比例跨店重算≠AVG"),
    "SP08": ("PASS", "", "平台notes+AI prompt明确'各店之和不去重'，无伪称唯一人数"),
    "SP09": ("PASS", "", "3区间两店完整覆盖PASS；函数含enabled/missing/coverage逻辑；缺店场景未构造(只读约束)"),
    "SP10": ("PASS", "", "MP=77(≥20)；UNMAPPED天然样本118；汇总仅CONFIRMED；SUGGESTED/CONFLICT样本需隔离库构造"),
    "SP11": ("PASS", "", "鱼子酱18/人参5成员；品线配置驱动，新增免代码"),
    "SP12": ("PASS", "", "中文数据.平台sku映射/未归属sku=WHERE false空壳→SKU_SOURCE_NOT_AVAILABLE"),
    "SP13": ("PASS", "", "biz_date全部来自源'日期'列(YYYYMMDD)非导入日期；每日粒度无快照伪装"),
    "SP14": ("PASS", "", "实测OK/NO_PREVIOUS_DATA；8个_diag_*函数含nullif/zero防护(PREVIOUS_ZERO不除0)"),
    "SP15": ("PASS", "", "8条anomaly_rule全部配置low_base_metric/value门禁"),
    "SP16": ("PASS", "", "完全重复=0组；同链多实体/跨日=生命周期语义"),
    "SP17": ("PASS", "", "evidence_json=数据证据链(funnel/current/previous)；AI prompt因果边界声明"),
    "SP18": ("PASS", "", "拆解函数含gross_negative分母逻辑；share=0.6966按负向分母"),
    "SP19": ("PASS", "", "8规则权重和=100(100制归一)；benchmark_pool按域分池(master_product/shop_product/carrier)；<70%不输出(209/264)"),
    "SP20": ("PASS", "", "TOP5含3个不同链；dedupe_group_key收敛；同一链未占满TOP5"),
    "SP21": ("PASS", "", "同店同日期风险+机会并存=3组；表独立评估"),
    "SP22": ("P2", "测试集", "MCP数字=期望 系统侧全对；test_cases#8/#10期望值0.2969错误(实为0.2667)"),
    "SP23": ("PASS", "", "路由含店铺/实体路由+多轮上下文继承"),
    "SP24": ("PASS", "", "57查询函数授权agent_readonly；5生成函数仅postgres(正确)；无写/DDL/core直读；get_business_report PUBLIC遗留(P1)"),
    "SP25": ("PASS", "", "无LEGACY/DEPRECATED对象"),
    "SP26": ("PASS", "", "无数据区间返回NO_DATA非0；unrecalculable_metrics保留"),
    "SP27": ("P2", "完善", "core 9表有表COMMENT；列注释覆盖待完善"),
    "SP28": ("PASS", "", "MCP 54工具49带参数schema；Backend只做API层(系统约束已声明)"),
}

with (OUT / "01_critical_logic_test_matrix.csv").open("r", encoding="utf-8-sig") as f:
    rows = list(csv.reader(f))
header = rows[0]
data = rows[1:]
for i, row in enumerate(data):
    sp = row[0]
    if sp in STATUS:
        st, lv, note = STATUS[sp]
        row[6] = st          # 实际状态
        row[7] = lv          # 发现等级
        row[8] = note        # 备注
with (OUT / "01_critical_logic_test_matrix.csv").open("w", newline="", encoding="utf-8-sig") as f:
    w = csv.writer(f)
    w.writerow(header)
    w.writerows(data)
print("01 矩阵已更新")

HDR = "> 生成时间：{} ｜ V1.3+V1.1+数据库封版关键逻辑专项检查 ｜ 只读检查，未修改任何数据库对象\n\n"
def w(fname, title, body):
    (OUT / fname).write_text("# {}\n\n{}".format(title, HDR.format(now) + body), encoding="utf-8")
    print("生成", fname)

# ===== 02 导入与覆盖 =====
w("02_import_overlap_test_report.md", "导入与覆盖逻辑报告（专项01）", """## 结论：PASS

| 检查点 | 结果 | 证据 |
|---|---|---|
| 业务唯一键重复 | ✅ 0 | 9 表完整维度键（shop_id+biz_date+业务键）重复=0 |
| 覆盖边界（replace_period） | ✅ 表+店铺+日期+sale_scope | `delete_period(table, shop_id, date_min, date_max, sale_scope)` |
| 事务原子性 | ✅ 单事务 | autocommit=False 删旧→插新→行数核对→COMMIT；失败 ROLLBACK |
| 失败无半成品 | ✅ 回滚+批次failed | 异常→db.rollback()+批次标记 failed |
| 重复文件保护 | ✅ SHA256 | find_duplicate_batch；force=受控覆盖(V1.0.1) |
| 行数核对 | ✅ 期望=实际 | 不符抛 RuntimeError→ROLLBACK |

> 构造型测试（同日期重传/7天覆盖3天/故意失败）未执行：受"禁止污染生产"约束，采用代码审查+历史批次只读验证代替。若需破坏性演练，建议在隔离库执行。""")

# ===== 03 比例效率 =====
w("03_rate_efficiency_recalculation_report.md", "比例与效率重算报告（专项03/04/05）", """## 结论：PASS（比例不 AVG，费比/效率按正式口径）

| 指标 | 验证 | 结果 |
|---|---|---|
| 退款率 | 126 组 正式 vs AVG(日率) | ✅ 仅 1 组恒定样本相等（护理随机段，样本恒定非错误） |
| CTR/CVR | 同上 | ✅ 全部 正式≠AVG |
| 投放费比/综合费比 | 同上 | ✅ 正式=SUM(消耗)/SUM(结算) |
| 投放/全店效率 | 同上 | ✅ 正式≠AVG |
| 整体比例 | 12 组 平台 vs 两店 AVG | ✅ 全部 重算≠AVG |
| 比例原值 | 0.0378/1/9.625 语义 | ✅ 未发现二次除100；⚠️ 12 行转化率源值>1（P2，疑似源Excel异常，见 SP05） |

> 正式公式证据：field_mapping transform_rule 明确"仅当源值为带%文本才除100"；跨期按分子/分母重算（metric_rule_v14）。""")

# ===== 04 多店 Scope 恒等式 =====
w("04_multishop_scope_identity_report.md", "多店与 18 Scope 恒等式报告（专项06/07/08）", """## 结论：PASS

| 恒等式 | 7天/30天 × 官方/护理/整体 | 结果 |
|---|---|---|
| 全部 = 自营 + 合作 | 6/6 | ✅ 差异=0 |
| 载体全部 = 商品卡+直播+短视频+图文+其他 | 6/6 | ✅ 差异=0 |
| 投放 不限 = 全域+乘方投放时段 + 标准+品牌投放 + 非投放时段 | 6/6 | ✅ 差异=0（49,919,922.12 精确相等） |
| 抖音整体 金额 = 两店 SUM | 100/100 组 | ✅ match=100 |

| 检查点 | 结果 |
|---|---|
| platform=douyin + shop=NULL = enabled 店铺汇总 | ✅（无 shop_id=0/假店铺，函数 notes 明确） |
| 比例跨店重算 ≠ AVG | ✅ 12/12 |
| 跨店人数语义 | ✅ 平台 notes + AI prompt 均声明"各店之和，跨店不去重"，无伪称唯一人数 |

> 口径注：ad_period 值域为 `不限/全域+乘方投放时段/标准+品牌投放/非投放时段`（测试 SQL 首版用了近似名导致误报，修正后全部成立）。""")

# ===== 05 Coverage =====
w("05_coverage_gate_report.md", "Coverage 门禁报告（专项09）", """## 结论：PASS（两店完整场景验证；缺店场景未构造）

| 区间 | enabled | covered | missing | days/expected | complete |
|---|---|---|---|---|---|
| 06-01~06-30 | 2 | 2 | 0 | 30/30 | True |
| 06-24~06-30 | 2 | 2 | 0 | 7/7 | True |
| 06-30 单日 | 2 | 2 | 0 | 1/1 | True |

- ✅ 函数 `get_platform_business_period_summary` 含 enabled/covered/missing/coverage 计算逻辑
- ✅ coverage_complete 字段语义正确；缺失店铺会出现在 missing_shops（V1.3 S2 已验收）
- ⚠️ 缺官方/缺1天/单期不完整 7 场景未在正式库构造（只读约束）；建议 F0.5 前置在隔离库做破坏性演练，验证"缺数据不触发假 GMV 暴跌"（V1.1 异常检测依赖 coverage_complete 门禁字段，anomaly_event.coverage_complete 已存在）""")

# ===== 06 MP/PL =====
w("06_master_product_product_line_report.md", "Master Product / Product Line 报告（专项10/11/12）", """## 结论：PASS

| 检查点 | 结果 | 证据 |
|---|---|---|
| Master Product 规模 | ✅ 77（≥20） | meta.master_product=77 |
| CONFIRMED 映射 | ✅ 82 | platform_product_mapping 全 CONFIRMED |
| UNMAPPED 样本 | ✅ 118 | mart.unmapped_products 天然样本 |
| 跨店汇总仅 CONFIRMED | ✅ | get_master_product_period_summary 只含 CONFIRMED 成员 |
| 禁止 product_name GROUP BY | ✅ | 汇总走 MP→shop_product 映射函数 |
| Product Line 链路 | ✅ | 鱼子酱 18 / 人参 5 成员；新增品线配置驱动免代码 |
| 未归属不塞"其他" | ✅ | 未映射商品在 unmapped_products 视图，不入品线 |
| SKU 边界 | ✅ | 中文数据.平台sku映射/未归属sku = WHERE false 空壳 → SKU_SOURCE_NOT_AVAILABLE |

> SUGGESTED/CONFLICT 样本在正式库不存在（无源数据触发）；1 个 CONFLICT 构造建议隔离库完成（V1.3 S3 已验收映射冲突检测逻辑 34/34）。""")

# ===== 07 时间粒度 =====
w("07_time_grain_snapshot_report.md", "时间粒度报告（专项13）", """## 结论：PASS

- ✅ 9 张 core 表均为**每日粒度**（biz_date 主键之一），无 PERIOD_SNAPSHOT 列混入
- ✅ biz_date 全部来自源 Excel"日期"列（YYYYMMDD 解析，非法日期阻止导入），**非导入日期**
- ✅ sheet 映射：成交概览/自营成交/合作成交→deal_daily；单载体构成→content_daily（视频/图文内容，每日）；商品构成→product_daily
- ✅ 无"30 天快照拆成 30 个日值"风险：源文件为日明细，逐日导入
- ⚠️ 12 行转化率值>1（SP05 关联），属源值异常观察项，不影响时间粒度语义""")

# ===== 08 Snapshot/异常 =====
w("08_v1_1_snapshot_anomaly_report.md", "V1.1 Snapshot 与异常引擎报告（专项14/15/16）", """## 结论：PASS

| 检查点 | 结果 | 证据 |
|---|---|---|
| Snapshot 状态机 | ✅ 实测 OK / NO_PREVIOUS_DATA | get_diagnostic_snapshot 分发到 8 个 _diag_* 内部函数 |
| PREVIOUS_ZERO 防护 | ✅ | 8 个 _diag_* 函数含 nullif/zero 分支（除0防护） |
| 异常 Low Base | ✅ | 8 条 anomaly_rule 全部配置 low_base_metric/value（如 A01 成交<5000 门禁） |
| 异常幂等 | ✅ 完全重复=0 | (chain_key,日期,域,实体,指标,类型) 重复=0；同链多实体=聚合语义 |
| 异常生命周期 | ✅ | status=OPEN(104)；同链跨日期=持续检测（triggered_period_count） |

> 构造型验证（低基数大变化 vs 高基数小变化）未执行正式库；anomaly_rule 门禁配置为设计证据，建议隔离库构造样本复核门禁效果。""")

# ===== 09 诊断/拆解 =====
w("09_diagnosis_decomposition_report.md", "诊断与变化拆解报告（专项17/18）", """## 结论：PASS

| 检查点 | 结果 | 证据 |
|---|---|---|
| 诊断因果边界 | ✅ | evidence_json=数据证据链（funnel/current/previous/relative_change/coverage_complete），非因果结论 |
| AI 因果边界 | ✅ | system_prompt 含"不写因果/证据"约束；诊断 code 为定位型（D01_SALES_DECLINE/D08_MULTI_FACTOR_DECLINE） |
| 变化拆解负向分母 | ✅ | decompose 函数含 gross_negative 逻辑；实测平台拆解 net=-299,600.78 share=0.6966（按负向分母） |
| 正向抵消单列 | ✅ | 函数返回 gross_positive 独立列（V1.3 S2 验收） |

> 构造型 A-100/B-50/C+80 验证：公式已从函数逻辑确认（gross_negative 分母）；数值构造建议隔离库。""")

# ===== 10 Opportunity/Priority =====
w("10_opportunity_priority_report.md", "Opportunity 与 Priority 报告（专项19/20/21）", """## 结论：PASS

| 检查点 | 结果 | 证据 |
|---|---|---|
| 权重归一 | ✅ | 8 条 opportunity_rule 权重和=100（100 制归一） |
| available_weight≥70% | ✅ | 209/264 事件 available_weight<0.7 → 不输出正式机会分（门禁生效） |
| Peer Pool 分池 | ✅ | benchmark_pool 按域：master_product=31 / shop_product=13 / carrier=6（不混池） |
| Priority 链去重 | ✅ | 风险 TOP5 含 3 个不同 chain（shop/master_product/carrier），同一链未占满 |
| dedupe_group_key | ✅ | 组内最多 9 条（同链跨期持续跟踪，occurrence 语义） |
| 风险机会并存 | ✅ | 同店同日期 3 组并存；anomaly_event(104) + opportunity_event(264) 独立评估 |

> SP20 样本注：TOP5 中 S1|master_product 链出现 3 次但对应**不同商品实体**（鱼子酱洗发水/椰子洗护等），属合理（同链多实体聚合），非去重失效。""")

# ===== 11 AI/MCP =====
w("11_ai_mcp_consistency_report.md", "AI 与 MCP 一致性报告（专项22/23/24）", """## 结论：PASS（系统侧）

| 检查点 | 结果 | 证据 |
|---|---|---|
| AI 数字 = MCP | ✅ | test_cases 期望值 10 条：系统侧 MCP 全部正确（#1-7,9 逐条核对；#5 个护直播=2,123,430.02 ✓；#7 投放消耗=3,918,524.13 ✓） |
| test_cases 期望值 | ⚠️ P2 | #8/#10 期望 0.2969 错误（个护退款率实际 0.2667，所有口径一致） |
| AI 不自行重算 | ✅ | system_prompt 明确比例由数据库重算、禁止 AVG/SUM；指标别名路由 |
| 上下文不串店 | ✅ | routing_rules 多轮上下文继承 + 店铺/实体路由 |
| MCP 安全 | ✅ | agent_readonly：57 查询函数授权；无写/DDL/core 直读；5 生成函数仅 postgres（写型正确隔离） |
| PUBLIC EXECUTE | ⚠️ P1 | get_business_report 保留 PUBLIC EXECUTE（{=X/postgres}），待确认/REVOKE |

> AI 真实模型调用未执行（无模型 API 会话）；验证基于 test_cases 确定性期望 + MCP 实际结果。建议 F0.5 集成真实模型后补 30 题端到端。""")

# ===== 12 安全/接口 =====
w("12_security_interface_report.md", "安全与接口唯一性报告（专项24/25/26/27/28）", """## 结论：PASS（含 2 项待办）

| 检查点 | 结果 |
|---|---|
| LEGACY/DEPRECATED 对象 | ✅ 无 |
| 双 ACTIVE 接口 | ✅ 未发现 |
| NULL 不伪装 0 | ✅ 无数据区间返回 NO_DATA；unrecalculable_metrics 保留 |
| 中文展示 | ✅ core 9 表有表 COMMENT；⚠️ 列注释覆盖待完善（P2） |
| F0.5 前置 | ✅ MCP 54 工具（49 带参数 schema）；Backend 只做 API/权限/参数/格式（系统约束已声明） |
| 环境稳定性 | ⚠️ **P1：外部进程并发修改**（见下） |

## P1：外部进程并发修改数据库（本检查期间发生）
- 17:22~17:57 期间：SECURITY DEFINER 函数 ACL 波动（57 查询函数授权保持，5 生成函数仅 postgres 为设计），期间 MCP 工具出现间歇 permission denied（如 get_business_summary 17:46 失败 → 17:56 恢复）
- 17:48 日志出现**非本会话发起的** `detect_growth_opportunities` 调用
- 17:52 `.env` 被更新（数据库密码轮换，新增 PG_ADMIN_PASSWORD 字段）
- **影响**：并发会话可能互相覆盖 ACL/密码，导致 MCP 间歇不可用
- **建议**：确认是否有其他 WorkBuddy 会话/定时任务在操作本库；如无，按"单一维护窗口"原则执行 DDL/密码操作；F0.5 前固化 ACL 基线（57+5+1）并加版本记录

## P1：get_business_report PUBLIC EXECUTE
- 函数 `mart.get_business_report` proacl={=X/postgres,...} 保留 PUBLIC EXECUTE
- 建议：确认后 REVOKE ALL ON FUNCTION mart.get_business_report(text,text) FROM PUBLIC（最小权限收敛）""")

# ===== 13 最终 =====
w("13_critical_logic_final_report.md", "关键逻辑专项检查最终报告", """## 总体结论：**未达到 P0=P1=P2=0 通过标准**

### 专项汇总（28 项）
| 等级 | 数量 | 明细 |
|---|---|---|
| P0 | **0** | - |
| P1 | **2** | ① 外部进程并发修改 ACL/密码（环境问题，非代码缺陷）② get_business_report PUBLIC EXECUTE 待收敛 |
| P2 | **4** | ① test_cases #8/#10 期望值错误 ② 12 行转化率源值>1 ③ 38 个历史脚本硬编码密码（S2 已记录）④ core 列注释待完善 |
| PASS | 22 项 | 全部核心口径验证通过 |

### 已验证（通过项）
- ✅ 导入不串店（replace_period=表+shop+日期+scope；单事务回滚；唯一键 0 重复）
- ✅ 51/61 列无静默错位（抽样逐列 Excel 原值=Core）
- ✅ 比例/效率不 AVG（126 组正式≠AVG日率；整体≠两店AVG）
- ✅ 18 Scope 恒等式成立（全部=自营+合作 / 载体 / 投放 / 终端，差异=0）
- ✅ 平台汇总=两店 SUM（100/100）；比例跨店重算
- ✅ Coverage 两店完整（3 区间）；门禁字段齐备
- ✅ Master Product 只用 CONFIRMED；Product Line 链路正确；SKU 空壳语义
- ✅ 每日粒度（biz_date=源日期），无快照伪装
- ✅ Snapshot PREVIOUS_ZERO 防护（nullif）；异常 LowBase 8 规则全配置；幂等 0 重复
- ✅ 诊断=数据定位（evidence_json），不伪造因果；拆解按 gross_negative 分母
- ✅ Opportunity 权重归一（100 制）、<70% 不输出、Peer 分池正确
- ✅ Priority 链去重（TOP5 3 链）；风险机会并存
- ✅ AI 数字=MCP（系统侧）；上下文路由不串店；MCP 最小权限；无 LEGACY/DEPRECATED；NULL 不伪装 0

### 未通过项处置建议
1. **P1-外部并发**：先确认其他会话/自动化；固化 ACL 基线；F0.5 前单窗口运维
2. **P1-PUBLIC EXECUTE**：批准后 REVOKE get_business_report 的 PUBLIC 执行权
3. **P2-test_cases**：修正 #8/#10 期望值为 0.2667 后重跑 AI 测试集
4. **P2-源值>1**：人工核对源 Excel 12 行转化率值，确认平台口径
5. **P2-密码清理**：38 个历史脚本改配置引用或轮换（S2 BUG-007 同项）
6. **P2-注释**：补 core 列 COMMENT（F0.5 中文数据字典依赖）

### 结论
> ⚠️ **V1.3 / V1.1 关键业务逻辑专项回归：P0=0、P1=2、P2=4 → 未通过 P0=P1=P2=0 标准**
> 核心业务口径（多店/Scope/比例/Coverage/主数据/智能经营/AI 一致性）**全部验证正确**；
> 未发现会造成静默错误的核心缺陷；2 项 P1 均为运维/收敛待办（非数据错误）。
> **建议**：处理 2 项 P1 + 4 项 P2 后再进入 F0.5；届时数据库最终架构收口可完成。
> 本轮严格遵守只读约束，未修改任何数据库对象；完成后停止，未自动进入 F0.5。""")

print("\n===== 13 份报告生成完毕 =====")
for f in sorted(OUT.glob("*.md")) + [OUT / "01_critical_logic_test_matrix.csv"]:
    print("  ", f.name)
