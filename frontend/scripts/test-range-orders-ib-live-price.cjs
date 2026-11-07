const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, filename);
const { ibLivePriceFromResponse } = require('../src/app/range-orders/ibLivePrice.ts');
assert.equal(ibLivePriceFromResponse({ stock_code: 'SPXL', live_price: 244.67, source: 'ib_live' }, 'SPXL.US'), 244.67);
for (const payload of [
  { stock_code: 'SPXL', live_price: 244.67, source: 'ib_delayed' },
  { stock_code: 'SPXL', live_price: 244.67, source: 'ib_futures_close' },
  { stock_code: 'SPY', live_price: 244.67, source: 'ib_live' },
  { stock_code: 'SPXL', live_price: 0, source: 'ib_live' },
  { stock_code: 'SPXL', live_price: null, source: 'ib_live' },
  { stock_code: 'SPXL', live_price: '244.67', source: 'ib_live' },
  null,
]) assert.equal(ibLivePriceFromResponse(payload, 'SPXL'), null);
const page = fs.readFileSync(path.join(__dirname, '../src/app/range-orders/page.tsx'), 'utf8');
assert.match(page, /api\/stock-map-live-price\?stock_code=/);
assert.match(page, /IB live price:/);
assert.match(page, /ibLiveQuote\?\.symbol === stockCode\.trim\(\)\.toUpperCase\(\)/);
assert.match(page, /: "N\/A"/);
console.log('Range orders IB live display is isolated from DB and rejects unavailable/delayed quotes');
