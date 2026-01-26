-- Stored Procedure: [Configuration].[usp_GetGEXAutoInsightStocks]
-- Returns the list of stocks configured for automatic GEX insight processing

CREATE PROCEDURE [Configuration].[usp_GetGEXAutoInsightStocks]
    @pbitActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        StockCode,
        DisplayName,
        IsActive,
        Priority,
        LLMModel,
        CreatedDate,
        UpdatedDate
    FROM [Configuration].[GEXAutoInsightStocks]
    WHERE @pbitActiveOnly = 0 OR IsActive = 1
    ORDER BY Priority DESC, StockCode ASC;
END
