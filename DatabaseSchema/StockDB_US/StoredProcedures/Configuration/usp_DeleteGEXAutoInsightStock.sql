-- Stored procedure: [Configuration].[usp_DeleteGEXAutoInsightStock]


CREATE PROCEDURE [Configuration].[usp_DeleteGEXAutoInsightStock]
    @pvchStockCode VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM [Configuration].[GEXAutoInsightStocks]
    WHERE StockCode = @pvchStockCode;

    SELECT @@ROWCOUNT AS RowsDeleted;
END
