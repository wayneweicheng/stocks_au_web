const assert = require('node:assert/strict');
const fs = require('node:fs');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
}).outputText, filename);
const { confirmReportDeletion } = require('../src/app/components/confirmReportDeletion.ts');
const messages = [];
assert.equal(confirmReportDeletion('SPX map', 'job-1', (message) => { messages.push(message); return true; }), true);
assert.equal(messages.length, 2);
assert.match(messages[0], /Delete report "SPX map"/);
assert.match(messages[1], /confirm again/);
let calls = 0;
assert.equal(confirmReportDeletion('Stock map', 'job-2', () => ++calls === 1), false);
assert.equal(calls, 2);
assert.equal(confirmReportDeletion('Stock map', 'job-2', () => { calls++; return false; }), false);
assert.equal(calls, 3);
console.log('Report deletion requires two confirmations and respects cancellation');
