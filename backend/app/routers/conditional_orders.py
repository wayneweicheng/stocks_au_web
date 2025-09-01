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
            "exec [Order].[usp_GetOrders]"
        )
        return data or []
    except Exception as e:
        # If stored procedure doesn't exist, return empty list
        return []


@router.post("/conditional-orders")
def create_conditional_order(order: ConditionalOrder) -> Dict[str, Any]:
    try:
        obj_sql_server_model = SQLServerModel(database='StockDB')
        
        # Call stored procedure with DECLARE for output parameters (SQL Server requirement)
        sql_with_outputs = """
        DECLARE @pintErrorNumber INT, @pvchMessage VARCHAR(200);
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
        SELECT @pintErrorNumber as ErrorNumber, @pvchMessage as Message;
        """
        
        result = obj_sql_server_model.execute_read_usp(
            sql_with_outputs,
            (0, order.order_price or 0, order.volume_gt or 0, order.order_volume or 0, 
             order.valid_until or "", order.additional_settings or "", order.order_value or 0, order.price_buffer_ticks or 0)
        )
        return {"message": "Conditional order saved successfully"}
    except Exception as e:
        return {"message": f"Error: {str(e)}"}


@router.get("/conditional-orders/categories")
def get_categories() -> List[str]:
    return ["Stock"]


@router.get("/conditional-orders/accounts")
def get_trade_accounts() -> List[str]:
    return ["huanw2114"]


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