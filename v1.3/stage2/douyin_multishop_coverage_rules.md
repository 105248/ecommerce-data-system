# V1.3 Stage2 抖音多店 coverage 规则（douyin_multishop_coverage_rules）

> 平台汇总必须携带覆盖信息，不得把不完整覆盖说成完整（文档第八/九节 P0/P1 级）。

## 一、返回字段（所有平台汇总 Function）

| 字段 | 说明 |
|---|---|
| enabled_shop_count | 启用店铺数（platform_code=douyin AND enabled） |
| covered_shop_count | 区间内有数据（合法 TOTAL 口径）的店铺数 |
| missing_shop_count | enabled - covered |
| missing_shops | 缺失店铺名（`、`分隔） |
| coverage_complete | = covered==enabled 且 每家店该区间覆盖天数 == 期望天数 |

## 二、日期按店检查（文档第九节）

`coverage_complete` 双重条件：
1. 店铺存在性：covered_shop_count == enabled_shop_count
2. 日期完整性：每家店 `count(DISTINCT biz_date) >= expected_days`（区间天数）

任一不满足 → `coverage_complete=false`。

## 三、测试场景（真实构造验证，事务回滚）

| 场景 | 构造 | 结果 |
|---|---|---|
| 两店完整 | 06-01~30 正常数据 | enabled=2 covered=2 complete=t |
| 区间无数据 | 07-01~07（未来） | enabled=2 covered=0 complete=f |
| 个护禁用 | 事务内 enabled=false 回滚 | enabled=1 covered=1 missing=NULL complete=t |
| 官方完整/个护缺失 | 事务内 DELETE 个护 7 天回滚 | enabled=2 covered=1 missing=弹动个人护理旗舰店 complete=f |

## 四、AI 表达义务

- 平台结果：先检查 coverage；`covered < enabled` 或 `coverage_complete=false` 时**必须**说明"当前仅覆盖 X/Y 家启用抖音店铺，以下结果不是完整抖音整体"。
- 禁止把"官方完整"误述为"抖音整体完整"（官方店有 30 天 ≠ 平台有 30 天）。
