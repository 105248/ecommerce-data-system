// F1.0.4-R3 /today 经营驾驶舱（标题随区间；KPI 绑定正确；环比消费 API 字段；店铺贡献已移周期进度页去重）
import { useEffect, useState } from 'react'
import type { BusinessSummary, Filters, RiskRow, OpportunityRow, TrendPoint } from '../../types'
import { getSummary, getTrend, getRiskTop, getOpportunityTop, getIntelligenceStatus, api } from '../../services/api'
import { MetricCard } from '../../components/MetricCard'
import { TrendChart } from '../../components/TrendChart'
import { CapabilityNotice } from '../../components/CapabilityNotice'
import { fmt, yuan, pct, esc, pageTitleForToday } from '../../lib/format'

interface CompareData { previous_value?: number | null; absolute_change?: number | null; percentage_point_change?: number | null }

export function TodayPage({ f }: { f: Filters }) {
  const [s, setS] = useState<BusinessSummary | null>(null)
  const [trend, setTrend] = useState<TrendPoint[]>([])
  const [risks, setRisks] = useState<RiskRow[]>([])
  const [opps, setOpps] = useState<OpportunityRow[]>([])
  const [cmp, setCmp] = useState<CompareData>({})
  const [stale, setStale] = useState(false)
  const [err, setErr] = useState('')
  const title = pageTitleForToday(f.sd, f.ed, f.today || '')

  useEffect(() => {
    setErr('')
    const q = { shop: f.shop, sd: f.sd, ed: f.ed, scope: f.scope }
    getSummary(q).then(r => setS(r.data)).catch(e => setErr(e.message))
    getTrend(q, 'transaction_amount').then(r => setTrend(r.data)).catch(() => setTrend([]))
    getRiskTop({ sd: f.sd, ed: f.ed }).then(r => setRisks(r.data)).catch(() => setRisks([]))
    getOpportunityTop({ sd: f.sd, ed: f.ed }).then(r => setOpps(r.data)).catch(() => setOpps([]))
    api<CompareData>('/business/compare', { start_date: f.sd, end_date: f.ed, metric_key: 'user_pay_amount' })
      .then(r => setCmp(r.data)).catch(() => setCmp({}))
    // F1.0.4-R2：智能层 STALE 时禁止用"无风险/无机会"误导（四能力任一落后事实即 STALE）
    getIntelligenceStatus().then(r => setStale(r.data.intelligence_status === 'STALE')).catch(() => {})
  }, [f.sd, f.ed, f.scope, f.shop])

  return (
    <div>
      <h1>{title}</h1>
      <div className="sub">{f.sd} ～ {f.ed} ｜ {f.shopName} ｜ {f.scope}</div>
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <>
          {stale && <CapabilityNotice state="REFRESH_STALE" text={`最新经营数据已更新，智能分析尚未刷新（本页风险/机会 TOP5 显示最近一次检测结果，不代表"当前无风险/无机会"）`} />}
          {s && (
            <div className="kpis" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(160px,1fr))', gap: 10, margin: '12px 0' }}>
              <MetricCard label="成交金额" value={s.transaction_amount} />
              <MetricCard label="用户支付金额" value={s.user_pay_amount} opts={{ chg: cmp.absolute_change ?? null }} />
              <MetricCard label="成交退款金额" value={s.transaction_refund_amount_pay_time} />
              <MetricCard label="结算金额" value={s.settlement_amount} />
              <MetricCard label="退款率" value={s.refund_rate} opts={{ isRate: true, goodWhen: 'low' }} />
              <MetricCard label="投放消耗" value={s.ad_spend_shop_bound} />
              <MetricCard label="投放费比" value={s.ad_spend_rate_net_refund_shop_bound} opts={{ isRate: true, goodWhen: 'low' }} />
            </div>
          )}
          <div className="card">
            <h3>成交金额趋势</h3>
            <TrendChart points={trend} />
            <div className="trend-note">数据粒度：日 ｜ 来源：经营数据库（mart 白名单）</div>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginTop: 12 }}>
            <div className="card">
              <h3>风险 TOP5</h3>
              {risks.length ? risks.slice(0, 5).map((x, i) => (
                <div key={i} style={{ padding: '6px 0', borderBottom: '1px solid #f3f4f6', fontSize: 13 }}>
                  <a href="#/risks">{esc(x.entity_name)}</a> <span className="badge red">{esc(x.severity)}</span>
                  <span className="num" style={{ float: 'right' }}>{x.business_impact != null ? yuan(x.business_impact) : ''}</span>
                </div>
              )) : <div className="empty">当前区间无风险</div>}
            </div>
            <div className="card">
              <h3>机会 TOP5</h3>
              {opps.length ? opps.slice(0, 5).map((x, i) => (
                <div key={i} style={{ padding: '6px 0', borderBottom: '1px solid #f3f4f6', fontSize: 13 }}>
                  <a href="#/opportunities">{esc(x.entity_name)}</a> <span className="badge green">{esc(x.opportunity_level)}</span>
                  <span className="num" style={{ float: 'right' }}>{x.opportunity_priority_score != null ? fmt(x.opportunity_priority_score) : ''}</span>
                </div>
              )) : <div className="empty">当前区间无机会</div>}
            </div>
          </div>
          <div className="card" style={{ marginTop: 12 }}>
            <h3>周期进度</h3>
            <div style={{ padding: '10px 0', fontSize: 13, color: '#374151' }}>
              日报 / 周报 / 月报（抖音整体 + 两店 × 6 经营类型 × 6 指标）已移至 <a href="#/cycle" style={{ fontWeight: 600 }}>周期进度</a> 页，与今日经营不重复。
            </div>
          </div>
        </>
      )}
    </div>
  )
}
