// F1.0.4 正式 App Shell：路由 / 侧边栏 / 筛选器单一状态源 / 数据状态条
import { useEffect, useRef, useState } from 'react'
import { PRESET_CN, SCOPE_LIST, type Filters, type PageMeta } from '../types'
import { api } from '../services/api'
import { esc } from '../lib/format'

export const ROUTES: Array<[string, string]> = [
  ['/today', '今日经营'],
  ['/store', '店铺'],
  ['/priorities', '经营优先级'],
  ['/product-lines', '品线'],
  ['/master-products', 'Master Product'],
  ['/products', '商品'],
  ['/product-card', '商品卡'],
  ['/advertising', '投放'],
  ['/refunds', '退款'],
  ['/accounts', '达人/账号'],
  ['/live', '直播'],
  ['/videos', '短视频'],
  ['/search', '搜索'],
  ['/materials', '素材'],
  ['/smart-operation', '智能经营'],
  ['/risks', '风险中心'],
  ['/diagnostics', '问题诊断'],
  ['/opportunities', '增长机会'],
]

export const PAGE_META: Record<string, PageMeta> = {
  '/today': { title: '今日经营', supportsShop: true, supportsScope: true },
  '/store': { title: '店铺经营', supportsShop: false, supportsScope: true },
  '/priorities': { title: '经营优先级', supportsShop: false, supportsScope: false },
  '/product-lines': { title: '品线分析', supportsShop: false, supportsScope: false },
  '/master-products': { title: 'Master Product', supportsShop: false, supportsScope: false },
  '/products': { title: '商品分析', supportsShop: true, supportsScope: false },
  '/product-card': { title: '商品卡经营', supportsShop: true, supportsScope: true },
  '/advertising': { title: '投放经营', supportsShop: true, supportsScope: true },
  '/refunds': { title: '退款分析', supportsShop: true, supportsScope: true },
  '/accounts': { title: '达人 / 账号', supportsShop: true, supportsScope: false },
  '/live': { title: '直播经营', supportsShop: true, supportsScope: true },
  '/videos': { title: '短视频经营', supportsShop: true, supportsScope: true },
  '/search': { title: '搜索', supportsShop: false, supportsScope: false },
  '/materials': { title: '素材', supportsShop: true, supportsScope: false },
  '/smart-operation': { title: '智能经营', supportsShop: false, supportsScope: false },
  '/risks': { title: '风险中心', supportsShop: false, supportsScope: false },
  '/diagnostics': { title: '问题诊断', supportsShop: false, supportsScope: false },
  '/opportunities': { title: '增长机会', supportsShop: false, supportsScope: false },
}

export const SHOP_OPTIONS = [
  { code: '', name: '全部店铺' },
  { code: 'DY_DANDONG_OFFICIAL', name: '弹动官方旗舰店' },
  { code: 'DY_GERENHULI_OFFICIAL', name: '弹动个人护理旗舰店' },
]

function todayStr() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function applyPreset(key: string, baseStr?: string): { sd: string; ed: string } {
  // F1.0.4-R2：日期基准优先用系统最新业务数据日（data-status MX），未取到才回退电脑今天
  const t = baseStr ? new Date(baseStr) : new Date()
  const fmtD = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  const ed = fmtD(t)
  const add = (days: number) => { const d = new Date(t); d.setDate(d.getDate() - days); return fmtD(d) }
  const monthStart = () => `${t.getFullYear()}-${String(t.getMonth() + 1).padStart(2, '0')}-01`
  const lastMonthEnd = () => fmtD(new Date(t.getFullYear(), t.getMonth(), 0))
  const lastMonthStart = () => `${t.getMonth() === 0 ? t.getFullYear() - 1 : t.getFullYear()}-${String(t.getMonth() === 0 ? 12 : t.getMonth()).padStart(2, '0')}-01`
  switch (key) {
    case 'today': return { sd: ed, ed }
    case 'yesterday': return { sd: add(1), ed: add(1) }
    case 'last7days': return { sd: add(6), ed }
    case 'last14days': return { sd: add(13), ed }
    case 'last30days': return { sd: add(29), ed }
    case 'this_month': return { sd: monthStart(), ed }
    case 'last_month': return { sd: lastMonthStart(), ed: lastMonthEnd() }
    default: return { sd: add(6), ed }
  }
}

const DEFAULT_FILTERS: Filters = (() => {
  const p = applyPreset('last7days')
  return { shop: '', shopName: '抖音整体', sd: p.sd, ed: p.ed, scope: '全店', preset: 'last7days' }
})()

export function AppShell({ children }: { children: (f: Filters) => React.ReactNode }) {
  const [route, setRoute] = useState<string>(() => location.hash.slice(1) || '/today')
  const [filters, setFilters] = useState<Filters>(DEFAULT_FILTERS)
  const [status, setStatus] = useState<{ fact?: string }>({})
  const userTouched = useRef(false)
  const today = todayStr()

  useEffect(() => {
    const onHash = () => setRoute(location.hash.slice(1) || '/today')
    window.addEventListener('hashchange', onHash)
    api<Array<{ max_date: string }>>('/data-status').then(r => {
      const mx = r.data.map(x => x.max_date).sort().pop()
      if (mx) {
        setStatus({ fact: mx })
        // 用户未手动改过日期时，默认区间基于系统最新业务数据日而非电脑今天
        if (!userTouched.current) {
          const p = applyPreset('last7days', mx)
          setFilters(prev => ({ ...prev, sd: p.sd, ed: p.ed }))
        }
      }
    }).catch(() => {})
    return () => window.removeEventListener('hashchange', onHash)
  }, [])

  const meta = PAGE_META[route] || PAGE_META['/today']
  const f: Filters = filters

  function changeShop(code: string) {
    userTouched.current = true
    const name = SHOP_OPTIONS.find(s => s.code === code)?.name || '全部店铺'
    setFilters({ ...filters, shop: code, shopName: name })
  }

  function changePreset(key: string) {
    userTouched.current = true
    const { sd, ed } = applyPreset(key, status.fact)
    setFilters({ ...filters, preset: key, sd, ed })
  }

  function changeScope(scope: string) {
    userTouched.current = true
    setFilters({ ...filters, scope })
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh' }}>
      <aside style={{ width: 190, background: '#1f2937', color: '#e5e7eb', padding: '16px 0', flexShrink: 0 }}>
        <div style={{ padding: '0 16px 16px', fontWeight: 600, fontSize: 15 }}>抖音智能<br />经营工作台</div>
        <nav>
          {ROUTES.map(([path, label]) => (
            <a key={path} href={`#${path}`}
              style={{ display: 'block', padding: '8px 16px', fontSize: 13, color: route === path ? '#fff' : '#9ca3af', background: route === path ? '#374151' : 'transparent' }}>
              {label}
            </a>
          ))}
        </nav>
      </aside>
      <main style={{ flex: 1, padding: 16, minWidth: 0 }}>
        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'center', background: '#fff', padding: '10px 14px', borderRadius: 10, border: '1px solid #e5e7eb', marginBottom: 12 }}>
          <span style={{ fontSize: 13, color: '#6b7280' }}>日期范围</span>
          <select value={filters.preset} onChange={e => changePreset(e.target.value)} style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid #d1d5db' }}>
            {Object.entries(PRESET_CN).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
          <input type="date" value={filters.sd} onChange={e => { userTouched.current = true; setFilters({ ...filters, preset: 'custom', sd: e.target.value }) }}
            style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid #d1d5db' }} />
          <span style={{ color: '#6b7280' }}>～</span>
          <input type="date" value={filters.ed} onChange={e => { userTouched.current = true; setFilters({ ...filters, preset: 'custom', ed: e.target.value }) }}
            style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid #d1d5db' }} />
          <span style={{ fontSize: 13, color: '#6b7280' }}>店铺</span>
          <select value={filters.shop} onChange={e => changeShop(e.target.value)} disabled={!meta.supportsShop}
            style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid #d1d5db' }}>
            {SHOP_OPTIONS.map(s => <option key={s.code} value={s.code}>{s.name}</option>)}
          </select>
          {meta.supportsScope && (
            <>
              <span style={{ fontSize: 13, color: '#6b7280' }}>口径</span>
              <select value={filters.scope} onChange={e => changeScope(e.target.value)}
                style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid #d1d5db' }}>
                {SCOPE_LIST.map(s => <option key={s} value={s}>{s}</option>)}
              </select>
            </>
          )}
          {!meta.supportsShop && filters.shop && <span className="badge gray">店铺筛选不适用于当前页面</span>}
        </div>
        <div style={{ background: '#f9fafb', border: '1px solid #e5e7eb', borderRadius: 8, padding: '8px 14px', marginBottom: 12, fontSize: 12, color: '#6b7280', display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          <span>查询区间：{filters.sd} ～ {filters.ed}</span>
          <span>系统最新入库数据：{esc(status.fact || '—')}</span>
          <span>店铺：{filters.shopName}｜口径：{filters.scope}</span>
        </div>
        <div id="page">{children({ ...filters, today })}</div>
      </main>
    </div>
  )
}
