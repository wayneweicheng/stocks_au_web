-- Add NOT_DETERMINED as an allowed SignalStrengthLevel.
-- Run this in StockDB_US after backing up or confirming no concurrent writes.

DECLARE @schema_name SYSNAME = 'Analysis';
DECLARE @table_name SYSNAME = 'SignalStrength';
DECLARE @constraint_name SYSNAME;
DECLARE @sql NVARCHAR(MAX);

SELECT @constraint_name = cc.name
FROM sys.check_constraints cc
INNER JOIN sys.tables t ON cc.parent_object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = @schema_name
  AND t.name = @table_name
  AND cc.definition LIKE '%SignalStrengthLevel%';

IF @constraint_name IS NOT NULL
BEGIN
    SET @sql = N'ALTER TABLE [' + @schema_name + N'].[' + @table_name + N'] DROP CONSTRAINT [' + @constraint_name + N'];';
    EXEC sp_executesql @sql;
END

ALTER TABLE Analysis.SignalStrength
ADD CONSTRAINT CK_SignalStrength_Level
CHECK (SignalStrengthLevel IN (
    'STRONGLY_BULLISH',
    'MILDLY_BULLISH',
    'NEUTRAL',
    'MILDLY_BEARISH',
    'STRONGLY_BEARISH',
    'NOT_DETERMINED'
));
