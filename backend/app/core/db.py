from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
from .config import settings
import pyodbc


def get_sql_model() -> SQLServerModel:
    return SQLServerModel(database=settings.sqlserver_database)


def get_db_connection(database: str = None) -> pyodbc.Connection:
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
    return pyodbc.connect(connection_string)

