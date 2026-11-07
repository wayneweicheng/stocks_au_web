const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const source = fs.readFileSync(path.join(__dirname, '../src/app/support-resistance/page.tsx'), 'utf8');
const file = ts.createSourceFile('page.tsx', source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
let layout;
function visit(node) {
  if (ts.isVariableDeclaration(node) && node.name.getText(file) === 'layout') layout = node.initializer;
  ts.forEachChild(node, visit);
}
visit(file);
assert.ok(layout, 'Test must exercise the actual Plotly layout');
const margin = layout.properties.find((node) => ts.isPropertyAssignment(node) && node.name.getText(file) === 'margin');
const match = margin?.getText(file).match(/r:\s*(\d+).*?r:\s*(\d+)/s);
assert.ok(match, 'Expected explicit mobile and desktop right margins');
const [mobile, desktop] = match.slice(1).map(Number);
assert.ok(mobile <= 50 && desktop <= 65, `Excess right blank space: ${mobile}px mobile, ${desktop}px desktop`);
assert.match(source, /aria-label="Visible level scores"/, 'Scores must remain visible independently of Plotly margins');
console.log('Support/resistance chart right gap is compact on desktop and mobile');
