from fastapi import APIRouter, Depends, HTTPException, Query, Path
from pydantic import BaseModel, EmailStr, Field, validator
from typing import Any, Dict, List, Optional, Literal
from app.routers.auth import verify_credentials
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel

router = APIRouter(prefix="/api", tags=["notification-users"])


class UserBase(BaseModel):
	email: EmailStr
	display_name: Optional[str] = None
	is_active: Optional[bool] = True
	# Channels
	pushover_user_key: Optional[str] = Field(default=None, max_length=50)
	pushover_enabled: Optional[bool] = True
	sms_phone_number: Optional[str] = Field(default=None, max_length=20)
	sms_enabled: Optional[bool] = False
	discord_webhook: Optional[str] = Field(default=None, max_length=500)
	discord_enabled: Optional[bool] = False
	# Global preferences
	notification_frequency: Optional[Literal["immediate", "batched_5min", "batched_hourly"]] = "immediate"
	quiet_hours_start: Optional[str] = None  # "HH:MM:SS"
	quiet_hours_end: Optional[str] = None
	timezone: Optional[str] = "Australia/Sydney"

	@validator("pushover_user_key")
	def validate_pushover_key(cls, v, values):
		if v is None or v == "":
			return None
		# Basic length/charset check (Pushover keys are 30 chars, but allow a range to be safe)
		if not (20 <= len(v) <= 40) or not v.isalnum():
			raise ValueError("Invalid Pushover user key format")
		return v

	@validator("sms_phone_number")
	def validate_sms_phone(cls, v, values):
		if v is None or v == "":
			return None
		# E.164 basic check e.g. +61412345678
		if v[0] != "+" or not v[1:].isdigit() or len(v) < 8 or len(v) > 20:
			raise ValueError("Phone must be in international format (e.g., +61412345678)")
		return v


class UserCreate(UserBase):
	pass


class UserUpdate(UserBase):
	pass


class UserOut(BaseModel):
	user_id: int
	email: str
	display_name: Optional[str]
	is_active: bool
	pushover_enabled: bool
	sms_enabled: bool
	discord_enabled: bool
	notification_frequency: str
	quiet_hours_start: Optional[str]
	quiet_hours_end: Optional[str]
	timezone: str
	subscription_count: int = 0
	last_notification_date: Optional[str] = None
	created_date: Optional[str] = None
	updated_date: Optional[str] = None


class UsersPage(BaseModel):
	items: List[UserOut]
	total: int
	page: int
	page_size: int


def _db() -> SQLServerModel:
	return SQLServerModel(database="StockDB")


@router.get("/users", response_model=UsersPage)
def list_users(
	q: Optional[str] = Query(default=None, description="Search by email or display name"),
	active: Optional[bool] = Query(default=None),
	page: int = Query(default=1, ge=1),
	page_size: int = Query(default=20, ge=1, le=100),
	username: str = Depends(verify_credentials),
) -> UsersPage:
	db = _db()
	filters = []
	params: List[Any] = []
	if q:
		filters.append("(u.Email LIKE ? OR u.DisplayName LIKE ?)")
		params.extend([f"%{q}%", f"%{q}%"])
	if active is not None:
		filters.append("u.IsActive = ?")
		params.append(1 if active else 0)
	where_sql = f"WHERE {' AND '.join(filters)}" if filters else ""

	count_rows = db.execute_read_usp(
		f"""
		SELECT COUNT(*) as total
		FROM [Notification].[Users] u
		{where_sql}
		""",
		tuple(params),
	) or []
	total = int(count_rows[0]["total"]) if count_rows else 0

	offset = (page - 1) * page_size
	rows = db.execute_read_usp(
		f"""
		SELECT
			u.UserID as user_id,
			u.Email as email,
			u.DisplayName as display_name,
			u.IsActive as is_active,
			u.PushoverEnabled as pushover_enabled,
			u.SMSEnabled as sms_enabled,
			u.DiscordEnabled as discord_enabled,
			u.NotificationFrequency as notification_frequency,
			CONVERT(varchar(8), u.QuietHoursStart, 108) as quiet_hours_start,
			CONVERT(varchar(8), u.QuietHoursEnd, 108) as quiet_hours_end,
			u.Timezone as timezone,
			ISNULL(COUNT(s.SubscriptionID), 0) as subscription_count,
			CONVERT(varchar(19), MAX(s.LastTriggeredDate), 126) as last_notification_date,
			CONVERT(varchar(19), u.CreatedDate, 126) as created_date,
			CONVERT(varchar(19), u.UpdatedDate, 126) as updated_date
		FROM [Notification].[Users] u
		LEFT JOIN [Notification].[UserSubscriptions] s ON u.UserID = s.UserID AND s.IsActive = 1
		{where_sql}
		GROUP BY u.UserID, u.Email, u.DisplayName, u.IsActive,
		         u.PushoverEnabled, u.SMSEnabled, u.DiscordEnabled,
		         u.NotificationFrequency, u.QuietHoursStart, u.QuietHoursEnd, u.Timezone,
		         u.CreatedDate, u.UpdatedDate
		ORDER BY u.CreatedDate DESC
		OFFSET ? ROWS FETCH NEXT ? ROWS ONLY
		""",
		tuple(params + [offset, page_size]),
	) or []
	# Normalize ISO timestamps
	for r in rows:
		if r.get("last_notification_date"):
			r["last_notification_date"] = r["last_notification_date"] + "Z"
		if r.get("created_date"):
			r["created_date"] = r["created_date"] + "Z"
		if r.get("updated_date"):
			r["updated_date"] = r["updated_date"] + "Z"
	return UsersPage(items=rows, total=total, page=page, page_size=page_size)


@router.get("/users/{user_id}", response_model=UserOut)
def get_user(
	user_id: int = Path(..., ge=1),
	username: str = Depends(verify_credentials),
) -> UserOut:
	db = _db()
	rows = db.execute_read_usp(
		"""
		SELECT
			u.UserID as user_id,
			u.Email as email,
			u.DisplayName as display_name,
			u.IsActive as is_active,
			u.PushoverEnabled as pushover_enabled,
			u.SMSEnabled as sms_enabled,
			u.DiscordEnabled as discord_enabled,
			u.NotificationFrequency as notification_frequency,
			CONVERT(varchar(8), u.QuietHoursStart, 108) as quiet_hours_start,
			CONVERT(varchar(8), u.QuietHoursEnd, 108) as quiet_hours_end,
			u.Timezone as timezone,
			ISNULL((SELECT COUNT(*) FROM [Notification].[UserSubscriptions] s WHERE s.UserID = u.UserID AND s.IsActive = 1), 0) as subscription_count,
			CONVERT(varchar(19), (SELECT MAX(s.LastTriggeredDate) FROM [Notification].[UserSubscriptions] s WHERE s.UserID = u.UserID), 126) as last_notification_date,
			CONVERT(varchar(19), u.CreatedDate, 126) as created_date,
			CONVERT(varchar(19), u.UpdatedDate, 126) as updated_date
		FROM [Notification].[Users] u
		WHERE u.UserID = ?
		""",
		(user_id,),
	) or []
	if not rows:
		raise HTTPException(status_code=404, detail="User not found")
	row = rows[0]
	for k in ["last_notification_date", "created_date", "updated_date"]:
		if row.get(k):
			row[k] = row[k] + "Z"
	return row  # type: ignore


@router.post("/users", response_model=UserOut)
def create_user(payload: UserCreate, username: str = Depends(verify_credentials)) -> UserOut:
	db = _db()
	# Enforce unique email
	exists = db.execute_read_usp(
		"SELECT COUNT(1) as cnt FROM [Notification].[Users] WHERE Email = ?",
		(payload.email,),
	) or []
	if int(exists[0]["cnt"]) > 0:
		raise HTTPException(status_code=400, detail="Email already exists")

	db.execute_update_usp(
		"""
		INSERT INTO [Notification].[Users] (
			Email, DisplayName, IsActive,
			PushoverUserKey, PushoverEnabled,
			SMSPhoneNumber, SMSEnabled,
			DiscordWebhook, DiscordEnabled,
			NotificationFrequency, QuietHoursStart, QuietHoursEnd, Timezone, CreatedDate, UpdatedDate
		) VALUES (
			?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, GETDATE(), GETDATE()
		)
		""",
		(
			str(payload.email).strip(),
			(payload.display_name or "").strip() or None,
			1 if payload.is_active else 0,
			(payload.pushover_user_key or None),
			1 if payload.pushover_enabled else 0,
			(payload.sms_phone_number or None),
			1 if payload.sms_enabled else 0,
			(payload.discord_webhook or None),
			1 if payload.discord_enabled else 0,
			payload.notification_frequency or "immediate",
			payload.quiet_hours_start,
			payload.quiet_hours_end,
			payload.timezone or "Australia/Sydney",
		),
	)
	# Return the created user
	row = db.execute_read_usp(
		"""
		SELECT TOP 1
			UserID as user_id, Email as email, DisplayName as display_name, IsActive as is_active,
			PushoverEnabled as pushover_enabled, SMSEnabled as sms_enabled, DiscordEnabled as discord_enabled,
			NotificationFrequency as notification_frequency,
			CONVERT(varchar(8), QuietHoursStart, 108) as quiet_hours_start,
			CONVERT(varchar(8), QuietHoursEnd, 108) as quiet_hours_end,
			Timezone as timezone,
			0 as subscription_count,
			NULL as last_notification_date,
			CONVERT(varchar(19), CreatedDate, 126) as created_date,
			CONVERT(varchar(19), UpdatedDate, 126) as updated_date
		FROM [Notification].[Users]
		WHERE Email = ?
		ORDER BY CreatedDate DESC
		""",
		(payload.email,),
	)[0]
	for k in ["last_notification_date", "created_date", "updated_date"]:
		if row.get(k):
			row[k] = row[k] + "Z"
	return row  # type: ignore


@router.put("/users/{user_id}", response_model=UserOut)
def update_user(
	user_id: int,
	payload: UserUpdate,
	username: str = Depends(verify_credentials),
) -> UserOut:
	db = _db()
	# Ensure exists
	found = db.execute_read_usp(
		"SELECT UserID FROM [Notification].[Users] WHERE UserID = ?",
		(user_id,),
	) or []
	if not found:
		raise HTTPException(status_code=404, detail="User not found")
	# Email uniqueness (if changed)
	exists = db.execute_read_usp(
		"SELECT COUNT(1) as cnt FROM [Notification].[Users] WHERE Email = ? AND UserID <> ?",
		(payload.email, user_id),
	) or []
	if int(exists[0]["cnt"]) > 0:
		raise HTTPException(status_code=400, detail="Email already exists")
	# Channel credential checks when enabled
	if payload.pushover_enabled and not payload.pushover_user_key:
		raise HTTPException(status_code=400, detail="Pushover user key required when Pushover is enabled")
	if payload.sms_enabled and not payload.sms_phone_number:
		raise HTTPException(status_code=400, detail="SMS phone number required when SMS is enabled")
	if payload.discord_enabled and not (payload.discord_webhook and payload.discord_webhook.startswith("http")):
		raise HTTPException(status_code=400, detail="Discord webhook URL required when Discord is enabled")

	db.execute_update_usp(
		"""
		UPDATE [Notification].[Users]
		SET Email = ?,
		    DisplayName = ?,
		    IsActive = ?,
		    PushoverUserKey = ?,
		    PushoverEnabled = ?,
		    SMSPhoneNumber = ?,
		    SMSEnabled = ?,
		    DiscordWebhook = ?,
		    DiscordEnabled = ?,
		    NotificationFrequency = ?,
		    QuietHoursStart = ?,
		    QuietHoursEnd = ?,
		    Timezone = ?,
		    UpdatedDate = GETDATE()
		WHERE UserID = ?
		""",
		(
			str(payload.email).strip(),
			(payload.display_name or "").strip() or None,
			1 if payload.is_active else 0,
			(payload.pushover_user_key or None),
			1 if payload.pushover_enabled else 0,
			(payload.sms_phone_number or None),
			1 if payload.sms_enabled else 0,
			(payload.discord_webhook or None),
			1 if payload.discord_enabled else 0,
			payload.notification_frequency or "immediate",
			payload.quiet_hours_start,
			payload.quiet_hours_end,
			payload.timezone or "Australia/Sydney",
			user_id,
		),
	)
	return get_user(user_id)


@router.delete("/users/{user_id}")
def delete_user(user_id: int, username: str = Depends(verify_credentials)) -> Dict[str, str]:
	db = _db()
	found = db.execute_read_usp(
		"SELECT UserID FROM [Notification].[Users] WHERE UserID = ?",
		(user_id,),
	) or []
	if not found:
		raise HTTPException(status_code=404, detail="User not found")
	# Cascade delete subscriptions
	db.execute_update_usp("DELETE FROM [Notification].[UserSubscriptions] WHERE UserID = ?", (user_id,))
	db.execute_update_usp("DELETE FROM [Notification].[Users] WHERE UserID = ?", (user_id,))
	return {"message": "User deleted"}


@router.patch("/users/{user_id}/toggle-active")
def toggle_user_active(
	user_id: int,
	is_active: bool = Query(...),
	username: str = Depends(verify_credentials),
) -> Dict[str, Any]:
	db = _db()
	found = db.execute_read_usp(
		"SELECT UserID FROM [Notification].[Users] WHERE UserID = ?",
		(user_id,),
	) or []
	if not found:
		raise HTTPException(status_code=404, detail="User not found")
	db.execute_update_usp(
		"UPDATE [Notification].[Users] SET IsActive = ?, UpdatedDate = GETDATE() WHERE UserID = ?",
		(1 if is_active else 0, user_id),
	)
	return {"user_id": user_id, "is_active": is_active}


