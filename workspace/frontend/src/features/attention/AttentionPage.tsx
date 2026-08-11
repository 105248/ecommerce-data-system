// F1.1 /attention 待关注：目标异常（第一来源）+ 数据异常（FRESH 时第二来源）
// 不做复杂评分；可读文案 + 查看链接
import { useEffect, useState } from 'react'
import { api } from '../../services/api'
import { CapabilityNotice } from '../../components/CapabilityNotice'
import { yuan, pct, esc } from '../../lib/format'

interface OpRow {
  section_name: string; business_type: string
  transaction_amount: number | null; transaction_period_target: number | null
  transaction_completion_rate: number | null; transaction_time_progress: number | null
  transaction_progress_gap: number | null
  transaction_refund_alert: string | null; settlement_alert: string | null
  refund_rate_alert: string | null; ad_spend_alert: string | null; ad_spend_rate_alert: string | null
  coverage_complete: boolean
}
interface RiskRow { entity_name: string; severity: string; anomaly_type: string; current_value: number | null }

interface Issue { level: '严重' | '关注'; kind: '目标' | '异常'; title: string; desc: string; link: string }

export function AttentionPage() {
  const [tab, setTab] = useState<'all' | 'target' | 'anomaly'>('all')
  const [targetIssues, setTargetIssues] = useState<Issue[]>([])
  const [anomalyIssues, setAnomalyIssues] = useState<Issue[]>([])
  const [err, setErr] = useState('')

  useEffect(() => {
    setErr('')
    // 目标异常：月报目标判定（全部目标）
    api<{ rows: OpRow[] }>('/operating-progress', { period_type: 'monthly' })
      .then(r => {
        const out: Issue[] = []
        r.data.rows.forEach(x => {
          const name = `${x.section_name}·${x.business_type}`
          if (x.transaction_progress_gap != null && x.transaction_progress_gap < 0) {
            const lag = -x.transaction_progress_gap * 100
            out.push({
              level: lag >= 10 ? '严重' : '关注', kind: '目标',
              title: `${name} 成交进度落后 ${lag.toFixed(1)}%`,
              desc: `实际 ${x.transaction_amount != null ? yuan(x.transaction_amount) : '—'}${x.transaction_period_target != null ? ` / 月目标 ${yuan(x.transaction_period_target)}` : ''}｜完成 ${x.transaction_completion_rate != null ? (x.transaction_completion_rate * 100).toFixed(1) : '—'}%｜时间进度 ${x.transaction_time_progress != null ? (x.transaction_time_progress * 100).toFixed(1) : '—'}%`,
              link: '#/progress',
            })
          }
          const extra: Array<[string, string | null]> = [
            [`${name} 退款率超目标`, x.refund_rate_alert],
            [`${name} 投放费比超目标`, x.ad_spend_rate_alert],
            [`${name} 成交退款超当前目标`, x.transaction_refund_alert],
            [`${name} 结算低于当前目标进度`, x.settlement_alert],
            [`${name} 投放消耗超预算进度`, x.ad_spend_alert],
          ]
          extra.forEach(([t, a]) => { if (a) out.push({ level: '关注', kind: '目标', title: t, desc: esc(a), link: '#/progress' }) })
        })
        setTargetIssues(out)
      }).catch(() => setTargetIssues([]))

    // 数据异常：智能层 FRESH 才取（第二来源，简单文案）
    api<{ intelligence_status: string }>('/intelligence-status')
      .then(st => {
        if (st.data.intelligence_status !== 'FRESH') { setAnomalyIssues([]); return }
        api<RiskRow[]>('/risks/complete', { start_date: '2026-07-01', end_date: '2026-07-31', limit: 8 })
          .then(r => {
            setAnomalyIssues((r.data || []).map(x => ({
              level: x.severity === 'CRITICAL' ? '严重' : '关注', kind: '异常',
              title: `${x.entity_name} ${x.anomaly_type || '经营指标异常'}`,
              desc: x.current_value != null ? `当前值 ${x.current_value}` : '',
              link: '#/product-lines',
            })))
          }).catch(() => setAnomalyIssues([]))
      }).catch(() => setAnomalyIssues([]))
  }, [])

  const shown = tab === 'all' ? [...targetIssues, ...anomalyIssues] : tab === 'target' ? targetIssues : anomalyIssues

  return (
    <div>
      <h1>待关注</h1>
      <div className="sub">目标未达成 + 数据异常（不显示复杂评分）；目标全部达标时不提示</div>
      <div style={{ display: 'flex', gap: 8, margin: '10px 0' }}>
        {([['all', '全部'], ['target', '目标'], ['anomaly', '异常']] as Array<[string, string]>).map(([k, l]) => (
          <button key={k} onClick={() => setTab(k as typeof tab)}
            style={{ padding: '5px 14px', borderRadius: 8, border: '1px solid #d1d5db', cursor: 'pointer',
                     background: tab === k ? '#2563eb' : '#fff', color: tab === k ? '#fff' : '#374151', fontSize: 13 }}>
            {l}{k === 'all' ? ` (${targetIssues.length + anomalyIssues.length})` : k === 'target' ? ` (${targetIssues.length})` : ` (${anomalyIssues.length})`}
          </button>
        ))}
      </div>
      {err && <CapabilityNotice state="ERROR" text={err} />}
      {shown.length === 0 ? (
        <CapabilityNotice state="NO_DATA" text="当前无待关注事项（目标均达标且无数据异常）" />
      ) : (
        <div>
          {shown.map((it, i) => (
            <div key={i} style={{ padding: '10px 14px', border: '1px solid #e5e7eb', borderRadius: 8, marginBottom: 8, background: '#fff' }}>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                <span className={`badge ${it.level === '严重' ? 'red' : 'amber'}`}>{it.level}</span>
                <span className="badge gray">{it.kind}</span>
                <b style={{ fontSize: 13 }}>{esc(it.title)}</b>
                <a href={it.link} style={{ marginLeft: 'auto', fontSize: 12, fontWeight: 600 }}>[查看数据]</a>
              </div>
              {it.desc && <div style={{ fontSize: 12, color: '#6b7280', marginTop: 4 }}>{it.desc}</div>}
            </div>
          ))}
        </div>
      )}
      <div className="trend-note" style={{ marginTop: 12 }}>
        目标异常来自目标系统（月目标自动测算）；数据异常仅在智能分析 FRESH（最新）时展示。复杂风险/机会评分不在此页展示。
      </div>
    </div>
  )
}
