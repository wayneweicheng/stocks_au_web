// Run the real SPX report loader with in-memory HTTP responses; no app, SQL or runner required.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const page = fs.readFileSync(path.join(__dirname, '../src/app/support-resistance/page.tsx'), 'utf8');
const ast = ts.createSourceFile('page.tsx', page, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
let loader;
function visit(node) {
  if (ts.isVariableDeclaration(node) && node.name.getText(ast) === 'loadMapReport') loader = node.initializer.arguments[0].getText(ast);
  ts.forEachChild(node, visit);
}
visit(ast);
assert.ok(loader);
const js = ts.transpileModule(`const load = ${loader};`, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const helpers = { ...require(path.join(__dirname, '../src/app/support-resistance/stockMapLevels.ts')),
  ...require(path.join(__dirname, '../src/app/support-resistance/spxMapLevels.ts')),
  ...require(path.join(__dirname, '../src/app/support-resistance/spxDerivedLevels.ts')) };
const { DEFAULT_CHART_DAYS } = require(path.join(__dirname, '../src/app/support-resistance/chartRange.ts'));
const asAt = { time: '2026-10-30T06:00:00', open: 7718, high: 7723, low: 7715, close: 7720.5, volume: 1 };
const later = { time: '2026-10-30T09:30:00', open: 7722, high: 7727, low: 7718, close: 7725, volume: 2 };
const map = { as_of_et: '2026-10-30T06:51:00-04:00', execution_reference_spx: 7721.02, reference_spx: 7721.02,
  primary_supports: [], primary_resistances: [{ rank: 1, zone_low: 7721.814925333334, zone_high: 7729.703408,
    reference_price: 7723.8175, total_score: 51, confidence: 'moderate confluence',
    last_close_reference_spx: 7721.02, option_validation: { oi_contracts: 17667, wall_type: 'magnet/pin' } }] };
const optionPair = { source: 'StockDB_US.StockData.v_OptionDelayedQuote_V2', observation_date: '2026-10-30',
  spot_reference_from_d1: 7721.02, status: 'available_historical_d1', option_rows: [
    { symbol: 'SPXW', observation_date: '2026-10-30', expiry: '2026-10-30', strike: 7720, right: 'C', price: 23, price_source: 'last' },
    { symbol: 'SPXW', observation_date: '2026-10-30', expiry: '2026-10-30', strike: 7720, right: 'P', price: 20, price_source: 'last' },
  ] };
const requests = [];
let selection;
let mapError;
let optionUnavailable = false;
let extraQuoteUnavailable = false;
const mapRequest = { current: 1 };
const mapping = { historical_closes: { SPX: 7721.02, ESMain: 7752.82, SPY: 769.36, QQQ: 610, SPXL: 185, TQQQ: 55 },
  historical_close_date: '2026-10-29', calibration_eligible: true,
  historical_close_dates: Object.fromEntries(['SPX', 'ESMain', 'SPY', 'QQQ', 'SPXL', 'TQQQ'].map((symbol) => [symbol, '2026-10-29'])) };
const authenticatedFetch = async (url) => {
  requests.push(url);
  const instrument = new URL(url, 'http://test.local').searchParams.get('stock_code');
  const targetBar = instrument === 'ESMain' ? { ...asAt, close: 7752.5 } : instrument === 'QQQ_D' ? { ...asAt, close: 700 } : asAt;
  const body = url.includes('/api/spx-map-reports/') ? { data: { content: map } }
    : url.includes('/spx-map-options?') ? optionUnavailable ? { detail: 'SQL unavailable' } : optionPair
    : url.includes('/api/spx-map-prices?') ? structuredClone(mapping)
    : url.includes('/api/spx-map-extra-prices?') ? { historical_close_source: '30m_regular_session', historical_close_date: '2026-10-29', historical_closes: { SOXL: 45, SOXX: 225 }, historical_close_dates: { SOXL: '2026-10-29', SOXX: '2026-10-29' } }
    : url.includes('/api/spx-map-live-extra-prices?') ? { live_prices: extraQuoteUnavailable ? {} : { [new URL(url, 'http://test.local').searchParams.get('symbol')]: new URL(url, 'http://test.local').searchParams.get('symbol') === 'SOXL' ? 44 : 223 } }
    : url.includes('/api/spx-map-live-prices') ? { live_prices: { SPY: 765, QQQ: 600 } }
    : { bars: url.includes('observation_date=') ? [targetBar] : [targetBar, later] };
  return { ok: !(optionUnavailable && url.includes('/spx-map-options?')), status: 503, json: async () => body };
};
const load = new Function('ctx', `with(ctx) { ${js}; return load; }`)({
  baseUrl: '', mapRequest, authenticatedFetch, DEFAULT_CHART_DAYS, URLSearchParams, ...helpers,
  setSelectedMapJob() {}, setMapData(value) { selection = typeof value === 'function' ? value(selection) : value; },
  setMapLoading() {}, setMapError(value) { mapError = value; },
});
(async () => {
  await load({ job_id: 'spx-30', title: '2026-10-30 21:51 Australia/Sydney' }, 'SPX', 1);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(mapError, '');
  assert.equal(selection.reportType, 'spx-map');
  assert.equal(selection.asAtClose.price, 7720.5);
  assert.equal(selection.resistances[0].range_low, 7721.814925333334);
  assert.equal(selection.resistances[0].range_high, 7729.703408);
  assert.equal(selection.resistances[0].score, 51);
  assert.equal(selection.spxOptions.premium, 43);
  assert.equal(selection.spxOptions.observationDate, '2026-10-30');
  assert.equal(selection.nextSessionStraddle, null);
  assert.ok(selection.bars.some((bar) => bar.time === later.time));
  assert.ok(requests.some((url) => url.includes('/api/spx-map-reports/spx-30/json')));
  assert.ok(!requests.some((url) => url.includes('/api/stock-map-reports/')));
  assert.ok(requests.some((url) => url.includes('/spx-map-options?observation_date=2026-10-30&reference_price=7721.02')));
  optionUnavailable = true;
  mapRequest.current = 2;
  await load({ job_id: 'spx-30', title: '2026-10-30 21:51 Australia/Sydney' }, 'SPX', 2);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(selection.resistances[0].score, 51, 'optional SQL failure must not hide SPX levels');
  assert.equal(selection.spxOptionError, 'SQL unavailable');
  assert.equal(mapError, '');
  const optionsBeforeDerived = requests.filter((url) => url.includes('/spx-map-options?')).length;
  mapRequest.current = 3;
  await load({ job_id: 'spx-30', title: '2026-10-30 21:51 Australia/Sydney' }, 'ESMain', 3);
  assert.equal(selection.stockCode, 'ESMain');
  assert.equal(selection.asAtClose.price, 7752.5, 'ES classification uses ESMain candles');
  assert.ok(Math.abs(selection.resistances[0].range_low - (7721.814925333334 + 31.8)) < 0.000001);
  assert.equal(selection.resistances[0].score, 51);
  assert.equal(selection.resistances[0].details.source_spx_anchor, 7723.8175);
  assert.ok(selection.mappingSource.includes('basis'));
  mapRequest.current = 4;
  await load({ job_id: 'spx-30', title: '2026-10-30 21:51 Australia/Sydney' }, 'QQQ_D', 4);
  assert.equal(selection.stockCode, 'QQQ_D');
  assert.equal(selection.asAtClose.price, 700, 'derived QQQ chart uses QQQ candles');
  assert.equal(selection.resistances[0].sourceSide, 'resistance', 'derived zones retain SPX report sides despite different target as-at price');
  assert.ok(selection.resistances[0].range_low < 1000, 'QQQ chart cannot plot SPX numbers');
  assert.equal(selection.resistances[0].details.source_spx_anchor, 7723.8175);
  assert.equal(selection.resistances[0].score, 51);
  assert.ok(requests.some((url) => url.includes('/api/spx-map-live-prices')));
  assert.equal(requests.filter((url) => url.includes('/spx-map-options?')).length, optionsBeforeDerived);
  for (const [code, close] of [['SOXL_D', 45], ['SOXX_D', 225]]) {
    const requestId = ++mapRequest.current;
    await load({ job_id: 'spx-30', title: '2026-10-30 21:51 Australia/Sydney' }, code, requestId);
    assert.equal(selection.stockCode, code);
    assert.equal(selection.resistances[0].details.mapping_selected_close, close);
    assert.equal(selection.resistances[0].details.source_spx_anchor, 7723.8175);
    assert.ok(selection.resistances[0].price < 1000, 'semiconductor chart may not plot raw SPX points');
    assert.ok(selection.mappingSource.includes(code.replace('_D', '/SPY')));
    assert.ok(requests.some((url) => url.includes(`/api/spx-map-live-extra-prices?symbol=${code.replace('_D', '')}`)));
  }
  extraQuoteUnavailable = true;
  const missingQuoteId = ++mapRequest.current;
  await load({ job_id: 'spx-30', title: '2026-10-30 21:51 Australia/Sydney' }, 'SOXX_D', missingQuoteId);
  assert.equal(selection.resistances.length, 0, 'missing target quote must fail closed, leaving only candles');
  assert.ok(selection.mappingError.includes('calibration unavailable'));
  assert.equal(requests.filter((url) => url.includes('/spx-map-options?')).length, optionsBeforeDerived);
  console.log('SPX and derived ES/ETF chart loaders use correct candles, dated closes and fail-closed IB calibration');
})().catch((error) => { console.error(error); process.exitCode = 1; });
