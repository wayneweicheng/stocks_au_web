from fastapi import APIRouter, Query
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
import json


router = APIRouter(prefix="/api", tags=["strategy-orders"])


DEFAULT_ACCOUNT = "huanw2114"
DEFAULT_USER_ID = 1


class StrategyOrder(BaseModel):
    id: Optional[int] = None
    stock_code: str
    order_type_id: int
    trigger_price: float
    total_volume: int
    entry_price: float
    stop_loss_price: float
    exit_price: float
    bar_completed_in_min: Optional[str] = None
    option_symbol: Optional[str] = None
    option_buy_sell: Optional[str] = None  # N/A | BUY | SELL
    buy_condition_type: Optional[str] = None  # stored as BuyConditionType in AdditionalSettings


def normalize_stock_code_for_us(symbol: str) -> str:
    s = (symbol or "").strip().upper()
    if not s:
        return s
    if "." in s:
        return s
    return f"{s}.US"


@router.get("/strategy-orders/types")
def get_strategy_order_types() -> List[Dict[str, Any]]:
    obj_sql_server_model = SQLServerModel(database='StockDB')
    rows = obj_sql_server_model.execute_read_usp(
        "exec [Order].[usp_GetStrategyOrderType] @pbitDebug = ?",
        (0,)
    ) or []

    types: List[Dict[str, Any]] = []
    for row in rows:
        # Rows may come back as {'': '23: Strategy XYZ'} or {'column': '23: Strategy XYZ'}
        # Extract the first value
        value = next(iter(row.values())) if isinstance(row, dict) and len(row) > 0 else None
        if not value or not isinstance(value, str) or ":" not in value:
            continue
        id_part, name_part = value.split(":", 1)
        try:
            order_type_id = int(id_part.strip())
        except Exception:
            continue
        types.append({"id": order_type_id, "name": name_part.strip(), "raw": value})
    return types


@router.get("/strategy-orders")
def get_strategy_orders(order_type_id: Optional[int] = Query(None)) -> List[Dict[str, Any]]:
    obj_sql_server_model = SQLServerModel(database='StockDB')
    # If order_type_id is None, pass -1 (All Orders) to SP
    pintOrderTypeID = order_type_id if order_type_id is not None else -1
    data = obj_sql_server_model.execute_read_usp(
        "exec [Order].[usp_GetStrategyOrder] @pintOrderTypeID = ?, @pvchTradeAccountName = ?",
        (pintOrderTypeID, DEFAULT_ACCOUNT)
    ) or []

    # Pass-through most fields; ensure consistent casing for frontend
    transformed: List[Dict[str, Any]] = []
    for r in data:
        # Prefer explicit column from SP (AS_BuyConditionType),
        # then fallback to BuyConditionType, then parse AdditionalSettings JSON
        buy_condition_type = r.get("AS_BuyConditionType") or r.get("BuyConditionType")
        if not buy_condition_type:
            additional_settings = r.get("AdditionalSettings")
            if isinstance(additional_settings, str) and additional_settings:
                try:
                    parsed = json.loads(additional_settings)
                    buy_condition_type = parsed.get("BuyConditionType")
                except Exception:
                    buy_condition_type = None

        transformed.append({
            "id": r.get("OrderID"),
            "stock_code": r.get("ASXCode"),
            "trade_account_name": r.get("TradeAccountName"),
            "order_type_id": r.get("OrderTypeID"),
            "trigger_price": r.get("TriggerPrice"),
            "total_volume": r.get("TotalVolume"),
            "entry_price": r.get("EntryPrice"),
            "stop_loss_price": r.get("StopLossPrice"),
            "exit_price": r.get("ExitPrice"),
            "bar_completed_in_min": r.get("BarCompletedInMin"),
            "option_symbol": r.get("OptionSymbol"),
            "option_buy_sell": r.get("OptionBuySell"),
            "buy_condition_type": buy_condition_type,
            "order_type": r.get("OrderType"),
            "created_date": r.get("CreateDate"),
        })
    return transformed


@router.post("/strategy-orders")
def create_strategy_order(order: StrategyOrder) -> Dict[str, Any]:
    obj_sql_server_model = SQLServerModel(database='StockDB')

    asx_code = normalize_stock_code_for_us(order.stock_code)

    # Normalize BuyConditionType: 'N/A' or empty -> None (serialize to JSON null)
    buy_condition = order.buy_condition_type if (order.buy_condition_type and order.buy_condition_type != 'N/A') else None

    additional_settings = {
        "TriggerPrice": order.trigger_price,
        "TotalVolume": int(order.total_volume),
        "Entry1Price": order.entry_price,
        "Entry2Price": -1,
        "StopLossPrice": order.stop_loss_price,
        "ExitStrategy": "SmartExit",
        "Exit1Price": order.exit_price,
        "Exit2Price": -1,
        "OptionSymbol": order.option_symbol,
        "OptionBuySell": order.option_buy_sell,
        "BarCompletedInMin": order.bar_completed_in_min,
        "BuyConditionType": buy_condition,
    }
    pvchAdditionalSettings = json.dumps(additional_settings)

    # Match Streamlit behavior: OrderPriceType='Price', OrderValue=5000
    params = (
        asx_code,
        DEFAULT_USER_ID,
        DEFAULT_ACCOUNT,
        order.order_type_id,
        'Price',
        order.entry_price,
        5000,
        pvchAdditionalSettings,
    )

    obj_sql_server_model.execute_update_usp(
        """
        DECLARE @pintErrorNumber INT = 0, @pvchMessage VARCHAR(200);
        EXEC [Order].[usp_AddOrder]
            @pvchASXCode = ?,
            @pintUserID = ?,
            @pvchTradeAccountName = ?,
            @pintOrderTypeID = ?,
            @pvchOrderPriceType = ?,
            @pdecOrderPrice = ?,
            @pdecOrderValue = ?,
            @pvchAdditionalSettings = ?,
            @pintErrorNumber = @pintErrorNumber OUTPUT,
            @pvchMessage = @pvchMessage OUTPUT;
        """,
        params
    )

    return {"message": f"Strategy order on {asx_code} successfully added."}


@router.put("/strategy-orders/{order_id}")
def update_strategy_order(order_id: int, order: StrategyOrder) -> Dict[str, Any]:
    obj_sql_server_model = SQLServerModel(database='StockDB')

    # Normalize BuyConditionType: 'N/A' or empty -> None (serialize to JSON null)
    buy_condition = order.buy_condition_type if (order.buy_condition_type and order.buy_condition_type != 'N/A') else None

    additional_settings = {
        "TriggerPrice": order.trigger_price,
        "TotalVolume": int(order.total_volume),
        "Entry1Price": order.entry_price,
        "Entry2Price": -1,
        "StopLossPrice": order.stop_loss_price,
        "ExitStrategy": "SmartExit",
        "Exit1Price": order.exit_price,
        "Exit2Price": -1,
        "OptionSymbol": order.option_symbol,
        "OptionBuySell": order.option_buy_sell,
        "BarCompletedInMin": order.bar_completed_in_min,
        "BuyConditionType": buy_condition,
    }
    pvchAdditionalSettings = json.dumps(additional_settings)

    params = (
        order_id,
        order.entry_price,
        5000,
        pvchAdditionalSettings,
    )

    obj_sql_server_model.execute_update_usp(
        """
        DECLARE @pintErrorNumber INT = 0, @pvchMessage VARCHAR(200);
        EXEC [Order].[usp_UpdateOrder]
            @pintOrderID = ?,
            @pdecOrderPrice = ?,
            @pdecOrderValue = ?,
            @pvchAdditionalSettings = ?,
            @pintErrorNumber = @pintErrorNumber OUTPUT,
            @pvchMessage = @pvchMessage OUTPUT;
        """,
        params
    )

    return {"message": "Strategy order updated successfully"}


@router.delete("/strategy-orders/{order_id}")
def delete_strategy_order(order_id: int) -> Dict[str, Any]:
    obj_sql_server_model = SQLServerModel(database='StockDB')
    obj_sql_server_model.execute_update_usp(
        "exec [Order].[usp_DeleteOrder] @pintOrderID = ?",
        (order_id,)
    )
    return {"message": "Strategy order deleted successfully"}





