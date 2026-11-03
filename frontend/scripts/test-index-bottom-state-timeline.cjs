const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
const ts = require('typescript');

const originalLoad = Module._load;
Module._load = function (request, parent, isMain) {
  if (request.endsWith('/authenticatedFetch')) return { authenticatedFetch: () => Promise.reject(new Error('not used')) };
  if (request.endsWith('/Alert') || request.endsWith('/Button')) return { default: () => null };
  return originalLoad.call(this, request, parent, isMain);
};
require.extensions['.tsx'] = (module, filename) => {
  const source = fs.readFileSync(filename, 'utf8');
  module._compile(ts.transpileModule(source, { fileName: filename, compilerOptions: {
    module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, target: ts.ScriptTarget.ES2022,
  } }).outputText, filename);
};
const sourcePath = path.join(__dirname, '../src/app/find-index-bottoms-reports/IndexBottomStatesTab.tsx');
const { PriceTable } = require(sourcePath);
const close = (price, date) => ({ price, timeframe: '5M', bar_end_et: date });
const changes = {
  '1': { date: '2026-11-02', close: close(105, '2026-11-02T16:00:00-05:00'), percent: 5 },
  '2': { date: '2026-11-03', close: null, percent: null },
};
const item = { job_id: 'one', as_of_et: '2026-10-30T16:09:00-04:00', state: 'Core state: Early watch',
  description: 'QQQ oversold', score: 25, prices: {
    SPY: { base: close(100, '2026-10-30T16:05:00-04:00'), returns: changes },
    QQQ: { base: close(200, '2026-10-30T16:05:00-04:00'), returns: changes },
  },
};
const html = renderToStaticMarkup(React.createElement(PriceTable, { item }));
for (const label of ['SPY', 'QQQ', 'D1', 'D2', 'D3', 'D5', 'D10', '100.00', '200.00', '+5.00%']) assert.ok(html.includes(label), label);
assert.match(html, /2026-11-02 cash close/);
assert.match(html, /No completed close on 2026-11-03/);
const page = fs.readFileSync(path.join(__dirname, '../src/app/find-index-bottoms-reports/page.tsx'), 'utf8');
assert.match(page, /extraTabs=\{\[\{ key: "states"/);
assert.match(page, /<IndexBottomStatesTab\s*\/>/);
const tab = fs.readFileSync(sourcePath, 'utf8');
assert.match(tab, /<details[\s\S]*?<summary[^>]*>Report reasoning, score and evidence completeness<\/summary>/);
assert.match(tab, /page=\$\{page\}&page_size=\$\{PAGE_SIZE\}/);
console.log('PASS: Find Index Bottoms paginated state tab renders both symbols, horizons, and collapsible report reasoning');
