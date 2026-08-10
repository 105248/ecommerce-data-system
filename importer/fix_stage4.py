# -*- coding: utf-8 -*-
src = open(r'C:/Users/EDY/Desktop/数据库/四阶段任务/04_mart_V1.0_阶段4_MCP_Readonly_Security.sql', encoding='utf-8-sig').read()

# 适配1: 视图 analysis_metric_rule -> analysis_metric_whitelist
src = src.replace("IF to_regclass('mart.analysis_metric_rule') IS NOT NULL THEN",
                  "IF to_regclass('mart.analysis_metric_whitelist') IS NOT NULL THEN")
src = src.replace("EXECUTE 'GRANT SELECT ON TABLE mart.analysis_metric_rule TO agent_readonly';",
                  "EXECUTE 'GRANT SELECT ON TABLE mart.analysis_metric_whitelist TO agent_readonly';")

# 适配2: 补授权 stage3_expected_scope_map 视图 (插到 metric_rule_v14 授权后面)
anchor = """    IF to_regclass('mart.metric_rule_v14') IS NOT NULL THEN
        EXECUTE 'GRANT SELECT ON TABLE mart.metric_rule_v14 TO agent_readonly';
    END IF;
"""
addition = anchor + """
    IF to_regclass('mart.stage3_expected_scope_map') IS NOT NULL THEN
        EXECUTE 'GRANT SELECT ON TABLE mart.stage3_expected_scope_map TO agent_readonly';
    END IF;
"""
src = src.replace(anchor, addition)

# 适配3: 函数白名单 - get_scope_contribution 实际为 get_business_contribution
src = src.replace("              'get_scope_contribution',",
                  "              'get_business_contribution',")

# 适配4: 设置随机强密码
src = src.replace("-- 连接数据库（数据库名如不是 ecommerce_db，WorkBuddy 做最小适配）",
                  "ALTER ROLE agent_readonly PASSWORD '__PG_ADMIN_PASSWORD_FROM_ENV__';\n\n-- 连接数据库（数据库名如不是 ecommerce_db，WorkBuddy 做最小适配）")

out = r'D:/ecommerce-data-system/mart_stage2_pkg/04_stage4_fixed.sql'
open(out, 'w', encoding='utf-8', newline='').write(src)
print('适配版已生成')
print('analysis_metric_whitelist 授权:', src.count('analysis_metric_whitelist'))
print('get_business_contribution 授权:', src.count('get_business_contribution'))
print('stage3_expected_scope_map 授权:', src.count('stage3_expected_scope_map'))
print('密码行:', 'Ar_lZRulbzPDQ' in src)
