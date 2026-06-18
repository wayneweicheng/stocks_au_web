-- Stored procedure: [StockData].[usp_GetDailyMarketSnapshotUniverse]

-- Stored procedure: [StockData].[usp_GetDailyMarketSnapshotUniverse]

CREATE   PROCEDURE [StockData].[usp_GetDailyMarketSnapshotUniverse]
    @pdtObservationDate date = NULL,
    @pvchCollectionType varchar(20) = 'DAILY',
    @pintLimit int = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ObservationDate date = COALESCE(
        @pdtObservationDate,
        (SELECT MAX(ObservationDate) FROM StockData.PriceHistory)
    );

    ;WITH Universe AS
    (
        SELECT DISTINCT ASXCode
        FROM StockData.PriceHistory
        WHERE ObservationDate BETWEEN DATEADD(day, -10, @ObservationDate) AND @ObservationDate
          AND ASXCode LIKE '%.US'
    ),
    Ranked AS
    (
        SELECT
            u.ASXCode,
            LEFT(u.ASXCode, LEN(u.ASXCode) - 3) AS StockCode,
            @ObservationDate AS ObservationDate,
            CASE
                WHEN @pvchCollectionType = 'BACKFILL'
                    THEN COALESCE(v.IVCount, 0)
                WHEN @pvchCollectionType = 'BACKFILL_IV_HV'
                    THEN CASE
                        WHEN COALESCE(v.IVCount, 0) < COALESCE(v.HVCount, 0)
                            THEN COALESCE(v.IVCount, 0)
                        ELSE COALESCE(v.HVCount, 0)
                    END
                WHEN s.CollectionStatus = 'COMPLETE'
                    THEN 1
                ELSE 0
            END AS Completed,
            ROW_NUMBER() OVER (
                ORDER BY
                    CASE WHEN u.ASXCode IN ('SPY.US', 'QQQ.US', 'IWM.US', 'DIA.US') THEN 0 ELSE 1 END,
                    u.ASXCode
            ) AS RowNumber
        FROM Universe u
        OUTER APPLY
        (
            SELECT
                COUNT(CASE WHEN IVClose IS NOT NULL THEN 1 END) AS IVCount,
                COUNT(CASE WHEN HVClose IS NOT NULL THEN 1 END) AS HVCount
            FROM StockData.UnderlyingVolatilityHistory vh
            WHERE vh.ASXCode = u.ASXCode
              AND vh.ObservationDate >= DATEADD(day, -400, @ObservationDate)
        ) v
        LEFT JOIN StockData.DailyMarketSnapshot s
            ON s.ASXCode = u.ASXCode
           AND s.ObservationDate = @ObservationDate
    )
    SELECT ASXCode, StockCode, ObservationDate
    FROM Ranked
    WHERE ((
        UPPER(@pvchCollectionType) IN ('BACKFILL', 'BACKFILL_IV_HV')
        AND Completed < 200
    ) OR (
        UPPER(@pvchCollectionType) <> 'BACKFILL' AND Completed = 0
    ))
      AND (@pintLimit IS NULL OR RowNumber <= @pintLimit)
    ORDER BY RowNumber;
END;
