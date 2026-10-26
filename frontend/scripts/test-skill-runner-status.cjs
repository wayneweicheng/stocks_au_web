const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
require.extensions['.ts'] = (module, filename) => {
  module._compile(ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 }, fileName: filename,
  }).outputText, filename);
};
const { formatBytes, usagePercent, snapshotAgeSeconds, formatAge, formatTime } =
  require(path.join(__dirname, '../src/app/skill-runner-status/format.ts'));
assert.equal(formatBytes(null), 'n/a');
assert.equal(formatBytes(undefined), 'n/a');
assert.equal(formatBytes(0), '0 B');
assert.equal(formatBytes(1280000000), '1.2 GiB');
assert.equal(formatBytes(1024 ** 2), '1.0 MiB');
assert.equal(usagePercent(null, 100), null);
assert.equal(usagePercent(10, null), null);
assert.equal(usagePercent(10, 0), null);
assert.equal(usagePercent(4150000000, 8250000000).toFixed(1), '50.3');
assert.equal(usagePercent(110, 100), 100);
const now = Date.parse('2026-10-25T08:15:15+00:00');
assert.equal(snapshotAgeSeconds('2026-10-25T08:15:00+00:00', now), 15);
assert.equal(snapshotAgeSeconds('invalid', now), null);
assert.equal(formatAge(15), '15s ago');
assert.equal(formatAge(90), '1m ago');
assert.equal(formatTime(null), 'n/a');
console.log('Skill runner status formatting OK');
