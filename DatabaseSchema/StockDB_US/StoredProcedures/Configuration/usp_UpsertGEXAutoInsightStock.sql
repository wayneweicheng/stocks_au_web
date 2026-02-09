-- Stored procedure: [Configuration].[usp_UpsertGEXAutoInsightStock]


CREATE PROCEDURE [Configuration].[usp_UpsertGEXAutoInsightStock]
    @pvchStockCode VARCHAR(20),
    @pnvcDisplayName NVARCHAR(100) = NULL,
    @pbitIsActive BIT = 1,
    @pintPriority INT = 0,
    @pvchLLMModel VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    MERGE INTO [Configuration].[GEXAutoInsightStocks] AS target
    USING (SELECT @pvchStockCode AS StockCode) AS source
    ON target.StockCode = source.StockCode
    WHEN MATCHED THEN
        UPDATE SET
            DisplayName = ISNULL(@pnvcDisplayName, target.DisplayName),
            IsActive = @pbitIsActive,
            Priority = @pintPriority,
            LLMModel = @pvchLLMModel,
            UpdatedDate = GETDATE()
    WHEN NOT MATCHED THEN
        INSERT (StockCode, DisplayName, IsActive, Priority, LLMModel)
        VALUES (@pvchStockCode, @pnvcDisplayName, @pbitIsActive, @pintPriority, @pvchLLMModel);

    SELECT
        StockCode,
        DisplayName,
        IsActive,
        Priority,
        LLMModel,
        CreatedDate,
        UpdatedDate
    FROM [Configuration].[GEXAutoInsightStocks]
    WHERE StockCode = @pvchStockCode;
END
