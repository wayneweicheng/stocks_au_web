import json, importlib.util, pathlib, math
p=pathlib.Path(__file__).parent
spec=importlib.util.spec_from_file_location("logic",p/"strategy_logic.py"); m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
f=json.load(open(p/"deterministic-fixtures.json"))
for x in f["fixtures"]:
    if x["kind"]=="BASE_SIGNAL":
        got=m.base_signal(x["input"]["CloseChangePct"],x["input"]["PCRChangePct"]); assert got==x["expected"],(x["id"],got)
    elif x["kind"]=="CLASSIFY":
        i=x["input"]; got=m.classify(i["base"],i.get("SC"),i.get("SCMed60"),i.get("SPShare"),i.get("SPP75"),i.get("Prior5D"),i.get("history",60)); assert got==x["expected"],(x["id"],got)
    elif x["kind"]=="EXIT":
        i=x["input"]; reason,price=m.short_first_touch(i["entry"],i["tp"],i["sl"],i["bar"]); assert reason==x["expected"]["exit_reason"] and abs(price-x["expected"]["exit_price"])<1e-9
print("deterministic core fixtures: PASS")
