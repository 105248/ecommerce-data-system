// F1.0.4 /priorities 经营优先级（风险/机会/Action；不复制首页 7 KPI；STALE 提示）
import { useEffect, useState } from 'react'
import type { Filters, RiskRow, OpportunityRow, IntelligenceStatus } from '../types'
import { getRiskTop, getOpportunityTop, api, getIntelligenceStatus } from '../services/api'
import { CapabilityNotice } from '../components/CapabilityNotice'
import { fmt, yuan, esc } from '../lib/format'

export function PrioritiesPage({ f }: { f: Filters }) {
  const [risks, setRisks] = useState<RiskRow[]>([])
  const [opps, setOpps] = useState<OpportunityRow[]>([])
  const [stale, setStale] = useState(false)
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    getRiskTop({ sd: f.sd, ed: f.ed }, 10).then(r => setRisks(r.data)).catch(() => setRisks([]))
    getOpportunityTop({ sd: f.sd, ed: f.ed }, 10).then(r => setOpps(r.data)).catch(() => setOpps([]))
    getIntelligenceStatus().then(r => setStale(r.data.intelligence_status === 'STALE')).catch(() => {})
  }, [f.sd, f.ed])
  return (
    <div>
      <h1>经营优先级</h1>
      <div className="sub">{f.sd} ～ {f.ed} ｜ 今天最应该做什么（V1.1 Priority，前端不重排）</div>
      {stale && <CapabilityNotice state="REFRESH_STALE" text={`最新经营数据已更新，智能分析尚未刷新（本页显示最近一次智能检测结果，不代表"当前无风险/无机会"）`} />}
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div className="card">
            <h3>风险优先级</h3>
            <table>
              <thead><tr><th>对象</th><th>级别</th><th className="num">得分</th><th className="num">影响金额</th></tr></thead>
              <tbody>
                {risks.map((x, i) => (
                  <tr key={i}>
                    <td><a href="#/risks">{esc(x.entity_name)}</a></td>
                    <td><span className="badge red">{esc(x.risk_level)}</span></td>
                    <td className="num">{fmt(x.risk_priority_score)}</td>
                    <td className="num">{x.business_impact != null ? yuan(x.business_impact) : '—'}</td>
                  </tr>
                ))}
                {!risks.length && <tr><td colSpan={4} className="empty">当前区间无风险优先级</td></tr>}
              </tbody>
            </table>
          </div>
          <div className="card">
            <h3>机会优先级</h3>
            <table>
              <thead><tr><th>对象</th><th>级别</th><th className="num">得分</th><th className="num">机会分</th></tr></thead>
              <tbody>
                {opps.map((x, i) => (
                  <tr key={i}>
                    <td><a href="#/opportunities">{esc(x.entity_name)}</a></td>
                    <td><span className="badge green">{esc(x.opportunity_level)}</span></td>
                    <td className="num">{fmt(x.opportunity_priority_score)}</td>
                    <td className="num">{fmt(x.opportunity_score)}</td>
                  </tr>
                ))}
                {!opps.length && <tr><td colSpan={4} className="empty">当前区间无机会优先级</td></tr>}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  )
}
