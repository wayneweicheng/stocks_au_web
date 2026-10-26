const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const { clickedLevelPanelId, levelPanelId } = require(path.join(__dirname, '../src/app/support-resistance/chartLevelNavigation.ts'));
const a = levelPanelId('stock-map', 'support', 0);
const b = levelPanelId('stock-map', 'resistance', 0);
assert.notEqual(a, b);
assert.notEqual(levelPanelId('calculated', 'support', 0), a);
const traces = [null, null, a, a, b, b]; // Price, volume, line, band, line, band
for (const curveNumber of [2, 3]) assert.equal(clickedLevelPanelId({ points: [{ curveNumber }] }, traces), a);
for (const curveNumber of [4, 5]) assert.equal(clickedLevelPanelId({ points: [{ curveNumber }] }, traces), b);
for (const curveNumber of [0, 1, 6]) assert.equal(clickedLevelPanelId({ points: [{ curveNumber }] }, traces), null);
assert.equal(clickedLevelPanelId({ points: [] }, traces), null);
// Guard the real chart/panel seam, not only the event parser.
const page = fs.readFileSync(path.join(__dirname, '../src/app/support-resistance/page.tsx'), 'utf8');
assert.match(page, /traceTargets\.push\(target, target\)/);
assert.match(page, /on\("plotly_click", jumpToLevel\)/);
assert.match(page, /id=\{levelPanelId\("stock-map", side, originalIndex\)\}/);
assert.match(page, /id=\{levelPanelId\(tab, "support", originalIndex\)\}/);
assert.match(page, /id=\{levelPanelId\(tab, "resistance", originalIndex\)\}/);
assert.match(page, /x: bars\.map\(\(bar\) => bar\.time\)/);
console.log('Chart level navigation targets line and band without ordering from price or rank: OK');
