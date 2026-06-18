-- Stored procedure: [StockData].[usp_UpsertUnderlyingVolatilityHistory]

-- Stored procedure: [StockData].[usp_UpsertUnderlyingVolatilityHistory]

CREATE   PROCEDURE [StockData].[usp_UpsertUnderlyingVolatilityHistory]
    @pvchASXCode varchar(20),
    @pdtObservationDate date,
    @pdecIVOpen decimal(18,8) = NULL,
    @pdecIVHigh decimal(18,8) = NULL,
    @pdecIVLow decimal(18,8) = NULL,
    @pdecIVClose decimal(18,8) = NULL,
    @pdecHVOpen decimal(18,8) = NULL,
    @pdecHVHigh decimal(18,8) = NULL,
    @pdecHVLow decimal(18,8) = NULL,
    @pdecHVClose decimal(18,8) = NULL,
    @pvchSource varchar(30) = 'IBKR'
AS
BEGIN
    SET NOCOUNT ON;

    MERGE StockData.UnderlyingVolatilityHistory WITH (HOLDLOCK) AS target
    USING (SELECT UPPER(@pvchASXCode) AS ASXCode, @pdtObservationDate AS ObservationDate) AS source
       ON target.ASXCode = source.ASXCode
      AND target.ObservationDate = source.ObservationDate
    WHEN MATCHED THEN
        UPDATE SET
            IVOpen = COALESCE(@pdecIVOpen, target.IVOpen),
            IVHigh = COALESCE(@pdecIVHigh, target.IVHigh),
            IVLow = COALESCE(@pdecIVLow, target.IVLow),
            IVClose = COALESCE(@pdecIVClose, target.IVClose),
            HVOpen = COALESCE(@pdecHVOpen, target.HVOpen),
            HVHigh = COALESCE(@pdecHVHigh, target.HVHigh),
            HVLow = COALESCE(@pdecHVLow, target.HVLow),
            HVClose = COALESCE(@pdecHVClose, target.HVClose),
            Source = @pvchSource,
            ModifyDate = SYSDATETIME()
    WHEN NOT MATCHED THEN
        INSERT (
            ASXCode, ObservationDate,
            IVOpen, IVHigh, IVLow, IVClose,
            HVOpen, HVHigh, HVLow, HVClose,
            Source
        )
        VALUES (
            UPPER(@pvchASXCode), @pdtObservationDate,
            @pdecIVOpen, @pdecIVHigh, @pdecIVLow, @pdecIVClose,
            @pdecHVOpen, @pdecHVHigh, @pdecHVLow, @pdecHVClose,
            @pvchSource
        );
END;
