# Manual Database Setup Order

The two SQL files in this directory are the only database scripts to apply manually before the smaller implementation model begins runtime coding.

## 1. Preflight

Run these read-only checks in the intended SQL Server connection:

```sql
SELECT
    @@SERVERNAME AS SqlServerName,
    DB_NAME() AS CurrentDatabase,
    CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)) AS ProductVersion;

USE [StockDB];
SELECT DB_NAME() AS DatabaseName,
       CAST(SERVERPROPERTY('ServerName') AS nvarchar(256)) AS ServerName;

USE [StockDB_US];
SELECT DB_NAME() AS DatabaseName,
       CAST(SERVERPROPERTY('ServerName') AS nvarchar(256)) AS ServerName;
```

The two `ServerName` values must match. If they do not, stop; the notification design needs a relay/outbox instead of a cross-database transaction.

Also confirm that the existing queue table has no unexpected `rowversion` column before applying [manual-notification-queue-ddl.sql](manual-notification-queue-ddl.sql).

## 2. Apply the DDL

Apply in this order, after taking backups:

1. [manual-trading-signal-ddl.sql](manual-trading-signal-ddl.sql) against `StockDB_US`.
2. [manual-notification-queue-ddl.sql](manual-notification-queue-ddl.sql) against `StockDB`.

The scripts create no Strategy Definition, Version, Deployment, Execution Book, recipient, schedule, stored procedure, view, permission, or notification data. Do not manually seed production strategy rows yet.

## 3. Verify objects

```sql
USE [StockDB_US];

SELECT s.name AS SchemaName, t.name AS TableName
FROM sys.tables AS t
JOIN sys.schemas AS s ON s.schema_id = t.schema_id
WHERE s.name = 'TradingSignal'
ORDER BY t.name;

SELECT i.name AS IndexName, OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName,
       OBJECT_NAME(i.object_id) AS TableName, i.is_unique, i.filter_definition
FROM sys.indexes AS i
WHERE i.object_id IN
(
    SELECT t.object_id
    FROM sys.tables AS t
    JOIN sys.schemas AS s ON s.schema_id = t.schema_id
    WHERE s.name = 'TradingSignal'
)
ORDER BY TableName, IndexName;

USE [StockDB];

SELECT c.name AS ColumnName, ty.name AS DataType, c.max_length,
       c.is_nullable, c.is_rowguidcol
FROM sys.columns AS c
JOIN sys.types AS ty ON ty.user_type_id = c.user_type_id
WHERE c.object_id = OBJECT_ID('[Notification].[MessageQueue]')
ORDER BY c.column_id;

SELECT i.name AS IndexName, i.is_unique, i.filter_definition
FROM sys.indexes AS i
WHERE i.object_id = OBJECT_ID('[Notification].[MessageQueue]')
ORDER BY i.name;
```

Expected TradingSignal tables are:

```text
AuditEvent
ExecutionBook
LegacyIdentityMap
LegacyImportBatch
NotificationDelivery
NotificationEvent
Observation
ReportAlias
ReportSnapshot
SchemaVersion
Signal
SignalOutcome
StrategyComparison
StrategyDefinition
StrategyDeployment
StrategyInstrumentRole
StrategyRun
StrategyRunAttempt
StrategySchedule
StrategyVersion
TradePlan
TradePlanEvent
```

## 4. What remains for the implementation model

The smaller model must still implement and test:

- claim/reclaim/lease/fencing stored procedures;
- evaluation/lifecycle/correction transactions;
- notification queue procedure changes and handler synchronization;
- report catalog views/procedures;
- permissions/read-only web principal;
- strategy seed/configuration rows;
- migration, runtime CLI, and deployment scheduling.

Do not treat successful DDL execution as proof that the runtime is ready or safe to enable.

