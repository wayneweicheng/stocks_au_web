-- Trigger: [Configuration].[trg_PriceLevelStockGroup_SyncStocksToCheck]

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
