from fastapi import APIRouter, HTTPException, Query
from typing import List, Dict, Any, Optional
from datetime import date, datetime
from pydantic import BaseModel
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel


router = APIRouter(prefix="/api", tags=["conditional-orders"])


def rows_to_dicts(cursor) -> List[Dict[str, Any]]:
    columns = [col[0] for col in cursor.description]
    return [dict(zip(columns, row)) for row in cursor.fetchall()]


class ConditionalOrder(BaseModel):
    id: Optional[int] = None
    order_type: str
    stock_code: str
    trade_account_name: str
    order_price_type: str
    order_price: Optional[float] = None
    price_buffer_ticks: Optional[int] = 0
    volume_gt: Optional[int] = None
    order_volume: Optional[int] = None
    order_value: Optional[float] = None
    valid_until: Optional[str] = None
    additional_settings: Optional[str] = None


@router.get("/conditional-orders")
def get_conditional_orders() -> List[Dict[str, Any]]:
    try:
        obj_sql_server_model = SQLServerModel(database='StockDB')
        data = obj_sql_server_model.execute_read_usp(
            "exec [Order].[usp_GetOrder] @pvchTradeAccountName = ?",
            ('huanw2114',)
        )

        # Transform PascalCase database fields to snake_case for frontend
        if data:
            transformed = []
            for record in data:
                transformed.append({
                    'id': record.get('OrderID'),
                    'order_type': record.get('OrderType'),
                    'stock_code': record.get('ASXCode'),
                    'trade_account_name': record.get('TradeAccountName'),
                    'order_price_type': record.get('OrderPriceType'),
                    'order_price': record.get('OrderPrice'),
                    'difference_to_current_price': record.get('DifferenceToCurrentPrice'),
                    'price_buffer_ticks': record.get('PriceBufferNumberOfTick'),
                    'volume_gt': record.get('CustomIntegerValue'),
                    'order_volume': record.get('OrderVolume'),
                    'order_value': record.get('OrderValue'),
                    'valid_until': record.get('ValidUntil'),
                    'additional_settings': record.get('AdditionalSettings'),
                    'created_date': record.get('CreateDate')
                })
            return transformed
        return []
    except Exception as e:
        # If stored procedure doesn't exist, return empty list
        return []


@router.get("/conditional-orders/order-types")
def get_conditional_order_types() -> List[Dict[str, Any]]:
    """Return available conditional order types via stored procedure.

    Expected columns from SP: OrderTypeID, OrderType, DisplayOrder (optional)
    """
    try:
        obj_sql_server_model = SQLServerModel(database='StockDB')
        rows = obj_sql_server_model.execute_read_usp(
            "exec [Order].[usp_GetOrderType]",
            ()
        ) or []

        # Normalize/guard against varying shapes
        normalized: List[Dict[str, Any]] = []
        for r in rows:
            if not isinstance(r, dict):
                continue
            normalized.append({
                "id": r.get("OrderTypeID"),
                "name": r.get("OrderType"),
                "display_order": r.get("DisplayOrder")
            })

        # Sort by display order if provided; otherwise leave as-is
        normalized.sort(key=lambda x: (999999 if x.get("display_order") is None else x.get("display_order")))
        return normalized
    except Exception:
        return []


@router.get("/conditional-orders/debug/direct")
def get_conditional_orders_direct() -> List[Dict[str, Any]]:
    """Debug endpoint to query Order table directly without stored procedure filtering"""
    try:
        obj_sql_server_model = SQLServerModel(database='StockDB')
        # Query the Order table directly to see all orders
        data = obj_sql_server_model.execute_read_usp(
            """
            SELECT TOP 100
                OrderID as id,
                ASXCode as stock_code,
                TradeAccountName as trade_account_name,
                OrderTypeID,
                OrderPriceType as order_price_type,
                OrderPrice as order_price,
                OrderPriceBufferNumberOfTick as price_buffer_ticks,
                VolumeGt as volume_gt,
                OrderVolume as order_volume,
                OrderValue as order_value,
                ValidUntil as valid_until,
                AdditionalSettings as additional_settings,
                CreateDate as created_date
            FROM [Order].[Order]
            ORDER BY CreateDate DESC
            """,
            ()  # Pass empty tuple for queries without parameters
        )
        return data or []
    except Exception as e:
        return [{"error": f"Failed to query Order table directly: {str(e)}"}]


@router.post("/conditional-orders")
def create_conditional_order(order: ConditionalOrder) -> Dict[str, Any]:
    try:
        obj_sql_server_model = SQLServerModel(database='StockDB')

        # Convert date format to YYYYMMDD for SQL Server
        # Handle both YYYY-MM-DD and ISO datetime formats (YYYY-MM-DDTHH:MM:SS)
        valid_until_formatted = None
        if order.valid_until:
            # Extract just the date portion if datetime format, then convert to YYYYMMDD
            date_part = order.valid_until.split('T')[0]
            valid_until_formatted = date_part.replace('-', '')

        # Resolve OrderTypeID from DB (no more hardcoded mapping)
        order_type_id: Optional[int] = None
        try:
            type_rows = obj_sql_server_model.execute_read_usp(
                "exec [Order].[usp_GetOrderType]",
                ()
            ) or []
            # Exact match on name; fall back to case-insensitive comparison
            for r in type_rows:
                name = r.get("OrderType") if isinstance(r, dict) else None
                oid = r.get("OrderTypeID") if isinstance(r, dict) else None
                if name == order.order_type:
                    order_type_id = int(oid) if oid is not None else None
                    break
            if order_type_id is None:
                for r in type_rows:
                    name_ci = (r.get("OrderType") or "").strip().lower() if isinstance(r, dict) else ""
                    if name_ci == (order.order_type or "").strip().lower():
                        oid = r.get("OrderTypeID")
                        order_type_id = int(oid) if oid is not None else None
                        break
        except Exception:
            order_type_id = None

        # Default to a sensible type if not found (prefer a sell open price advantage if available)
        if order_type_id is None:
            order_type_id = 9

        # Prepare parameters tuple
        params = (order.stock_code, 1, order.trade_account_name, order_type_id, order.order_price_type,
                 order.order_price or 0, order.volume_gt or 0, order.order_volume or 0,
                 order.order_value or 0, order.price_buffer_ticks or 0, valid_until_formatted,
                 order.additional_settings or None)

        # DEBUG: Log parameters
        print(f"DEBUG - Creating order with params: {params}")

        # Call usp_AddOrder stored procedure
        # Use execute_update_usp for INSERT operations to ensure proper commit
        # Wrap with DECLARE to provide the required output parameters
        try:
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
                    @pintVolumeGT = ?,
                    @pintOrderVolume = ?,
                    @pdecOrderValue = ?,
                    @pintOrderPriceBufferNumberOfTick = ?,
                    @pvchValidUntil = ?,
                    @pvchAdditionalSettings = ?,
                    @pintErrorNumber = @pintErrorNumber OUTPUT,
                    @pvchMessage = @pvchMessage OUTPUT;
                """,
                params
            )

            print(f"DEBUG - Order inserted successfully using execute_update_usp")
            return {"message": f"Order on {order.stock_code} successfully added."}
        except Exception as insert_error:
            print(f"DEBUG - Insert failed: {str(insert_error)}")
            return {"message": f"Error: {str(insert_error)}"}
    except Exception as e:
        print(f"DEBUG - Exception occurred: {str(e)}")
        return {"message": f"Error: {str(e)}"}


@router.get("/conditional-orders/categories")
def get_categories() -> List[str]:
    return ["Stock"]


@router.get("/conditional-orders/accounts")
def get_trade_accounts() -> List[str]:
    return ["huanw2114"]


@router.put("/conditional-orders/{order_id}")
def update_conditional_order(order_id: int, order: ConditionalOrder) -> Dict[str, Any]:
    try:
        obj_sql_server_model = SQLServerModel(database='StockDB')

        # Convert date format to YYYYMMDD for SQL Server
        # Handle both YYYY-MM-DD and ISO datetime formats (YYYY-MM-DDTHH:MM:SS)
        valid_until_formatted = None
        if order.valid_until:
            # Extract just the date portion if datetime format, then convert to YYYYMMDD
            date_part = order.valid_until.split('T')[0]
            valid_until_formatted = date_part.replace('-', '')

        # Call usp_UpdateOrder stored procedure
        # Use execute_update_usp for UPDATE operations to ensure proper commit
        # Wrap with DECLARE to provide the required output parameters
        obj_sql_server_model.execute_update_usp(
            """
            DECLARE @pintErrorNumber INT = 0, @pvchMessage VARCHAR(200);
            EXEC [Order].[usp_UpdateOrder]
                @pintOrderID = ?,
                @pdecOrderPrice = ?,
                @pintVolumeGt = ?,
                @pintOrderVolume = ?,
                @pvchValidUntil = ?,
                @pvchAdditionalSettings = ?,
                @pdecOrderValue = ?,
                @pintOrderPriceBufferNumberOfTick = ?,
                @pintErrorNumber = @pintErrorNumber OUTPUT,
                @pvchMessage = @pvchMessage OUTPUT;
            """,
            (order_id, order.order_price or 0, order.volume_gt or 0, order.order_volume or 0,
             valid_until_formatted, order.additional_settings or None, order.order_value or 0,
             order.price_buffer_ticks or 0)
        )

        return {"message": "Conditional order updated successfully"}
    except Exception as e:
        return {"message": f"Error: {str(e)}"}


@router.delete("/conditional-orders/{order_id}")
def delete_conditional_order(order_id: int) -> Dict[str, Any]:
    try:
        obj_sql_server_model = SQLServerModel(database='StockDB')
        obj_sql_server_model.execute_update_usp(
            "exec [Order].[usp_DeleteOrder] @pintOrderID = ?",
            (order_id,)
        )
        return {"message": "Conditional order deleted successfully"}
    except Exception as e:
        return {"message": f"Note: Stored procedure may not exist. Error: {str(e)}"}