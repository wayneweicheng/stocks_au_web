const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const { chartMinimumWidth, chartLevelColor } = require(path.join(__dirname, '../src/app/support-resistance/chartLayout.ts'));
assert.equal(chartMinimumWidth(100, '30m'), 1160);
assert.equal(chartMinimumWidth(100, '5m'), 760);
assert.ok(chartMinimumWidth(1000, '5m') > chartMinimumWidth(100, '5m'));
assert.equal(chartLevelColor('support', 0), '#065f46');
assert.equal(chartLevelColor('resistance', 0), '#991b1b');
assert.equal(chartLevelColor('support', 8), '#6ee7b7');
const page = fs.readFileSync(path.join(__dirname, '../src/app/support-resistance/page.tsx'), 'utf8');
assert.match(page, /showlegend: false, \/\/ The responsive legend is rendered below the scrollable plot/);
assert.match(page, /overflow-x-auto/);
assert.match(page, /aria-label="Chart legend"/);
assert.match(page, /visibleSide\(side\)\.map\(\(\{ level: zone, originalIndex \}\)/);
assert.match(page, /chartMinimumWidth\(bars\.length, chartTimeframe\)/);
assert.match(page, /scrollLeft = viewport\.scrollWidth/);
console.log('Chart legend below a bar-sized, horizontally scrollable plot: OK');
