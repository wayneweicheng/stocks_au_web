-- Stored procedure: [Transform].[usp_RefreshBrokerEnhancePhase23]

-- Stored procedure: [Transform].[usp_RefreshBrokerEnhancePhase23]


/*
    Broker Enhance Unified Phase 2+3

    Orchestrates candidate selection, tx extraction, coverage build, and
    microstructure scoring in one pass using shared temp tables.

    Notes:
    - Default @pPersistArchive = 0 (fast path, no archive persistence).
    - Set @pPersistArchive = 1 for audit/backfill runs.
*/

CREATE   PROCEDURE Transform.usp_RefreshBrokerEnhancePhase23
    @pAsOfDate                    date            = NULL,
    @pASXCode                     varchar(10)     = NULL,
    @pvchStockCodeList            varchar(max)    = NULL,
    @pLookbackCalendarDays        int             = 30,
    @pTriggerMode                 varchar(20)     = 'HYBRID',
    @pMinBullishSetupScore        decimal(18,8)   = 0.60000000,
    @pMinBearishSetupScore        decimal(18,8)   = 0.60000000,
    @pMaxEventStocks              int             = 200,
    @pMinTotalValue               decimal(20,2)   = 0,
    @pPersistArchive              bit             = 0,
    @pArchiveRetentionDays        int             = 90
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    EXEC Transform.usp_RefreshBrokerEnhancePhase2
        @pAsOfDate = @pAsOfDate,
        @pASXCode = @pASXCode,
        @pvchStockCodeList = @pvchStockCodeList,
        @pLookbackCalendarDays = @pLookbackCalendarDays,
        @pTriggerMode = @pTriggerMode,
        @pMinBullishSetupScore = @pMinBullishSetupScore,
        @pMinBearishSetupScore = @pMinBearishSetupScore,
        @pMaxEventStocks = @pMaxEventStocks,
        @pArchiveRetentionDays = @pArchiveRetentionDays,
        @pRunPhase3 = 1,
        @pMinTotalValue = @pMinTotalValue,
        @pPersistArchive = @pPersistArchive;
END
