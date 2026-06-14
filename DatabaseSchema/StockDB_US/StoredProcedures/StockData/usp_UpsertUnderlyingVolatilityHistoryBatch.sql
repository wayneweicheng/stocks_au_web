-- Stored procedure: [StockData].[usp_UpsertUnderlyingVolatilityHistoryBatch]

CREATE OR ALTER PROCEDURE [StockData].[usp_UpsertUnderlyingVolatilityHistoryBatch]
    @pnvchRows nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Rows TABLE
    (
        ASXCode varchar(20) NOT NULL,
        ObservationDate date NOT NULL,
        IVOpen decimal(18,8) NULL,
        IVHigh decimal(18,8) NULL,
        IVLow decimal(18,8) NULL,
        IVClose decimal(18,8) NULL,
        HVOpen decimal(18,8) NULL,
        HVHigh decimal(18,8) NULL,
        HVLow decimal(18,8) NULL,
        HVClose decimal(18,8) NULL,
        Source varchar(30) NOT NULL
    );

    INSERT INTO @Rows
    SELECT
        UPPER(ASXCode), ObservationDate,
        IVOpen, IVHigh, IVLow, IVClose,
        HVOpen, HVHigh, HVLow, HVClose,
        COALESCE(Source, 'IBKR')
    FROM OPENJSON(@pnvchRows)
    WITH
    (
        ASXCode varchar(20) '$.asx_code',
        ObservationDate date '$.observation_date',
        IVOpen decimal(18,8) '$.iv_open',
        IVHigh decimal(18,8) '$.iv_high',
        IVLow decimal(18,8) '$.iv_low',
        IVClose decimal(18,8) '$.iv_close',
        HVOpen decimal(18,8) '$.hv_open',
        HVHigh decimal(18,8) '$.hv_high',
        HVLow decimal(18,8) '$.hv_low',
        HVClose decimal(18,8) '$.hv_close',
        Source varchar(30) '$.source'
    )
    WHERE ASXCode IS NOT NULL
      AND ObservationDate IS NOT NULL;

    MERGE StockData.UnderlyingVolatilityHistory WITH (HOLDLOCK) AS target
    USING @Rows AS source
       ON target.ASXCode = source.ASXCode
      AND target.ObservationDate = source.ObservationDate
    WHEN MATCHED THEN UPDATE SET
        IVOpen = COALESCE(source.IVOpen, target.IVOpen),
        IVHigh = COALESCE(source.IVHigh, target.IVHigh),
        IVLow = COALESCE(source.IVLow, target.IVLow),
        IVClose = COALESCE(source.IVClose, target.IVClose),
        HVOpen = COALESCE(source.HVOpen, target.HVOpen),
        HVHigh = COALESCE(source.HVHigh, target.HVHigh),
        HVLow = COALESCE(source.HVLow, target.HVLow),
        HVClose = COALESCE(source.HVClose, target.HVClose),
        Source = source.Source,
        ModifyDate = SYSDATETIME()
    WHEN NOT MATCHED THEN INSERT (
        ASXCode, ObservationDate,
        IVOpen, IVHigh, IVLow, IVClose,
        HVOpen, HVHigh, HVLow, HVClose,
        Source
    ) VALUES (
        source.ASXCode, source.ObservationDate,
        source.IVOpen, source.IVHigh, source.IVLow, source.IVClose,
        source.HVOpen, source.HVHigh, source.HVLow, source.HVClose,
        source.Source
    );
END;
