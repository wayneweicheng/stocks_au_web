-- Trigger: [Configuration].[trg_PriceLevelStockGroupMember_SyncStocksToCheck]

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
