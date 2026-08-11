from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import AliasChoices, Field
from typing import Optional
import os
from pathlib import Path


_BACKEND_ENV_FILE = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(_BACKEND_ENV_FILE),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # SQL Server connection pieces (support legacy and new env names)
    sqlserver_server: str = Field(validation_alias=AliasChoices("sqlserver_server", "sql_server_host"))
    sqlserver_port: int = Field(default=1433, validation_alias=AliasChoices("sqlserver_port", "sql_server_port"))
    sqlserver_database: str = Field(validation_alias=AliasChoices("sqlserver_database", "sql_server_database", "sql_server_db"))
    sqlserver_username: str = Field(validation_alias=AliasChoices("sqlserver_username", "sql_server_user", "sql_server_username"))
    sqlserver_password: str = Field(validation_alias=AliasChoices("sqlserver_password", "sql_server_password"))
    sqlserver_encrypt: str = Field(default="yes", validation_alias=AliasChoices("sqlserver_encrypt"))
    sqlserver_trust_server_certificate: str = Field(default="yes", validation_alias=AliasChoices("sqlserver_trust_server_certificate"))
    sqlserver_odbc_driver: str = Field(default="ODBC Driver 18 for SQL Server", validation_alias=AliasChoices("sqlserver_odbc_driver"))
    sqlserver_connection_timeout: int = Field(default=30, validation_alias=AliasChoices("sqlserver_connection_timeout"))

    # Support/resistance is a synchronous, multi-query endpoint. Keep its
    # database work bounded so a blocked SQL query cannot hold the web worker
    # until the reverse proxy resets the connection.
    support_resistance_db_connection_timeout: int = Field(
        default=5,
        ge=1,
        le=60,
        validation_alias=AliasChoices(
            "support_resistance_db_connection_timeout",
            "SUPPORT_RESISTANCE_DB_CONNECTION_TIMEOUT",
        ),
    )
    support_resistance_db_query_timeout: int = Field(
        default=8,
        ge=1,
        le=60,
        validation_alias=AliasChoices(
            "support_resistance_db_query_timeout",
            "SUPPORT_RESISTANCE_DB_QUERY_TIMEOUT",
        ),
    )
    support_resistance_max_concurrent_requests: int = Field(
        default=1,
        ge=1,
        le=4,
        validation_alias=AliasChoices(
            "support_resistance_max_concurrent_requests",
            "SUPPORT_RESISTANCE_MAX_CONCURRENT_REQUESTS",
        ),
    )

    # Web
    allowed_origins: str = Field(default="http://localhost:3100", validation_alias=AliasChoices("allowed_origins"))
    allowed_origin_regex: Optional[str] = Field(default=None, validation_alias=AliasChoices("allowed_origin_regex"))

    # External resources (local directory path for charts)
    chart_base_url: str = Field(default="", validation_alias=AliasChoices("chart_base_url", "CHART_BASE_URL", "CHART_BASE_DIR"))

    # IB Gateway automation
    ibg_exe_path: str = Field(default="", validation_alias=AliasChoices("ibg_exe_path", "IBG_EXE_PATH"))
    ibg_username: str = Field(default="", validation_alias=AliasChoices("ibg_username", "IBG_USERNAME"))
    ibg_password: str = Field(default="", validation_alias=AliasChoices("ibg_password", "IBG_PASSWORD"))
    ibg_wait_after_kill_seconds: int = Field(default=10, validation_alias=AliasChoices("ibg_wait_after_kill_seconds", "IBG_WAIT_AFTER_KILL_SECONDS"))
    # IBC integration (preferred method for unattended operation)
    ibg_use_ibc_script: bool = Field(default=False, validation_alias=AliasChoices("ibg_use_ibc_script", "IBG_USE_IBC_SCRIPT"))
    ibg_ibc_script_path: str = Field(default="", validation_alias=AliasChoices("ibg_ibc_script_path", "IBG_IBC_SCRIPT_PATH"))

    # IB API connectivity (status probing)
    ibg_api_host: str = Field(default="127.0.0.1", validation_alias=AliasChoices("ibg_api_host", "IBG_API_HOST", "IB_SERVER"))
    ibg_api_port: int = Field(default=0, validation_alias=AliasChoices("ibg_api_port", "IBG_API_PORT", "PORT_NUMBER"))

    # SPXW GEX signal assistant
    spx_gex_strategy_enabled: bool = Field(default=True, validation_alias=AliasChoices("spx_gex_strategy_enabled", "SPX_GEX_STRATEGY_ENABLED"))
    spx_gex_source_database: str = Field(default="StockDB_US", validation_alias=AliasChoices("spx_gex_source_database", "SPX_GEX_SOURCE_DATABASE"))
    spx_gex_data_mode: str = Field(default="sql", validation_alias=AliasChoices("spx_gex_data_mode", "SPX_GEX_DATA_MODE"))
    spx_gex_gex_path: str = Field(default="data/option_gex_delta_signal_SPXW_2025-01-01_to_present.csv", validation_alias=AliasChoices("spx_gex_gex_path", "SPX_GEX_GEX_PATH"))
    spx_gex_nq_path: str = Field(default="data/NQMain_30M.csv", validation_alias=AliasChoices("spx_gex_nq_path", "SPX_GEX_NQ_PATH"))
    spx_gex_db_path: str = Field(default="data/spx_gex_strategy.sqlite3", validation_alias=AliasChoices("spx_gex_db_path", "SPX_GEX_DB_PATH"))
    spx_gex_timezone: str = Field(default="America/New_York", validation_alias=AliasChoices("spx_gex_timezone", "SPX_GEX_TIMEZONE"))
    spx_gex_lookback_days: int = Field(default=60, ge=60, validation_alias=AliasChoices("spx_gex_lookback_days", "SPX_GEX_LOOKBACK_DAYS"))
    spx_gex_initial_capital: float = Field(default=100000.0, gt=0, validation_alias=AliasChoices("spx_gex_initial_capital", "SPX_GEX_INITIAL_CAPITAL"))
    spx_gex_exposure_factor: float = Field(default=1.0, gt=0, validation_alias=AliasChoices("spx_gex_exposure_factor", "SPX_GEX_EXPOSURE_FACTOR"))
    spx_gex_notification_no_signal: bool = Field(default=False, validation_alias=AliasChoices("spx_gex_notification_no_signal", "SPX_GEX_NOTIFICATION_NO_SIGNAL"))
    spx_gex_require_live_nq: bool = Field(default=True, validation_alias=AliasChoices("spx_gex_require_live_nq", "SPX_GEX_REQUIRE_LIVE_NQ"))
    spx_gex_report_url: str = Field(default="https://pegasus.asxstocktoolings.com.au/api/spx-gex/report.html", validation_alias=AliasChoices("spx_gex_report_url", "SPX_GEX_REPORT_URL"))
    spx_gex_report_token: str = Field(default="", validation_alias=AliasChoices("spx_gex_report_token", "SPX_GEX_REPORT_TOKEN"))
    pushover_user_key: str = Field(
        default="",
        validation_alias=AliasChoices("pushover_user_key", "PUSHOVER_USER_KEY", "PUSHOVER_APP_USER"),
    )
    pushover_app_token: str = Field(
        default="",
        validation_alias=AliasChoices(
            "pushover_app_token",
            "PUSHOVER_APP_TOKEN",
            "pushover_api_token",
            "PUSHOVER_API_TOKEN",
        ),
    )
    pushover_device: str = Field(default="droid4", validation_alias=AliasChoices("pushover_device", "PUSHOVER_DEVICE"))
    pushover_sound: str = Field(default="echo", validation_alias=AliasChoices("pushover_sound", "PUSHOVER_SOUND"))
    ib_nq_symbol: str = Field(default="NQ", validation_alias=AliasChoices("ib_nq_symbol", "IB_NQ_SYMBOL"))
    ib_nq_exchange: str = Field(default="CME", validation_alias=AliasChoices("ib_nq_exchange", "IB_NQ_EXCHANGE"))
    ib_nq_currency: str = Field(default="USD", validation_alias=AliasChoices("ib_nq_currency", "IB_NQ_CURRENCY"))
    ib_market_data_type: int = Field(default=1, ge=1, le=4, validation_alias=AliasChoices("ib_market_data_type", "IB_MARKET_DATA_TYPE", "MARKET_DATA_TYPE"))

    # IB Gateway UI preferences
    ibg_trading_mode: str = Field(default="Live", validation_alias=AliasChoices("ibg_trading_mode", "IBG_TRADING_MODE"))
    # Optional: allow last-resort foreground typing fallback when UIA fails
    ibg_allow_fallback_typing: bool = Field(default=False, validation_alias=AliasChoices("ibg_allow_fallback_typing", "IBG_ALLOW_FALLBACK_TYPING"))
    # Optional calibrated relative positions (0..1) within IB Gateway window
    ibg_username_x_pct: Optional[float] = Field(default=None, validation_alias=AliasChoices("ibg_username_x_pct", "IBG_USERNAME_X_PCT"))
    ibg_username_y_pct: Optional[float] = Field(default=None, validation_alias=AliasChoices("ibg_username_y_pct", "IBG_USERNAME_Y_PCT"))
    ibg_password_x_pct: Optional[float] = Field(default=None, validation_alias=AliasChoices("ibg_password_x_pct", "IBG_PASSWORD_X_PCT"))
    ibg_password_y_pct: Optional[float] = Field(default=None, validation_alias=AliasChoices("ibg_password_y_pct", "IBG_PASSWORD_Y_PCT"))
    # Optional calibrated positions for Trading Mode tabs/buttons
    ibg_live_tab_x_pct: Optional[float] = Field(default=None, validation_alias=AliasChoices("ibg_live_tab_x_pct", "IBG_LIVE_TAB_X_PCT"))
    ibg_live_tab_y_pct: Optional[float] = Field(default=None, validation_alias=AliasChoices("ibg_live_tab_y_pct", "IBG_LIVE_TAB_Y_PCT"))
    ibg_paper_tab_x_pct: Optional[float] = Field(default=None, validation_alias=AliasChoices("ibg_paper_tab_x_pct", "IBG_PAPER_TAB_X_PCT"))
    ibg_paper_tab_y_pct: Optional[float] = Field(default=None, validation_alias=AliasChoices("ibg_paper_tab_y_pct", "IBG_PAPER_TAB_Y_PCT"))

    # IB simple order service (proxy target)
    ib_order_service_url: str = Field(default="http://127.0.0.1:8123", validation_alias=AliasChoices("ib_order_service_url", "IB_ORDER_SERVICE_URL"))

    # Skill runner service (proxy target)
    skill_runner_api_base_url: str = Field(default="http://192.168.20.112:3205", validation_alias=AliasChoices("skill_runner_api_base_url", "SKILL_RUNNER_API_BASE_URL"))
    skill_runner_api_token: str = Field(default="", validation_alias=AliasChoices("skill_runner_api_token", "SKILL_RUNNER_API_TOKEN"))


settings = Settings()

# Ensure arkofdata_common EnvVarHelper sees expected uppercase keys
os.environ.setdefault("SQL_SERVER_HOST", settings.sqlserver_server)
os.environ.setdefault("SQL_SERVER_PORT", str(settings.sqlserver_port))
os.environ.setdefault("SQL_SERVER_DATABASE", settings.sqlserver_database)
os.environ.setdefault("SQL_SERVER_USER", settings.sqlserver_username)
os.environ.setdefault("SQL_SERVER_PASSWORD", settings.sqlserver_password)
