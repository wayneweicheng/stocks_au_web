from fastapi import APIRouter, Depends, HTTPException, Query, Path
from typing import Any, Dict, List, Optional
from app.routers.auth import verify_credentials
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel

router = APIRouter(prefix="/api", tags=["subscription-types"])


def _db() -> SQLServerModel:
	return SQLServerModel(database="StockDB")


@router.get("/subscription-types")
def list_subscription_types(
	eventType: Optional[str] = Query(default=None, alias="eventType"),
	username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
	db = _db()
	if eventType:
		rows = db.execute_read_usp(
			"""
			SELECT
				SubscriptionTypeID,
				SubscriptionTypeCode,
				EventType,
				DisplayName,
				Description,
				RequiresTriggerValue,
				TriggerValueType,
				TriggerValueMin,
				TriggerValueMax,
				TriggerValueUnit,
				RequiresTriggerValue2,
				TriggerValue2Type,
				SupportsTextFilter,
				SupportsPriorityLevels,
				IsActive,
				SortOrder
			FROM [Notification].[SubscriptionTypes]
			WHERE IsActive = 1 AND EventType = ?
			ORDER BY SortOrder, DisplayName
			""",
			(eventType,),
		) or []
	else:
		rows = db.execute_read_usp(
			"""
			SELECT
				SubscriptionTypeID,
				SubscriptionTypeCode,
				EventType,
				DisplayName,
				Description,
				RequiresTriggerValue,
				TriggerValueType,
				TriggerValueMin,
				TriggerValueMax,
				TriggerValueUnit,
				RequiresTriggerValue2,
				TriggerValue2Type,
				SupportsTextFilter,
				SupportsPriorityLevels,
				IsActive,
				SortOrder
			FROM [Notification].[SubscriptionTypes]
			WHERE IsActive = 1
			ORDER BY EventType, SortOrder, DisplayName
			""",
			(),
		) or []
	return rows


@router.get("/subscription-types/{subscription_type_id}")
def get_subscription_type(
	subscription_type_id: int = Path(..., ge=1),
	username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
	db = _db()
	rows = db.execute_read_usp(
		"""
		SELECT
			SubscriptionTypeID,
			SubscriptionTypeCode,
			EventType,
			DisplayName,
			Description,
			RequiresTriggerValue,
			TriggerValueType,
			TriggerValueMin,
			TriggerValueMax,
			TriggerValueUnit,
			RequiresTriggerValue2,
			TriggerValue2Type,
			SupportsTextFilter,
			SupportsPriorityLevels,
			IsActive,
			SortOrder
		FROM [Notification].[SubscriptionTypes]
		WHERE SubscriptionTypeID = ?
		""",
		(subscription_type_id,),
	) or []
	if not rows:
		raise HTTPException(status_code=404, detail="Subscription type not found")
	return rows[0]


