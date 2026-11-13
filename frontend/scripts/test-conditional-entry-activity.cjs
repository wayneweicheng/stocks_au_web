const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { formatActivityTimestamp, matchesActivityFilters, waitingForReversalMessage } = require('../src/app/pegasus-conditional-entries/activityStatus.ts');

const page = fs.readFileSync(path.join(__dirname, '../src/app/pegasus-conditional-entries/page.tsx'), 'utf8');
assert.match(page, /waitingForReversalMessage\(row\)/);
assert.match(page, /formatActivityTimestamp\(row\.ObservedAtUtc\)/);
assert.match(page, /Attempt status/);
assert.match(page, /Outbox mode/);
assert.match(page, /formatActivityTimestamp\(lastRefreshedAt\)/);
assert.doesNotMatch(page, /new Date\(row\.ObservedAtUtc\)\.toLocaleString\(\)/);
assert.match(page, /row\.TargetCursorRegion === "WAITING_FOR_REVERSAL"/);
assert.match(page, /Execution-enabled dry run/);
assert.match(page, /logs WOULD_SUBMIT decisions only/);
assert.match(page, /SIMULATED without changing the Trade Intent or contacting IB/);

const buy = {
  Status: 'PENDING', Side: 'B', TargetPriceActivationMode: 'TOUCH_THEN_RETRACE',
  TargetPriceThreshold: 683.5, TargetPriceTickSize: 0.01,
  TargetCursorRegion: 'WAITING_FOR_REVERSAL', TargetTouchPrice: 683.45,
  AttemptState: null,
};
assert.equal(waitingForReversalMessage(buy),
  'Target price touched at $683.45; waiting for a fresh last-trade price of $683.51 or higher to confirm reversal. No claim yet.');
assert.equal(waitingForReversalMessage({ ...buy, Side: 'S', TargetPriceThreshold: 100, TargetTouchPrice: 100.05 }),
  'Target price touched at $100.05; waiting for a fresh last-trade price of $99.99 or lower to confirm reversal. No claim yet.');
assert.equal(waitingForReversalMessage({ ...buy, Status: 'CANCELLED' }), null);
assert.equal(waitingForReversalMessage({ ...buy, TargetCursorRegion: 'OUTSIDE' }), null);
assert.equal(waitingForReversalMessage({ ...buy, TargetPriceActivationMode: 'IMMEDIATE' }), null);
assert.equal(waitingForReversalMessage({ ...buy, TargetTouchPrice: null }), null);
assert.equal(waitingForReversalMessage({ ...buy, AttemptState: 'BLOCKED' }),
  waitingForReversalMessage(buy));
assert.equal(formatActivityTimestamp('2026-11-13T19:45:51.242000'),
  'Sydney: 14/11/2026, 06:45:51 AEDT (US market: 13/11/2026, 14:45:51 EST)');
assert.equal(formatActivityTimestamp('2026-11-13T19:45:51.242Z'),
  'Sydney: 14/11/2026, 06:45:51 AEDT (US market: 13/11/2026, 14:45:51 EST)');
assert.equal(formatActivityTimestamp('not-a-timestamp'), 'Unknown time');
assert.equal(matchesActivityFilters(
  { AttemptState: 'BLOCKED', EvaluatorMode: 'EXECUTION_ENABLED' },
  { attemptStatus: 'BLOCKED', outboxMode: 'EXECUTION_ENABLED' },
), true);
assert.equal(matchesActivityFilters(
  { AttemptState: null, EvaluatorMode: null },
  { attemptStatus: 'NONE', outboxMode: 'NONE' },
), true);
assert.equal(matchesActivityFilters(
  { AttemptState: 'ACCEPTED', EvaluatorMode: 'EXECUTION_ENABLED' },
  { attemptStatus: 'BLOCKED', outboxMode: 'ALL' },
), false);
console.log('Conditional Entry activity status tests passed');
