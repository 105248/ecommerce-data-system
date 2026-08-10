# V1.3 Stage1｜第二抖音店铺接入 — README

> 阶段性质：V1.3 多店基础接入。在不破坏抖音单店 V1.0~V1.1 全链路前提下，将第二家抖音店铺「弹动个人护理旗舰店」正式接入，实现两店物理隔离、独立导入、独立覆盖、独立查询、独立诊断。
> **本阶段不做两店汇总、不做跨店商品统一、不做天猫/京东。**
> 本阶段通过后停止，等待确认进入 V1.3 阶段2《抖音多店统一经营层》。

## 一、交付文件

| 文件 | 说明 |
|---|---|
| `01_second_shop_meta.sql` | 第二店注册与命名统一（弹动个人护理旗舰店） |
| `02_second_shop_compatibility_check.sql` | 兼容性检查（见 qa 报告） |
| `03_second_shop_import_tests.sql` | 导入/覆盖/隔离测试 |
| `04_second_shop_regression.sql` | 旧店回归 |
| `05_second_shop_security.sql` | 安全层 |
| `second_shop_source_profile.md` | 第二店源文件结构扫描 |
| `second_shop_import_report.md` | 导入报告（跨店覆盖验证） |
| `second_shop_isolation_test.md` | 两店隔离测试 |
| `README.md` | 本文件 |
| `qa\v1.3_stage1_test_results.md` | 测试结果汇总 |
| `qa\v1.3_stage1_bug_log.csv` | 问题记录 |

## 二、店铺注册状态

| shop_id | platform | shop_code | shop_name | 导入批次 |
|---|---|---|---|---|
| 1 | douyin | DY_DANDONG_OFFICIAL | 弹动官方旗舰店 | batch9（18809 行） |
| 2 | douyin | DY_GERENHULI_OFFICIAL | **弹动个人护理旗舰店** | batch10/11（20551 行） |

命名说明：本阶段将第二店正式名统一为「弹动个人护理旗舰店」（原「抖音个人护理旗舰店」），与官方店命名风格一致；`meta.shop`、raw_files 目录、中文 View、MCP、AI 全部同步。

## 三、关键能力（均已验证）

1. **两店隔离**：同一 core 表 + shop_id 区分；9 表唯一索引含 shop_id；覆盖删除限定 shop_id+日期+表；20 组同日期同 Scope 查询无串店。
2. **独立导入/覆盖**：`--shop-id 2 --commit --force` 受控覆盖仅替换第二店，官方店 9,397,490.90/退款率 0.16565230 完全不变。
3. **独立查询**：mart Period / V1.1 诊断快照 / MCP / 中文 View 全部支持 `p_shop_name` 两店。
4. **18 Scope 第二店**：18/18 可查询（自营图文=0 为源数据无记录）。
5. **投放指标**：61 列投放字段规则与官方店完全一致（消耗/贡献/费比/综合费比/效率/全店效率）。
6. **MCP 店铺参数**：未知店铺 → UNKNOWN_SHOP（V1.3 新增 check_shop 校验）。
7. **AI 店铺识别**：官方旗舰店/弹动官方旗舰店/个人护理店/弹动个人护理旗舰店 别名映射；歧义追问；多轮继承店铺上下文。

## 四、验收结果

- ✅ Excel→core 对账 **2670 字段值 0 不匹配**（含投放专项）
- ✅ core→mart 对账 **150/150 PASS 0 差异**
- ✅ 跨店覆盖专项：官方店完全不变、个护独立替换
- ✅ 两店隔离 20 组无串店
- ✅ V1.1 诊断快照 6 域第二店全通（shop 31 / scope 558 / product 285 / carrier 108 / account 2727 / category 42）
- ✅ 性能无退化（个护 30 天 5ms、TOP100 商品 35ms）
- ✅ 安全边界不变（agent_readonly 只读、UNKNOWN_SHOP）
- ✅ 旧店回归：官方 9,397,490.90 / 9,461,162.26 / 1,556,715.99 不变
- ✅ P0=0 P1=0 P2=0

## 五、MCP 工具数

27（V1.0.1）+ 2（V1.1 诊断）= **29**（本阶段未新增工具，仅增强店铺校验）。

## 六、AI 层变更

- `system_prompt.md`：角色改为多店；新增「店铺识别（多店）」节（别名映射/不默认错店/歧义追问/UNKNOWN_SHOP）。
- `routing_rules.md`：日报模板路由已含两店。
