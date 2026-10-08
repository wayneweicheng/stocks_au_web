-- Stored procedure: [Transform].[usp_ExecuteDailyBreakoutWatchlist]



CREATE OR ALTER PROCEDURE Transform.usp_ExecuteDailyBreakoutWatchlist
AS
BEGIN
    SET NOCOUNT ON;

    -- Do not blindly use GETDATE(): the current date may still be partial,
    -- may be a weekend/holiday, or may not have completed ASX data yet.
    -- Select the most recent sufficiently populated transformed date instead.
    DECLARE @ObservationDate DATE;

    SELECT TOP (1)
        @ObservationDate = ObservationDate
    FROM StockDB.Transform.PriceHistory
    WHERE ObservationDate <= CAST(GETDATE() AS DATE)
    GROUP BY ObservationDate
    HAVING COUNT(*) >= 100
    ORDER BY ObservationDate DESC;

    IF @ObservationDate IS NULL
        THROW 51001, 'No completed ASX price-history date is available for breakout watchlist calculation.', 1;

    EXEC Transform.usp_CalculateBreakoutWatchlist
        @ObservationDate = @ObservationDate;
END;
