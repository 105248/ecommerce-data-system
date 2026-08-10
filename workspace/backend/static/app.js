// ============================================================================
// F1.0 抖音智能经营工作台 SPA（全页面业务化整改版）
// 架构：公共 AppShell（Sidebar/GlobalFilters/StatusBar）+ 18 个独立业务路由
// 数据路径：Web → Backend API → 正式数据库接口（mart/meta 白名单），前端零经营计算
// ============================================================================
const $ = s => document.querySelector(s);
const fmt = n => n == null ? '—' : Number(n).toLocaleString('zh-CN', {maximumFractionDigits: 2});
const pct = n => n == null ? '—' : (Number(n) * 100).toFixed(2) + '%';
const yuan = n => n == null ? '—' : '¥' + fmt(n);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const iso = d => d.toISOString().slice(0,10);
const addDay = (dt, n) => { const x = new Date(dt + 'T00:00:00'); x.setDate(x.getDate() + n); return iso(x); };
const prevMonth = mx => { const d = new Date(mx + 'T00:00:00'); const p = new Date(d.getFullYear(), d.getMonth()-1, 1); const pe = new Date(d.getFullYear(), d.getMonth(), 0); return [iso(p), iso(pe)]; };

// ============================================================================
// 全局状态（Single Source of Truth）
// 日期只允许一种状态：preset ∈ {today,yesterday,last7days,last14days,last30days,this_month,last_month,custom}
// preset 与 sd/ed 永远一致：改 preset → 重算 sd/ed；改 sd/ed → preset 自动转 custom
// ============================================================================
let MX = null; // 系统最新入库日期（来自 /data-status，独立于查询区间）
const PRESET_CN = {today:'今天', yesterday:'昨天', last7days:'近7天', last14days:'近14天', last30days:'近30天', this_month:'本月', last_month:'上月', custom:'自定义'};
const G = {
  shop: localStorage.getItem('g.shop') || '',
  scope: localStorage.getItem('g.scope') || '全店',
  page: location.hash.slice(1) || '/today',
  preset: 'custom',
  sd: localStorage.getItem('g.sd') || '',
  ed: localStorage.getItem('g.ed') || '',
};
function saveG(){ ['shop','scope','sd','ed'].forEach(k=>localStorage.setItem('g.'+k, G[k])); G.preset = derivePreset(G.sd, G.ed); }

function applyPreset(preset){
  if (!MX) return;
  if (preset === 'today')       { G.sd = MX; G.ed = MX; }
  else if (preset === 'yesterday') { const y = addDay(MX,-1); G.sd = y; G.ed = y; }
  else if (preset === 'last7days') { G.sd = addDay(MX,-6); G.ed = MX; }
  else if (preset === 'last14days'){ G.sd = addDay(MX,-13); G.ed = MX; }
  else if (preset === 'last30days'){ G.sd = addDay(MX,-29); G.ed = MX; }
  else if (preset === 'this_month'){ G.sd = MX.slice(0,8) + '01'; G.ed = MX; }
  else if (preset === 'last_month'){ const pm = prevMonth(MX); G.sd = pm[0]; G.ed = pm[1]; }
  G.preset = preset;
}
function derivePreset(sd, ed){
  if (!MX || !sd || !ed) return 'custom';
  if (sd === ed && sd === MX) return 'today';
  if (sd === ed && ed === addDay(MX,-1)) return 'yesterday';
  if (sd === addDay(MX,-6) && ed === MX) return 'last7days';
  if (sd === addDay(MX,-13) && ed === MX) return 'last14days';
  if (sd === addDay(MX,-29) && ed === MX) return 'last30days';
  if (sd === MX.slice(0,8)+'01' && ed === MX) return 'this_month';
  const pm = prevMonth(MX);
  if (sd === pm[0] && ed === pm[1]) return 'last_month';
  return 'custom';
}

// ============================================================================
// 菜单（业务路由；/smart-operation 为新智能经营总入口）
// ============================================================================
const MENU = [
  ['g0','核心',''], ['/today','今日经营'], ['/store','店铺'], ['/priorities','经营优先级'],
  ['g1','业务分析',''], ['/product-lines','品线'], ['/master-products','Master Product'], ['/products','商品'],
  ['/product-card','商品卡'], ['/advertising','投放'], ['/refund','退款'], ['/accounts','达人/账号'],
  ['/live','直播'], ['/video','短视频'], ['/search','搜索'], ['/materials','素材'],
  ['g2','决策层',''], ['/smart-operation','智能经营'], ['/risks','风险中心'], ['/diagnosis','问题诊断'], ['/opportunities','增长机会'],
  ['g3','平台',''], ['/data-center','数据中心'], ['/system-status','系统状态'], ['/data-status','数据状态'],
];

// ============================================================================
// Filter Capability Matrix：每个页面独立声明支持哪些筛选
// supports_shop / supports_date / supports_scope（平台固定 douyin 全站显示）
// ============================================================================
const PAGE_META = {
  '/today':           {title:'经营概览', supports_shop:true,  supports_scope:true},
  '/store':           {title:'店铺经营', supports_shop:false, supports_scope:true},
  '/priorities':      {title:'经营优先级', supports_shop:false, supports_scope:false},
  '/product-lines':   {title:'品线分析', supports_shop:false, supports_scope:false},
  '/master-products': {title:'Master Product', supports_shop:false, supports_scope:false},
  '/products':        {title:'商品分析', supports_shop:true,  supports_scope:false},
  '/product-card':    {title:'商品卡经营', supports_shop:true, supports_scope:false},
  '/advertising':     {title:'投放经营', supports_shop:true,  supports_scope:true},
  '/refund':          {title:'退款分析', supports_shop:true,  supports_scope:true},
  '/accounts':        {title:'达人 / 账号', supports_shop:false, supports_scope:false},
  '/live':            {title:'直播经营', supports_shop:true,  supports_scope:false},
  '/video':           {title:'短视频经营', supports_shop:true, supports_scope:false},
  '/search':          {title:'搜索', supports_shop:false, supports_scope:false},
  '/materials':       {title:'素材', supports_shop:false, supports_scope:false},
  '/smart-operation': {title:'智能经营', supports_shop:false, supports_scope:false},
  '/risks':           {title:'风险中心', supports_shop:false, supports_scope:false},
  '/diagnosis':       {title:'问题诊断', supports_shop:true,  supports_scope:false},
  '/opportunities':   {title:'增长机会', supports_shop:false, supports_scope:false},
  '/data-center':     {title:'数据中心', supports_shop:false, supports_scope:false},
  '/system-status':   {title:'系统状态', supports_shop:false, supports_scope:false},
  '/data-status':     {title:'数据状态', supports_shop:false, supports_scope:false},
};
const SCOPES = ['全店','自营','合作','商品卡','直播','短视频','图文','其他','自营直播','合作直播','自营短视频','合作短视频','自营商品卡','合作商品卡','自营图文','合作图文','自营其他','合作其他'];
const SHOP_NAMES = {DY_DANDONG_OFFICIAL:'弹动官方旗舰店', DY_GERENHULI_OFFICIAL:'弹动个人护理旗舰店'};

async function api(path, params){
  const q = params ? '?' + new URLSearchParams(params) : '';
  const r = await fetch('/api/v1' + path + q);
  const j = await r.json();
  if (!j.success) { const e = new Error(j.error?.message || j.error?.code); e.code = j.error?.code; throw e; }
  return j;
}

// ============================================================================
// 共享组件（共享 UI 组件 ≠ 共享业务查询）
// ============================================================================
// goodWhen: 'high' 涨=好绿跌=坏红；'low'（退款率/费比等）跌=好绿涨=坏红
function MetricCard(label, cur, prev, opts){
  opts = opts || {};
  const v = opts.isRate ? pct(cur) : yuan(cur);
  if (prev == null || cur == null) return `<div class="kpi"><div class="l">${label}</div><div class="v">${v}</div></div>`;
  const d = cur - prev;
  const up = d > (opts.isRate ? 0.0001 : 0.0001), dn = d < -(opts.isRate ? 0.0001 : 0.0001);
  const good = opts.goodWhen === 'low' ? dn : up;   // 低优指标下跌=好
  const cls = up || dn ? (good ? 'good' : 'bad') : 'flat';
  const txt = opts.isRate ? (d >= 0 ? '+' : '') + (d*100).toFixed(2) + ' pp' : (d >= 0 ? '+' : '') + fmt(d);
  return `<div class="kpi"><div class="l">${label}</div><div class="v">${v}</div><div class="c ${cls}">较上期 ${txt}</div></div>`;
}
function covBadge(meta){
  // Coverage 真实绑定：有值才显示；无则显示"Coverage 暂不可用"
  if (!meta) return '';
  if (meta.coverage_days == null || meta.expected_days == null)
    return `<span class="badge gray">Coverage 暂不可用</span>`;
  const ok = !!meta.coverage_complete;
  const cls = ok ? 'green' : 'amber';
  const label = ok ? '覆盖完整' : '覆盖不完整';
  return `<span class="badge ${cls}">${label} ${meta.coverage_days}/${meta.expected_days}天</span>`;
}
function StateNotice(state, text){
  if (state === 'NOT_READY') return `<div class="notice amber"><b>NOT_READY</b> ｜ ${esc(text)}</div>`;
  if (state === 'NO_DATA')   return `<div class="empty">${esc(text)}（当前区间无数据）</div>`;
  return `<div class="err">${esc(text)}</div>`;
}
// 统一错误渲染：NO_DATA（接口存在、查询合法、区间无数据）→ 空态；其余 → 错误
function errBlock(e, emptyText, colspan){
  if (e.code === 'NO_DATA') return `<tr><td colspan="${colspan||4}" class="empty">${emptyText||'当前区间无数据'}</td></tr>`;
  return `<div class="err">${esc(e.message)}</div>`;
}
function TrendSvg(points, field, w, h){
  w = w || 560; h = h || 130;
  const vals = (points||[]).map(p => p[field]).filter(v => v != null);
  if (!vals.length) return `<div class="empty">当前区间无${field}数据</div>`;
  const mx = Math.max(...vals), mn = Math.min(...vals);
  const px = i => i/(vals.length-1||1)*(w-20)+10, py = v => h-20-(v-mn)/(mx-mn||1)*(h-40);
  const poly = points.filter(p=>p[field]!=null).map((p,i)=>px(i)+','+py(Number(p[field]))).join(' ');
  const dots = points.filter(p=>p[field]!=null).map((p,i)=>`<circle cx="${px(i)}" cy="${py(Number(p[field]))}" r="2.5" fill="#2563eb"><title>${p.date}：${fmt(p[field])}</title></circle>`).join('');
  return `<svg viewBox="0 0 ${w} ${h}" style="width:100%;max-height:170px"><polyline points="${poly}" fill="none" stroke="#2563eb" stroke-width="2"/><line x1="10" y1="${h-20}" x2="${w-10}" y2="${h-20}" stroke="#e5e7eb"/>${dots}</svg>
    <div class="trend-note">数据粒度：日 ｜ 来源：经营数据库（mart 白名单）｜ 悬停数据点查看当日数值</div>`;
}

// ============================================================================
// 页面渲染（18 个业务路由各自独立：独立 API、独立业务参数、独立空态）
// ============================================================================
const PAGES = {

  // ---- /today 经营驾驶舱：唯一允许"今日经营"标题的页面（标题随查询区间变化）----
  '/today': async (f)=>{
    const q = {start_date:f.sd, end_date:f.ed, scope_key:f.scope};
    if (f.shop) q.shop_code = f.shop;
    // 标题语义：单日=今日经营/单日经营；多日=经营概览
    const isOneDay = f.sd === f.ed;
    const title = isOneDay ? (f.sd === MX ? '今日经营' : '单日经营') : '经营概览';
    const subDate = isOneDay ? f.sd : `${f.sd} ～ ${f.ed}`;
    let html = `<h1>${title}</h1><div class="sub">${f.shop_name||'抖音整体'} ｜ ${subDate} ｜ ${f.scope}</div>`;
    try {
      const cur = await api('/business/summary', q);
      const c = cur.data;
      let pv = {}, pvr = null;
      try { pv = (await api('/business/compare', {...q, metric_key:'user_pay_amount'})).data; } catch(e){}
      try { pvr = (await api('/business/compare', {...q, metric_key:'refund_rate_pay_time'})).data.previous_value; } catch(e){}
      html += `<div class="kpis">` +
        MetricCard('成交金额', c.transaction_amount, null) +
        MetricCard('用户支付金额', c.user_pay_amount, pv.previous_value) +
        MetricCard('成交退款金额', c.refund_amount_pay_time, null) +
        MetricCard('结算金额', c.settlement_amount, null) +
        MetricCard('退款率', c.refund_rate, pvr, {isRate:true, goodWhen:'low'}) +
        MetricCard('投放消耗', c.ad_spend_shop_bound, null) +
        MetricCard('投放费比', c.ad_spend_rate_net_refund_shop_bound, null, {isRate:true, goodWhen:'low'}) +
        `</div>`;
      html += `<div class="card"><h3>成交金额趋势 ${covBadge(cur.meta)}</h3>`;
      try {
        const trend = await api('/business/trend', q);
        html += TrendSvg(trend.data, 'user_pay_amount');
      } catch(e){ html += `<div class="err">趋势加载失败：${esc(e.message)}</div>`; }
      html += `</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    // 风险/机会 TOP5 + 店铺贡献（首页摘要，完整列表在各独立页面）
    html += `<div class="grid2">`;
    try {
      const r = await api('/priorities/risks', {start_date:f.sd, end_date:f.ed, limit:5});
      html += `<div class="card"><h3>风险 TOP5 <span class="badge red">V1.1</span></h3><table><tr><th>对象</th><th>级别</th><th>得分</th><th>影响</th></tr>` +
        (r.data.length ? r.data.map(x=>`<tr><td><a href="#/risks">${esc(x.entity_name)}</a></td><td><span class="badge red">${esc(x.risk_level)}</span></td><td class="num">${fmt(x.risk_priority_score)}</td><td class="num">${yuan(x.business_impact)}</td></tr>`).join('') : `<tr><td colspan="4" class="empty">当前区间无风险</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>风险 TOP5</h3>${errBlock(e, '当前区间无风险（V1.1 检测未覆盖新月份数据）', 4)}</div>`; }
    try {
      const o = await api('/priorities/opportunities', {start_date:f.sd, end_date:f.ed, limit:5});
      html += `<div class="card"><h3>机会 TOP5 <span class="badge green">V1.1</span></h3><table><tr><th>对象</th><th>级别</th><th>得分</th><th>机会分</th></tr>` +
        (o.data.length ? o.data.map(x=>`<tr><td><a href="#/opportunities">${esc(x.entity_name)}</a></td><td><span class="badge green">${esc(x.opportunity_level)}</span></td><td class="num">${fmt(x.opportunity_priority_score)}</td><td class="num">${fmt(x.opportunity_score)}</td></tr>`).join('') : `<tr><td colspan="4" class="empty">当前区间无机会</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>机会 TOP5</h3>${errBlock(e, '当前区间无机会（V1.1 检测未覆盖新月份数据）', 4)}</div>`; }
    html += `</div>`;
    try {
      const sc = await api('/business/shop-contribution', {start_date:f.sd, end_date:f.ed, scope_key:f.scope});
      html += `<div class="card"><h3>店铺贡献（抖音整体）</h3><table><tr><th>店铺</th><th>当前值</th><th>贡献率</th><th>上期</th><th>贡献环比</th></tr>` +
        sc.data.shops.map(x=>`<tr><td>${esc(x.shop_name)}</td><td class="num">${yuan(x.current_value)}</td><td class="num">${pct(x.contribution)}</td><td class="num">${yuan(x.previous_value)}</td><td class="num">${x.contribution_change==null?'—':((x.contribution_change>=0?'+':'')+(x.contribution_change*100).toFixed(2)+' pp')}</td></tr>`).join('') + `</table></div>`;
    } catch(e){}
    return html;
  },

  // ---- /store 店铺经营：对比表 + 贡献 + 环比（前端不 SUM，全部来自正式接口）----
  '/store': async (f)=>{
    let html = `<h1>店铺经营</h1><div class="sub">${f.sd} ～ ${f.ed} ｜ ${f.scope} ｜ 平台整体 + 两店拆解（正式跨店聚合）</div>`;
    const shops = [['','抖音整体'],['DY_DANDONG_OFFICIAL','弹动官方旗舰店'],['DY_GERENHULI_OFFICIAL','弹动个人护理旗舰店']];
    const rows = [];
    try {
      for (const [code, name] of shops){
        const params = {start_date:f.sd, end_date:f.ed, scope_key:f.scope};
        if (code) params.shop_code = code;
        const r = await api('/business/summary', params);
        rows.push({name, ...r.data});
      }
      html += `<div class="card"><table><tr><th>店铺</th><th>成交金额</th><th>结算金额</th><th>退款率</th><th>投放消耗</th><th>投放费比</th></tr>` +
        rows.map(x=>`<tr><td><b>${esc(x.name)}</b></td><td class="num">${yuan(x.transaction_amount)}</td><td class="num">${yuan(x.settlement_amount)}</td><td class="num">${pct(x.refund_rate)}</td><td class="num">${yuan(x.ad_spend_shop_bound)}</td><td class="num">${pct(x.ad_spend_rate_net_refund_shop_bound)}</td></tr>`).join('') + `</table></div>`;
      const sc = await api('/business/shop-contribution', {start_date:f.sd, end_date:f.ed, scope_key:f.scope});
      html += `<div class="card"><h3>店铺贡献与环比</h3><table><tr><th>店铺</th><th>当前值</th><th>上期</th><th>贡献率</th><th>贡献环比</th></tr>` +
        sc.data.shops.map(x=>`<tr><td>${esc(x.shop_name)}</td><td class="num">${yuan(x.current_value)}</td><td class="num">${yuan(x.previous_value)}</td><td class="num">${pct(x.contribution)}</td><td class="num">${x.contribution_change==null?'—':((x.contribution_change>=0?'+':'')+(x.contribution_change*100).toFixed(2)+' pp')}</td></tr>`).join('') + `</table></div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /priorities 经营优先级：主体是 Priority/Action，非通用 KPI ----
  '/priorities': async (f)=>{
    let html = `<h1>经营优先级</h1><div class="sub">${f.sd} ～ ${f.ed} ｜ 今天最应该做什么（V1.1 Priority，前端不重排）</div><div class="grid2">`;
    try {
      const r = await api('/priorities/risks', {start_date:f.sd, end_date:f.ed, limit:10});
      html += `<div class="card"><h3>风险优先级 <span class="badge red">V1.1</span></h3><table><tr><th>对象</th><th>级别</th><th>得分</th><th>影响金额</th></tr>` +
        (r.data.length ? r.data.map(x=>`<tr><td><a href="#/risks">${esc(x.entity_name)}</a></td><td><span class="badge red">${esc(x.risk_level)}</span></td><td class="num">${fmt(x.risk_priority_score)}</td><td class="num">${yuan(x.business_impact)}</td></tr>`).join('') : `<tr><td colspan="4" class="empty">当前区间无风险优先级</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>风险优先级</h3>${errBlock(e, '当前区间无风险优先级（V1.1 检测未覆盖新月份）', 4)}</div>`; }
    try {
      const o = await api('/priorities/opportunities', {start_date:f.sd, end_date:f.ed, limit:10});
      html += `<div class="card"><h3>机会优先级 <span class="badge green">V1.1</span></h3><table><tr><th>对象</th><th>级别</th><th>得分</th><th>机会分</th></tr>` +
        (o.data.length ? o.data.map(x=>`<tr><td><a href="#/opportunities">${esc(x.entity_name)}</a></td><td><span class="badge green">${esc(x.opportunity_level)}</span></td><td class="num">${fmt(x.opportunity_priority_score)}</td><td class="num">${fmt(x.opportunity_score)}</td></tr>`).join('') : `<tr><td colspan="4" class="empty">当前区间无机会优先级</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>机会优先级</h3>${errBlock(e, '当前区间无机会优先级（V1.1 检测未覆盖新月份）', 4)}</div>`; }
    html += `</div>`;
    try {
      const w = await api('/priorities/watchlist', {start_date:f.sd, end_date:f.ed, limit:10});
      html += `<div class="card"><h3>今日行动 / Watchlist</h3><table><tr><th>对象</th><th>类型</th><th>状态</th></tr>` +
        (w.data.length ? w.data.map(x=>`<tr><td>${esc(x.entity_name)}</td><td>${esc(x.item_type||'')}</td><td><span class="badge amber">WATCH</span></td></tr>`).join('') : `<tr><td colspan="3" class="empty">当前区间无观察项</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>今日行动</h3>${errBlock(e, '当前区间无观察项（V1.1 检测未覆盖新月份）', 3)}</div>`; }
    return html;
  },

  // ---- /product-lines 品线：品线结构 + 成员（经营汇总为正式能力缺口）----
  '/product-lines': async (f)=>{
    try {
      const pl = await api('/master-data/product-lines');
      let html = `<h1>品线分析</h1><div class="sub">Product Line → Master Product → 店铺商品（正式跨店聚合，仅 CONFIRMED）</div>`;
      html += `<div class="notice">品线经营汇总（成交/退款/趋势）在正式接口白名单中尚未提供 → <b>NOT_READY</b>；当前展示品线结构与成员。</div>`;
      for (const line of pl.data){
        const members = await api('/master-data/product-line-members', {product_line_code: line.product_line_code});
        html += `<div class="card"><h3>${esc(line.product_line_name)} <span class="badge blue">${esc(line.product_line_code)}</span> <span class="badge gray">${members.data.length} 个 Master Product</span></h3>` +
          `<table><tr><th>Master Product</th><th>编码</th><th>状态</th></tr>` +
          (members.data.length ? members.data.map(m=>`<tr><td><a href="#/master-products">${esc(m.master_product_name)}</a></td><td>${esc(m.master_product_code)}</td><td><span class="badge ${m.enabled?'green':'gray'}">${m.enabled?'启用':'停用'}</span></td></tr>`).join('') : `<tr><td colspan="3" class="empty">暂无成员</td></tr>`) + `</table></div>`;
      }
      return html;
    } catch(e){ return `<h1>品线分析</h1><div class="err">${esc(e.message)}</div>`; }
  },

  // ---- /master-products Master Product：主档列表 + 映射状态（经营排名 NOT_READY）----
  '/master-products': async (f)=>{
    try {
      const r = await api('/master-data/products', {page_size:100});
      const list = r.data || [];
      const mapped = list.filter(m=>m.master_product_code).length;
      let html = `<h1>Master Product</h1><div class="sub">公司商品主档（跨店统一主商品；CONFIRMED 映射进入正式跨店汇总）</div>`;
      html += `<div class="notice">Master Product 经营排名/跨店拆解在正式接口白名单中尚未提供 → <b>NOT_READY</b>；当前展示主档结构与映射状态。</div>`;
      html += `<div class="card"><table><tr><th>编码</th><th>名称</th><th>状态</th></tr>` +
        (list.length ? list.map(m=>`<tr><td>${esc(m.master_product_code||'—')}</td><td>${esc(m.master_product_name||'—')}</td><td><span class="badge ${m.enabled?'green':'gray'}">${m.enabled?'启用':'停用'}</span></td></tr>`).join('') : `<tr><td colspan="3" class="empty">暂无主档数据</td></tr>`) + `</table></div>`;
      return html;
    } catch(e){ return `<h1>Master Product</h1><div class="err">${esc(e.message)}</div>`; }
  },

  // ---- /products 商品：平台商品排名（正式 rank_products）----
  '/products': async (f)=>{
    const shop = f.shop || 'DY_DANDONG_OFFICIAL';
    const shopName = f.shop ? f.shop_name : '弹动官方旗舰店';
    try {
      const r = await api('/business/products/top', {shop_code:shop, start_date:f.sd, end_date:f.ed, limit:50});
      let html = `<h1>商品分析</h1><div class="sub">${shopName} ｜ ${f.sd} ～ ${f.ed} ｜ 按用户支付金额排序（正式 mart 排名）</div>`;
      html += `<div class="notice">商品退款/结算/投放列为正式接口未覆盖指标 → 不补造。</div>`;
      html += `<div class="card"><table><tr><th>#</th><th>商品</th><th>成交金额</th></tr>` +
        (r.data.length ? r.data.map((x,i)=>`<tr><td>${i+1}</td><td>${esc(x.product_name||x.shop_product_name)}</td><td class="num">${yuan(x.current_value)}</td></tr>`).join('') : `<tr><td colspan="3" class="empty">当前区间无商品数据</td></tr>`) + `</table></div>`;
      return html;
    } catch(e){ return `<h1>商品分析</h1><div class="err">${esc(e.message)}</div>`; }
  },

  // ---- /product-card 商品卡：scope=商品卡 正式口径（非全店经营）----
  '/product-card': async (f)=>{
    const params = {start_date:f.sd, end_date:f.ed, scope_key:'商品卡'};
    if (f.shop) params.shop_code = f.shop;
    let html = `<h1>商品卡经营</h1><div class="sub">${f.shop_name||'抖音整体'} ｜ ${f.sd} ～ ${f.ed} ｜ 口径：商品卡（正式 Scope，非全店）</div>`;
    try {
      const s = await api('/business/summary', params);
      html += `<div class="kpis">` +
        MetricCard('商品卡成交金额', s.data.user_pay_amount, null) +
        MetricCard('商品卡退款率', s.data.refund_rate, null, {isRate:true, goodWhen:'low'}) +
        MetricCard('商品卡结算金额', s.data.settlement_amount, null) +
        MetricCard('商品卡投放消耗', s.data.ad_spend_shop_bound, null) + `</div>`;
      html += `<div class="card"><h3>商品卡成交金额趋势 ${covBadge(s.meta)}</h3>`;
      try { const t = await api('/business/trend', params); html += TrendSvg(t.data, 'user_pay_amount'); }
      catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
      html += `</div>`;
      html += `<div class="notice">商品卡来源构成（曝光/点击/转化分解）正式接口未提供 → <b>NOT_READY</b>。</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /advertising 投放：正式广告口径，费比直接消费 mart 结果（广告摘要按店铺维度提供）----
  '/advertising': async (f)=>{
    const shop = f.shop || 'DY_DANDONG_OFFICIAL';
    const shopName = f.shop ? f.shop_name : '弹动官方旗舰店（整体模式下投放按官方店）';
    const params = {shop_code:shop, start_date:f.sd, end_date:f.ed, scope_key:f.scope};
    let html = `<h1>投放经营</h1><div class="sub">${shopName} ｜ ${f.sd} ～ ${f.ed} ｜ ${f.scope} ｜ 费比/效率全部来自正式 mart 口径</div>`;
    try {
      const s = await api('/advertising/summary', params);
      const m = s.data || {};
      html += `<div class="kpis">` +
        MetricCard('投放消耗(店铺被投)', m.ad_spend_shop_promoted, null) +
        MetricCard('投放消耗(店铺绑定)', m.ad_spend_shop_bound, null) +
        MetricCard('投放贡献成交', m.ad_attributed_transaction_amount, null) +
        MetricCard('投放贡献占比', m.ad_attributed_transaction_share, null, {isRate:true}) +
        MetricCard('投放费比', m.ad_spend_rate_net_refund_shop_bound, null, {isRate:true, goodWhen:'low'}) +
        MetricCard('综合费比', m.total_expense_rate_net_refund_shop_bound, null, {isRate:true, goodWhen:'low'}) +
        MetricCard('投放效率', m.ad_efficiency_shop_bound, null) +
        MetricCard('全店效率', m.store_efficiency_shop_bound, null) + `</div>`;
      html += `<div class="card"><h3>投放消耗趋势</h3>`;
      try { const t = await api('/business/trend', params); html += TrendSvg(t.data, 'ad_spend_shop_bound'); }
      catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
      html += `</div>`;
      html += `<div class="notice">计划/单元/预算级投放明细未接入 → <b>KNOWN LIMITATION</b>（不补造）。</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /refund 退款：退款聚焦（金额/率/趋势/两店对比），原因分析 NOT_READY ----
  '/refund': async (f)=>{
    const q = {start_date:f.sd, end_date:f.ed, scope_key:f.scope};
    if (f.shop) q.shop_code = f.shop;
    let html = `<h1>退款分析</h1><div class="sub">${f.shop_name||'抖音整体'} ｜ ${f.sd} ～ ${f.ed} ｜ ${f.scope}</div>`;
    try {
      const s = await api('/business/summary', q);
      html += `<div class="kpis">` +
        MetricCard('成交退款金额', s.data.refund_amount_pay_time, null) +
        MetricCard('退款率', s.data.refund_rate, null, {isRate:true, goodWhen:'low'}) +
        MetricCard('成交金额', s.data.user_pay_amount, null) + `</div>`;
      html += `<div class="card"><h3>退款率趋势（低优指标，上涨为风险）</h3>`;
      try { const t = await api('/business/trend', q); html += TrendSvg(t.data, 'refund_rate_pay_time'); }
      catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
      html += `</div>`;
      // 两店退款对比（正式接口）
      html += `<div class="card"><h3>两店退款对比</h3><table><tr><th>店铺</th><th>退款金额</th><th>退款率</th><th>成交金额</th></tr>`;
      for (const [code,name] of [['DY_DANDONG_OFFICIAL','弹动官方旗舰店'],['DY_GERENHULI_OFFICIAL','弹动个人护理旗舰店']]){
        try {
          const r = await api('/business/summary', {shop_code:code, start_date:f.sd, end_date:f.ed, scope_key:f.scope});
          html += `<tr><td>${name}</td><td class="num">${yuan(r.data.refund_amount_pay_time)}</td><td class="num">${pct(r.data.refund_rate)}</td><td class="num">${yuan(r.data.user_pay_amount)}</td></tr>`;
        } catch(e){ html += `<tr><td>${name}</td><td colspan="3" class="empty">无数据</td></tr>`; }
      }
      html += `</table></div>`;
      html += `<div class="notice">退款原因/售后原因数据源尚未接入 → <b>NOT_READY</b>（不制造"退款原因分析"假页面）。</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /accounts 达人/账号：正式接口缺口，NOT_READY（不占位首页数据）----
  '/accounts': async (f)=>{
    return `<h1>达人 / 账号</h1>` +
      StateNotice('NOT_READY', '账号维度明细数据已在数据库（core.douyin_account_daily），但 F1.0 正式接口白名单未暴露账号级查询 API（F1.5 计划）。为避免用全店数据冒充，本页不展示经营摘要。');
  },

  // ---- /live 直播：scope=直播 正式摘要 + 明细 NOT_READY ----
  '/live': async (f)=>{
    const params = {start_date:f.sd, end_date:f.ed, scope_key:'直播'};
    if (f.shop) params.shop_code = f.shop;
    let html = `<h1>直播经营</h1><div class="sub">${f.shop_name||'抖音整体'} ｜ ${f.sd} ～ ${f.ed} ｜ 口径：直播（正式 Scope）</div>`;
    try {
      const s = await api('/business/summary', params);
      html += `<div class="kpis">` +
        MetricCard('直播成交金额', s.data.user_pay_amount, null) +
        MetricCard('直播退款率', s.data.refund_rate, null, {isRate:true, goodWhen:'low'}) +
        MetricCard('直播投放消耗', s.data.ad_spend_shop_bound, null) + `</div>`;
      html += `<div class="card"><h3>直播成交金额趋势</h3>`;
      try { const t = await api('/business/trend', params); html += TrendSvg(t.data, 'user_pay_amount'); }
      catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
      html += `</div>`;
      html += `<div class="notice">直播场次/账号/商品级明细未在正式接口暴露 → <b>NOT_READY</b>（分钟级/时段级不支持）。</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /video 短视频：scope=短视频 正式摘要 + 明细 NOT_READY ----
  '/video': async (f)=>{
    const params = {start_date:f.sd, end_date:f.ed, scope_key:'短视频'};
    if (f.shop) params.shop_code = f.shop;
    let html = `<h1>短视频经营</h1><div class="sub">${f.shop_name||'抖音整体'} ｜ ${f.sd} ～ ${f.ed} ｜ 口径：短视频（正式 Scope）</div>`;
    try {
      const s = await api('/business/summary', params);
      html += `<div class="kpis">` +
        MetricCard('短视频成交金额', s.data.user_pay_amount, null) +
        MetricCard('短视频退款率', s.data.refund_rate, null, {isRate:true, goodWhen:'low'}) +
        MetricCard('短视频投放消耗', s.data.ad_spend_shop_bound, null) + `</div>`;
      html += `<div class="card"><h3>短视频成交金额趋势</h3>`;
      try { const t = await api('/business/trend', params); html += TrendSvg(t.data, 'user_pay_amount'); }
      catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
      html += `</div>`;
      html += `<div class="notice">内容级（单载体构成）明细未在正式接口暴露 → <b>NOT_READY</b>（仅区间快照，不伪装逐日内容趋势）。</div>`;
    } catch(e){ html += `<div class="err">${esc(e.message)}</div>`; }
    return html;
  },

  // ---- /search 搜索 / /materials 素材：正式能力缺口 ----
  '/search': async (f)=>{
    return `<h1>搜索</h1>` + StateNotice('NOT_READY', '搜索独立数据源尚未接入正式接口白名单（关键词粒度缺失 → 不出现"关键词排行榜"；F1.5 计划）。');
  },
  '/materials': async (f)=>{
    return `<h1>素材</h1>` + StateNotice('NOT_READY', '素材数据源尚未接入正式接口白名单（素材指标不完整 → 不用视频表冒充素材分析；F1.5 计划）。');
  },

  // ---- /smart-operation 智能经营总入口：决策中心（风险/机会/Action 摘要 + AI 入口）----
  '/smart-operation': async (f)=>{
    let html = `<h1>智能经营</h1><div class="sub">${f.sd} ～ ${f.ed} ｜ 经营决策中心：智能层结果集中视图</div>`;
    html += `<div class="grid3">`;
    try {
      const r = await api('/priorities/risks', {start_date:f.sd, end_date:f.ed, limit:5});
      html += `<div class="card"><h3>当前风险摘要</h3><table><tr><th>对象</th><th>级别</th><th>得分</th></tr>` +
        (r.data.length ? r.data.map(x=>`<tr><td><a href="#/risks">${esc(x.entity_name)}</a></td><td><span class="badge red">${esc(x.risk_level)}</span></td><td class="num">${fmt(x.risk_priority_score)}</td></tr>`).join('') : `<tr><td colspan="3" class="empty">无</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>当前风险摘要</h3>${errBlock(e, '无（V1.1 检测未覆盖新月份）', 3)}</div>`; }
    try {
      const o = await api('/priorities/opportunities', {start_date:f.sd, end_date:f.ed, limit:5});
      html += `<div class="card"><h3>当前机会摘要</h3><table><tr><th>对象</th><th>级别</th><th>得分</th></tr>` +
        (o.data.length ? o.data.map(x=>`<tr><td><a href="#/opportunities">${esc(x.entity_name)}</a></td><td><span class="badge green">${esc(x.opportunity_level)}</span></td><td class="num">${fmt(x.opportunity_priority_score)}</td></tr>`).join('') : `<tr><td colspan="3" class="empty">无</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>当前机会摘要</h3>${errBlock(e, '无（V1.1 检测未覆盖新月份）', 3)}</div>`; }
    try {
      const w = await api('/priorities/watchlist', {start_date:f.sd, end_date:f.ed, limit:5});
      html += `<div class="card"><h3>今日 Action / Watchlist</h3><table><tr><th>对象</th><th>状态</th></tr>` +
        (w.data.length ? w.data.map(x=>`<tr><td>${esc(x.entity_name)}</td><td><span class="badge amber">WATCH</span></td></tr>`).join('') : `<tr><td colspan="2" class="empty">无</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card"><h3>今日 Action</h3>${errBlock(e, '无（V1.1 检测未覆盖新月份）', 2)}</div>`; }
    html += `</div>`;
    html += `<div class="card"><h3>AI 经营助手</h3><p style="font-size:13px">基于正式结果解释经营问题（不自行重算）：<a href="#/ai">进入 AI 助手 →</a></p></div>`;
    return html;
  },

  // ---- /risks 风险中心：完整列表（首页 TOP5 仅为摘要）----
  '/risks': async (f)=>{
    let html = `<h1>风险中心</h1><div class="sub">V1.1 异常检测正式结果 ｜ ${f.sd} ～ ${f.ed} ｜ 完整列表（支持按级别/域/店铺筛选见下方）</div>`;
    try {
      const r = await api('/priorities/risks', {start_date:f.sd, end_date:f.ed, limit:50});
      html += `<div class="card"><table><tr><th>对象</th><th>域</th><th>类型</th><th>级别</th><th>得分</th><th>影响金额</th><th>持续</th><th>链路</th></tr>` +
        (r.data.length ? r.data.map(x=>`<tr><td><a href="#/diagnosis">${esc(x.entity_name)}</a></td><td>${esc(x.entity_level||'')}</td><td>${esc(x.source_anomaly_code||'')}</td><td><span class="badge red">${esc(x.risk_level)}</span></td><td class="num">${fmt(x.risk_priority_score)}</td><td class="num">${yuan(x.business_impact)}</td><td class="num">${x.occurrence_count||''}天</td><td style="font-size:11px">${esc((x.diagnostic_chain_id||'').slice(0,30))}</td></tr>`).join('') : `<tr><td colspan="8" class="empty">当前区间无风险</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card">${errBlock(e, '当前区间无风险（V1.1 检测未覆盖新月份数据）', 8)}</div>`; }
    return html;
  },

  // ---- /diagnosis 问题诊断：数据定位（非因果）----
  '/diagnosis': async (f)=>{
    let html = `<h1>问题诊断</h1><div class="sub">V1.1 诊断正式结果 ｜ ${f.sd} ～ ${f.ed} ｜ 数据定位，非因果结论</div>`;
    try {
      const params = {start_date:f.sd, end_date:f.ed, domain_key:'shop'};
      if (f.shop) params.shop_code = f.shop;
      const r = await api('/diagnostics/results', params);
      html += `<div class="card"><table><tr><th>诊断类型</th><th>Primary Stage</th><th>置信度</th><th>当前值</th><th>变化</th><th>证据</th></tr>` +
        (r.data.length ? r.data.map(x=>`<tr><td>${esc(x.diagnostic_code)}</td><td><span class="badge blue">${esc(x.primary_stage)}</span></td><td class="num">${pct(x.confidence_score)}</td><td class="num">${fmt(x.current_value)}</td><td class="num">${fmt(x.absolute_change)}</td><td style="font-size:11px;color:var(--muted)">${esc((x.evidence_json||'').slice(0,60))}</td></tr>`).join('') : `<tr><td colspan="6" class="empty">当前区间无诊断结果</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card">${errBlock(e, '当前区间无诊断结果（V1.1 检测未覆盖新月份数据）', 6)}</div>`; }
    try {
      const d = await api('/diagnostics/decomposition', {start_date:f.sd, end_date:f.ed});
      const x = d.data;
      html += `<div class="card"><h3>变化拆解（${f.sd} ~ ${f.ed} vs 上期）</h3><table><tr><th>净变化</th><th>负向贡献</th><th>正向抵消</th></tr>` +
        `<tr><td class="num" style="color:${x.net_change<0?'var(--red)':'var(--green)'}">${yuan(x.net_change)}</td><td class="num" style="color:var(--red)">${yuan(x.gross_negative)}</td><td class="num" style="color:var(--green)">${yuan(x.gross_positive)}</td></tr></table></div>`;
    } catch(e){}
    return html;
  },

  // ---- /opportunities 增长机会：完整机会中心（首页 TOP5 仅为摘要）----
  '/opportunities': async (f)=>{
    let html = `<h1>增长机会</h1><div class="sub">V1.1 机会正式结果 ｜ ${f.sd} ～ ${f.ed} ｜ Opportunity Score 是机会质量排序，不是未来成功概率</div>`;
    try {
      const o = await api('/priorities/opportunities', {start_date:f.sd, end_date:f.ed, limit:50});
      html += `<div class="card"><table><tr><th>对象</th><th>类型</th><th>级别</th><th>得分</th><th>机会分</th><th>可用权重</th></tr>` +
        (o.data.length ? o.data.map(x=>`<tr><td><a href="#/opportunities">${esc(x.entity_name)}</a></td><td>${esc(x.source_opportunity_code||'')}</td><td><span class="badge green">${esc(x.opportunity_level)}</span></td><td class="num">${fmt(x.opportunity_priority_score)}</td><td class="num">${fmt(x.opportunity_score)}</td><td class="num">${x.available_weight!=null?pct(x.available_weight):'—'}</td></tr>`).join('') : `<tr><td colspan="6" class="empty">当前区间无机会</td></tr>`) + `</table></div>`;
    } catch(e){ html += `<div class="card">${errBlock(e, '当前区间无机会（V1.1 检测未覆盖新月份数据）', 6)}</div>`; }
    return html;
  },

  // ---- /ai AI 经营助手（上下文继承筛选；AI 只解释正式结果）----
  '/ai': async (f)=>{
    const ctx = `店铺：${f.shop_name||'抖音整体'} ｜ 日期：${f.sd}~${f.ed} ｜ Scope：${f.scope}`;
    return `<h1>AI 经营助手</h1><div class="sub">AI 只解释正式结果，不自行重算；上下文自动继承当前筛选</div>
      <div class="notice">当前上下文：${ctx}</div>
      <div class="card"><h3>快捷问题</h3><table><tr><th>问题</th><th>回答方式</th></tr>
      <tr><td>为什么下降？</td><td>引用变化拆解/诊断正式结果（当前数据表明…）</td></tr>
      <tr><td>最大风险是什么？</td><td>引用 get_daily_risk_priorities 正式结果（TOP1）</td></tr>
      <tr><td>最大机会是什么？</td><td>引用 get_daily_opportunity_priorities 正式结果（TOP1）</td></tr>
      <tr><td>哪个商品拖累最大？</td><td>引用 decompose 负向贡献/rank_products 正式结果</td></tr>
      <tr><td>最近 ${f.sd}~${f.ed} 发生了什么？</td><td>引用 business/summary + compare 正式结果</td></tr></table>
      <p style="margin-top:10px;font-size:12px;color:var(--muted)">AI 边界：不能修改 Priority/Opportunity Score；不能自算退款率；不能编造异常（V1.1 AI 铁律）。真实 LLM 接入见部署配置。</p></div>`;
  },

  // ---- 平台页（保留原实现）----
  '/data-center': async (f)=>{
    try {
      const r = await api('/data-status');
      return `<h1>数据中心</h1><div class="sub">为什么今天没数据？先看这里：源文件未导入 / 导入失败 / 数据不完整 / 业务为 0</div><div class="card"><table><tr><th>店铺</th><th>最早日期</th><th>最新日期</th><th>天数</th><th>行数</th><th>时间类型</th><th>状态</th></tr>` +
        r.data.map(x=>`<tr><td>${esc(x.shop_name)}</td><td>${x.min_date}</td><td>${x.max_date}</td><td class="num">${x.day_count}</td><td class="num">${x.row_count}</td><td>DAILY_FACT</td><td><span class="badge green">OK</span></td></tr>`).join('') + `</table></div>`;
    } catch(e){ return `<h1>数据中心</h1><div class="err">${esc(e.message)}</div>`; }
  },
  '/system-status': async (f)=>{
    try {
      const h = await api('/health'), r = await api('/ready');
      return `<h1>系统状态</h1><div class="card"><table><tr><td>Web</td><td><span class="badge green">正常</span></td></tr><tr><td>Backend</td><td><span class="badge green">${esc(h.data.service)}</span></td></tr><tr><td>Database</td><td><span class="badge green">正常（店铺 ${r.data.shop_count} 家）</span></td></tr><tr><td>关键 Function 样例</td><td>${r.data.sample_value!=null?'正常（'+yuan(r.data.sample_value)+'）':'—'}</td></tr></table></div>`;
    } catch(e){ return `<h1>系统状态</h1><div class="err">${esc(e.message)}</div>`; }
  },
  '/data-status': async (f)=>{
    try {
      const r = await api('/data-status');
      return `<h1>数据状态</h1><div class="card"><table><tr><th>店铺</th><th>最早</th><th>最新</th><th>天数</th><th>行数</th><th>时间类型</th><th>状态</th></tr>` +
        r.data.map(x=>`<tr><td>${esc(x.shop_name)}</td><td>${x.min_date}</td><td>${x.max_date}</td><td class="num">${x.day_count}</td><td class="num">${x.row_count}</td><td>DAILY_FACT</td><td><span class="badge green">OK</span></td></tr>`).join('') + `</table></div>`;
    } catch(e){ return `<h1>数据状态</h1><div class="err">${esc(e.message)}</div>`; }
  },
};
// 路由别名：/ 与 /diagnostics 兼容
PAGES['/'] = PAGES['/today'];
PAGES['/diagnostics'] = PAGES['/diagnosis'];
PAGES['/refunds'] = PAGES['/refund'];
PAGES['/videos'] = PAGES['/video'];
PAGES['/shop'] = PAGES['/store'];

// ============================================================================
// 渲染：Sidebar / Filters（按页面能力矩阵）/ StatusBar（查询区间与系统最新日期分离）/ Page
// ============================================================================
function renderSide(){
  const cur = G.page;
  $('#side').innerHTML = `<div class="logo">抖音智能<br>经营工作台</div>` + MENU.map(m =>
    m[1] ? `<a href="#${m[1]}" class="${cur===m[1]?'active':''}">${m[1]}</a>` : `<div class="grp">${m[0]}</div>`
  ).join('');
}
function renderFilters(){
  const meta = PAGE_META[G.page] || PAGE_META['/today'];
  G.shop_name = G.shop ? SHOP_NAMES[G.shop] : '抖音整体';
  G.preset = derivePreset(G.sd, G.ed);
  const sel = v => `value="${v}"`;
  $('#filters').innerHTML = `
    <div class="field"><label>平台</label><select disabled><option>douyin（固定）</option></select></div>
    ${meta.supports_shop ? `<div class="field"><label>店铺</label><select id="f_shop">
      <option ${sel('')}>抖音整体</option><option ${sel('DY_DANDONG_OFFICIAL')}>弹动官方旗舰店</option><option ${sel('DY_GERENHULI_OFFICIAL')}>弹动个人护理旗舰店</option></select></div>` : ''}
    <div class="field"><label>日期</label><select id="f_mode">${Object.keys(PRESET_CN).map(k=>`<option ${G.preset===k?'selected':''}>${PRESET_CN[k]}</option>`).join('')}</select></div>
    ${G.preset==='custom' ? `<div class="field"><label>开始</label><input type="date" id="f_sd" value="${G.sd}"></div><div class="field"><label>结束</label><input type="date" id="f_ed" value="${G.ed}"></div>` : `<div class="field"><label>区间</label><input type="date" value="${G.sd}" disabled style="background:#f9fafb"></div><div class="field"><label>～</label><input type="date" value="${G.ed}" disabled style="background:#f9fafb"></div>`}
    ${meta.supports_scope ? `<div class="field"><label>Scope</label><select id="f_scope">${SCOPES.map(s=>`<option ${s===G.scope?'selected':''}>${s}</option>`).join('')}</select></div>` : `<div class="field"><label>Scope</label><select disabled><option>${G.scope}（当前模块不适用）</option></select></div>`}`;
  if (meta.supports_shop){ $('#f_shop').value = G.shop; $('#f_shop').onchange = e=>{ G.shop = e.target.value; saveG(); location.hash = G.page; }; }
  if (meta.supports_scope){ $('#f_scope').value = G.scope; $('#f_scope').onchange = e=>{ G.scope = e.target.value; saveG(); location.hash = G.page; }; }
  $('#f_mode').onchange = e=>{
    const k = Object.keys(PRESET_CN).find(x=>PRESET_CN[x]===e.target.value);
    applyPreset(k); saveG(); location.hash = G.page;
  };
  const fd = $('#f_sd'), fe = $('#f_ed');
  if (fd) fd.onchange = e=>{ G.sd = e.target.value; G.preset = 'custom'; saveG(); location.hash = G.page; };
  if (fe) fe.onchange = e=>{ G.ed = e.target.value; G.preset = 'custom'; saveG(); location.hash = G.page; };
  renderStatus();
}
function renderStatus(){
  // 查询区间 与 系统最新入库日期 是两个独立概念，分开展示
  $('#status').innerHTML = `<span>查询区间：<b>${G.sd||'—'} ～ ${G.ed||'—'}</b>（${PRESET_CN[G.preset]||''}）</span>
    <span>系统最新入库数据：<b>${MX||'—'}</b></span>
    <span>店铺：<b>${G.shop_name||'抖音整体'}</b></span>
    <span>Scope：<b>${G.scope}</b></span>`;
}
async function renderPage(){
  const fn = PAGES[G.page] || PAGES['/today'];
  $('#page').innerHTML = `<div class="loading">加载中…</div>`;
  try { $('#page').innerHTML = await fn(G); }
  catch(e){ $('#page').innerHTML = `<div class="err">加载失败：${esc(e.message)}</div>`; }
  // CSV 导出（数字直接来自当前 API 返回，前端不聚合）
  const t = $('#page table');
  if (t){
    const btn = document.createElement('button');
    btn.textContent = '导出 CSV';
    btn.style.cssText = 'margin:0 0 10px;padding:6px 14px;border:none;background:var(--accent);color:#fff;border-radius:8px;cursor:pointer;font-size:13px';
    btn.onclick = () => {
      const rows = [...t.rows].map(r => [...r.cells].map(c => c.innerText.replace(/\n/g,' ').trim()));
      const csv = rows.map(r => r.map(c => '"' + c.replace(/"/g,'""') + '"').join(',')).join('\r\n');
      const blob = new Blob(['\ufeff' + csv], {type:'text/csv;charset=utf-8'});
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `export_${G.page.slice(1)||'today'}_${G.sd}_${G.ed}.csv`;
      a.click();
      URL.revokeObjectURL(a.href);
    };
    $('#page h1').after(btn);
  }
}

// ============================================================================
// 初始化：先取系统最新入库日期（MX），再推导日期状态，最后渲染
// ============================================================================
window.addEventListener('hashchange', ()=>{ G.page = location.hash.slice(1)||'/today'; renderSide(); renderFilters(); renderPage(); });
(async function init(){
  try {
    const r = await api('/data-status', {platform_code:'douyin'});
    const rows = r.data || [];
    rows.forEach(x=>{ if (x.max_date && (!MX || x.max_date > MX)) MX = x.max_date; });
  } catch(e) {}
  // 首次访问（无 localStorage）默认近 7 天；已有值则推导 preset
  if (!G.sd || !G.ed){ applyPreset('last7days'); }
  else { G.preset = derivePreset(G.sd, G.ed); }
  if (!G.sd) { G.sd = addDay(MX||'2026-08-07', -6); }
  renderSide(); renderFilters(); renderPage();
})();
