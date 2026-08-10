// F1.0.4-R3 正式前端入口：核心页 + 周期进度 + 智能视图（业务分析页已按需求移除）
import React from 'react'
import ReactDOM from 'react-dom/client'
import { AppShell } from './components/AppShell'
import { TodayPage } from './features/dashboard/TodayPage'
import { CycleProgressPage } from './features/cycle/CycleProgressPage'
import { PrioritiesPage } from './features/priorities/PrioritiesPage'
import { ProductLinesPage } from './features/product-lines/ProductLinesPage'
import { MasterProductsPage } from './features/master-products/MasterProductsPage'
import { MaterialsPage } from './features/materials/MaterialsPage'
import { AccountsPage, RisksPage, OpportunitiesPage, DiagnosticsPage, SmartOperationPage, SearchPage } from './features/pages'
import type { Filters } from './types'

type Helpers = { changePreset: (k: string) => void }

function Router({ f, h }: { f: Filters; h: Helpers }) {
  const route = location.hash.slice(1) || '/today'
  switch (route) {
    case '/today': return <TodayPage f={f} />
    case '/cycle': return <CycleProgressPage f={f} h={h} />
    case '/priorities': return <PrioritiesPage f={f} />
    case '/product-lines': return <ProductLinesPage f={f} />
    case '/master-products': return <MasterProductsPage f={f} />
    case '/accounts': return <AccountsPage f={f} />
    case '/materials': return <MaterialsPage f={f} />
    case '/search': return <SearchPage />
    case '/smart-operation': return <SmartOperationPage f={f} />
    case '/risks': return <RisksPage f={f} />
    case '/diagnostics': return <DiagnosticsPage f={f} />
    case '/opportunities': return <OpportunitiesPage f={f} />
    default: return <TodayPage f={f} />
  }
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AppShell>
      {(f, h) => <Router f={f} h={h} />}
    </AppShell>
  </React.StrictMode>,
)
