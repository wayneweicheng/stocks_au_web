// Exercise the real SPX mapped-levels page's quote effects and row buttons.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');
const pageFile = path.resolve(__dirname, '../src/app/spx-map-reports/[jobId]/mapped-levels/page.tsx');
const code = ts.transpileModule(fs.readFileSync(pageFile, 'utf8'), { compilerOptions: {
  module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, target: ts.ScriptTarget.ES2020,
} }).outputText;
const states = [
  { primary_supports: [{ zone_low: 7700.3, zone_high: 7709.7, tradable_center: 7704.5 }] },
  { historical_closes: { SPX: 7700, SPY: 773.13, QQQ: 725.21, SPXL: 290.76, TQQQ: 72.61, ESMain: 7799.25, NQMain: 29997.5 },
    historical_close_date: '2026-10-21', calibration_eligible: false },
  {}, 'loading', 'loading', {}, false, '', false, null, {}, 'loading', null, null, {}, {},
];
let cursor = 0;
let effects = [];
const intervals = [];
const requests = [];
const manualRef = { current: new Map() };
let spyUnauthorized = false;
let reproQuotes = false;
let reproSpyPrice = 764.15;
let reproQqqPrice = 707.15;
let nvdaManualPrice = 195;
global.window = { setInterval: (fn, delay) => { intervals.push({ fn, delay }); return intervals.length; }, clearInterval: () => {},
  setTimeout: () => 1, clearTimeout: () => {} };
const element = (type, props) => ({ type, ...props });
const react = { use: () => ({ jobId: 'fixture' }), useEffect: f => effects.push(f), useMemo: f => f(), useRef: () => manualRef,
  useState: () => { const i = cursor++; return [states[i], (update) => { states[i] = typeof update === 'function' ? update(states[i]) : update; }]; } };
const authenticatedFetch = async (url) => {
  requests.push(String(url));
  const requested = new URL(String(url), 'http://localhost');
  const symbol = requested.searchParams.get('symbol');
  if (spyUnauthorized && symbol === 'SPY') return { ok: false, status: 401 };
  let payload;
  if (requested.pathname.endsWith('/spx-map-extra-prices')) payload = {
    historical_closes: { NVDA: 200, SQQQ: 30 }, historical_close_dates: { NVDA: '2026-10-21', SQQQ: '2026-10-20' },
    historical_close_source: '30m_regular_session',
  };
  else if (requested.pathname.endsWith('/spx-map-live-extra-prices')) {
    const value = { NVDA: nvdaManualPrice, SQQQ: 30.5 }[symbol];
    payload = { live_prices: value ? { [symbol]: value } : {}, status: value ? 'available' : 'unavailable' };
  } else if (requested.pathname.endsWith('/spx-map-live-futures')) {
    const prices = { ESMain: 7721, NQMain: 29480.25 };
    payload = { live_prices: symbol ? { [symbol]: prices[symbol] } : prices, status: 'available' };
  } else {
    const prices = { SPY: 765.49, QQQ: 714.06, SPXL: 281.91, TQQQ: 68.86 };
    payload = { live_prices: symbol ? { [symbol]: reproQuotes ? { SPY: reproSpyPrice, QQQ: reproQqqPrice }[symbol] : { ...prices, QQQ: 710, SPY: 766.8, SPXL: 275, TQQQ: 65 }[symbol] } : prices, status: 'available' };
  }
  return { ok: true, json: async () => payload };
};
const m = new Module(pageFile, module);
m.filename = pageFile;
m.paths = Module._nodeModulePaths(path.dirname(pageFile));
const originalRequire = m.require.bind(m);
m.require = id => {
  if (id === 'react') return react;
  if (id === 'react/jsx-runtime') return { jsx: element, jsxs: element, Fragment: 'fragment' };
  if (id === './calibration') {
    const file = path.resolve(path.dirname(pageFile), 'calibration.ts');
    const child = new Module(file, m);
    child._compile(ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, file);
    return child.exports;
  }
  if (id.endsWith('authenticatedFetch')) return { authenticatedFetch };
  if (id.startsWith('../../../')) return { __esModule: true, default: id, levelReportKey: () => '', parseHtmlLevelDetails: () => ({}) };
  return originalRequire(id);
};
m._compile(code, pageFile);
const render = () => { cursor = 0; effects = []; return m.exports.default({ params: Promise.resolve({ jobId: 'fixture' }) }); };
function collect(node, type, result = []) {
  if (Array.isArray(node)) { node.forEach(n => collect(n, type, result)); return result; }
  if (!node || typeof node !== 'object') return result;
  if (typeof node.type === 'function') return collect(node.type(node), type, result);
  if (node.type === type) result.push(node);
  collect(node.children, type, result);
  return result;
}
function rowFor(tree, label) {
  const row = collect(tree, 'tr').find(tr => collect(tr, 'td')[0]?.children === label);
  assert.ok(row, `${label} row not rendered`);
  return row;
}
function checkUnavailable(tree, label) {
  const row = rowFor(tree, label);
  const cells = collect(row, 'td');
  assert.equal(collect(cells[3], 'div').length, 0, `${label} must not show a fallback range`);
  assert.equal(collect(cells[6], 'a').length, 0, `${label} must not offer orders without a ratio`);
  assert.match(row.className, /amber|red/);
}
function mappedRangeAndOrders(tree, symbol) {
  const cells = collect(rowFor(tree, symbol), 'td');
  return {
    range: JSON.stringify(cells[3]),
    orders: collect(cells[6], 'a').map(link => link.href),
    source: JSON.stringify(cells[5]),
  };
}
function refreshButton(tree, symbol) {
  const row = rowFor(tree, symbol);
  const button = collect(collect(row, 'td')[2], 'button')[0];
  assert.equal(button['aria-label'], `Refresh ${symbol} live price`);
  return button;
}
const flush = () => new Promise(resolve => setImmediate(resolve));
(async () => {
  const data = states[0], mapping = states[1];
  states[0] = null; states[1] = null;
  assert.doesNotThrow(() => render(), 'first render must work before data arrives');
  states[0] = data; states[1] = mapping;
  let tree = render();
  assert.equal(collect(tree, 'details')[0].open, undefined, 'more stocks closed by default');
  for (const symbol of ['SPY', 'QQQ', 'SPXL', 'TQQQ', 'ESMain', 'NQMain']) refreshButton(tree, symbol);
  for (const symbol of ['QQQ', 'TQQQ', 'NQMain']) checkUnavailable(tree, symbol);

  effects[1](); // initial stock batch
  effects[2](); // independent initial futures batch
  await flush();
  tree = render();
  assert.equal(requests.filter(url => url.endsWith('/spx-map-live-prices')).length, 1);
  assert.equal(requests.filter(url => url.endsWith('/spx-map-live-futures')).length, 1);
  assert.equal(intervals.length, 0, 'never poll IB automatically');
  assert.match(JSON.stringify(collect(rowFor(tree, 'QQQ'), 'td')[5]), /observed QQQ\/SPY ratio/);
  assert.match(mappedRangeAndOrders(tree, 'SPXL').source, /SPY mapped % move × 3/);
  assert.match(mappedRangeAndOrders(tree, 'TQQQ').source, /QQQ mapped % move × 3/);
  const mappedLow = (symbol) => Number(String(collect(collect(rowFor(tree, symbol), 'td')[3], 'div')[0].children[0]).replaceAll(',', ''));
  const spyClose = states[1].historical_closes.SPY;
  const qqqClose = states[1].historical_closes.QQQ;
  assert.ok(Math.abs(mappedLow('SPXL') - states[1].historical_closes.SPXL * (1 + 3 * (mappedLow('SPY') / spyClose - 1))) < 0.04);
  assert.ok(Math.abs(mappedLow('TQQQ') - states[1].historical_closes.TQQQ * (1 + 3 * (mappedLow('QQQ') / qqqClose - 1))) < 0.04);
  assert.equal(requests.some(url => url.includes('live-extra-prices')), false);

  // Leveraged ranges depend on the mapped parent, not on their own IB ticks.
  const spxlBefore = mappedRangeAndOrders(tree, 'SPXL');
  const tqqqBeforeOwnQuote = mappedRangeAndOrders(tree, 'TQQQ');
  refreshButton(tree, 'SPXL').onClick();
  await flush();
  tree = render();
  assert.match(JSON.stringify(collect(rowFor(tree, 'SPXL'), 'td')[2]), /275\.00/);
  assert.deepEqual(mappedRangeAndOrders(tree, 'SPXL'), spxlBefore);
  refreshButton(tree, 'TQQQ').onClick();
  await flush();
  tree = render();
  assert.match(JSON.stringify(collect(rowFor(tree, 'TQQQ'), 'td')[2]), /65\.00/);
  assert.deepEqual(mappedRangeAndOrders(tree, 'TQQQ'), tqqqBeforeOwnQuote);
  const qqqQuote = states[2].QQQ;
  delete states[2].QQQ;
  tree = render();
  checkUnavailable(tree, 'QQQ');
  checkUnavailable(tree, 'TQQQ');
  states[2].QQQ = qqqQuote;
  tree = render();

  // A different QQQ tick must update the mapped range AND executable links.
  const qqqBefore = mappedRangeAndOrders(tree, 'QQQ');
  const tqqqBefore = mappedRangeAndOrders(tree, 'TQQQ');
  refreshButton(tree, 'QQQ').onClick();
  await flush();
  tree = render();
  assert.ok(requests.some(url => url.endsWith('/spx-map-live-prices?symbol=QQQ')));
  assert.match(JSON.stringify(collect(rowFor(tree, 'SPY'), 'td')[2]), /765\.49/);
  assert.match(JSON.stringify(collect(rowFor(tree, 'QQQ'), 'td')[2]), /710\.00/);
  const qqqAfter = mappedRangeAndOrders(tree, 'QQQ');
  assert.notEqual(qqqAfter.range, qqqBefore.range, 'new QQQ quote must recalculate mapped levels');
  assert.notDeepEqual(qqqAfter.orders, qqqBefore.orders, 'orders must use new QQQ range');
  assert.match(qqqAfter.source, /observed QQQ\/SPY ratio/);
  assert.notEqual(mappedRangeAndOrders(tree, 'TQQQ').range, tqqqBefore.range,
    'TQQQ mapped levels must follow the refreshed QQQ range');
  assert.notDeepEqual(mappedRangeAndOrders(tree, 'TQQQ').orders, tqqqBefore.orders,
    'TQQQ order links must follow the refreshed QQQ range');

  // TQQQ derives from QQQ even when its own IB quote is unavailable.
  delete states[2].TQQQ;
  tree = render();
  assert.equal(collect(collect(rowFor(tree, 'TQQQ'), 'td')[3], 'div').length, 2);
  assert.equal(mappedRangeAndOrders(tree, 'TQQQ').orders.length, 3);
  states[2].TQQQ = 68.86;
  tree = render();

  // SPY is the ratio denominator: updating it should recalculate every target.
  const qqqBeforeSpy = mappedRangeAndOrders(tree, 'QQQ');
  const tqqqBeforeSpy = mappedRangeAndOrders(tree, 'TQQQ');
  refreshButton(tree, 'SPY').onClick();
  await flush();
  tree = render();
  assert.notEqual(mappedRangeAndOrders(tree, 'QQQ').range, qqqBeforeSpy.range);
  assert.notEqual(mappedRangeAndOrders(tree, 'TQQQ').range, tqqqBeforeSpy.range);
  assert.notDeepEqual(mappedRangeAndOrders(tree, 'QQQ').orders, qqqBeforeSpy.orders);
  refreshButton(tree, 'NQMain').onClick();
  await flush();
  assert.ok(requests.some(url => url.endsWith('/spx-map-live-futures?symbol=NQMain')));

  const pane = collect(tree, 'details')[0];
  pane.onToggle({ currentTarget: { open: true } });
  tree = render();
  effects[3](); // fetch date-bound closes only
  await flush();
  tree = render();
  assert.ok(requests.some(url => url.includes('/spx-map-extra-prices?observation_date=2026-10-21')));
  assert.equal(requests.some(url => url.includes('live-extra-prices')), false, 'opening the pane must not subscribe to IB');
  assert.equal(intervals.length, 0);
  checkUnavailable(tree, 'NVDA');
  refreshButton(tree, 'NVDA').onClick();
  await flush();
  tree = render();
  assert.ok(requests.some(url => url.endsWith('/spx-map-live-extra-prices?symbol=NVDA')));
  const nvda = rowFor(tree, 'NVDA');
  const nvdaLinks = collect(collect(nvda, 'td')[6], 'a');
  assert.deepEqual(nvdaLinks.map(link => link.children), ['Buy range', 'Sell range', 'Sell put']);
  assert.match(nvdaLinks[2].href, /action=SELL/);
  const nvdaBefore = mappedRangeAndOrders(tree, 'NVDA');
  nvdaManualPrice = 193;
  refreshButton(tree, 'NVDA').onClick();
  await flush();
  tree = render();
  const nvdaAfter = mappedRangeAndOrders(tree, 'NVDA');
  assert.notEqual(nvdaAfter.range, nvdaBefore.range, 'extra-stock range must follow refreshed IB quote');
  assert.notDeepEqual(nvdaAfter.orders, nvdaBefore.orders, 'extra-stock order targets must follow new ratio');
  assert.match(nvdaAfter.source, /observed NVDA\/SPY ratio/);
  checkUnavailable(tree, 'SQQQ'); // still unfetched despite NVDA success
  refreshButton(tree, 'SQQQ').onClick();
  await flush();
  tree = render();
  assert.match(JSON.stringify(collect(rowFor(tree, 'SQQQ'), 'td')[5]), /observed SQQQ-SPY move spread/);
  refreshButton(tree, 'SPCX').onClick(); // no IB tick: fail closed
  await flush();
  tree = render();
  checkUnavailable(tree, 'SPCX');
  assert.match(JSON.stringify(collect(rowFor(tree, 'SPCX'), 'td')[2]), /IB returned no SPCX price/);

  // Reproduce the 23.41x raw ratio (SPY +0.016%, QQQ +0.368%).
  // A near-flat SPY should use the live percentage-point difference instead.
  states[1] = { ...states[1], historical_closes: { ...states[1].historical_closes, SPY: 764.03, QQQ: 704.56 } };
  reproQuotes = true;
  refreshButton(tree, 'SPY').onClick();
  await flush();
  tree = render();
  refreshButton(tree, 'QQQ').onClick();
  await flush();
  tree = render();
  const qqqReproCells = collect(rowFor(tree, 'QQQ'), 'td');
  assert.match(JSON.stringify(qqqReproCells[2]), /707\.15/);
  assert.equal(collect(qqqReproCells[3], 'div').length, 2, 'real QQQ quote must produce a live-ratio range');
  assert.match(JSON.stringify(qqqReproCells[5]), /observed QQQ-SPY move spread/);
  assert.match(JSON.stringify(qqqReproCells[5]), /SPY \+0\.016%, QQQ \+0\.368%/);
  assert.doesNotMatch(JSON.stringify(qqqReproCells[5]), /23\.41×/);
  const qqqRiskLinks = collect(qqqReproCells[6], 'a');
  const mappedStart = Number(new URL(qqqRiskLinks[0].href, 'http://localhost').searchParams.get('start'));
  assert.ok(Math.abs(mappedStart - 707.15) < 5, `near-flat SPY mapping should be near QQQ's live quote; got ${mappedStart}`);
  assert.deepEqual(qqqRiskLinks.map(link => link.children), ['Buy range', 'Sell range', 'Sell put']);
  assert.match(qqqRiskLinks[0].href, /stock=QQQ/);
  assert.match(qqqRiskLinks[2].href, /symbol=QQQ/);
  const extraRiskCells = collect(rowFor(tree, 'SQQQ'), 'td');
  assert.equal(collect(extraRiskCells[3], 'div').length, 2, 'extra stock can also display a high-risk range');
  assert.equal(collect(extraRiskCells[6], 'a').length, 3, 'extra-stock actions follow its displayed range');

  // Same-direction +0.12% SPY remains on the difference method; only
  // strictly above 0.20% switches to the live ratio.
  reproSpyPrice = 764.03 * 1.0012;
  refreshButton(tree, 'SPY').onClick();
  await flush();
  tree = render();
  assert.match(mappedRangeAndOrders(tree, 'QQQ').source, /observed QQQ-SPY move spread/);
  reproSpyPrice = 764.03 * 1.0021;
  refreshButton(tree, 'SPY').onClick();
  await flush();
  tree = render();
  assert.match(mappedRangeAndOrders(tree, 'QQQ').source, /observed QQQ\/SPY ratio/);
  assert.equal(mappedRangeAndOrders(tree, 'QQQ').orders.length, 3);

  // Even with SPY +0.21%, QQQ +0.15% is too small for the ratio method.
  reproQqqPrice = 704.56 * 1.0015;
  refreshButton(tree, 'QQQ').onClick();
  await flush();
  tree = render();
  assert.match(mappedRangeAndOrders(tree, 'QQQ').source, /observed QQQ-SPY move spread/);
  assert.equal(mappedRangeAndOrders(tree, 'QQQ').orders.length, 3);
  reproQqqPrice = 707.15;
  refreshButton(tree, 'QQQ').onClick();
  await flush();
  tree = render();
  assert.match(mappedRangeAndOrders(tree, 'QQQ').source, /observed QQQ\/SPY ratio/);

  // Reported case: SPY -0.170%, QQQ +0.072%. Opposite moves must use
  // QQQ%-SPY% = +0.242 percentage points and retain mapped actions.
  reproSpyPrice = 764.03 * (1 - 0.0017);
  reproQqqPrice = 705.07;
  refreshButton(tree, 'SPY').onClick();
  await flush();
  tree = render();
  refreshButton(tree, 'QQQ').onClick();
  await flush();
  tree = render();
  const divergentQqq = collect(rowFor(tree, 'QQQ'), 'td');
  assert.match(JSON.stringify(divergentQqq[2]), /705\.07/);
  assert.equal(collect(divergentQqq[3], 'div').length, 2);
  assert.match(JSON.stringify(divergentQqq[5]), /observed QQQ-SPY move spread \(\+0\.242pp\)/);
  assert.match(JSON.stringify(divergentQqq[5]), /SPY -0\.170%, QQQ \+0\.072%/);
  assert.equal(collect(divergentQqq[6], 'a').length, 3);

  // Authentication failure is shown on the specific row, not blamed on IB Gateway.
  spyUnauthorized = true;
  refreshButton(tree, 'SPY').onClick();
  await flush();
  tree = render();
  assert.match(JSON.stringify(collect(rowFor(tree, 'SPY'), 'td')[2]), /Quote API authentication failed/);
  checkUnavailable(tree, 'QQQ');
  assert.equal(intervals.length, 0);
  console.log('Initial quotes; both same-sign >0.20% ratio, otherwise target-SPY difference; no polling or extra-stock prefetch: OK');
})().catch(err => { console.error(err); process.exitCode = 1; });
