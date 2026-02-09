-- Stored procedure: [StockData].[usp_LogMetalsDataRefresh]


CREATE PROCEDURE [StockData].[usp_LogMetalsDataRefresh]
    @pdtRefreshDateTime DATETIME,
    @pvchMetal VARCHAR(20),
    @pintRecordsInserted INT = 0,
    @pintRecordsUpdated INT = 0,
    @pdecUnderlyingPrice DECIMAL(18, 6) = NULL,
    @pintTotalContracts INT = NULL,
    @pintContractsWithOI INT = NULL,
    @pintContractsWithVolume INT = NULL,
    @pintExecutionTimeSeconds INT = NULL,
    @pvchStatus VARCHAR(20) = 'Success',
    @pvchErrorMessage NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [StockData].[IBMetalsDataRefreshLog] (
        [RefreshDateTime],
        [Metal],
        [RecordsInserted],
        [RecordsUpdated],
        [UnderlyingPrice],
        [TotalContracts],
        [ContractsWithOI],
        [ContractsWithVolume],
        [ExecutionTimeSeconds],
        [Status],
        [ErrorMessage],
        [CreateDate]
    )
    VALUES (
        @pdtRefreshDateTime,
        @pvchMetal,
        @pintRecordsInserted,
        @pintRecordsUpdated,
        @pdecUnderlyingPrice,
        @pintTotalContracts,
        @pintContractsWithOI,
        @pintContractsWithVolume,
        @pintExecutionTimeSeconds,
        @pvchStatus,
        @pvchErrorMessage,
        GETDATE()
    )
END
