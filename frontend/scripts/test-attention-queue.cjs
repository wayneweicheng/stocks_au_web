const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const React = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
require.extensions['.ts'] = require.extensions['.tsx'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true } }).outputText, filename);
const AttentionQueue = require('../src/app/components/AttentionQueue.tsx').default;
const html = renderToStaticMarkup(React.createElement(AttentionQueue, {
  market: 'US', selectedDate: '2026-11-06', regime: { as_of: '2026-11-05', components: [{ available: false }, { available: true }] },
  opportunities: [{ symbol: 'SPXL', risks: ['Price near a resistance cluster'] }],
}));
assert.match(html, /regime input/);
assert.match(html, /Regime date differs/);
assert.match(html, /SPXL: review contrary evidence/);
assert.match(html, /Current IB|IB account: current snapshot/);
assert.doesNotMatch(html, /place-order|Place orders automatically/);
const source = fs.readFileSync(path.join(__dirname, '../src/app/components/AttentionQueue.tsx'), 'utf8');
assert.match(source, /\/api\/ib\/account-risk/);
assert.match(source, /IB account status unavailable/);
assert.match(source, /setAccountStatus\("unavailable"\); controller\.abort\(\)/);
console.log('Attention queue states evidence and IB availability without trading actions');
