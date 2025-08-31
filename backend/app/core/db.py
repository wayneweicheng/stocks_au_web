from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel
from .config import settings


def get_sql_model() -> SQLServerModel:
    return SQLServerModel(database=settings.sqlserver_database)

