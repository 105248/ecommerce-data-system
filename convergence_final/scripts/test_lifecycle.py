# -*- coding: utf-8 -*-
def lifecycle(obj):
    s, t, n = obj["schema"], obj["name"], obj["type"]
    if t == "SEQUENCE":
        return "INTERNAL"
    if s == "core":
        return "ACTIVE"
    if s == "audit":
        return "ACTIVE"
    if s == "meta":
        if t in ("FUNCTION", "PROCEDURE"):
            return "INTERNAL"
        return "ACTIVE"
    if s == "中文数据":
        return "ACTIVE"
    if s == "mart":
        if t == "TABLE":
            return "ACTIVE"
        if t == "VIEW":
            return "ACTIVE"
        if t in ("FUNCTION", "PROCEDURE"):
            if n.startswith("_diag"):
                return "INTERNAL"
            return "ACTIVE"
    if s == "stg":
        return "REVIEW"
    return "REVIEW"


tests = [
    ({"schema": "mart", "name": "anomaly_event_anomaly_event_id_seq", "type": "SEQUENCE"}, "INTERNAL"),
    ({"schema": "mart", "name": "get_business_report", "type": "FUNCTION"}, "ACTIVE"),
    ({"schema": "中文数据", "name": "抖音成交日报", "type": "VIEW"}, "ACTIVE"),
    ({"schema": "core", "name": "douyin_deal_daily", "type": "TABLE"}, "ACTIVE"),
]
for obj, expect in tests:
    got = lifecycle(obj)
    print(obj["schema"], obj["name"], obj["type"], "->", got, "expect", expect, "OK" if got == expect else "FAIL")
