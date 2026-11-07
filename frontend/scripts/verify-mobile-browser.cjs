// Optional local Edge smoke test. Uses fixture API responses and a fake localStorage
// login to exercise responsive layout; does not contact a real IB account.
const assert = require('node:assert/strict');
const { spawn, execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const edgePath = process.env.EDGE_PATH || 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
if (!fs.existsSync(edgePath)) { console.log('Edge unavailable; browser smoke test skipped'); process.exit(0); }
const port = 19241;
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'stocks-au-edge-'));
const browser = spawn(edgePath, [`--headless=new`, `--remote-debugging-port=${port}`, `--user-data-dir=${profile}`, '--no-first-run', '--disable-gpu', 'about:blank'], { stdio: 'ignore' });
let socket;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function ready() {
  for (let i = 0; i < 50; i++) {
    try { const response = await fetch(`http://127.0.0.1:${port}/json/new?about:blank`, { method: 'PUT' }); if (response.ok) return response.json(); } catch { /* Starting. */ }
    await sleep(200);
  }
  throw new Error('Could not start headless Edge');
}
async function main() {
  const tab = await ready();
  socket = new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });
  let nextId = 0;
  const pending = new Map();
  function send(method, params = {}) { return new Promise((resolve, reject) => { const id = ++nextId; pending.set(id, { resolve, reject }); socket.send(JSON.stringify({ id, method, params })); }); }
  socket.addEventListener('message', async ({ data }) => {
    const event = JSON.parse(data);
    if (event.id && pending.has(event.id)) { const task = pending.get(event.id); pending.delete(event.id); event.error ? task.reject(new Error(event.error.message)) : task.resolve(event.result); }
    if (event.method !== 'Fetch.requestPaused') return;
    const url = event.params.request.url;
    let response = null;
    if (url.includes('/api/stock-map-reports/fixture-1/json') || url.includes('/api/stock-map-reports/fixture-2/json')) response = { data: { content: { stock_code: url.includes('fixture-2') ? 'NVDA' : 'SPXL', as_of_et: '2026-11-07T09:30:00-05:00', primary_supports: [{ rank: 1, zone_low: 240, zone_high: 241, total_score: 90 }], primary_resistances: [{ rank: 1, zone_low: 251, zone_high: 252, total_score: 85 }] } } };
    else if (url.includes('/api/stock-map-reports')) response = { items: [{ job_id: 'fixture-1', title: 'SPXL map', stock_code: 'SPXL', status: 'succeeded', created_at: '2026-11-07T12:00:00Z' }, { job_id: 'fixture-2', title: 'NVDA map', stock_code: 'NVDA', status: 'succeeded', created_at: '2026-11-07T12:00:00Z' }] };
    else if (url.includes('/api/stock-map-live-prices')) response = { prices: { SPXL: 245 }, price_sources: { SPXL: 'ib_live' }, price_times: { SPXL: '2026-11-07T12:00:00Z' } };
    else if (url.includes('/api/stock-map-live-price')) response = { live_price: 245, source: 'ib_live', fetched_at_utc: '2026-11-07T12:00:00Z' };
    else if (url.includes('/api/support-resistance/stock-map-bars') || url.includes('/api/support-resistance/chart-bars')) response = { bars: Array.from({ length: 15 }, (_, i) => ({ time: `2026-11-06T${String(i + 1).padStart(2, '0')}:00:00`, open: 245, high: 246, low: 244, close: 245, volume: 1000 })) };
    else if (url.includes('/api/market-command/summary')) { const date = new URL(url).searchParams.get('observation_date'); response = { requested_date: date, generated_at: '2026-11-07T12:00:00Z', regimes: { US: { as_of: date, label: 'NEUTRAL', score: 50, confidence: 50, components: [], supporting_factors: [], conflicting_factors: [], trading_implication: '' } }, opportunities: { US: [] } }; }
    else if (url.includes('/api/ib/account-risk')) response = { ok: true, as_of: '2026-11-07T12:00:00Z', metrics: { excess_liquidity: 1000 }, open_orders: [] };
    try {
      if (response !== null) await send('Fetch.fulfillRequest', { requestId: event.params.requestId, responseCode: 200, responseHeaders: [{ name: 'content-type', value: 'application/json' }], body: Buffer.from(JSON.stringify(response)).toString('base64') });
      else await send('Fetch.continueRequest', { requestId: event.params.requestId });
    } catch { /* Navigation can cancel a paused request before fulfillment. */ }
  });
  await send('Page.enable');
  await send('Runtime.enable');
  await send('Fetch.enable', { patterns: [{ urlPattern: '*api/*' }] });
  await send('Page.addScriptToEvaluateOnNewDocument', { source: `try { localStorage.setItem('auth', JSON.stringify({ username: 'fixture', credentials: { username: 'fixture', password: 'fixture' } })); } catch {}` });
  async function evaluate(expression) { const result = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true }); if (result.exceptionDetails) throw new Error(result.exceptionDetails.text); return result.result.value; }
  async function navigate(route, width) {
    await send('Emulation.setDeviceMetricsOverride', { width, height: 812, deviceScaleFactor: 1, mobile: width < 768 });
    await send('Page.navigate', { url: `http://localhost:3100${route}` });
    for (let i = 0; i < 60; i++) { await sleep(150); if (await evaluate(`document.readyState === 'complete' && !!document.querySelector('main')`)) return; }
    throw new Error(`Page did not mount: ${route}`);
  }
  await navigate('/stock-level-overview', 375);
  for (let i = 0; i < 40 && !(await evaluate(`Array.from(document.querySelectorAll('article')).some((node) => node.textContent.includes('SPXL'))`)); i++) await sleep(150);
  assert.equal(await evaluate(`document.querySelector('[aria-label="Mobile quick tools"]')?.getBoundingClientRect().height > 0`), true);
  assert.equal(await evaluate(`Array.from(document.querySelectorAll('article')).some((node) => node.textContent.includes('SPXL'))`), true);
  assert.equal(await evaluate(`document.documentElement.scrollWidth <= window.innerWidth + 1`), true);
  await evaluate(`document.querySelector('button[aria-label="Search stock symbol"]').click()`);
  await sleep(150);
  assert.equal(await evaluate(`document.querySelector('form[role="search"]').getBoundingClientRect().width < window.innerWidth`), true);
  await navigate('/stock-map-reports', 375);
  assert.equal(await evaluate(`document.getElementById('mobile-report-picker')?.getBoundingClientRect().height > 0`), true);
  await navigate('/stock-level-overview', 320);
  assert.equal(await evaluate(`document.documentElement.scrollWidth <= window.innerWidth + 1`), true);
  await navigate('/stock-level-overview', 768);
  assert.equal(await evaluate(`document.querySelector('table')?.getBoundingClientRect().height > 0`), true);
  await navigate('/stock-level-overview', 1280);
  assert.equal(await evaluate(`document.querySelector('table')?.getBoundingClientRect().height > 0`), true);
  console.log('Headless Edge: 320/375px cards/navigation/report picker and 768/1280px table OK (chart ticks covered by unit test)');
}
main().catch((error) => { console.error(error); process.exitCode = 1; }).finally(() => {
  socket?.close();
  if (browser.pid) { try { execFileSync('taskkill', ['/F', '/T', '/PID', String(browser.pid)], { stdio: 'ignore' }); } catch { browser.kill(); } }
  try { fs.rmSync(profile, { recursive: true, force: true, maxRetries: 3 }); } catch { /* Edge may still be releasing files. */ }
});
