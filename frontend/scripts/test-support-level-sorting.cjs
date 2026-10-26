const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const { sortedLevelEntries, topPercentEntries, sortLevelEntries } = require(path.join(__dirname, '../src/app/support-resistance/levelSorting.ts'));
const levels = [{ price: 700, score: 30 }, { price: 740, score: 88 }, { price: 711, score: null }, { price: 709, score: 88 }];
const entries = (mode, reference = 710) => sortedLevelEntries(levels, mode, reference, (zone) => zone.score);
assert.deepEqual(entries('quality').map((e) => e.originalIndex), [3, 1, 0, 2]);
assert.deepEqual(entries('distance').map((e) => e.originalIndex), [3, 2, 0, 1]);
assert.deepEqual(entries('quality', null).map((e) => e.originalIndex), [1, 3, 0, 2]);
const ranked = [{ price: 699, strength_rank: 2 }, { price: 705, strength_rank: 1 }];
assert.deepEqual(sortedLevelEntries(ranked, 'quality', 700, (z) => z.strength_rank > 0 ? z.strength_rank : null, false).map((e) => e.originalIndex), [1, 0]);
// Ties remain stable and never lose the original chart->card identity.
assert.deepEqual(sortedLevelEntries([{ price: 700, score: 5 }, { price: 700, score: 5 }], 'quality', 700, (z) => z.score).map((e) => e.originalIndex), [0, 1]);
const example = [35, 26, 3, 45, 28, 56, 9, 26, 7].map((score, i) => ({ score, price: 700 + i }));
const top = (percent) => topPercentEntries(example, percent, (zone) => zone.score);
assert.deepEqual(top(100).map((entry) => entry.originalIndex), [0, 1, 2, 3, 4, 5, 6, 7, 8]);
assert.deepEqual(top(50).map((entry) => entry.originalIndex), [0, 1, 3, 4, 5]); // ceil(9/2) = 5
assert.deepEqual(top(10).map((entry) => entry.originalIndex), [5]);
assert.deepEqual(top(0), []);
assert.deepEqual(sortLevelEntries(top(50), 'quality', 700, (zone) => zone.score).map((entry) => entry.originalIndex), [5, 3, 0, 4, 1]);
assert.deepEqual(sortLevelEntries(top(50), 'distance', 700, (zone) => zone.score).map((entry) => entry.originalIndex), [0, 1, 3, 4, 5]);
assert.deepEqual(topPercentEntries(ranked, 50, (zone) => zone.strength_rank, false).map((entry) => entry.originalIndex), [1]);
assert.deepEqual(topPercentEntries([{ score: null }, { score: 12 }], 50, (z) => z.score).map((entry) => entry.originalIndex), [1]);
const page = fs.readFileSync(path.join(__dirname, '../src/app/support-resistance/page.tsx'), 'utf8');
assert.match(page, /useState<Record<"support" \| "resistance", LevelSort>>\(\{ support: "quality", resistance: "quality" \}\)/);
assert.match(page, /topPercentEntries\(/);
assert.match(page, /id=\{levelPanelId\("stock-map", side, originalIndex\)\}/);
assert.match(page, /for \(const \{ level: zone, originalIndex: index \} of supports\)/);
assert.match(page, /for \(const \{ level: zone, originalIndex: index \} of resistances\)/);
assert.match(page, /visibleSide\(side\)\.map\(\(\{ level: zone, originalIndex \}\)/);
assert.match(page, /percentBySide=\{levelPercent\}/);
assert.match(page, /min=\{0\} max=\{100\} step=\{1\}/);
console.log('Score/rank and reference-distance sorting preserves chart target indices: OK');
