const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');
const file = path.resolve(__dirname, '../src/app/components/MappedLevelReportDetails.tsx');
const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX },
}).outputText;
const mod = new Module(file, module);
mod.require = (id) => id === 'react/jsx-runtime'
  ? { jsx: (type, props) => ({ type, ...props }), jsxs: (type, props) => ({ type, ...props }), Fragment: 'fragment' }
  : require(id);
mod._compile(code, file);
const details = mod.exports.default({
  side: 'support', spxLastClose: 7700, detail: {
    level: 'S6', optionVerification: 'SPXW put wall + GEX · SPX 7,670.00 · 0DTE',
    distanceToPreviousClose: '-1.10%', executionStrength: '', mainBasis: '', behavior: '',
  },
});
assert.match(details.children[0].children, /前收 7,700\.00 -1\.10%/);
console.log('Compact SPX 前收 shows the SPX last-close price and distance: OK');
