// F1.0.4 其余 8 页（products/advertising/refunds/accounts/risks/diagnostics/opportunities/smart-operation/search）
// 每页独立 Page/Service/契约/状态，数据全部来自正式 API
import { useEffect, useState } from 'react'
import type { Filters, RiskRow, OpportunityRow } from '../types'
import { api, getSummary, getRiskTop, getOpportunityTop, getIntelligenceStatus } from '../services/api'
import { MetricCard } from '../components/MetricCard'
import { CapabilityNotice } from '../components/CapabilityNotice'
import { fmt, yuan, pct, esc } from '../lib/format'

// ===== /products 商品（店铺级；rank_products 正式函数；仅 user_pay） =====
export function ProductsPage({ f }: { f: Filters }) {
  const [rows, setRows] = useState<Array<{ product_name: string; current_value: number }>>([])
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    if (!f.shop) { setRows([]); return }
    api<Array<{ product_name: string; current_value: number }>>('/business/products/top', { shop_code: f.shop, start_date: f.sd, end_date: f.ed, limit: 50 })
      .then(r => setRows(r.data)).catch(e => setErr(e.message))
  }, [f.shop, f.sd, f.ed])
  return (
    <div>
      <h1>商品分析</h1>
      <div className="sub">{f.shopName} ｜ {f.sd} ～ {f.ed} ｜ 按用户支付金额排序（正式 mart 排名）</div>
      {!f.shop ? <CapabilityNotice state="SELECT_SHOP_REQUIRED" /> : (
        err ? <CapabilityNotice state="ERROR" text={err} /> : (
          <div className="card">
            <CapabilityNotice state="UNSUPPORTED_METRIC" text="商品粒度无结算/投放/成交事实，页面仅展示用户支付金额" />
            <table>
              <thead><tr><th>#</th><th>商品</th><th className="num">用户支付金额</th></tr></thead>
              <tbody>
                {rows.map((x, i) => (
                  <tr key={i}><td>{i + 1}</td><td>{esc(x.product_name)}</td><td className="num">{yuan(x.current_value)}</td></tr>
                ))}
                {!rows.length && <tr><td colSpan={3} className="empty">当前区间无商品数据</td></tr>}
              </tbody>
            </table>
          </div>
        )
      )}
    </div>
  )
}

// ===== /advertising 投放（店铺级；整体→SELECT_SHOP_REQUIRED） =====
export function AdvertisingPage({ f }: { f: Filters }) {
  const [d, setD] = useState<Record<string, number | null>>({})
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    if (!f.shop) { setD({}); return }
    api<Record<string, number | null>>('/advertising/summary', { shop_code: f.shop, start_date: f.sd, end_date: f.ed, scope_key: f.scope })
      .then(r => setD(r.data)).catch(e => setErr(e.message))
  }, [f.shop, f.sd, f.ed, f.scope])
  return (
    <div>
      <h1>投放经营</h1>
      <div className="sub">{f.shopName} ｜ {f.sd} ～ {f.ed} ｜ {f.scope} ｜ 费比/效率全部来自正式 mart 口径</div>
      {!f.shop ? <CapabilityNotice state="SELECT_SHOP_REQUIRED" /> : (
        err ? <CapabilityNotice state="ERROR" text={err} /> : (
          <div className="kpis" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(160px,1fr))', gap: 10, margin: '12px 0' }}>
            <MetricCard label="投放消耗(店铺被投)" value={d.ad_spend_shop_promoted} />
            <MetricCard label="投放消耗(店铺绑定)" value={d.ad_spend_shop_bound} />
            <MetricCard label="投放贡献成交" value={d.ad_attributed_transaction_amount} />
            <MetricCard label="投放贡献占比" value={d.ad_attributed_transaction_share} opts={{ isRate: true }} />
            <MetricCard label="投放费比" value={d.ad_spend_rate_net_refund_shop_bound} opts={{ isRate: true, goodWhen: 'low' }} />
            <MetricCard label="综合费比" value={d.total_expense_rate_net_refund_shop_bound} opts={{ isRate: true, goodWhen: 'low' }} />
            <MetricCard label="投放效率" value={d.ad_efficiency_shop_bound} />
            <MetricCard label="全店效率" value={d.store_efficiency_shop_bound} />
          </div>
        )
      )}
      <CapabilityNotice state="SOURCE_NOT_AVAILABLE" text="计划/账户/单元/预算/状态：无计划级源数据，不从店铺总投放推算" />
    </div>
  )
}

// ===== /refunds 退款 =====
export function RefundsPage({ f }: { f: Filters }) {
  const [s, setS] = useState<Record<string, number | null>>({})
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    getSummary({ shop: f.shop, sd: f.sd, ed: f.ed, scope: f.scope }).then(r => setS(r.data)).catch(e => setErr(e.message))
  }, [f.shop, f.sd, f.ed, f.scope])
  return (
    <div>
      <h1>退款分析</h1>
      <div className="sub">{f.shopName} ｜ {f.sd} ～ {f.ed} ｜ {f.scope}</div>
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <div className="kpis" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(150px,1fr))', gap: 10, margin: '12px 0' }}>
          <MetricCard label="退款金额(支付时间)" value={s.refund_amount_pay_time} />
          <MetricCard label="退款率" value={s.refund_rate} opts={{ isRate: true, goodWhen: 'low' }} />
          <MetricCard label="成交金额" value={s.transaction_amount} />
          <MetricCard label="用户支付金额" value={s.user_pay_amount} />
        </div>
      )}
      <CapabilityNotice state="SOURCE_NOT_AVAILABLE" text="退款原因/售后原因：当前数据源不支持退款原因分析；AI 不得推测具体原因" />
    </div>
  )
}

// ===== /accounts 达人/账号（F1.0.2 正式 wrapper；自营+合作） =====
export function AccountsPage({ f }: { f: Filters }) {
  const [rows, setRows] = useState<Array<{ account_name: string; account_type: string; current_value: number | null }>>([])
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    if (!f.shop) { setRows([]); return }
    Promise.all(['自营', '合作'].map(sc =>
      api<Array<{ account_name: string; account_type: string; current_value: number | null }>>('/accounts/top', { shop_code: f.shop, start_date: f.sd, end_date: f.ed, sale_scope: sc, limit: 25 })
        .then(r => r.data).catch(() => [])
    )).then(([a, b]) => setRows([...a, ...b])).catch(e => setErr(e.message))
  }, [f.shop, f.sd, f.ed])
  return (
    <div>
      <h1>达人 / 账号</h1>
      <div className="sub">{f.shopName} ｜ {f.sd} ～ {f.ed} ｜ 自营 + 合作（正式 mart 账号层）</div>
      {!f.shop ? <CapabilityNotice state="SELECT_SHOP_REQUIRED" /> : (
        err ? <CapabilityNotice state="ERROR" text={err} /> : (
          <div className="card">
            <table>
              <thead><tr><th>#</th><th>账号</th><th>类型</th><th className="num">用户支付金额</th></tr></thead>
              <tbody>
                {rows.map((x, i) => (
                  <tr key={i}><td>{i + 1}</td><td>{esc(x.account_name || '—')}</td><td>{esc(x.account_type || '—')}</td><td className="num">{x.current_value != null ? yuan(x.current_value) : '—'}</td></tr>
                ))}
                {!rows.length && <tr><td colSpan={4} className="empty">当前区间无账号数据</td></tr>}
              </tbody>
            </table>
          </div>
        )
      )}
    </div>
  )
}

// ===== /risks 风险中心（完整 Anomaly） =====
export function RisksPage({ f }: { f: Filters }) {
  const [rows, setRows] = useState<RiskRow[]>([])
  const [stale, setStale] = useState(false)
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    api<RiskRow[]>('/risks/complete', { start_date: f.sd, end_date: f.ed, limit: 200 }).then(r => setRows(r.data)).catch(e => setErr(e.message))
    getIntelligenceStatus().then(r => setStale(r.data.intelligence_status === 'STALE')).catch(() => {})
  }, [f.sd, f.ed])
  return (
    <div>
      <h1>风险中心</h1>
      <div className="sub">V1.1 异常检测正式结果 ｜ {f.sd} ～ {f.ed} ｜ 完整列表</div>
      {stale && <CapabilityNotice state="REFRESH_STALE" text={`最新经营数据已更新，智能分析尚未刷新（本页显示最近一次智能检测结果，不代表"当前无风险"）`} />}
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <div className="card">
          <table>
            <thead><tr><th>对象</th><th>域</th><th>级别</th><th>类型</th><th className="num">当前值</th><th className="num">变化</th><th className="num">持续</th><th>覆盖率</th></tr></thead>
            <tbody>
              {rows.map((x, i) => (
                <tr key={i}>
                  <td><a href="#/diagnostics">{esc(x.entity_name)}</a></td>
                  <td>{esc(x.domain_key || '')}</td>
                  <td><span className="badge red">{esc(x.severity || '')}</span></td>
                  <td>{esc(x.anomaly_name_cn || x.anomaly_type || '')}</td>
                  <td className="num">{fmt(x.current_value)}</td>
                  <td className="num">{x.absolute_change != null ? ((x.absolute_change > 0 ? '+' : '') + fmt(x.absolute_change)) : '—'}</td>
                  <td className="num">{x.consecutive_day_count || ''}天</td>
                  <td>{x.coverage_complete ? <span className="badge green">完整</span> : <span className="badge amber">不完整</span>}</td>
                </tr>
              ))}
              {!rows.length && <tr><td colSpan={8} className="empty">当前区间无风险（Anomaly）</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

// ===== /opportunities 机会中心（完整列表） =====
export function OpportunitiesPage({ f }: { f: Filters }) {
  const [rows, setRows] = useState<OpportunityRow[]>([])
  const [stale, setStale] = useState(false)
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    api<OpportunityRow[]>('/opportunities/complete', { start_date: f.sd, end_date: f.ed, limit: 200 }).then(r => setRows(r.data)).catch(e => setErr(e.message))
    getIntelligenceStatus().then(r => setStale(r.data.intelligence_status === 'STALE')).catch(() => {})
  }, [f.sd, f.ed])
  return (
    <div>
      <h1>增长机会</h1>
      <div className="sub">V1.1 机会正式结果 ｜ {f.sd} ～ {f.ed} ｜ Opportunity Score 是机会质量排序，不是未来成功概率</div>
      {stale && <CapabilityNotice state="REFRESH_STALE" text={`最新经营数据已更新，智能分析尚未刷新（本页显示最近一次智能检测结果，不代表"当前无机会"）`} />}
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <div className="card">
          <table>
            <thead><tr><th>对象</th><th>域</th><th className="num">机会分</th><th>级别</th><th className="num">当前值</th><th className="num">相对变化</th><th className="num">可用权重</th></tr></thead>
            <tbody>
              {rows.map((x, i) => (
                <tr key={i}>
                  <td>{esc(x.entity_name)}</td>
                  <td>{esc(x.domain_key || '')}</td>
                  <td className="num">{fmt(x.opportunity_score)}</td>
                  <td><span className="badge green">{esc(x.opportunity_level)}</span></td>
                  <td className="num">{fmt(x.current_value)}</td>
                  <td className="num">{x.relative_change != null ? ((x.relative_change > 0 ? '+' : '') + (x.relative_change * 100).toFixed(1) + '%') : '—'}</td>
                  <td className="num">{x.available_weight != null ? fmt(x.available_weight) + ' 分' : '—'}</td>
                </tr>
              ))}
              {!rows.length && <tr><td colSpan={7} className="empty">当前区间无机会</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

// ===== /diagnostics 问题诊断 =====
export function DiagnosticsPage({ f }: { f: Filters }) {
  const [rows, setRows] = useState<Array<{ diagnostic_code: string; primary_stage: string; confidence_score: number; current_value: number; absolute_change: number }>>([])
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    api<Array<{ diagnostic_code: string; primary_stage: string; confidence_score: number; current_value: number; absolute_change: number }>>('/diagnostics/results', { start_date: f.sd, end_date: f.ed, domain_key: 'shop' })
      .then(r => setRows(r.data)).catch(e => setErr(e.message))
  }, [f.sd, f.ed])
  return (
    <div>
      <h1>问题诊断</h1>
      <div className="sub">V1.1 诊断正式结果 ｜ {f.sd} ～ {f.ed} ｜ 数据定位，非因果结论 ｜ 平台级诊断</div>
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <div className="card">
          <table>
            <thead><tr><th>诊断类型</th><th>Primary Stage</th><th className="num">置信度</th><th className="num">当前值</th><th className="num">变化</th></tr></thead>
            <tbody>
              {rows.map((x, i) => (
                <tr key={i}>
                  <td>{esc(x.diagnostic_code)}</td>
                  <td><span className="badge blue">{esc(x.primary_stage)}</span></td>
                  <td className="num">{pct(x.confidence_score)}</td>
                  <td className="num">{fmt(x.current_value)}</td>
                  <td className="num">{fmt(x.absolute_change)}</td>
                </tr>
              ))}
              {!rows.length && <tr><td colSpan={5} className="empty">当前区间无诊断结果</td></tr>}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}

// ===== /smart-operation 智能经营（决策中心） =====
export function SmartOperationPage({ f }: { f: Filters }) {
  const [risks, setRisks] = useState<RiskRow[]>([])
  const [opps, setOpps] = useState<OpportunityRow[]>([])
  const [stale, setStale] = useState(false)
  useEffect(() => {
    getRiskTop({ sd: f.sd, ed: f.ed }, 5).then(r => setRisks(r.data)).catch(() => setRisks([]))
    getOpportunityTop({ sd: f.sd, ed: f.ed }, 5).then(r => setOpps(r.data)).catch(() => setOpps([]))
    getIntelligenceStatus().then(r => setStale(r.data.intelligence_status === 'STALE')).catch(() => {})
  }, [f.sd, f.ed])
  return (
    <div>
      <h1>智能经营</h1>
      <div className="sub">{f.sd} ～ {f.ed} ｜ 经营决策中心：智能层结果集中视图</div>
      {stale && <CapabilityNotice state="REFRESH_STALE" text={`最新经营数据已更新，智能分析尚未刷新（本页显示最近一次智能检测结果）`} />}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        <div className="card">
          <h3>当前风险摘要</h3>
          {risks.map((x, i) => (
            <div key={i} style={{ padding: '6px 0', borderBottom: '1px solid #f3f4f6', fontSize: 13 }}>
              <a href="#/risks">{esc(x.entity_name)}</a> <span className="badge red">{esc(x.risk_level)}</span>
              <span className="num" style={{ float: 'right' }}>{x.risk_priority_score != null ? fmt(x.risk_priority_score) : ''}</span>
            </div>
          ))}
          {!risks.length && <div className="empty">无</div>}
        </div>
        <div className="card">
          <h3>当前机会摘要</h3>
          {opps.map((x, i) => (
            <div key={i} style={{ padding: '6px 0', borderBottom: '1px solid #f3f4f6', fontSize: 13 }}>
              <a href="#/opportunities">{esc(x.entity_name)}</a> <span className="badge green">{esc(x.opportunity_level)}</span>
              <span className="num" style={{ float: 'right' }}>{x.opportunity_priority_score != null ? fmt(x.opportunity_priority_score) : ''}</span>
            </div>
          ))}
          {!opps.length && <div className="empty">无</div>}
        </div>
      </div>
    </div>
  )
}

// ===== /search 搜索（SOURCE_NOT_AVAILABLE） =====
export function SearchPage() {
  return (
    <div>
      <h1>搜索</h1>
      <CapabilityNotice state="SOURCE_NOT_AVAILABLE" text="当前本机/正式数据库尚无搜索核心数据源，暂不支持搜索成交、搜索词、关键词排行" />
    </div>
  )
}
