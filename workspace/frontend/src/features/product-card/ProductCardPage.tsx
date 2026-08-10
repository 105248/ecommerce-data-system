// F1.0.4 /product-card（渠道整体 + 快照 PERIOD_SNAPSHOT + 来源 SOURCE_NOT_AVAILABLE）
import { useEffect, useState } from 'react'
import type { Filters, BusinessSummary, TrendPoint } from '../types'
import { getSummary, getTrend } from '../services/api'
import { api } from '../services/api'
import { MetricCard } from '../components/MetricCard'
import { TrendChart } from '../components/TrendChart'
import { CapabilityNotice } from '../components/CapabilityNotice'
import { yuan, esc } from '../lib/format'

interface SnapSummary { product_count: number; exposure_users: number; click_users: number; user_pay_amount: number; transaction_users: number; transaction_orders: number }
interface SnapRank { product_title: string; product_id: string; current_value: number }

export function ProductCardPage({ f }: { f: Filters }) {
  const [s, setS] = useState<BusinessSummary | null>(null)
  const [trend, setTrend] = useState<TrendPoint[]>([])
  const [snap, setSnap] = useState<SnapSummary | null>(null)
  const [rank, setRank] = useState<SnapRank[]>([])
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    const q = { shop: f.shop, sd: f.sd, ed: f.ed, scope: '商品卡' }
    getSummary(q).then(r => setS(r.data)).catch(e => setErr(e.message))
    getTrend(q, 'transaction_amount').then(r => setTrend(r.data)).catch(() => setTrend([]))
    const shop = f.shop || 'DY_DANDONG_OFFICIAL'
    api<SnapSummary>('/product-card/snapshot-summary', { shop_code: shop, start_date: f.sd, end_date: f.ed })
      .then(r => setSnap(r.data)).catch(() => setSnap(null))
    api<SnapRank[]>('/product-card/snapshot-rank', { shop_code: shop, start_date: f.sd, end_date: f.ed, metric_key: 'user_pay_amount', limit: 20 })
      .then(r => setRank(r.data)).catch(() => setRank([]))
  }, [f.sd, f.ed, f.scope, f.shop])
  return (
    <div>
      <h1>商品卡经营</h1>
      <div className="sub">{f.shopName} ｜ {f.sd} ～ {f.ed} ｜ 口径：商品卡（正式 Scope，非全店）</div>
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <>
          {s && (
            <div className="kpis" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(150px,1fr))', gap: 10, margin: '12px 0' }}>
              <MetricCard label="成交金额" value={s.transaction_amount} />
              <MetricCard label="用户支付金额" value={s.user_pay_amount} />
              <MetricCard label="退款率" value={s.refund_rate} opts={{ isRate: true, goodWhen: 'low' }} />
              <MetricCard label="结算金额" value={s.settlement_amount} />
              <MetricCard label="投放消耗" value={s.ad_spend_shop_bound} />
            </div>
          )}
          <div className="card"><h3>商品卡成交金额趋势</h3><TrendChart points={trend} /><div className="trend-note">数据粒度：日</div></div>
          <div className="card">
            <h3>商品卡快照（统计周期 {f.sd} ～ {f.ed}）<span className="badge green">PERIOD_SNAPSHOT</span></h3>
            {snap && (
              <div className="kpis" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(130px,1fr))', gap: 8, margin: '8px 0' }}>
                <div className="kpi"><div className="l">覆盖商品</div><div className="v">{snap.product_count}</div></div>
                <div className="kpi"><div className="l">曝光人数</div><div className="v">{yuan(snap.exposure_users)}</div></div>
                <div className="kpi"><div className="l">点击人数</div><div className="v">{yuan(snap.click_users)}</div></div>
                <div className="kpi"><div className="l">快照用户支付金额</div><div className="v">{yuan(snap.user_pay_amount)}</div></div>
                <div className="kpi"><div className="l">成交订单</div><div className="v">{snap.transaction_orders}</div></div>
              </div>
            )}
            <table>
              <thead><tr><th>#</th><th>商品</th><th className="num">用户支付金额</th></tr></thead>
              <tbody>
                {rank.map((x, i) => (
                  <tr key={i}><td>{i + 1}</td><td>{esc(x.product_title || x.product_id)}</td><td className="num">{yuan(x.current_value)}</td></tr>
                ))}
                {!rank.length && <tr><td colSpan={3} className="empty">当前周期无商品卡快照数据</td></tr>}
              </tbody>
            </table>
            <div className="trend-note">商品卡快照为统计周期导出（PERIOD_SNAPSHOT），不提供日趋势</div>
          </div>
          <CapabilityNotice state="SOURCE_NOT_AVAILABLE" text="流量来源分析：当前数据源未提供商品卡来源构成导出，暂不支持来源榜" />
        </>
      )}
    </div>
  )
}
