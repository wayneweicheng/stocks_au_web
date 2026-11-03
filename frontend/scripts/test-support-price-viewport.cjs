const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const { priceWindowForBars, priceBottomForScroll } = require(path.join(__dirname, '../src/app/support-resistance/priceViewport.ts'));
const bars = [{ high: 751, low: 744, close: 748 }, ...Array.from({ length: 34 }, (_, index) => ({ high: 712 + index % 3, low: 703, close: 707 }))];
const zones = [{ price: 714, range_low: 713, range_high: 715 }, { price: 700, range_low: 698, range_high: 702 }];
const window = priceWindowForBars(bars, zones);
assert.ok(window.contentHeight > window.trackHeight, 'older 751 high should require a price scrollbar');
assert.ok(window.span >= (window.maximum - window.minimum) * 0.42 - 1e-8, 'default view should show a wider portion of the price domain');
assert.ok(window.bottom + window.span < window.maximum, 'initial price window should remove blank space above nearby resistance');
assert.ok(window.bottom + window.span >= 715, 'nearby resistance should remain visible');
assert.ok(window.bottom <= 707 && window.bottom + window.span >= 707, 'latest candle must be in view');
assert.ok(Math.abs(priceBottomForScroll(window, window.initialScrollTop) - window.bottom) < 1e-8);
assert.ok(Math.abs(priceBottomForScroll(window, 0) + window.span - window.maximum) < 1e-8, 'scroll up reveals older highs');
assert.ok(Math.abs(priceBottomForScroll(window, window.contentHeight - window.trackHeight) - window.minimum) < 1e-8, 'scroll down reveals lows');
assert.equal(priceWindowForBars([], zones), null);
const withStraddleBand = priceWindowForBars(bars, [...zones, { price: 694, range_low: 690, range_high: 698 }]);
assert.ok(withStraddleBand.minimum < 690, 'price scrollbar should include the full yellow option band');
const page = fs.readFileSync(path.join(__dirname, '../src/app/support-resistance/page.tsx'), 'utf8');
assert.match(page, /priceWindowForBars\(visibleBars, zones\)/);
assert.match(page, /range: \[priceWindow\.bottom, priceWindow\.bottom \+ priceWindow\.span\]/);
assert.match(page, /onScroll=\{handlePriceScroll\}/);
assert.match(page, /relayout\(plotRef\.current, \{ "yaxis\.range": \[bottom, bottom \+ priceWindow\.span\] \}\)/);
assert.match(page, /Visible price:/);
console.log('Price-axis scroll centers recent levels and preserves earlier highs: OK');
