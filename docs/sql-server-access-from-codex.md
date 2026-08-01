# SQL Server Access From Codex

This note documents how Codex should inspect SQL Server objects in this repo when the connection details are already present in `backend/.env`.

Do not paste or print the actual username/password in chat, docs, logs, or command output. Load them from `.env` and show only database/object results.

## Configuration Source

The canonical runtime config is `backend/app/core/config.py`.

It reads `backend/.env` through Pydantic settings and supports these keys:

```env
sql_server_host=
sql_server_port=1433
sql_server_database=
sql_server_user=
sql_server_password=
```

It also maps them to the uppercase environment variables expected by `arkofdata_common`:

```text
SQL_SERVER_HOST
SQL_SERVER_PORT
SQL_SERVER_DATABASE
SQL_SERVER_USER
SQL_SERVER_PASSWORD
```

## Preferred Repo Helpers

For normal backend code, use the existing helpers in `backend/app/core/db.py`.

Use `SQLServerModel` for simple reads/writes:

```python
from arkofdata_common.SQLServerHelper.SQLServerHelper import SQLServerModel

model = SQLServerModel(database="StockDB_US")
rows = model.execute_read_query(
    """
    SELECT TOP (20) TABLE_SCHEMA, TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    ORDER BY TABLE_SCHEMA, TABLE_NAME
    """,
    (),
)
```

Use direct `pyodbc` when cursor metadata, transactions, or lower-level control is needed:

```python
from app.core.db import get_db_connection

with get_db_connection(database="StockDB_US") as conn:
    cursor = conn.cursor()
    cursor.execute(
        """
        SELECT TOP (20) s.name AS schema_name, o.name AS object_name, o.type_desc
        FROM sys.objects o
        JOIN sys.schemas s ON s.schema_id = o.schema_id
        WHERE o.is_ms_shipped = 0
        ORDER BY s.name, o.name
        """
    )
    rows = cursor.fetchall()
```

## One-Off Codex Inspection Command

From the repo root, run Python with `backend` on `PYTHONPATH` and let `backend/app/core/config.py` load `.env`.

PowerShell example:

```powershell
$env:PYTHONPATH = "backend"
C:\Application\PythonVenv\venv\Scripts\python.exe -c "from app.core.db import get_db_connection; conn=get_db_connection('StockDB_US'); cur=conn.cursor(); cur.execute('SELECT TOP (20) TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES ORDER BY TABLE_SCHEMA, TABLE_NAME'); print([tuple(r) for r in cur.fetchall()]); conn.close()"
```

For larger checks, create a temporary script under `.tmp/` and run it with the same interpreter. Keep output limited and never print `settings.sqlserver_password`.

## Common Object Queries

List user tables:

```sql
SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
ORDER BY s.name, t.name;
```

List views:

```sql
SELECT s.name AS schema_name, v.name AS view_name
FROM sys.views v
JOIN sys.schemas s ON s.schema_id = v.schema_id
ORDER BY s.name, v.name;
```

List stored procedures:

```sql
SELECT s.name AS schema_name, p.name AS procedure_name
FROM sys.procedures p
JOIN sys.schemas s ON s.schema_id = p.schema_id
ORDER BY s.name, p.name;
```

Show columns for one object:

```sql
SELECT
    c.column_id,
    c.name AS column_name,
    ty.name AS data_type,
    c.max_length,
    c.precision,
    c.scale,
    c.is_nullable
FROM sys.columns c
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID(N'Trading.Orders')
ORDER BY c.column_id;
```

Read module definition for a view/procedure/function:

```sql
SELECT sm.definition
FROM sys.sql_modules sm
WHERE sm.object_id = OBJECT_ID(N'Trading.v_ActiveOrders');
```

## Updating SQL Objects

For app code, prefer parameterized calls:

```python
model.execute_update_usp(
    """
    UPDATE Trading.Orders
    SET Status = ?
    WHERE OrderId = ?
    """,
    ("CANCELLED", order_id),
)
```

For ad hoc schema/data changes:

1. Put SQL in `backend/sql/` or `.tmp/`.
2. Include `USE [StockDB_US];` when the target database matters.
3. Make the script idempotent with `IF EXISTS` / `IF NOT EXISTS`.
4. Run a read-only verification query afterwards.
5. Do not echo credentials or connection strings.

## Sandbox Note

Codex shell commands run inside the workspace sandbox by default. SQL Server access may require network permission. If a DB command fails with a network or connection error that looks sandbox-related, rerun the same command with escalation approval rather than copying credentials into another tool.
