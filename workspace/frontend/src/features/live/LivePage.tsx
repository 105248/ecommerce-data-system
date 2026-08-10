// F1.0.4 /live 直播（渠道整体 + 场次 SESSION_FACT + 日数据 DAILY_FACT）
import { useEffect, useState } from 'react'
import type { Filters, BusinessSummary, TrendPoint } from '../types'
import { getSummary, getTrend, api } from '../services/api'
import { MetricCard } from '../components/MetricCard'
import { TrendChart } from '../components/TrendChart'
import { CapabilityNotice } from '../components/CapabilityNotice'
import { fmt, yuan, esc } from '../lib/format'

interface SessionRow { live_room_name: string; live_room_id: string; start_time: string; end_time: string; duration_minutes: number; account_type: string; creator_nickname: string; period_key: string }
interface DailyRow { biz_date: string | null; transaction_amount: number; ad_spend: number; net_roi: number; gpm: number }

export function LivePage({ f }: { f: Filters }) {
  const [s, setS] = useState<BusinessSummary | null>(null)
  const [trend, setTrend] = useState<TrendPoint[]>([])
  const [sessions, setSessions] = useState<SessionRow[]>([])
  const [daily, setDaily] = useState<DailyRow[]>([])
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    const q = { shop: f.shop, sd: f.sd, ed: f.ed, scope: '直播' }
    getSummary(q).then(r => setS(r.data)).catch(e => setErr(e.message))
    getTrend(q, 'transaction_amount').then(r => setTrend(r.data)).catch(() => setTrend([]))
    if (f.shop) {
      api<SessionRow[]>('/live/sessions', { shop_code: f.shop, limit: 100 }).then(r => setSessions(r.data)).catch(() => setSessions([]))
      api<DailyRow[]>('/live/daily', { shop_code: f.shop }).then(r => setDaily(r.data)).catch(() => setDaily([]))
    }
  }, [f.sd, f.ed, f.shop])
  return (
    <div>
      <h1>直播经营</h1>
      <div className="sub">{f.shopName} ｜ {f.sd} ～ {f.ed} ｜ 口径：直播（正式 Scope）+ 场次/日数据快照</div>
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
          <div className="card"><h3>直播成交金额趋势</h3><TrendChart points={trend} /><div className="trend-note">数据粒度：日</div></div>
          {f.shop && (
            <>
              {sessions.length > 0 && (
                <div className="card">
                  <h3>直播场次（{esc(sessions[0].period_key)}，SESSION_FACT）<span className="badge green">真实场次</span></h3>
                  <table>
                    <thead><tr><th>直播间</th><th>开始</th><th>结束</th><th className="num">时长(分)</th><th>账号类型</th><th>达人</th></tr></thead>
                    <tbody>
                      {sessions.slice(0, 30).map((x, i) => (
                        <tr key={i}>
                          <td>{esc(x.live_room_name || x.live_room_id)}</td><td>{esc(x.start_time)}</td><td>{esc(x.end_time)}</td>
                          <td className="num">{x.duration_minutes != null ? fmt(x.duration_minutes) : '—'}</td>
                          <td>{esc(x.account_type || '')}</td><td>{esc(x.creator_nickname || '')}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {sessions.length > 30 && <div className="trend-note">共 {sessions.length} 场（前 30 场展示）</div>}
                </div>
              )}
              {daily.length > 0 && (
                <div className="card">
                  <h3>直播日数据（DAILY_FACT）</h3>
                  <table>
                    <thead><tr><th>日期</th><th className="num">成交金额</th><th className="num">消耗</th><th className="num">净成交ROI</th><th className="num">GPM</th></tr></thead>
                    <tbody>
                      {daily.map((x, i) => (
                        <tr key={i}>
                          <td>{esc(x.biz_date || '周期汇总')}</td><td className="num">{yuan(x.transaction_amount)}</td>
                          <td className="num">{yuan(x.ad_spend)}</td><td className="num">{x.net_roi != null ? fmt(x.net_roi) : '—'}</td>
                          <td className="num">{x.gpm != null ? fmt(x.gpm) : '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </>
          )}
          <CapabilityNotice state="SOURCE_NOT_AVAILABLE" text="分钟级/时段级/直播商品级：当前源数据不支持，不推算" />
        </>
      )}
    </div>
  )
}
