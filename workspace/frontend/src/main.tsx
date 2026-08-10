// F1.0.4 正式前端入口：18 路由 → 独立 Page
import React from 'react'
import ReactDOM from 'react-dom/client'
import { AppShell } from './components/AppShell'
import { TodayPage } from './features/dashboard/TodayPage'
import { StorePage } from './features/store/StorePage'
import { PrioritiesPage } from './features/priorities/PrioritiesPage'
import { ProductLinesPage } from './features/product-lines/ProductLinesPage'
import { MasterProductsPage } from './features/master-products/MasterProductsPage'
import { ProductCardPage } from './features/product-card/ProductCardPage'
import { VideosPage } from './features/videos/VideosPage'
import { MaterialsPage } from './features/materials/MaterialsPage'
import { LivePage } from './features/live/LivePage'
import { ProductsPage, AdvertisingPage, RefundsPage, AccountsPage, RisksPage, OpportunitiesPage, DiagnosticsPage, SmartOperationPage, SearchPage } from './features/pages'
import type { Filters } from './types'

function Router({ f }: { f: Filters }) {
  const route = location.hash.slice(1) || '/today'
  switch (route) {
    case '/today': return <TodayPage f={f} />
    case '/store': return <StorePage f={f} />
    case '/priorities': return <PrioritiesPage f={f} />
    case '/product-lines': return <ProductLinesPage f={f} />
    case '/master-products': return <MasterProductsPage f={f} />
    case '/products': return <ProductsPage f={f} />
    case '/product-card': return <ProductCardPage f={f} />
    case '/advertising': return <AdvertisingPage f={f} />
    case '/refunds': return <RefundsPage f={f} />
    case '/accounts': return <AccountsPage f={f} />
    case '/live': return <LivePage f={f} />
    case '/videos': return <VideosPage f={f} />
    case '/search': return <SearchPage />
    case '/materials': return <MaterialsPage f={f} />
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
      {(f) => <Router f={f} />}
    </AppShell>
  </React.StrictMode>,
)
