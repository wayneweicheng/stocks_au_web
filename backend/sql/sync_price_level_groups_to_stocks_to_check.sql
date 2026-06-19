USE [StockDB_US];
GO

SET NOCOUNT ON;
GO

/*
Keeps Configuration.PriceLevelStockGroupMember in sync with
LookupRef.StocksToCheck for the TRADE stock group type.

Rules:
- Any stock in at least one active price-level group should exist as TRADE.
- A TRADE row should be removed only when the stock is no longer in any active
  price-level group.
*/

INSERT INTO [LookupRef].[StocksToCheck] (ASXCode, StockGroupType)
SELECT DISTINCT m.ASXCode, 'TRADE'
FROM [Configuration].[PriceLevelStockGroupMember] AS m
INNER JOIN [Configuration].[PriceLevelStockGroup] AS g
    ON g.GroupID = m.GroupID
WHERE g.IsActive = 1
  AND NOT EXISTS (
      SELECT 1
      FROM [LookupRef].[StocksToCheck] AS s
      WHERE s.ASXCode = m.ASXCode
        AND s.StockGroupType = 'TRADE'
  );
GO

DELETE s
FROM [LookupRef].[StocksToCheck] AS s
WHERE s.StockGroupType = 'TRADE'
  AND NOT EXISTS (
      SELECT 1
      FROM [Configuration].[PriceLevelStockGroupMember] AS m
      INNER JOIN [Configuration].[PriceLevelStockGroup] AS g
          ON g.GroupID = m.GroupID
      WHERE g.IsActive = 1
        AND m.ASXCode = s.ASXCode
  );
GO

CREATE OR ALTER TRIGGER [Configuration].[trg_PriceLevelStockGroupMember_SyncStocksToCheck]
ON [Configuration].[PriceLevelStockGroupMember]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [LookupRef].[StocksToCheck] (ASXCode, StockGroupType)
    SELECT DISTINCT i.ASXCode, 'TRADE'
    FROM inserted AS i
    INNER JOIN [Configuration].[PriceLevelStockGroup] AS g
        ON g.GroupID = i.GroupID
    WHERE g.IsActive = 1
      AND NOT EXISTS (
          SELECT 1
          FROM [LookupRef].[StocksToCheck] AS s
          WHERE s.ASXCode = i.ASXCode
            AND s.StockGroupType = 'TRADE'
      );

    DELETE s
    FROM [LookupRef].[StocksToCheck] AS s
    WHERE s.StockGroupType = 'TRADE'
      AND s.ASXCode IN (
          SELECT ASXCode FROM deleted
          UNION
          SELECT ASXCode FROM inserted
      )
      AND NOT EXISTS (
          SELECT 1
          FROM [Configuration].[PriceLevelStockGroupMember] AS m
          INNER JOIN [Configuration].[PriceLevelStockGroup] AS g
              ON g.GroupID = m.GroupID
          WHERE g.IsActive = 1
            AND m.ASXCode = s.ASXCode
      );
END;
GO

CREATE OR ALTER TRIGGER [Configuration].[trg_PriceLevelStockGroup_SyncStocksToCheck]
ON [Configuration].[PriceLevelStockGroup]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(IsActive)
        RETURN;

    INSERT INTO [LookupRef].[StocksToCheck] (ASXCode, StockGroupType)
    SELECT DISTINCT m.ASXCode, 'TRADE'
    FROM inserted AS i
    INNER JOIN [Configuration].[PriceLevelStockGroupMember] AS m
        ON m.GroupID = i.GroupID
    WHERE i.IsActive = 1
      AND NOT EXISTS (
          SELECT 1
          FROM [LookupRef].[StocksToCheck] AS s
          WHERE s.ASXCode = m.ASXCode
            AND s.StockGroupType = 'TRADE'
      );

    DELETE s
    FROM [LookupRef].[StocksToCheck] AS s
    WHERE s.StockGroupType = 'TRADE'
      AND s.ASXCode IN (
          SELECT m.ASXCode
          FROM inserted AS i
          INNER JOIN [Configuration].[PriceLevelStockGroupMember] AS m
              ON m.GroupID = i.GroupID
      )
      AND NOT EXISTS (
          SELECT 1
          FROM [Configuration].[PriceLevelStockGroupMember] AS m
          INNER JOIN [Configuration].[PriceLevelStockGroup] AS g
              ON g.GroupID = m.GroupID
          WHERE g.IsActive = 1
            AND m.ASXCode = s.ASXCode
      );
END;
GO

SELECT *
FROM [LookupRef].[StocksToCheck]
WHERE ASXCode IN ('HOOD.US', 'SMCI.US')
ORDER BY ASXCode, StockGroupType;
GO
