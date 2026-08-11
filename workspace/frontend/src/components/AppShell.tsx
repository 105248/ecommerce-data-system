// F1.1 V2.0 正式 App Shell：分组导航 / 经营进度为主入口 / 工具页跳转
import { useEffect, useRef, useState } from 'react'
import { PRESET_CN, SCOPE_LIST, type Filters, type PageMeta } from '../types'
import { api } from '../services/api'
import { esc } from '../lib/format'

// V2 分组导航（旧业务分析页 UI_HIDDEN，能力保留：数据库/mart/API/MCP 不删除）
type NavItem = [string, string]
type NavGroup = [string, NavItem[]]
export const NAV: NavGroup[] = [
  ['核心', [['/progress', '经营进度']]],
  ['业务分析', [['/product-lines', '品线'], ['/master-products', '标准商品'], ['/accounts', '达人/账号']]],
  ['决策', [['/attention', '待关注']]],
  ['管理', [['/targets', '目标管理']]],
  ['数据', [['/data-center', '数据中心'], ['/data-status', '数据状态'], ['/system-status', '系统状态']]],
  ['智能助手', [['/ask', '问数据']]],
]
export const FLAT_ROUTES: NavItem[] = NAV.flatMap(([, items]) => items)

// 整页跳转的工具页（独立 HTML，非 React SPA）
const EXTERNAL_PAGES = new Set(['/data-status', '/system-status'])

export const PAGE_META: Record<string, PageMeta> = {
  '/progress': { title: '经营进度', supportsShop: false, supportsScope: false, supportsDate: false },
  '/product-lines': { title: '品线', supportsShop: false, supportsScope: false },
  '/master-products': { title: '标准商品', supportsShop: false, supportsScope: false },
  '/accounts': { title: '达人 / 账号', supportsShop: true, supportsScope: false },
  '/attention': { title: '待关注', supportsShop: false, supportsScope: false, supportsDate: false },
  '/targets': { title: '目标管理', supportsShop: false, supportsScope: false, supportsDate: false },
  '/data-center': { title: '数据中心', supportsShop: false, supportsScope: false, supportsDate: false },
  '/ask': { title: '问数据', supportsShop: false, supportsScope: false, supportsDate: false },
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
  const monthEnd = () => fmtD(new Date(t.getFullYear(), t.getMonth() + 1, 0))
  const lastMonthEnd = () => fmtD(new Date(t.getFullYear(), t.getMonth(), 0))
  const lastMonthStart = () => `${t.getMonth() === 0 ? t.getFullYear() - 1 : t.getFullYear()}-${String(t.getMonth() === 0 ? 12 : t.getMonth()).padStart(2, '0')}-01`
  switch (key) {
    case 'today': return { sd: ed, ed }
    case 'yesterday': return { sd: add(1), ed: add(1) }
    case 'last7days': return { sd: add(6), ed }
    case 'last14days': return { sd: add(13), ed }
    case 'last30days': return { sd: add(29), ed }
    // F1.0.4-R3：月报=自然月（整月区间，数据覆盖到哪显示到哪），不随 MX 截断
    case 'this_month': return { sd: monthStart(), ed: monthEnd() }
    case 'last_month': return { sd: lastMonthStart(), ed: lastMonthEnd() }
    default: return { sd: add(6), ed }
  }
}

const DEFAULT_FILTERS: Filters = (() => {
  const p = applyPreset('last7days')
  return { shop: '', shopName: '抖音整体', sd: p.sd, ed: p.ed, scope: '全店', preset: 'last7days' }
})()

export function AppShell({ children }: { children: (f: Filters, h: { changePreset: (k: string) => void }) => React.ReactNode }) {
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

  function go(path: string) {
    // 数据状态/系统状态为独立工具页（非 React SPA），整页跳转
    if (EXTERNAL_PAGES.has(path)) { location.href = path; return }
    location.hash = '#' + path
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh' }}>
      <aside style={{ width: 190, background: '#1f2937', color: '#e5e7eb', padding: '16px 0', flexShrink: 0 }}>
        <div style={{ padding: '0 16px 16px', fontWeight: 600, fontSize: 15 }}>抖音经营<br />工作台</div>
        <nav>
          {NAV.map(([group, items]) => (
            <div key={group} style={{ marginBottom: 6 }}>
              <div style={{ padding: '8px 16px 4px', fontSize: 11, color: '#6b7280', letterSpacing: 1 }}>{group}</div>
              {items.map(([path, label]) => (
                <a key={path} href={EXTERNAL_PAGES.has(path) ? path : `#${path}`}
                  onClick={EXTERNAL_PAGES.has(path) ? undefined : e => { e.preventDefault(); go(path) }}
                  style={{ display: 'block', padding: '7px 16px 7px 22px', fontSize: 13, cursor: 'pointer',
                           color: route === path ? '#fff' : '#9ca3af', background: route === path ? '#374151' : 'transparent' }}>
                  {label}
                </a>
              ))}
            </div>
          ))}
        </nav>
      </aside>
      <main style={{ flex: 1, padding: 16, minWidth: 0 }}>
        {meta.supportsDate !== false && (
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
          {meta.supportsShop && (
            <>
              <span style={{ fontSize: 13, color: '#6b7280' }}>店铺</span>
              <select value={filters.shop} onChange={e => changeShop(e.target.value)}
                style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid #d1d5db' }}>
                {SHOP_OPTIONS.map(s => <option key={s.code} value={s.code}>{s.name}</option>)}
              </select>
            </>
          )}
          {meta.supportsScope && (
            <>
              <span style={{ fontSize: 13, color: '#6b7280' }}>口径</span>
              <select value={filters.scope} onChange={e => changeScope(e.target.value)}
                style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid #d1d5db' }}>
                {SCOPE_LIST.map(s => <option key={s} value={s}>{s}</option>)}
              </select>
            </>
          )}
        </div>
        )}
        <div style={{ background: '#f9fafb', border: '1px solid #e5e7eb', borderRadius: 8, padding: '8px 14px', marginBottom: 12, fontSize: 12, color: '#6b7280', display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          {meta.supportsDate !== false && <span>查询区间：{filters.sd} ～ {filters.ed}</span>}
          <span>系统最新入库数据：{esc(status.fact || '—')}</span>
          <span>店铺：{filters.shopName}｜口径：{filters.scope}</span>
        </div>
        <div id="page">{children({ ...filters, today }, { changePreset })}</div>
      </main>
    </div>
  )
}
