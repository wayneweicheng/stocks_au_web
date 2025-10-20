from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import AliasChoices, Field
from typing import Optional
import os


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
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

    # IB API connectivity (status probing)
    ibg_api_host: str = Field(default="127.0.0.1", validation_alias=AliasChoices("ibg_api_host", "IBG_API_HOST"))
    ibg_api_port: int = Field(default=0, validation_alias=AliasChoices("ibg_api_port", "IBG_API_PORT"))

    # IB Gateway UI preferences
    ibg_trading_mode: str = Field(default="Live", validation_alias=AliasChoices("ibg_trading_mode", "IBG_TRADING_MODE"))
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


settings = Settings()

# Ensure arkofdata_common EnvVarHelper sees expected uppercase keys
os.environ.setdefault("SQL_SERVER_HOST", settings.sqlserver_server)
os.environ.setdefault("SQL_SERVER_PORT", str(settings.sqlserver_port))
os.environ.setdefault("SQL_SERVER_DATABASE", settings.sqlserver_database)
os.environ.setdefault("SQL_SERVER_USER", settings.sqlserver_username)
os.environ.setdefault("SQL_SERVER_PASSWORD", settings.sqlserver_password)


