// F1.0.4 /store 店铺经营（两店贡献/环比，全消费正式字段）
import { useEffect, useState } from 'react'
import type { Filters, ShopContributionRow } from '../../types'
import { getShopContribution } from '../../services/api'
import { CapabilityNotice } from '../../components/CapabilityNotice'
import { yuan, pct, fmt, esc } from '../../lib/format'

export function StorePage({ f }: { f: Filters }) {
  const [shops, setShops] = useState<ShopContributionRow[]>([])
  const [err, setErr] = useState('')
  useEffect(() => {
    setErr('')
    getShopContribution({ sd: f.sd, ed: f.ed, scope: f.scope })
      .then(r => setShops(r.data.shops || [])).catch(e => setErr(e.message))
  }, [f.sd, f.ed, f.scope])
  return (
    <div>
      <h1>店铺经营</h1>
      <div className="sub">两店对比/贡献/环比 ｜ {f.sd} ～ {f.ed} ｜ {f.scope}（正式平台聚合）</div>
      {err ? <CapabilityNotice state="ERROR" text={err} /> : (
        <div className="card">
          <table>
            <thead><tr><th>店铺</th><th className="num">当前值</th><th className="num">上期</th><th className="num">贡献率</th><th className="num">绝对变化</th><th className="num">贡献变化</th></tr></thead>
            <tbody>
              {shops.map((x, i) => (
                <tr key={i}>
                  <td>{esc(x.shop_name)}</td>
                  <td className="num">{yuan(x.current_value)}</td>
                  <td className="num">{x.previous_value != null ? yuan(x.previous_value) : '—'}</td>
                  <td className="num">{pct(x.contribution)}</td>
                  <td className="num">{x.absolute_change != null ? fmt(x.absolute_change) : '—'}</td>
                  <td className="num">{x.contribution_change != null ? fmt(x.contribution_change) : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  )
}
