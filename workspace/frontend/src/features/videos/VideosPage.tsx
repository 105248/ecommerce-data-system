// F1.0.4 /videos 短视频（渠道整体 + 视频快照 PERIOD_SNAPSHOT）
import { useEffect, useState } from 'react'
import type { Filters, BusinessSummary, TrendPoint } from '../types'
import { getSummary, getTrend, api } from '../services/api'
import { MetricCard } from '../components/MetricCard'
import { TrendChart } from '../components/TrendChart'
import { CapabilityNotice } from '../components/CapabilityNotice'
import { yuan, esc } from '../lib/format'

interface VSnap { video_count: number; view_count: number; user_pay_amount: number; refund_amount: number; transaction_orders: number }
interface VRank { video_title: string; video_id: string; selling_type: string; carrier_type: string; current_value: number }

export function VideosPage({ f }: { f: Filters }) {
  const [s, setS] = useState<BusinessSummary | null>(null)
  const [trend, setTrend] = useState<TrendPoint[]>([])
  const [snap, setSnap] = useState<VSnap | null>(null)
  const [rank, setRank] = useState<VRank[]>([])
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    const q = { shop: f.shop, sd: f.sd, ed: f.ed, scope: '短视频' }
    getSummary(q).then(r => setS(r.data)).catch(e => setErr(e.message))
    getTrend(q, 'transaction_amount').then(r => setTrend(r.data)).catch(() => setTrend([]))
    if (f.shop) {
      api<VSnap>('/video/snapshot-summary', { shop_code: f.shop, start_date: f.sd, end_date: f.ed }).then(r => setSnap(r.data)).catch(() => setSnap(null))
      api<VRank[]>('/video/snapshot-rank', { shop_code: f.shop, start_date: f.sd, end_date: f.ed, metric_key: 'user_pay_amount', limit: 20 }).then(r => setRank(r.data)).catch(() => setRank([]))
    }
  }, [f.sd, f.ed, f.shop])
  return (
    <div>
      <h1>短视频经营</h1>
      <div className="sub">{f.shopName} ｜ {f.sd} ～ {f.ed} ｜ 口径：短视频（正式 Scope）</div>
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <>
          {s && (
            <div className="kpis" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(150px,1fr))', gap: 10, margin: '12px 0' }}>
              <MetricCard label="成交金额" value={s.transaction_amount} />
              <MetricCard label="用户支付金额" value={s.user_pay_amount} />
              <MetricCard label="退款率" value={s.refund_rate} opts={{ isRate: true, goodWhen: 'low' }} />
              <MetricCard label="投放消耗" value={s.ad_spend_shop_bound} />
            </div>
          )}
          <div className="card"><h3>短视频成交金额趋势</h3><TrendChart points={trend} /><div className="trend-note">数据粒度：日</div></div>
          {f.shop && (
            <div className="card">
              <h3>视频快照（周期 {f.sd} ～ {f.ed}）<span className="badge green">PERIOD_SNAPSHOT</span></h3>
              {snap && (
                <div className="kpis" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(130px,1fr))', gap: 8, margin: '8px 0' }}>
                  <div className="kpi"><div className="l">覆盖视频</div><div className="v">{snap.video_count}</div></div>
                  <div className="kpi"><div className="l">观看次数</div><div className="v">{yuan(snap.view_count)}</div></div>
                  <div className="kpi"><div className="l">视频用户支付金额</div><div className="v">{yuan(snap.user_pay_amount)}</div></div>
                  <div className="kpi"><div className="l">视频退款金额</div><div className="v">{yuan(snap.refund_amount)}</div></div>
                  <div className="kpi"><div className="l">成交订单</div><div className="v">{snap.transaction_orders}</div></div>
                </div>
              )}
              <table>
                <thead><tr><th>#</th><th>视频</th><th>类型</th><th className="num">用户支付金额</th></tr></thead>
                <tbody>
                  {rank.map((x, i) => (
                    <tr key={i}><td>{i + 1}</td><td>{esc(x.video_title || x.video_id)}</td><td>{esc((x.selling_type || '') + (x.carrier_type || ''))}</td><td className="num">{yuan(x.current_value)}</td></tr>
                  ))}
                  {!rank.length && <tr><td colSpan={4} className="empty">当前周期无视频快照</td></tr>}
                </tbody>
              </table>
              <div className="trend-note">视频快照为统计周期导出（PERIOD_SNAPSHOT），不按发布时间做日趋势</div>
            </div>
          )}
          <CapabilityNotice state="SOURCE_NOT_AVAILABLE" text="单视频日趋势/内容级拆解：源数据为区间快照，不伪装逐日内容趋势" />
        </>
      )}
    </div>
  )
}
