from fastapi import APIRouter, Depends, HTTPException, Query, Path
from pydantic import BaseModel, Field, validator
from typing import Any, Dict, List, Optional, Literal
import json
from app.routers.auth import verify_credentials
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel

router = APIRouter(prefix="/api", tags=["user-subscriptions"])

TriggerOperator = Literal["above", "below", "equals", "between", "change_more_than", "change_less_than"]


def _db() -> SQLServerModel:
	return SQLServerModel(database="StockDB")


class SubscriptionBase(BaseModel):
	subscription_type_id: int = Field(..., ge=1)
	entity_code: str
	is_active: Optional[bool] = True
	trigger_value: Optional[float] = None
	trigger_value2: Optional[float] = None
	trigger_operator: Optional[TriggerOperator] = "above"
	include_keywords: Optional[List[str]] = None
	exclude_keywords: Optional[List[str]] = None
	priority: Optional[int] = 0
	notification_channel: Optional[Literal["Pushover", "SMS", "Discord", "Email"]] = None
	configuration_json: Optional[Dict[str, Any]] = None

	@validator("entity_code")
	def validate_entity_code(cls, v):
		val = (v or "").strip().upper()
		if not val:
			raise ValueError("EntityCode cannot be empty")
		return val

	@validator("priority")
	def validate_priority(cls, v):
		if v is None:
			return 0
		if v not in (0, 1, 2):
			raise ValueError("Priority must be 0, 1, or 2")
		return v


class SubscriptionCreate(SubscriptionBase):
	pass


class SubscriptionUpdate(SubscriptionBase):
	pass


def _load_subscription_type(db: SQLServerModel, subscription_type_id: int) -> Optional[Dict[str, Any]]:
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
			SupportsTextFilter
		FROM [Notification].[SubscriptionTypes]
		WHERE SubscriptionTypeID = ? AND IsActive = 1
		""",
		(subscription_type_id,),
	) or []
	return rows[0] if rows else None


def _validate_against_type(payload: SubscriptionBase, typ: Dict[str, Any]) -> None:
	requires_tv = bool(typ.get("RequiresTriggerValue"))
	if requires_tv and payload.trigger_value is None:
		raise HTTPException(status_code=400, detail="TriggerValue is required for this subscription type")
	if requires_tv:
		tvmin = typ.get("TriggerValueMin")
		tvmax = typ.get("TriggerValueMax")
		if tvmin is not None and payload.trigger_value is not None and float(payload.trigger_value) < float(tvmin):
			raise HTTPException(status_code=400, detail=f"TriggerValue must be >= {tvmin}")
		if tvmax is not None and payload.trigger_value is not None and float(payload.trigger_value) > float(tvmax):
			raise HTTPException(status_code=400, detail=f"TriggerValue must be <= {tvmax}")
	requires_tv2 = bool(typ.get("RequiresTriggerValue2"))
	if requires_tv2 and payload.trigger_value2 is None:
		# Only strictly require second when operator suggests range/between
		if (payload.trigger_operator or "above") == "between":
			raise HTTPException(status_code=400, detail="TriggerValue2 is required for 'between' operator")
	supports_text = bool(typ.get("SupportsTextFilter"))
	if not supports_text and (payload.include_keywords or payload.exclude_keywords):
		raise HTTPException(status_code=400, detail="This subscription type does not support keyword filters")
	# JSON validation
	if payload.configuration_json is not None:
		try:
			json.dumps(payload.configuration_json)
		except Exception:
			raise HTTPException(status_code=400, detail="ConfigurationJSON must be valid JSON")
	if payload.include_keywords is not None:
		if not isinstance(payload.include_keywords, list) or any(not isinstance(x, str) for x in payload.include_keywords):
			raise HTTPException(status_code=400, detail="IncludeKeywords must be a list of strings")
	if payload.exclude_keywords is not None:
		if not isinstance(payload.exclude_keywords, list) or any(not isinstance(x, str) for x in payload.exclude_keywords):
			raise HTTPException(status_code=400, detail="ExcludeKeywords must be a list of strings")


@router.get("/users/{user_id}/subscriptions")
def list_user_subscriptions(
	user_id: int,
	username: str = Depends(verify_credentials),
) -> List[Dict[str, Any]]:
	db = _db()
	rows = db.execute_read_usp(
		"""
		SELECT
			s.SubscriptionID,
			s.EntityCode,
			st.EventType,
			st.DisplayName as SubscriptionTypeName,
			st.SubscriptionTypeCode,
			s.TriggerValue,
			st.TriggerValueUnit,
			s.TriggerOperator,
			s.TriggerValue2,
			s.IncludeKeywords,
			s.ExcludeKeywords,
			s.Priority,
			s.NotificationChannel,
			s.IsActive,
			CONVERT(varchar(19), s.LastTriggeredDate, 126) as LastTriggeredDate,
			s.TriggerCount,
			CONVERT(varchar(19), s.CreatedDate, 126) as CreatedDate
		FROM [Notification].[UserSubscriptions] s
		INNER JOIN [Notification].[SubscriptionTypes] st ON s.SubscriptionTypeID = st.SubscriptionTypeID
		WHERE s.UserID = ?
		ORDER BY st.EventType, s.EntityCode
		""",
		(user_id,),
	) or []
	for r in rows:
		if r.get("LastTriggeredDate"):
			r["LastTriggeredDate"] = r["LastTriggeredDate"] + "Z"
		if r.get("CreatedDate"):
			r["CreatedDate"] = r["CreatedDate"] + "Z"
	return rows


@router.get("/subscriptions/{subscription_id}")
def get_subscription(
	subscription_id: int,
	username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
	db = _db()
	rows = db.execute_read_usp(
		"""
		SELECT
			s.*,
			st.DisplayName as SubscriptionTypeName,
			st.EventType
		FROM [Notification].[UserSubscriptions] s
		INNER JOIN [Notification].[SubscriptionTypes] st ON s.SubscriptionTypeID = st.SubscriptionTypeID
		WHERE s.SubscriptionID = ?
		""",
		(subscription_id,),
	) or []
	if not rows:
		raise HTTPException(status_code=404, detail="Subscription not found")
	row = rows[0]
	return row


@router.post("/users/{user_id}/subscriptions")
def create_subscription(
	user_id: int,
	payload: SubscriptionCreate,
	username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
	db = _db()
	# ensure user exists
	u = db.execute_read_usp("SELECT UserID FROM [Notification].[Users] WHERE UserID = ?", (user_id,)) or []
	if not u:
		raise HTTPException(status_code=404, detail="User not found")
	# load type
	sub_type = _load_subscription_type(db, payload.subscription_type_id)
	if not sub_type:
		raise HTTPException(status_code=400, detail="Invalid or inactive SubscriptionTypeID")
	# validate
	_validate_against_type(payload, sub_type)
	# duplicates
	dup = db.execute_read_usp(
		"""
		SELECT COUNT(*) as cnt
		FROM [Notification].[UserSubscriptions]
		WHERE UserID = ? AND SubscriptionTypeID = ? AND EntityCode = ?
		""",
		(user_id, payload.subscription_type_id, payload.entity_code),
	) or []
	if int(dup[0]["cnt"]) > 0:
		raise HTTPException(status_code=400, detail="Duplicate subscription for this type and entity")
	inc = json.dumps(payload.include_keywords or [])
	exc = json.dumps(payload.exclude_keywords or [])
	cfg = json.dumps(payload.configuration_json) if payload.configuration_json is not None else None
	db.execute_update_usp(
		"""
		INSERT INTO [Notification].[UserSubscriptions](
			UserID, SubscriptionTypeID, EntityCode,
			TriggerValue, TriggerValue2, TriggerOperator,
			IncludeKeywords, ExcludeKeywords,
			ConfigurationJSON,
			Priority, NotificationChannel, IsActive, CreatedDate, UpdatedDate
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE())
		""",
		(
			user_id,
			payload.subscription_type_id,
			payload.entity_code,
			payload.trigger_value,
			payload.trigger_value2,
			(payload.trigger_operator or "above"),
			inc,
			exc,
			cfg,
			payload.priority or 0,
			payload.notification_channel,
			1 if (payload.is_active is None or payload.is_active) else 0,
		),
	)
	return {"message": "Subscription created"}


@router.put("/subscriptions/{subscription_id}")
def update_subscription(
	subscription_id: int,
	payload: SubscriptionUpdate,
	username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
	db = _db()
	found = db.execute_read_usp(
		"SELECT UserID, SubscriptionTypeID, EntityCode FROM [Notification].[UserSubscriptions] WHERE SubscriptionID = ?",
		(subscription_id,),
	) or []
	if not found:
		raise HTTPException(status_code=404, detail="Subscription not found")
	# validate type
	sub_type = _load_subscription_type(db, payload.subscription_type_id)
	if not sub_type:
		raise HTTPException(status_code=400, detail="Invalid or inactive SubscriptionTypeID")
	_validate_against_type(payload, sub_type)
	# prevent duplicate clash if changing keys
	dup = db.execute_read_usp(
		"""
		SELECT COUNT(*) as cnt
		FROM [Notification].[UserSubscriptions]
		WHERE UserID = ?
		  AND SubscriptionTypeID = ?
		  AND EntityCode = ?
		  AND SubscriptionID <> ?
		""",
		(
			int(found[0]["UserID"]),
			payload.subscription_type_id,
			payload.entity_code,
			subscription_id,
		),
	) or []
	if int(dup[0]["cnt"]) > 0:
		raise HTTPException(status_code=400, detail="Duplicate subscription for this type and entity")
	inc = json.dumps(payload.include_keywords or [])
	exc = json.dumps(payload.exclude_keywords or [])
	cfg = json.dumps(payload.configuration_json) if payload.configuration_json is not None else None
	db.execute_update_usp(
		"""
		UPDATE [Notification].[UserSubscriptions]
		SET SubscriptionTypeID = ?,
		    EntityCode = ?,
		    TriggerValue = ?,
		    TriggerValue2 = ?,
		    TriggerOperator = ?,
		    IncludeKeywords = ?,
		    ExcludeKeywords = ?,
		    ConfigurationJSON = ?,
		    Priority = ?,
		    NotificationChannel = ?,
		    IsActive = ?,
		    UpdatedDate = GETDATE()
		WHERE SubscriptionID = ?
		""",
		(
			payload.subscription_type_id,
			payload.entity_code,
			payload.trigger_value,
			payload.trigger_value2,
			(payload.trigger_operator or "above"),
			inc,
			exc,
			cfg,
			payload.priority or 0,
			payload.notification_channel,
			1 if (payload.is_active is None or payload.is_active) else 0,
			subscription_id,
		),
	)
	return {"message": "Subscription updated"}


@router.delete("/subscriptions/{subscription_id}")
def delete_subscription(subscription_id: int, username: str = Depends(verify_credentials)) -> Dict[str, str]:
	db = _db()
	found = db.execute_read_usp(
		"SELECT SubscriptionID FROM [Notification].[UserSubscriptions] WHERE SubscriptionID = ?",
		(subscription_id,),
	) or []
	if not found:
		raise HTTPException(status_code=404, detail="Subscription not found")
	db.execute_update_usp(
		"DELETE FROM [Notification].[UserSubscriptions] WHERE SubscriptionID = ?",
		(subscription_id,),
	)
	return {"message": "Subscription deleted"}


