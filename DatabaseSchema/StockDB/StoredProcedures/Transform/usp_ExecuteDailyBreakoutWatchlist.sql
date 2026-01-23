-- Stored procedure: [Transform].[usp_ExecuteDailyBreakoutWatchlist]



CREATE PROCEDURE Transform.usp_ExecuteDailyBreakoutWatchlist
AS
BEGIN
    SET NOCOUNT ON;

    -- Get today's date (removes the time component)
    DECLARE @CurrentDate DATE = CAST(GETDATE() AS DATE);

    -- Execute the main procedure with today's date
    EXEC Transform.usp_CalculateBreakoutWatchlist
        @ObservationDate = @CurrentDate;
END;
