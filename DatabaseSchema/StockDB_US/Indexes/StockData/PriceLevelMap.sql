/* Indexes for StockDB_US.StockData.PriceLevelMap snapshots and ranges. */
IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'StockData.PriceLevelMap')
      AND name = N'IX_PriceLevelMap_Latest'
)
BEGIN
    CREATE INDEX IX_PriceLevelMap_Latest
        ON StockData.PriceLevelMap
        (ASXCode, ObservationDate, MapGeneratedAtUtc DESC, PriceLevelMapId DESC)
        INCLUDE (MapAsOfAtUtc, MethodVersion, SourceSystem);
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'StockData.PriceLevelMapLevel')
      AND name = N'IX_PriceLevelMapLevel_MapRange'
)
BEGIN
    CREATE INDEX IX_PriceLevelMapLevel_MapRange
        ON StockData.PriceLevelMapLevel
        (PriceLevelMapId, LevelLow, LevelHigh)
        INCLUDE (LevelCenter, LevelOrdinal, LevelType, Polarity);
END;
GO
