// F1.0.4-R3 /cycle 周期进度（日报/周报/月报同一模板结构，仅统计周期不同）
// 模板：抖音日报、周报数据模板 V1.0（无利润计算版）
//   3 张表（抖音整体 / 抖音弹动官方旗舰店 / 抖音弹动个人护理旗舰店）
//   每表 6 行（店铺整体/自营直播/自营商品/达人直播/达人短视频/橱窗）× 6 指标
//   指标：成交金额 / 成交退款金额 / 结算金额 / 退款率 / 投放消耗 / 投放费比
import { useEffect, useState } from 'react'
import type { Filters } from '../../types'
import { api } from '../../services/api'
import { CapabilityNotice } from '../../components/CapabilityNotice'
import { yuan, pct, esc } from '../../lib/format'

interface CycleRow {
  shop_display: string
  biz_type: string
  transaction_amount: number | null
  transaction_refund_amount: number | null
  settlement_amount: number | null
  refund_rate: number | null
  ad_spend_shop_bound: number | null
  ad_spend_rate: number | null
}

const SHOPS = ['抖音整体', '抖音弹动官方旗舰店', '抖音弹动个人护理旗舰店'] as const
const TABS: Array<[string, string, string]> = [
  ['today', '日报', '今天'],
  ['last7days', '周报', '近 7 天'],
  ['this_month', '月报', '本月'],
]

export function CycleProgressPage({ f, h }: { f: Filters; h: { changePreset: (k: string) => void } }) {
  const [rows, setRows] = useState<CycleRow[]>([])
  const [err, setErr] = useState('')
  const tab = f.preset === 'today' ? 'today' : f.preset === 'this_month' ? 'this_month' : 'last7days'

  useEffect(() => {
    setErr('')
    api<{ rows: CycleRow[] }>('/business/cycle-report', { start_date: f.sd, end_date: f.ed })
      .then(r => setRows(r.data.rows || [])).catch(e => setErr(e.message))
  }, [f.sd, f.ed])

  return (
    <div>
      <h1>周期进度</h1>
      <div className="sub">{f.sd} ～ {f.ed} ｜ 日报/周报/月报同一模板结构，仅统计周期不同（无利润计算）</div>
      <div style={{ display: 'flex', gap: 8, margin: '10px 0' }}>
        {TABS.map(([key, label, desc]) => (
          <button key={key} onClick={() => h.changePreset(key)}
            style={{ padding: '6px 14px', borderRadius: 8, border: '1px solid #d1d5db', cursor: 'pointer',
                     background: tab === key ? '#2563eb' : '#fff', color: tab === key ? '#fff' : '#374151', fontSize: 13 }}>
            {label}<span style={{ opacity: 0.75, marginLeft: 4 }}>{desc}</span>
          </button>
        ))}
      </div>
      {err ? <CapabilityNotice state="ERROR" text={err} /> : rows.length === 0 ? (
        <CapabilityNotice state="NO_DATA" text="当前区间无经营数据" />
      ) : (
        SHOPS.map(shop => {
          const shopRows = rows.filter(r => r.shop_display === shop)
          if (!shopRows.length) return null
          return (
            <div className="card" key={shop} style={{ marginBottom: 14 }}>
              <h3 style={{ fontSize: 15, marginBottom: 6 }}>{esc(shop)}</h3>
              <table>
                <thead>
                  <tr>
                    <th>经营类型</th>
                    <th className="num">成交金额</th>
                    <th className="num">成交退款金额</th>
                    <th className="num">结算金额</th>
                    <th className="num">退款率</th>
                    <th className="num">投放消耗</th>
                    <th className="num">投放费比</th>
                  </tr>
                </thead>
                <tbody>
                  {shopRows.map((r, i) => (
                    <tr key={i} style={r.biz_type === '店铺整体' ? { fontWeight: 600, background: '#f9fafb' } : undefined}>
                      <td>{esc(r.biz_type)}</td>
                      <td className="num">{yuan(r.transaction_amount)}</td>
                      <td className="num">{yuan(r.transaction_refund_amount)}</td>
                      <td className="num">{yuan(r.settlement_amount)}</td>
                      <td className="num">{r.refund_rate != null ? pct(r.refund_rate) : '—'}</td>
                      <td className="num">{yuan(r.ad_spend_shop_bound)}</td>
                      <td className="num">{r.ad_spend_rate != null ? pct(r.ad_spend_rate) : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        })
      )}
      <div className="trend-note" style={{ marginTop: 10 }}>
        字段口径：成交退款金额=成交退款金额（支付时间）；投放消耗=投放消耗（店铺被投）；投放费比=投放费比（剔除退款、店铺绑定）。
        经营类型归并：自营商品=自营短视频+自营商品卡+自营其他+自营图文；达人短视频=合作短视频+合作图文；橱窗=合作商品卡+合作其他。
      </div>
    </div>
  )
}
