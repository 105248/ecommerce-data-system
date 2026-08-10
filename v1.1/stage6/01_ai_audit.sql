-- ============================================================================
-- V1.1 阶段6｜AI智能经营诊断（多店兼容修订版）
-- 01_ai_audit.sql（AI 诊断审计表）
-- ============================================================================
-- 记录 AI 每次诊断运行：时间/意图/工具/来源ID/时长；不记录密码/密钥/.env/完整 system prompt。
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit.ai_diagnosis_run (
    run_id          bigserial PRIMARY KEY,
    occurred_at     timestamptz NOT NULL DEFAULT now(),
    intent          text,                     -- DAILY_BRIEF / RISK_PRIORITY / ...
    question_hash   text,                     -- 问题哈希（不存原文以防敏感）
    scope_text      text,                     -- platform/shop/entity_level/scope 摘要
    tools_called    jsonb,                    -- [{"tool": "...", "result_id": ...}]
    result_id       text,                     -- anomaly_event_id / diagnostic_id / opportunity_event_id / action_item_id
    duration_ms     integer,
    error_type      text,
    note            text
);
COMMENT ON TABLE audit.ai_diagnosis_run IS 'V1.1 AI 诊断审计（不含密码/密钥/.env/完整system prompt）。';
