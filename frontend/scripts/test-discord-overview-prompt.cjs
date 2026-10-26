const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const ts = require('typescript');
const file = path.resolve(__dirname, '../src/app/discord-summary/page.tsx');
const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: {
  jsx: ts.JsxEmit.ReactJSX, module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020,
} }).outputText;
const states = [];
let cursor = 0;
let effects = [];
const ref = { current: 0 };
const calls = [];
const fetch = async (url) => {
  calls.push(String(url));
  return { ok: true, json: async () => String(url).includes('discord-summary-latest')
    ? { summary_date: '2026-10-20', summary_markdown: 'latest follower' }
    : { prompt: 'historical prompt', window_mode: 'selected_sydney_16_window', window_start: '2026-10-20T16:00:00+11:00', window_end: '2026-10-21T16:00:00+11:00' } };
};
const react = { useState: (init) => { const i = cursor++; if (!(i in states)) states[i] = typeof init === 'function' ? init() : init;
  return [states[i], (value) => { states[i] = typeof value === 'function' ? value(states[i]) : value; }]; },
  useCallback: f => f, useEffect: f => effects.push(f), useRef: () => ref };
const m = new Module(file, module);
m.require = (id) => {
  if (id === 'react') return react;
  if (id === 'react/jsx-runtime') return { jsx: (type, props) => ({ ...props, tag: type }), jsxs: (type, props) => ({ ...props, tag: type }), Fragment: 'fragment' };
  if (id.endsWith('authenticatedFetch')) return { authenticatedFetch: fetch };
  if (id === './promptWindow') {
    const childFile = path.resolve(path.dirname(file), 'promptWindow.ts');
    const child = new Module(childFile, m);
    child._compile(ts.transpileModule(fs.readFileSync(childFile, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText, childFile);
    return child.exports;
  }
  if (id.endsWith('llmModelOptions')) return { DEFAULT_MARKET_FLOW_MODEL: 'test', SHARED_MARKET_FLOW_MODEL_OPTIONS: [] };
  if (id.endsWith('MarkdownRenderer')) return { default: () => null };
  return require(id);
};
m._compile(code, file);
const render = () => { cursor = 0; effects = []; return m.exports.default(); };
function all(node, type, out = []) {
  if (Array.isArray(node)) { node.forEach(x => all(x, type, out)); return out; }
  if (!node || typeof node !== 'object') return out;
  if (node.tag === type) out.push(node);
  all(node.children, type, out);
  return out;
}
(async () => {
  states[0] = '2026-10-22';
  let tree = render();
  effects[0](); // auto-load latest follower summary, which is older than selected Overview date
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(states[0], '2026-10-22', 'auto-loading followers must not overwrite Overview date');
  tree = render();
  all(tree, 'button').find(b => b.children === 'Overview').onClick();
  tree = render();
  all(tree, 'input').find(input => input.type === 'date').onChange({ target: { value: '2026-10-21' } });
  tree = render();
  const prompt = all(tree, 'button').find(b => b.children === 'Get Selected 16:00 Prompt');
  assert.ok(prompt, 'date picker must select the historical prompt action');
  await prompt.onClick();
  const requested = calls.find(url => url.includes('/api/discord-summary-prompt'));
  assert.equal(new URL(requested, 'https://example.com').searchParams.get('observation_date'), '2026-10-21');
  console.log('Overview button sends selected date; follower auto-load does not override it: OK');
})().catch(err => { console.error(err); process.exitCode = 1; });
