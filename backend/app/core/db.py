from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
from .config import settings
import pyodbc
from typing import Optional


SQL_ATTR_CONNECTION_TIMEOUT = 103


def get_sql_model() -> SQLServerModel:
    return SQLServerModel(database=settings.sqlserver_database)


class TimedSQLServerModel:
    """Small SQL model with explicit login and statement timeouts.

    The third-party SQLServerModel currently uses a five-minute connection
    timeout and swallows query exceptions. That is unsuitable for a request
    path where the caller needs a bounded failure and a useful HTTP response.
    """

    def __init__(
        self,
        database: Optional[str] = None,
        connection_timeout: int = 5,
        query_timeout: int = 8,
    ) -> None:
        self.cnxn = get_db_connection(
            database=database,
            connection_timeout=connection_timeout,
        )
        # pyodbc exposes the statement timeout on the connection, not on the
        # cursor, for the SQL Server driver used by this application.
        self.cnxn.timeout = query_timeout
        self.cursor = self.cnxn.cursor()

    def execute_read_query(self, sql_query, values):
        self.cursor.execute(sql_query, values)
        if not self.cursor.description:
            return []
        columns = [column[0] for column in self.cursor.description]
        return [dict(zip(columns, list(row))) for row in self.cursor.fetchall()]

    def close(self) -> None:
        try:
            self.cursor.close()
        finally:
            self.cnxn.close()


def get_timed_sql_model(
    database: Optional[str] = None,
    connection_timeout: int = 5,
    query_timeout: int = 8,
) -> TimedSQLServerModel:
    return TimedSQLServerModel(
        database=database,
        connection_timeout=connection_timeout,
        query_timeout=query_timeout,
    )


def get_db_connection(
    database: str = None,
    connection_timeout: Optional[int] = None,
) -> pyodbc.Connection:
    """
    Get a direct pyodbc connection to the SQL Server database.
    Use this for operations that require more control than SQLServerModel provides.

    Args:
        database: Optional database name to connect to. If not provided, uses settings.sqlserver_database.

    Returns:
        pyodbc Connection object
    """
    db_name = database if database is not None else settings.sqlserver_database

    connection_string = (
        f"DRIVER={{{settings.sqlserver_odbc_driver}}};"
        f"SERVER={settings.sqlserver_server},{settings.sqlserver_port};"
        f"DATABASE={db_name};"
        f"UID={settings.sqlserver_username};"
        f"PWD={settings.sqlserver_password};"
        f"Encrypt={settings.sqlserver_encrypt};"
        f"TrustServerCertificate={settings.sqlserver_trust_server_certificate};"
    )
    connect_options = {}
    if connection_timeout is not None:
        connect_options["attrs_before"] = {
            SQL_ATTR_CONNECTION_TIMEOUT: int(connection_timeout),
        }
    return pyodbc.connect(connection_string, **connect_options)

