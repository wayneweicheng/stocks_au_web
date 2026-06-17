# Sell Put Spread Option Orders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a checkbox-based sell put spread mode to Option Orders that preserves the default cash-secured put behavior and submits a single IB combo spread with a linked 30% profit exit when enabled.

**Architecture:** Add pure backend helpers for spread math and validation, then expose a new `/api/ib/place-sell-put-spread` endpoint that builds an IB BAG combo order. Add a focused `/option-orders` Next page that supports current single-leg cash-secured put submission by default and switches to combo spread submission when `Sell put spread` is checked.

**Tech Stack:** FastAPI, Pydantic, ib_insync, Python `unittest`, Next.js 15, React 19, TypeScript.

---

## File Structure

- Create `backend/app/services/option_spread_order_service.py`
  - Owns spread validation, preview math, OCC option-symbol parsing, and IB-neutral data shapes.
- Create `backend/tests/test_option_spread_order_service.py`
  - Unit tests for validation, math, symbol parsing, and combo-leg intent.
- Modify `backend/app/routers/ib_orders.py`
  - Add option imports, request models, combo contract builders, and `/api/ib/place-sell-put-spread`.
- Create `frontend/src/app/option-orders/page.tsx`
  - Implements the Option Orders form, default cash-secured put path, spread checkbox path, preview, and submit branching.
- Modify `frontend/src/app/components/AppShell.tsx`
  - Add navigation entry for Option Orders.
- Modify `frontend/src/app/page.tsx`
  - Add dashboard card for Option Orders if the homepage uses cards for trading pages.

The visible repository does not currently contain a literal `price-levels-30m` route or existing `option-orders` page. This plan creates the Option Orders page and makes it query-param friendly so the support-zone page can link to it later with `stock_code`, `short_option_symbol`, `expiry`, `short_strike`, and `net_credit`.

---

### Task 1: Backend Spread Helper Tests

**Files:**
- Create: `backend/tests/test_option_spread_order_service.py`
- Create: `backend/tests/__init__.py`

- [ ] **Step 1: Create the backend test package**

Create `backend/tests/__init__.py` as an empty file.

- [ ] **Step 2: Write failing tests for spread parsing, validation, and preview math**

Create `backend/tests/test_option_spread_order_service.py`:

```python
import unittest

from app.services.option_spread_order_service import (
    OptionLeg,
    SellPutSpread,
    calculate_sell_put_spread_preview,
    parse_occ_option_symbol,
    validate_sell_put_spread,
)


class OptionSpreadOrderServiceTests(unittest.TestCase):
    def test_parse_occ_option_symbol(self):
        parsed = parse_occ_option_symbol("QQQ260116P00480000")

        self.assertEqual(parsed["underlying"], "QQQ")
        self.assertEqual(parsed["expiry"], "20260116")
        self.assertEqual(parsed["put_call"], "P")
        self.assertEqual(parsed["strike"], 480.0)

    def test_validate_sell_put_spread_accepts_vertical_put_credit_spread(self):
        spread = SellPutSpread(
            underlying="QQQ",
            quantity=2,
            short_leg=OptionLeg(
                option_symbol="QQQ260116P00480000",
                action="SELL",
                put_call="P",
                expiry="20260116",
                strike=480.0,
            ),
            long_leg=OptionLeg(
                option_symbol="QQQ260116P00470000",
                action="BUY",
                put_call="P",
                expiry="20260116",
                strike=470.0,
            ),
            net_credit=1.25,
            profit_exit_percent=30.0,
        )

        validated = validate_sell_put_spread(spread)

        self.assertEqual(validated.short_leg.action, "SELL")
        self.assertEqual(validated.long_leg.action, "BUY")
        self.assertEqual(validated.short_leg.strike, 480.0)
        self.assertEqual(validated.long_leg.strike, 470.0)

    def test_validate_rejects_long_strike_above_short_strike(self):
        spread = SellPutSpread(
            underlying="QQQ",
            quantity=1,
            short_leg=OptionLeg(
                option_symbol="QQQ260116P00480000",
                action="SELL",
                put_call="P",
                expiry="20260116",
                strike=480.0,
            ),
            long_leg=OptionLeg(
                option_symbol="QQQ260116P00490000",
                action="BUY",
                put_call="P",
                expiry="20260116",
                strike=490.0,
            ),
            net_credit=1.25,
            profit_exit_percent=30.0,
        )

        with self.assertRaises(ValueError) as ctx:
            validate_sell_put_spread(spread)

        self.assertIn("Short put strike must be greater than long put strike", str(ctx.exception))

    def test_preview_math_for_credit_spread(self):
        spread = SellPutSpread(
            underlying="QQQ",
            quantity=2,
            short_leg=OptionLeg(
                option_symbol="QQQ260116P00480000",
                action="SELL",
                put_call="P",
                expiry="20260116",
                strike=480.0,
            ),
            long_leg=OptionLeg(
                option_symbol="QQQ260116P00470000",
                action="BUY",
                put_call="P",
                expiry="20260116",
                strike=470.0,
            ),
            net_credit=1.25,
            profit_exit_percent=30.0,
        )

        preview = calculate_sell_put_spread_preview(spread)

        self.assertEqual(preview["width"], 10.0)
        self.assertEqual(preview["max_profit"], 250.0)
        self.assertEqual(preview["max_loss"], 1750.0)
        self.assertEqual(preview["breakeven"], 478.75)
        self.assertEqual(preview["profit_exit_debit"], 0.875)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```powershell
Set-Location backend
python -m unittest tests.test_option_spread_order_service -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'app.services.option_spread_order_service'`.

- [ ] **Step 4: Commit the failing tests**

```powershell
git add backend/tests/__init__.py backend/tests/test_option_spread_order_service.py
git commit -m "test: cover sell put spread order helpers"
```

---

### Task 2: Backend Spread Helper Implementation

**Files:**
- Create: `backend/app/services/option_spread_order_service.py`
- Test: `backend/tests/test_option_spread_order_service.py`

- [ ] **Step 1: Implement the helper module**

Create `backend/app/services/option_spread_order_service.py`:

```python
from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Any, Dict


OCC_SYMBOL_RE = re.compile(r"^([A-Z]+)(\d{6})([CP])(\d{8})$")


@dataclass(frozen=True)
class OptionLeg:
    option_symbol: str
    action: str
    put_call: str
    expiry: str
    strike: float


@dataclass(frozen=True)
class SellPutSpread:
    underlying: str
    quantity: int
    short_leg: OptionLeg
    long_leg: OptionLeg
    net_credit: float
    profit_exit_percent: float = 30.0


def parse_occ_option_symbol(option_symbol: str) -> Dict[str, Any]:
    symbol = (option_symbol or "").strip().upper().replace(" ", "")
    match = OCC_SYMBOL_RE.match(symbol)
    if not match:
        raise ValueError("Option symbol must use OCC format such as QQQ260116P00480000")

    underlying, yymmdd, put_call, strike_raw = match.groups()
    expiry = f"20{yymmdd}"
    strike = int(strike_raw) / 1000.0
    return {
        "underlying": underlying,
        "expiry": expiry,
        "put_call": put_call,
        "strike": strike,
    }


def normalize_leg(leg: OptionLeg) -> OptionLeg:
    return OptionLeg(
        option_symbol=(leg.option_symbol or "").strip().upper().replace(" ", ""),
        action=(leg.action or "").strip().upper(),
        put_call=(leg.put_call or "").strip().upper(),
        expiry=(leg.expiry or "").strip().replace("-", ""),
        strike=float(leg.strike),
    )


def validate_sell_put_spread(spread: SellPutSpread) -> SellPutSpread:
    underlying = (spread.underlying or "").strip().upper()
    short_leg = normalize_leg(spread.short_leg)
    long_leg = normalize_leg(spread.long_leg)

    if not underlying:
        raise ValueError("Underlying is required")
    if int(spread.quantity) <= 0:
        raise ValueError("Quantity must be greater than zero")
    if float(spread.net_credit) <= 0:
        raise ValueError("Net credit must be greater than zero")
    if short_leg.action != "SELL":
        raise ValueError("Short leg action must be SELL")
    if long_leg.action != "BUY":
        raise ValueError("Long leg action must be BUY")
    if short_leg.put_call != "P" or long_leg.put_call != "P":
        raise ValueError("Both spread legs must be puts")
    if short_leg.expiry != long_leg.expiry:
        raise ValueError("Spread legs must use the same expiry")
    if short_leg.strike <= long_leg.strike:
        raise ValueError("Short put strike must be greater than long put strike")

    exit_debit = calculate_profit_exit_debit(float(spread.net_credit), float(spread.profit_exit_percent))
    if exit_debit <= 0 or exit_debit >= float(spread.net_credit):
        raise ValueError("Profit exit debit must be positive and less than entry credit")

    return SellPutSpread(
        underlying=underlying,
        quantity=int(spread.quantity),
        short_leg=short_leg,
        long_leg=long_leg,
        net_credit=float(spread.net_credit),
        profit_exit_percent=float(spread.profit_exit_percent),
    )


def calculate_profit_exit_debit(net_credit: float, profit_exit_percent: float = 30.0) -> float:
    remaining_percent = 1.0 - (float(profit_exit_percent) / 100.0)
    return round(float(net_credit) * remaining_percent, 4)


def calculate_sell_put_spread_preview(spread: SellPutSpread) -> Dict[str, float]:
    validated = validate_sell_put_spread(spread)
    width = round(validated.short_leg.strike - validated.long_leg.strike, 4)
    multiplier = 100
    quantity = validated.quantity
    max_profit = round(validated.net_credit * multiplier * quantity, 2)
    max_loss = round((width - validated.net_credit) * multiplier * quantity, 2)
    breakeven = round(validated.short_leg.strike - validated.net_credit, 4)
    profit_exit_debit = calculate_profit_exit_debit(validated.net_credit, validated.profit_exit_percent)

    return {
        "width": width,
        "max_profit": max_profit,
        "max_loss": max_loss,
        "breakeven": breakeven,
        "profit_exit_debit": profit_exit_debit,
    }
```

- [ ] **Step 2: Run tests to verify they pass**

Run:

```powershell
Set-Location backend
python -m unittest tests.test_option_spread_order_service -v
```

Expected: 4 tests pass.

- [ ] **Step 3: Commit helper implementation**

```powershell
git add backend/app/services/option_spread_order_service.py backend/tests/test_option_spread_order_service.py
git commit -m "feat: add sell put spread validation helpers"
```

---

### Task 3: Backend IB Combo Endpoint

**Files:**
- Modify: `backend/app/routers/ib_orders.py`
- Test: `backend/tests/test_option_spread_order_service.py`

- [ ] **Step 1: Add endpoint-focused tests for request validation helper output**

Append this test to `backend/tests/test_option_spread_order_service.py` inside `OptionSpreadOrderServiceTests`:

```python
    def test_preview_rejects_profit_exit_above_credit(self):
        spread = SellPutSpread(
            underlying="QQQ",
            quantity=1,
            short_leg=OptionLeg(
                option_symbol="QQQ260116P00480000",
                action="SELL",
                put_call="P",
                expiry="20260116",
                strike=480.0,
            ),
            long_leg=OptionLeg(
                option_symbol="QQQ260116P00470000",
                action="BUY",
                put_call="P",
                expiry="20260116",
                strike=470.0,
            ),
            net_credit=1.25,
            profit_exit_percent=0.0,
        )

        with self.assertRaises(ValueError) as ctx:
            calculate_sell_put_spread_preview(spread)

        self.assertIn("Profit exit debit must be positive and less than entry credit", str(ctx.exception))
```

- [ ] **Step 2: Run tests to verify they pass after Task 2 and fail only if validation regresses**

Run:

```powershell
Set-Location backend
python -m unittest tests.test_option_spread_order_service -v
```

Expected: all tests pass.

- [ ] **Step 3: Modify imports in `backend/app/routers/ib_orders.py`**

Change:

```python
from pydantic import BaseModel, field_validator
```

to:

```python
from pydantic import BaseModel, field_validator, model_validator
```

Change:

```python
from typing import List, Dict, Any, Optional
```

to:

```python
from typing import List, Dict, Any, Optional, Literal
```

Change:

```python
    from ib_insync import IB, Stock, LimitOrder, StopOrder  # type: ignore
```

to:

```python
    from ib_insync import IB, Stock, LimitOrder, StopOrder, Contract, ComboLeg  # type: ignore
```

Change the fallback block:

```python
    StopOrder = None  # type: ignore
```

to:

```python
    StopOrder = None  # type: ignore
    Contract = None  # type: ignore
    ComboLeg = None  # type: ignore
```

Add after the imports:

```python
from app.services.option_spread_order_service import (
    OptionLeg,
    SellPutSpread,
    calculate_sell_put_spread_preview,
    validate_sell_put_spread,
)
```

- [ ] **Step 4: Add Pydantic request models in `ib_orders.py` after `PlaceOrdersAtPriceBatchRequest`**

```python
class OptionLegRequest(BaseModel):
    option_symbol: str
    action: Literal["BUY", "SELL"]
    put_call: Literal["P", "C"]
    expiry: str
    strike: float
    con_id: Optional[int] = None
    exchange: str = "SMART"

    @field_validator("option_symbol", "expiry", "exchange")
    @classmethod
    def validate_required_text(cls, v: str) -> str:
        vv = (v or "").strip()
        if not vv:
            raise ValueError("Value is required")
        return vv

    @field_validator("strike")
    @classmethod
    def validate_strike(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Strike must be greater than zero")
        return float(v)


class SellPutSpreadOrderRequest(BaseModel):
    underlying: str
    quantity: int
    short_leg: OptionLegRequest
    long_leg: OptionLegRequest
    net_credit: float
    profit_exit_percent: Optional[float] = 30.0
    place_profit_exit: bool = True

    @field_validator("underlying")
    @classmethod
    def validate_underlying(cls, v: str) -> str:
        vv = (v or "").strip().upper()
        if not vv:
            raise ValueError("Underlying is required")
        return vv

    @field_validator("quantity")
    @classmethod
    def validate_quantity(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("Quantity must be greater than zero")
        return int(v)

    @field_validator("net_credit")
    @classmethod
    def validate_net_credit(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Net credit must be greater than zero")
        return float(v)

    @model_validator(mode="after")
    def validate_spread_shape(self) -> "SellPutSpreadOrderRequest":
        validate_sell_put_spread(_spread_from_request(self))
        return self


class SellPutOrderRequest(BaseModel):
    underlying: str
    quantity: int
    short_leg: OptionLegRequest
    net_credit: float

    @field_validator("underlying")
    @classmethod
    def validate_underlying(cls, v: str) -> str:
        vv = (v or "").strip().upper()
        if not vv:
            raise ValueError("Underlying is required")
        return vv

    @field_validator("quantity")
    @classmethod
    def validate_quantity(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("Quantity must be greater than zero")
        return int(v)

    @field_validator("net_credit")
    @classmethod
    def validate_net_credit(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Net credit must be greater than zero")
        return float(v)
```

- [ ] **Step 5: Add conversion and combo builders in `ib_orders.py` before `_connect_ib`**

```python
def _spread_from_request(request: SellPutSpreadOrderRequest) -> SellPutSpread:
    return SellPutSpread(
        underlying=request.underlying,
        quantity=request.quantity,
        short_leg=OptionLeg(
            option_symbol=request.short_leg.option_symbol,
            action=request.short_leg.action,
            put_call=request.short_leg.put_call,
            expiry=request.short_leg.expiry,
            strike=request.short_leg.strike,
        ),
        long_leg=OptionLeg(
            option_symbol=request.long_leg.option_symbol,
            action=request.long_leg.action,
            put_call=request.long_leg.put_call,
            expiry=request.long_leg.expiry,
            strike=request.long_leg.strike,
        ),
        net_credit=request.net_credit,
        profit_exit_percent=request.profit_exit_percent or 30.0,
    )


def _build_combo_leg(leg: OptionLegRequest, ratio: int = 1):
    if leg.con_id is None:
        raise HTTPException(status_code=400, detail=f"Missing con_id for {leg.option_symbol}; qualify option legs before placing combo")
    combo_leg = ComboLeg()
    combo_leg.conId = int(leg.con_id)
    combo_leg.ratio = ratio
    combo_leg.action = leg.action
    combo_leg.exchange = leg.exchange or "SMART"
    return combo_leg


def _build_sell_put_spread_contract(request: SellPutSpreadOrderRequest):
    if Contract is None or ComboLeg is None:
        raise HTTPException(status_code=500, detail="ib_insync combo support is not available")

    contract = Contract()
    contract.symbol = request.underlying.split(".")[0].upper()
    contract.secType = "BAG"
    contract.currency = "USD"
    contract.exchange = "SMART"
    contract.comboLegs = [
        _build_combo_leg(request.short_leg),
        _build_combo_leg(request.long_leg),
    ]
    return contract
```

- [ ] **Step 6: Add the cash-secured put and spread endpoints in `ib_orders.py` before `/quote`**

```python
@router.post("/place-sell-put")
def place_sell_put(order: SellPutOrderRequest) -> Dict[str, Any]:
    if order.short_leg.put_call != "P" or order.short_leg.action != "SELL":
        raise HTTPException(status_code=400, detail="Cash-secured put order requires one SELL put leg")
    if order.short_leg.con_id is None:
        raise HTTPException(status_code=400, detail=f"Missing con_id for {order.short_leg.option_symbol}")
    if Contract is None:
        raise HTTPException(status_code=500, detail="ib_insync option support is not available")

    ib, loop = _connect_ib()
    try:
        contract = Contract()
        contract.conId = int(order.short_leg.con_id)
        contract.secType = "OPT"
        contract.exchange = order.short_leg.exchange or "SMART"
        contract.currency = "USD"

        limit_order = LimitOrder("SELL", order.quantity, lmtPrice=float(order.net_credit))
        limit_order.outsideRth = True
        try:
            limit_order.tif = "DAY"
        except Exception:
            pass
        limit_order.eTradeOnly = None
        limit_order.firmQuoteOnly = None

        trade = ib.placeOrder(contract, limit_order)
        additional_settings = {
            "OptionStrategy": "SELL_PUT",
            "OptionBuySell": "SELL",
            "OptionSymbol": order.short_leg.option_symbol,
            "NetCreditLimit": order.net_credit,
        }
        return {
            "ok": True,
            "message": f"Placed cash-secured sell put {order.short_leg.option_symbol} credit {order.net_credit}",
            "order_type": "SELL_PUT",
            "entry": {
                "ib_order_id": getattr(trade, "order", None).orderId if getattr(trade, "order", None) else None,
                "side": "SELL",
                "quantity": order.quantity,
                "net_credit": order.net_credit,
            },
            "additional_settings": additional_settings,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("IB place_sell_put unexpected error for %s: %s", order.short_leg.option_symbol, e)
        raise HTTPException(status_code=500, detail=f"Unexpected IB sell put error: {e}")
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass


@router.post("/place-sell-put-spread")
def place_sell_put_spread(order: SellPutSpreadOrderRequest) -> Dict[str, Any]:
    spread = validate_sell_put_spread(_spread_from_request(order))
    preview = calculate_sell_put_spread_preview(spread)
    entry_credit = float(order.net_credit)
    profit_exit_debit = float(preview["profit_exit_debit"])

    ib, loop = _connect_ib()
    try:
        contract = _build_sell_put_spread_contract(order)

        parent = LimitOrder("SELL", order.quantity, lmtPrice=entry_credit)
        parent.orderId = ib.client.getReqId()
        parent.transmit = not order.place_profit_exit
        parent.outsideRth = True
        try:
            parent.tif = "DAY"
        except Exception:
            pass
        parent.eTradeOnly = None
        parent.firmQuoteOnly = None

        parent_trade = ib.placeOrder(contract, parent)
        ib.sleep(0.05)

        profit_trade = None
        if order.place_profit_exit:
            profit_exit = LimitOrder("BUY", order.quantity, lmtPrice=profit_exit_debit)
            profit_exit.parentId = parent.orderId
            profit_exit.transmit = True
            profit_exit.outsideRth = True
            try:
                profit_exit.tif = "GTC"
            except Exception:
                pass
            profit_exit.eTradeOnly = None
            profit_exit.firmQuoteOnly = None
            profit_trade = ib.placeOrder(contract, profit_exit)

        additional_settings = {
            "OptionStrategy": "SELL_PUT_SPREAD",
            "OptionBuySell": "SELL",
            "OptionSymbol": spread.short_leg.option_symbol,
            "SpreadLegs": [
                {
                    "role": "SHORT",
                    "action": "SELL",
                    "put_call": "P",
                    "option_symbol": spread.short_leg.option_symbol,
                    "expiry": spread.short_leg.expiry,
                    "strike": spread.short_leg.strike,
                },
                {
                    "role": "LONG",
                    "action": "BUY",
                    "put_call": "P",
                    "option_symbol": spread.long_leg.option_symbol,
                    "expiry": spread.long_leg.expiry,
                    "strike": spread.long_leg.strike,
                },
            ],
            "NetCreditLimit": entry_credit,
            "ProfitExitPercent": order.profit_exit_percent or 30.0,
            "ProfitExitDebit": profit_exit_debit,
        }

        return {
            "ok": True,
            "message": f"Placed sell put spread {order.underlying} credit {entry_credit}",
            "order_type": "SELL_PUT_SPREAD",
            "entry": {
                "ib_order_id": getattr(parent_trade, "order", None).orderId if getattr(parent_trade, "order", None) else None,
                "side": "SELL",
                "quantity": order.quantity,
                "net_credit": entry_credit,
            },
            "profit_exit": None if profit_trade is None else {
                "ib_order_id": getattr(profit_trade, "order", None).orderId if getattr(profit_trade, "order", None) else None,
                "side": "BUY",
                "quantity": order.quantity,
                "limit_debit": profit_exit_debit,
                "profit_exit_percent": order.profit_exit_percent or 30.0,
            },
            "spread": {
                "underlying": spread.underlying,
                "short_leg": spread.short_leg.__dict__,
                "long_leg": spread.long_leg.__dict__,
            },
            "preview": preview,
            "additional_settings": additional_settings,
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("IB place_sell_put_spread unexpected error for %s: %s", order.underlying, e)
        raise HTTPException(status_code=500, detail=f"Unexpected IB spread order error: {e}")
    finally:
        try:
            ib.disconnect()
        except Exception:
            pass
```

- [ ] **Step 7: Run backend tests and compile check**

Run:

```powershell
Set-Location backend
python -m unittest tests.test_option_spread_order_service -v
python -m compileall app
```

Expected: tests pass and compileall reports no syntax errors.

- [ ] **Step 8: Commit endpoints**

```powershell
git add backend/app/routers/ib_orders.py backend/tests/test_option_spread_order_service.py
git commit -m "feat: add IB option put order endpoints"
```

---

### Task 4: Option Orders UI Helpers

**Files:**
- Create: `frontend/src/app/option-orders/page.tsx`

- [ ] **Step 1: Create the initial Option Orders page with helper functions and UI state**

Create `frontend/src/app/option-orders/page.tsx` with:

```tsx
"use client";

import { useMemo, useState } from "react";
import { authenticatedFetch } from "../utils/authenticatedFetch";
import PageHeader from "../components/PageHeader";

type OptionSide = "BUY" | "SELL";

interface OptionLegForm {
  option_symbol: string;
  action: OptionSide;
  put_call: "P";
  expiry: string;
  strike: string;
  con_id: string;
}

function toNumber(value: string): number | null {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function round4(n: number): number {
  return Math.round(n * 10000) / 10000;
}

function parseOccOptionSymbol(optionSymbol: string): { underlying: string; expiry: string; putCall: "P" | "C"; strike: number } | null {
  const match = optionSymbol.trim().toUpperCase().replace(/\s+/g, "").match(/^([A-Z]+)(\d{6})([CP])(\d{8})$/);
  if (!match) return null;
  return {
    underlying: match[1],
    expiry: `20${match[2]}`,
    putCall: match[3] as "P" | "C",
    strike: Number(match[4]) / 1000,
  };
}

function buildLowerPutSymbol(shortSymbol: string, longStrike: number): string {
  const parsed = parseOccOptionSymbol(shortSymbol);
  if (!parsed) return "";
  const yymmdd = parsed.expiry.slice(2);
  const strikeRaw = String(Math.round(longStrike * 1000)).padStart(8, "0");
  return `${parsed.underlying}${yymmdd}P${strikeRaw}`;
}

function calculateSpreadPreview(shortStrike: number, longStrike: number, netCredit: number, quantity: number) {
  const width = round4(shortStrike - longStrike);
  const maxProfit = round4(netCredit * 100 * quantity);
  const maxLoss = round4((width - netCredit) * 100 * quantity);
  const breakeven = round4(shortStrike - netCredit);
  const profitExitDebit = round4(netCredit * 0.7);
  return { width, maxProfit, maxLoss, breakeven, profitExitDebit };
}
```

- [ ] **Step 2: Add the form component body**

Continue the same file:

```tsx
export default function OptionOrdersPage() {
  const baseUrl = process.env.NEXT_PUBLIC_BACKEND_URL;
  const [underlying, setUnderlying] = useState("QQQ");
  const [quantity, setQuantity] = useState("1");
  const [shortLeg, setShortLeg] = useState<OptionLegForm>({
    option_symbol: "",
    action: "SELL",
    put_call: "P",
    expiry: "",
    strike: "",
    con_id: "",
  });
  const [sellPutSpread, setSellPutSpread] = useState(false);
  const [longLeg, setLongLeg] = useState<OptionLegForm>({
    option_symbol: "",
    action: "BUY",
    put_call: "P",
    expiry: "",
    strike: "",
    con_id: "",
  });
  const [netCredit, setNetCredit] = useState("");
  const [placeProfitExit, setPlaceProfitExit] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [result, setResult] = useState<any | null>(null);

  const parsedShortSymbol = useMemo(() => parseOccOptionSymbol(shortLeg.option_symbol), [shortLeg.option_symbol]);
  const qty = toNumber(quantity) ?? 0;
  const shortStrike = toNumber(shortLeg.strike) ?? parsedShortSymbol?.strike ?? 0;
  const longStrike = toNumber(longLeg.strike) ?? 0;
  const credit = toNumber(netCredit) ?? 0;

  const preview = useMemo(() => {
    if (!sellPutSpread || shortStrike <= 0 || longStrike <= 0 || credit <= 0 || qty <= 0 || shortStrike <= longStrike) {
      return null;
    }
    return calculateSpreadPreview(shortStrike, longStrike, credit, qty);
  }, [sellPutSpread, shortStrike, longStrike, credit, qty]);

  const prefillFromShortSymbol = () => {
    const parsed = parseOccOptionSymbol(shortLeg.option_symbol);
    if (!parsed) {
      setError("Short put option symbol must use OCC format, e.g. QQQ260116P00480000.");
      return;
    }
    if (parsed.putCall !== "P") {
      setError("Short leg must be a put.");
      return;
    }
    const suggestedLongStrike = Math.max(0.5, parsed.strike - 5);
    setUnderlying(parsed.underlying);
    setShortLeg((prev) => ({ ...prev, expiry: parsed.expiry, strike: String(parsed.strike) }));
    setLongLeg((prev) => ({
      ...prev,
      expiry: parsed.expiry,
      strike: String(suggestedLongStrike),
      option_symbol: buildLowerPutSymbol(shortLeg.option_symbol, suggestedLongStrike),
    }));
    setError("");
  };
```

- [ ] **Step 3: Add submit logic**

Continue the same file:

```tsx
  const submitCashSecuredPut = async () => {
    if (!baseUrl) throw new Error("NEXT_PUBLIC_BACKEND_URL is not configured.");
    const shortConId = toNumber(shortLeg.con_id);
    if (!shortLeg.option_symbol.trim()) throw new Error("Short put option symbol is required.");
    if (!shortConId) throw new Error("Short put con_id is required.");
    if (qty <= 0) throw new Error("Quantity must be greater than zero.");
    if (credit <= 0) throw new Error("Net credit must be greater than zero.");

    const payload = {
      underlying: underlying.trim().toUpperCase(),
      quantity: qty,
      short_leg: {
        option_symbol: shortLeg.option_symbol.trim().toUpperCase(),
        action: "SELL",
        put_call: "P",
        expiry: shortLeg.expiry,
        strike: shortStrike,
        con_id: shortConId,
      },
      net_credit: credit,
    };

    const res = await authenticatedFetch(`${baseUrl}/api/ib/place-sell-put`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(typeof data?.detail === "string" ? data.detail : "Cash-secured put order failed.");
    }
    return data;
  };

  const submitSellPutSpread = async () => {
    if (!baseUrl) throw new Error("NEXT_PUBLIC_BACKEND_URL is not configured.");
    if (!preview) throw new Error("Enter a valid short put, lower long put, quantity, and net credit.");
    const shortConId = toNumber(shortLeg.con_id);
    const longConId = toNumber(longLeg.con_id);
    if (!shortConId || !longConId) {
      throw new Error("Both option legs need IB con_id values before combo placement.");
    }

    const payload = {
      underlying: underlying.trim().toUpperCase(),
      quantity: qty,
      short_leg: {
        option_symbol: shortLeg.option_symbol.trim().toUpperCase(),
        action: "SELL",
        put_call: "P",
        expiry: shortLeg.expiry,
        strike: shortStrike,
        con_id: shortConId,
      },
      long_leg: {
        option_symbol: longLeg.option_symbol.trim().toUpperCase(),
        action: "BUY",
        put_call: "P",
        expiry: longLeg.expiry,
        strike: longStrike,
        con_id: longConId,
      },
      net_credit: credit,
      profit_exit_percent: 30,
      place_profit_exit: placeProfitExit,
    };

    const res = await authenticatedFetch(`${baseUrl}/api/ib/place-sell-put-spread`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(typeof data?.detail === "string" ? data.detail : "Sell put spread order failed.");
    }
    return data;
  };

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError("");
    setResult(null);
    try {
      const data = sellPutSpread ? await submitSellPutSpread() : await submitCashSecuredPut();
      setResult(data);
    } catch (err: any) {
      setError(err?.message || "Submit failed.");
    } finally {
      setSubmitting(false);
    }
  };
```

- [ ] **Step 4: Add JSX**

Complete the same file:

```tsx
  return (
    <div className="min-h-screen text-slate-800">
      <div className="mx-auto max-w-5xl px-6 py-10">
        <PageHeader
          title="Option Orders"
          subtitle="Create cash-secured sell puts by default, or opt into a single combo sell put spread."
        />

        {error && <div className="mb-4 rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">Error: {error}</div>}

        <form onSubmit={onSubmit} className="rounded-lg border border-slate-200 bg-white p-6 space-y-5">
          <div className="grid gap-4 sm:grid-cols-3">
            <label className="block text-sm text-slate-600">
              Underlying
              <input value={underlying} onChange={(e) => setUnderlying(e.target.value)} className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm" />
            </label>
            <label className="block text-sm text-slate-600">
              Quantity
              <input type="number" min={1} value={quantity} onChange={(e) => setQuantity(e.target.value)} className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm" />
            </label>
            <label className="block text-sm text-slate-600">
              Net Credit
              <input type="number" step="0.01" value={netCredit} onChange={(e) => setNetCredit(e.target.value)} className="mt-1 w-full rounded-md border border-slate-300 px-3 py-2 text-sm" />
            </label>
          </div>

          <div className="rounded-md border border-slate-200 p-4">
            <div className="font-medium text-slate-700 mb-3">Sell Put Leg</div>
            <div className="grid gap-4 sm:grid-cols-4">
              <input placeholder="Short option symbol" value={shortLeg.option_symbol} onChange={(e) => setShortLeg({ ...shortLeg, option_symbol: e.target.value })} className="rounded-md border border-slate-300 px-3 py-2 text-sm" />
              <input placeholder="Expiry YYYYMMDD" value={shortLeg.expiry} onChange={(e) => setShortLeg({ ...shortLeg, expiry: e.target.value })} className="rounded-md border border-slate-300 px-3 py-2 text-sm" />
              <input placeholder="Short strike" type="number" step="0.01" value={shortLeg.strike} onChange={(e) => setShortLeg({ ...shortLeg, strike: e.target.value })} className="rounded-md border border-slate-300 px-3 py-2 text-sm" />
              <input placeholder="Short con_id" value={shortLeg.con_id} onChange={(e) => setShortLeg({ ...shortLeg, con_id: e.target.value })} className="rounded-md border border-slate-300 px-3 py-2 text-sm" />
            </div>
            <button type="button" onClick={prefillFromShortSymbol} className="mt-3 rounded-md border border-slate-300 px-3 py-2 text-sm hover:bg-slate-50">
              Prefill from short symbol
            </button>
          </div>

          <label className="flex items-center gap-2 text-sm font-medium text-slate-700">
            <input type="checkbox" checked={sellPutSpread} onChange={(e) => setSellPutSpread(e.target.checked)} className="h-4 w-4" />
            Sell put spread
          </label>

          {sellPutSpread && (
            <div className="rounded-md border border-blue-200 bg-blue-50/40 p-4 space-y-4">
              <div className="font-medium text-slate-700">Protective Long Put Leg</div>
              <div className="grid gap-4 sm:grid-cols-4">
                <input placeholder="Long option symbol" value={longLeg.option_symbol} onChange={(e) => setLongLeg({ ...longLeg, option_symbol: e.target.value })} className="rounded-md border border-slate-300 px-3 py-2 text-sm" />
                <input placeholder="Expiry YYYYMMDD" value={longLeg.expiry} onChange={(e) => setLongLeg({ ...longLeg, expiry: e.target.value })} className="rounded-md border border-slate-300 px-3 py-2 text-sm" />
                <input placeholder="Long strike" type="number" step="0.01" value={longLeg.strike} onChange={(e) => setLongLeg({ ...longLeg, strike: e.target.value })} className="rounded-md border border-slate-300 px-3 py-2 text-sm" />
                <input placeholder="Long con_id" value={longLeg.con_id} onChange={(e) => setLongLeg({ ...longLeg, con_id: e.target.value })} className="rounded-md border border-slate-300 px-3 py-2 text-sm" />
              </div>
              <label className="flex items-center gap-2 text-sm text-slate-700">
                <input type="checkbox" checked={placeProfitExit} onChange={(e) => setPlaceProfitExit(e.target.checked)} className="h-4 w-4" />
                Place 30% profit exit as linked buy-to-close combo order
              </label>
              {preview && (
                <div className="grid gap-2 text-sm sm:grid-cols-5">
                  <div>Width: ${preview.width.toFixed(2)}</div>
                  <div>Max profit: ${preview.maxProfit.toFixed(2)}</div>
                  <div>Max loss: ${preview.maxLoss.toFixed(2)}</div>
                  <div>Breakeven: ${preview.breakeven.toFixed(2)}</div>
                  <div>Exit debit: ${preview.profitExitDebit.toFixed(2)}</div>
                </div>
              )}
              <div className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
                Spread orders are submitted as one net-credit combo. Fair prices may be harder to fill; aggressive prices may fill faster but reduce edge.
              </div>
            </div>
          )}

          <button type="submit" disabled={submitting} className="rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50">
            {submitting ? "Submitting..." : "Submit Order"}
          </button>
        </form>

        {result && (
          <pre className="mt-6 overflow-auto rounded-lg border border-slate-200 bg-slate-950 p-4 text-xs text-slate-100">
            {JSON.stringify(result, null, 2)}
          </pre>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Run frontend lint**

Run:

```powershell
Set-Location frontend
npm run lint
```

Expected: lint passes or reports only pre-existing unrelated warnings.

- [ ] **Step 6: Commit initial UI**

```powershell
git add frontend/src/app/option-orders/page.tsx
git commit -m "feat: add option orders spread form"
```

---

### Task 5: Display Order Metadata For Recording

**Files:**
- Modify: `frontend/src/app/option-orders/page.tsx`

- [ ] **Step 1: Add a formatted order metadata panel**

In `frontend/src/app/option-orders/page.tsx`, replace the result block:

```tsx
        {result && (
          <pre className="mt-6 overflow-auto rounded-lg border border-slate-200 bg-slate-950 p-4 text-xs text-slate-100">
            {JSON.stringify(result, null, 2)}
          </pre>
        )}
```

with:

```tsx
        {result && (
          <div className="mt-6 space-y-4">
            <div className="rounded-lg border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800">
              {result.message || "Order submitted."}
            </div>
            {result.additional_settings && (
              <div className="rounded-lg border border-slate-200 bg-white p-4">
                <div className="mb-2 text-sm font-semibold text-slate-700">Order metadata</div>
                <pre className="overflow-auto rounded-md bg-slate-950 p-3 text-xs text-slate-100">
                  {JSON.stringify(result.additional_settings, null, 2)}
                </pre>
              </div>
            )}
            <pre className="overflow-auto rounded-lg border border-slate-200 bg-slate-950 p-4 text-xs text-slate-100">
              {JSON.stringify(result, null, 2)}
            </pre>
          </div>
        )}
```

- [ ] **Step 2: Verify both endpoint responses include `additional_settings`**

Read the two return blocks in `backend/app/routers/ib_orders.py`:

- `/place-sell-put` includes `OptionStrategy: "SELL_PUT"`
- `/place-sell-put-spread` includes `OptionStrategy: "SELL_PUT_SPREAD"` and `SpreadLegs`

If either response is missing those keys, add the exact `additional_settings` objects from Task 3 Step 6.

- [ ] **Step 3: Run checks**

Run:

```powershell
Set-Location backend
python -m compileall app
Set-Location ..\frontend
npm run lint
```

Expected: backend compiles and frontend lint passes.

- [ ] **Step 4: Commit metadata display**

```powershell
git add backend/app/routers/ib_orders.py frontend/src/app/option-orders/page.tsx
git commit -m "feat: show option order metadata"
```

---

### Task 6: Navigation And Query Prefill

**Files:**
- Modify: `frontend/src/app/option-orders/page.tsx`
- Modify: `frontend/src/app/components/AppShell.tsx`
- Modify: `frontend/src/app/page.tsx`

- [ ] **Step 1: Add query-param prefill support**

At the top of `frontend/src/app/option-orders/page.tsx`, change:

```tsx
import { useMemo, useState } from "react";
```

to:

```tsx
import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
```

Inside `OptionOrdersPage`, add after `const baseUrl...`:

```tsx
  const searchParams = useSearchParams();
```

Add this effect before `const parsedShortSymbol...`:

```tsx
  useEffect(() => {
    const stockCode = searchParams.get("stock_code");
    const shortSymbol = searchParams.get("short_option_symbol");
    const expiry = searchParams.get("expiry");
    const shortStrikeParam = searchParams.get("short_strike");
    const longStrikeParam = searchParams.get("long_strike");
    const creditParam = searchParams.get("net_credit");
    const spreadParam = searchParams.get("sell_put_spread");

    if (stockCode) setUnderlying(stockCode.trim().toUpperCase().replace(".US", ""));
    if (shortSymbol) setShortLeg((prev) => ({ ...prev, option_symbol: shortSymbol.trim().toUpperCase() }));
    if (expiry) setShortLeg((prev) => ({ ...prev, expiry }));
    if (shortStrikeParam) setShortLeg((prev) => ({ ...prev, strike: shortStrikeParam }));
    if (longStrikeParam) setLongLeg((prev) => ({ ...prev, strike: longStrikeParam }));
    if (creditParam) setNetCredit(creditParam);
    if (spreadParam === "1" || spreadParam === "true") setSellPutSpread(true);
  }, [searchParams]);
```

- [ ] **Step 2: Add AppShell navigation entry**

In `frontend/src/app/components/AppShell.tsx`, add this item near the trading/order links:

```tsx
{ href: "/option-orders", label: "Option Orders" },
```

- [ ] **Step 3: Add homepage card**

In `frontend/src/app/page.tsx`, add a card object matching the existing homepage card shape:

```tsx
{
  title: "Option Orders",
  href: "/option-orders",
  desc: "Submit cash-secured puts or opt into combo sell put spreads with a 30% profit exit.",
}
```

- [ ] **Step 4: Run frontend lint**

Run:

```powershell
Set-Location frontend
npm run lint
```

Expected: lint passes.

- [ ] **Step 5: Commit navigation and prefill**

```powershell
git add frontend/src/app/option-orders/page.tsx frontend/src/app/components/AppShell.tsx frontend/src/app/page.tsx
git commit -m "feat: add option orders navigation and prefill"
```

---

### Task 7: End-To-End Verification

**Files:**
- No new files expected.

- [ ] **Step 1: Run backend tests**

```powershell
Set-Location backend
python -m unittest tests.test_option_spread_order_service -v
python -m compileall app
```

Expected: tests pass and compileall succeeds.

- [ ] **Step 2: Run frontend lint/build**

```powershell
Set-Location frontend
npm run lint
npm run build
```

Expected: lint and build pass.

- [ ] **Step 3: Start the frontend dev server**

```powershell
Set-Location frontend
npm run dev
```

Expected: Next serves on `http://localhost:3100`.

- [ ] **Step 4: Browser smoke test**

Open:

```text
http://localhost:3100/option-orders?stock_code=QQQ&short_option_symbol=QQQ260116P00480000&short_strike=480&long_strike=470&net_credit=1.25&sell_put_spread=1
```

Verify:

- `Sell put spread` is checked.
- Short leg fields are prefilled.
- Long strike and net credit are prefilled.
- Preview shows width `10.00`, max profit `125.00` for quantity 1, max loss `875.00`, breakeven `478.75`, exit debit `0.88`.
- Unchecking `Sell put spread` hides the long leg and preview.

- [ ] **Step 5: Commit any verification fixes**

If fixes were required:

```powershell
git add <fixed-files>
git commit -m "fix: polish option orders spread flow"
```

If no fixes were required, do not create an empty commit.

---

## Self-Review

Spec coverage:

- Existing cash-secured put remains default: Task 4 and Task 5.
- Checkbox opt-in spread mode: Task 4.
- Combo spread, not independent legs: Task 3.
- 30% profit exit as buy-to-close combo: Task 3 and Task 4.
- Liquidity warning and preview math: Task 4.
- Query-prefill readiness for `price-levels-30m`: Task 6.
- Tests and verification: Tasks 1, 2, 3, and 7.

The plan has no unresolved implementation markers. The only caveat is explicit: the checked-in repo lacks the existing Option Orders page, so this plan creates one and documents where to integrate if that page exists outside the visible tree.
