/* StockDB_US.StockData.PriceLevelMapLevel */
IF SCHEMA_ID(N'StockData') IS NULL
    EXEC(N'CREATE SCHEMA StockData');
GO

IF OBJECT_ID(N'StockData.PriceLevelMapLevel', N'U') IS NULL
BEGIN
    CREATE TABLE StockData.PriceLevelMapLevel
    (
        PriceLevelMapLevelId BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_PriceLevelMapLevel PRIMARY KEY,
        PriceLevelMapId      BIGINT NOT NULL,
        LevelOrdinal         INT NOT NULL,
        LevelLow             DECIMAL(19,6) NOT NULL,
        LevelHigh            DECIMAL(19,6) NOT NULL,
        LevelCenter          AS CONVERT(DECIMAL(19,6), (LevelLow + LevelHigh) / 2.0) PERSISTED,
        LevelType            VARCHAR(32) NULL,
        Polarity             VARCHAR(16) NULL,
        SourceJsonPath       VARCHAR(128) NOT NULL
            CONSTRAINT DF_PriceLevelMapLevel_SourceJsonPath DEFAULT ('zones[]'),
        LevelJson            NVARCHAR(MAX) NULL,
        InsertedAtUtc        DATETIME2(3) NOT NULL
            CONSTRAINT DF_PriceLevelMapLevel_InsertedAtUtc DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_PriceLevelMapLevel_Map FOREIGN KEY (PriceLevelMapId)
            REFERENCES StockData.PriceLevelMap (PriceLevelMapId),
        CONSTRAINT CK_PriceLevelMapLevel_Range CHECK (LevelLow > 0 AND LevelHigh >= LevelLow),
        CONSTRAINT CK_PriceLevelMapLevel_LevelJson CHECK (LevelJson IS NULL OR ISJSON(LevelJson) = 1),
        CONSTRAINT UQ_PriceLevelMapLevel_Ordinal UNIQUE (PriceLevelMapId, LevelOrdinal)
    );
END;
GO
