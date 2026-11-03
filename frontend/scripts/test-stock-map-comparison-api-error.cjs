const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');

const source = fs.readFileSync(path.join(__dirname, '../src/app/stock-map-reports/comparisonApiError.ts'), 'utf8');
const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
const context = { exports: {} };
vm.runInNewContext(js, context);
const { comparisonApiError } = context.exports;

const runner422 = { detail: [
  { loc: ['body', 'D1'], msg: 'Field required', input: { stock_code: 'QQQ', private_note: 'do not render this payload' } },
  { loc: ['body', 'D2'], msg: 'Field required', input: { stock_code: 'QQQ' } },
  { loc: ['body', 'execution_policy'], msg: 'Input should be a valid dictionary', input: 'recommendations_only_no_order_placement' },
] };
assert.equal(comparisonApiError(runner422, 422), 'D1: Field required; D2: Field required; execution_policy: Input should be a valid dictionary');
assert.equal(comparisonApiError({ detail: 'No completed Stock Map JSON for QQQ' }, 422), 'No completed Stock Map JSON for QQQ');
assert.equal(comparisonApiError({}, 503), 'HTTP 503');
assert.equal(comparisonApiError({ detail: [{ loc: ['body', 'D1'], msg: 'Field required', input: { secret: 'never-print' } }] }, 422).includes('never-print'), false);
console.log('Stock Map comparison displays validation errors without [object Object] or raw request bodies');
