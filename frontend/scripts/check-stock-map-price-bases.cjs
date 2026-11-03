// Regression for prior-session daily close vs separately fetched live IB quote.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');

require.extensions['.tsx'] = (module, filename) => {
  const source = fs.readFileSync(filename, 'utf8');
  const javascript = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, target: ts.ScriptTarget.ES2022 },
    fileName: filename,
  }).outputText;
  module._compile(javascript, filename);
};
const { selectedClose, StockZonePriceCells, StockZonePriceHeaders } = require(path.join(__dirname, '../src/app/stock-map-reports/[jobId]/mapped-levels/priceComparison.tsx'));
const report = { ticker: 'QQQ', execution_reference: 713.6, execution_reference_type: 'intraday_stock' };
const quote = { last_close: 704.47, last_close_source: 'last_completed_daily_close', last_close_observation_date: '2026-10-30', live_price: 704.47, live_price_source: 'ib' };
const selected = selectedClose(report, quote);
assert.equal(selected.value, 704.47, 'Selected close must use the previous completed daily close, not the report execution reference');
assert.match(selected.source, /last completed daily close.*2026-10-30/i);
const html = renderToStaticMarkup(React.createElement('table', null,
  React.createElement('thead', null, React.createElement('tr', null, React.createElement(StockZonePriceHeaders, { isNative30m: selected.isNative30m, fromReport: selected.fromReport }))),
  React.createElement('tbody', null, React.createElement('tr', null,
    React.createElement(StockZonePriceCells, { low: 700, high: 720, mid: 710,
      close: selected.value, closeSource: selected.source, livePrice: quote.live_price, livePriceSource: quote.live_price_source })))));
assert.match(html, /Selected close/);
assert.match(html, /System zone \(vs selected close\)/);
assert.match(html, /System zone \(vs Live Price\)/);
assert.doesNotMatch(html, /Reference anchor \(vs 30M close\)/);
const cells = html.match(/<td\b[^>]*>[\s\S]*?<\/td>/g);
assert.equal(cells.length, 4);
assert.match(cells[0], /704\.47/);
assert.match(cells[1], /704\.47/);
assert.match(cells[2], /700\.00[^<]*<span[^>]*>\(-0\.63%\)<\/span>[\s\S]*720\.00[^<]*<span[^>]*>\(\+2\.20%\)<\/span>/);
assert.match(cells[3], /700\.00[^<]*<span[^>]*>\(-0\.63%\)<\/span>[\s\S]*720\.00[^<]*<span[^>]*>\(\+2\.20%\)<\/span>/);
const missing = selectedClose({ ticker: 'QQQ' }, { last_close: 703, live_price: null });
assert.equal(missing.value, 703, 'Reports use the backend previous-daily-close fallback');
assert.equal(selectedClose({ execution_reference: 725.21, execution_reference_type: 'prior_session_close' }, quote).value, 704.47);
assert.equal(selectedClose({ execution_reference: 0 }, { last_close: 703 }).value, 703);
assert.equal(selectedClose({ execution_reference: 713.6 }, { live_price: null }).value, null);
const pageSource = fs.readFileSync(path.join(__dirname, '../src/app/stock-map-reports/[jobId]/mapped-levels/page.tsx'), 'utf8');
assert.match(pageSource, /selectedClose\(mapData, stockPrices\)/);
assert.match(pageSource, /pricesUrl\.searchParams\.set\("as_of_et", asOfEt\)/);
assert.match(pageSource, /<StockZonePriceHeaders \/>/);
assert.match(pageSource, /<StockZonePriceCells[^>]*close=\{mapped\.selectedClose\}[^>]*livePrice=\{mapped\.livePrice\}/);
console.log('PASS: mapped zone prices compare to the prior-session daily close and live IB quote independently');
