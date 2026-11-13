import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import ts from "typescript";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const compile = (relativePath) => {
  const source = fs.readFileSync(path.join(scriptDir, relativePath), "utf8");
  return ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText;
};
const loadModule = (relativePath) => {
  const context = { exports: {} };
  vm.runInNewContext(compile(relativePath), context);
  return context.exports;
};
const plain = (values) => Array.from(values);

const { orderWeights, buyOrderVolumes, sellOrderVolumes } = loadModule("../src/app/pegasus-conditional-entries/orderSizing.ts");
assert.deepEqual(plain(orderWeights(3, "Even", 1.15)), [1 / 3, 1 / 3, 1 / 3]);
assert.deepEqual(plain(buyOrderVolumes(30000, [268.38, 268.38, 268.38], orderWeights(3, "Even", 1.15))), [38, 38, 38]);
assert.deepEqual(plain(sellOrderVolumes(10, orderWeights(3, "Even", 1.15))), [4, 3, 3]);
assert.equal(sellOrderVolumes(2, orderWeights(3, "Even", 1.15)).length, 0);
assert.equal(buyOrderVolumes(0, [100], [1]).length, 0);
assert.equal(sellOrderVolumes(10, []).length, 0);

const { targetPriceTiers, referencePriceTiers } = loadModule("../src/app/pegasus-conditional-entries/triggerTiers.ts");
assert.deepEqual(plain(targetPriceTiers(100, 110, 3, "B")), [110, 105, 100]);
assert.deepEqual(plain(targetPriceTiers(110, 100, 3, "B")), [110, 105, 100]);
assert.deepEqual(plain(targetPriceTiers(110, 100, 3, "S")), [100, 105, 110]);
assert.deepEqual(plain(referencePriceTiers(7404.25, 7400.5, 3, "B")), [7404.25, 7402.25, 7400.5]);
assert.deepEqual(plain(referencePriceTiers(7400.5, 7404.25, 3, "S")), [7400.5, 7402.5, 7404.25]);
assert.deepEqual(plain(referencePriceTiers(7400.5, 7400.75, 3, "B")), []);

const page = fs.readFileSync(path.join(scriptDir, "../src/app/pegasus-conditional-entries/page.tsx"), "utf8");
assert.match(page, /Number of Orders/);
assert.ok(page.includes("Total Amount (USD)"));
assert.ok(page.includes("Total Volume (shares)"));
assert.match(page, /Trigger stock price condition/);
assert.doesNotMatch(page, /Number of tranches|Target stock price condition/);
assert.match(page, /triggerSource === "TARGET_STOCK" \? \{ target_price:/);
assert.match(page, /triggerSource === "TARGET_STOCK" \|\| targetLivePrice != null/);

const rangePage = fs.readFileSync(path.join(scriptDir, "../src/app/range-orders/page.tsx"), "utf8");
assert.ok(rangePage.includes('<label className="block text-sm mb-1 text-slate-600">Start Price</label>'));
assert.ok(rangePage.includes('<label className="block text-sm mb-1 text-slate-600">End Price</label>'));
assert.match(rangePage, /aria-label="Move start and end price up by 25 cents"/);
assert.match(rangePage, /aria-label="Move start and end price down by 25 cents"/);
const { generateLinearPricesInclusive } = loadModule("../src/app/range-orders/priceLadder.ts");
assert.deepEqual(plain(generateLinearPricesInclusive(110, 100, 3, "Buy")), [100, 105, 110]);
assert.deepEqual(plain(generateLinearPricesInclusive(100, 110, 3, "Sell")), [100, 105, 110]);
assert.deepEqual(plain(generateLinearPricesInclusive(110, 100, 1, "Buy")), [100]);
assert.deepEqual(plain(generateLinearPricesInclusive(110, 100, 1, "Sell")), [110]);
console.log("Conditional Entry sizing tests passed");
