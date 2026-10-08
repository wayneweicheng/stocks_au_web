/* StockDB_US.StockData.PriceLevelMap */
IF SCHEMA_ID(N'StockData') IS NULL
    EXEC(N'CREATE SCHEMA StockData');
GO

IF OBJECT_ID(N'StockData.PriceLevelMap', N'U') IS NULL
BEGIN
    CREATE TABLE StockData.PriceLevelMap
    (
        PriceLevelMapId   BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_PriceLevelMap PRIMARY KEY,
        ASXCode           VARCHAR(32) NOT NULL,
        ObservationDate   DATE NOT NULL,
        MapGeneratedAtUtc DATETIME2(3) NOT NULL,
        MapAsOfAtUtc      DATETIME2(3) NULL,
        MethodVersion     VARCHAR(64) NULL,
        SourceSystem      VARCHAR(64) NOT NULL
            CONSTRAINT DF_PriceLevelMap_SourceSystem DEFAULT ('spx-map'),
        MapJson           NVARCHAR(MAX) NOT NULL,
        InsertedAtUtc     DATETIME2(3) NOT NULL
            CONSTRAINT DF_PriceLevelMap_InsertedAtUtc DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT CK_PriceLevelMap_AsxCode CHECK (LEN(ASXCode) > 0),
        CONSTRAINT CK_PriceLevelMap_MapJson CHECK (ISJSON(MapJson) = 1)
    );
END;
GO
