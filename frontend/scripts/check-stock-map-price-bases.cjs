// Regression for report execution price vs separately fetched 30M close vs live IB quote.
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
const report = { ticker: 'QQQ', execution_reference: 713.6, execution_reference_type: 'completed_30m_bar' };
const quote = { last_close: 704.47, last_close_source: '30m_close', live_price: 704.47, live_price_source: 'ib' };
const selected = selectedClose(report, quote);
assert.equal(selected.value, 713.6, 'Selected close must be the report execution reference, not the separate current DB close');
assert.match(selected.source, /report|execution/i);
const html = renderToStaticMarkup(React.createElement('table', null,
  React.createElement('thead', null, React.createElement('tr', null, React.createElement(StockZonePriceHeaders, { isNative30m: selected.isNative30m, fromReport: selected.fromReport }))),
  React.createElement('tbody', null, React.createElement('tr', null,
    React.createElement(StockZonePriceCells, { low: 700, high: 720, mid: 710,
      close: selected.value, closeSource: selected.source, livePrice: quote.live_price, livePriceSource: quote.live_price_source })))));
assert.match(html, /Selected close \(30M/);
assert.match(html, /System zone \(vs 30M close\)/);
assert.match(html, /System zone \(vs Live Price\)/);
assert.doesNotMatch(html, /Reference anchor \(vs 30M close\)/);
const cells = html.match(/<td\b[^>]*>[\s\S]*?<\/td>/g);
assert.equal(cells.length, 4);
assert.match(cells[0], /713\.60/);
assert.match(cells[1], /704\.47/);
assert.match(cells[2], /700\.00[^<]*<span[^>]*>\(-1\.91%\)<\/span>[\s\S]*720\.00[^<]*<span[^>]*>\(\+0\.90%\)<\/span>/);
assert.match(cells[3], /700\.00[^<]*<span[^>]*>\(-0\.63%\)<\/span>[\s\S]*720\.00[^<]*<span[^>]*>\(\+2\.20%\)<\/span>/);
const missing = selectedClose({ ticker: 'QQQ' }, { last_close: 703, live_price: null });
assert.equal(missing.value, 703, 'Legacy reports without an execution reference retain the 30M DB fallback');
assert.equal(missing.fromReport, false);
assert.equal(selectedClose({ execution_reference: 725.21, execution_reference_type: 'prior_session_close' }, quote).isNative30m, false);
assert.equal(selectedClose({ execution_reference: 0 }, { last_close: 703 }).value, 703);
assert.equal(selectedClose({ execution_reference: 713.6 }, { live_price: null }).value, 713.6);
const pageSource = fs.readFileSync(path.join(__dirname, '../src/app/stock-map-reports/[jobId]/mapped-levels/page.tsx'), 'utf8');
assert.match(pageSource, /selectedClose\(mapData, stockPrices\)/);
assert.match(pageSource, /<StockZonePriceHeaders isNative30m=\{isNative30m\} fromReport=\{fromReport\} \/>/);
assert.match(pageSource, /<StockZonePriceCells[^>]*close=\{mapped\.selectedClose\}[^>]*livePrice=\{mapped\.livePrice\}/);
console.log('PASS: mapped zone prices compare to the report execution reference and the live IB quote independently');
