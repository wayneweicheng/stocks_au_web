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
assert.ok(layout && ts.isObjectLiteralExpression(layout), 'must inspect the actual Plotly layout');
const xaxis = layout.properties.find((node) => ts.isPropertyAssignment(node) && node.name.getText(file) === 'xaxis');
assert.ok(xaxis, 'chart needs an x axis');
const text = xaxis.getText(file);
assert.match(text, /range:\s*\[-0\.5,\s*bars\.length\s*-\s*0\.5\]/, 'Last candle must end at the right edge, not leave a large empty future range');
assert.match(text, /markerPosition\s*>=\s*bars\.length[\s\S]*range:\s*\[-0\.5,\s*bars\.length\s*\+\s*0\.5\]/, 'Keep one candle of space for a future as-at marker');
console.log('Chart category x range ends at last candle (or immediately after a future marker)');
