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


settings = Settings()

# Ensure arkofdata_common EnvVarHelper sees expected uppercase keys
os.environ.setdefault("SQL_SERVER_HOST", settings.sqlserver_server)
os.environ.setdefault("SQL_SERVER_PORT", str(settings.sqlserver_port))
os.environ.setdefault("SQL_SERVER_DATABASE", settings.sqlserver_database)
os.environ.setdefault("SQL_SERVER_USER", settings.sqlserver_username)
os.environ.setdefault("SQL_SERVER_PASSWORD", settings.sqlserver_password)


