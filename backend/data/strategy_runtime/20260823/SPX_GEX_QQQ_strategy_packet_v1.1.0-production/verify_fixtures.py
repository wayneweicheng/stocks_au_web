import json
from strategy_logic import classify
f=json.load(open("deterministic-fixtures.json"))
for x in f["fixtures"]:
    if x["id"].startswith("rg-"):
        got=classify(**x["inputs"]); assert got==x["expected"],(x["id"],got,x["expected"])
print("PASS")
