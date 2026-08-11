DECLARE @StockCode varchar(10) = 'SPXW.US';
DECLARE @Ticker varchar(10) = 'SPXW';
DECLARE @DateFrom date = '2025-01-01';
DECLARE @DateTo date = CONVERT(date, GETDATE());

;WITH SourceRows AS (
    SELECT
        CONVERT(date, ObservationDate) AS ObservationDate,
        ASXCode,
        CONVERT(decimal(38, 10), ABS(CONVERT(decimal(38, 10), GEXDelta))) AS AbsGEXDelta,
        CapitalType,
        CONVERT(decimal(19, 4), [Close]) AS [Close],
        CONVERT(decimal(19, 4), VWAP) AS VWAP
    FROM StockDB_US.Transform.OptionGEXChangeCapitalType WITH (NOLOCK)
    WHERE ASXCode = @StockCode
      AND CapitalType IS NOT NULL
      AND [Close] IS NOT NULL
      AND ObservationDate >= @DateFrom
      AND ObservationDate < DATEADD(day, 1, @DateTo)
),
DailyTotals AS (
    SELECT
        ObservationDate,
        SUM(AbsGEXDelta) AS TotalAbsGEXDelta,
        SUM(CASE WHEN CapitalType = 'BC' THEN AbsGEXDelta ELSE 0 END) AS BCAbsGEXDelta,
        SUM(CASE WHEN CapitalType = 'BP' THEN AbsGEXDelta ELSE 0 END) AS BPAbsGEXDelta,
        SUM(CASE WHEN CapitalType = 'SC' THEN AbsGEXDelta ELSE 0 END) AS SCAbsGEXDelta,
        SUM(CASE WHEN CapitalType = 'SP' THEN AbsGEXDelta ELSE 0 END) AS SPAbsGEXDelta
    FROM SourceRows
    GROUP BY ObservationDate
),
Metrics AS (
    SELECT
        s.ObservationDate,
        s.ASXCode,
        s.CapitalType,
        s.[Close],
        s.VWAP,
        s.AbsGEXDelta,
        d.TotalAbsGEXDelta,
        d.BCAbsGEXDelta,
        d.BPAbsGEXDelta,
        d.SCAbsGEXDelta,
        d.SPAbsGEXDelta,
        CONVERT(decimal(10, 2), ROUND(
            CASE WHEN d.TotalAbsGEXDelta = 0 THEN 0
                 ELSE s.AbsGEXDelta * CONVERT(decimal(10, 2), 100.0) / d.TotalAbsGEXDelta
            END,
            2
        )) AS GEXDeltaPerc,
        CONVERT(decimal(19, 8), d.BPAbsGEXDelta / NULLIF(d.BCAbsGEXDelta, 0)) AS PutCallRatio
    FROM SourceRows AS s
    INNER JOIN DailyTotals AS d
        ON d.ObservationDate = s.ObservationDate
),
Lagged AS (
    SELECT
        m.*,
        LAG(m.[Close]) OVER (
            PARTITION BY m.CapitalType
            ORDER BY m.ObservationDate
        ) AS PreviousClose,
        LAG(m.PutCallRatio) OVER (
            PARTITION BY m.CapitalType
            ORDER BY m.ObservationDate
        ) AS PreviousPutCallRatio
    FROM Metrics AS m
),
Changes AS (
    SELECT
        l.*,
        CONVERT(decimal(19, 3), ROUND(
            CASE WHEN l.PreviousClose IS NULL OR l.PreviousClose = 0 OR l.[Close] IS NULL THEN NULL
                 ELSE (l.[Close] - l.PreviousClose) * CONVERT(decimal(10, 3), 100.0) / l.PreviousClose
            END,
            3
        )) AS CloseChangePct,
        CONVERT(decimal(19, 3), ROUND(
            CASE WHEN l.PreviousPutCallRatio IS NULL OR l.PutCallRatio IS NULL THEN NULL
                 WHEN l.PreviousPutCallRatio = 0 THEN 0
                 ELSE (l.PutCallRatio - l.PreviousPutCallRatio) * CONVERT(decimal(10, 3), 100.0) / l.PreviousPutCallRatio
            END,
            3
        )) AS PCRChangePct
    FROM Lagged AS l
),
Signals AS (
    SELECT
        c.*,
        CASE
            WHEN c.[Close] > c.PreviousClose AND c.PCRChangePct > 5 THEN 'BEARISH'
            WHEN c.[Close] < c.PreviousClose AND c.PCRChangePct < -5 THEN 'BULLISH'
            WHEN c.CloseChangePct IS NOT NULL AND ABS(c.CloseChangePct) < 0.1 AND c.PCRChangePct > 20 THEN 'BEARISH'
            WHEN c.CloseChangePct IS NOT NULL AND ABS(c.CloseChangePct) < 0.1 AND c.PCRChangePct < -20 THEN 'BULLISH'
            ELSE NULL
        END AS Signal,
        CASE
            WHEN c.[Close] > c.PreviousClose AND c.PCRChangePct > 5 THEN '#fde047'
            WHEN c.[Close] < c.PreviousClose AND c.PCRChangePct < -5 THEN '#84cc16'
            WHEN c.CloseChangePct IS NOT NULL AND ABS(c.CloseChangePct) < 0.1 AND c.PCRChangePct > 20 THEN '#fde047'
            WHEN c.CloseChangePct IS NOT NULL AND ABS(c.CloseChangePct) < 0.1 AND c.PCRChangePct < -20 THEN '#84cc16'
            ELSE NULL
        END AS SignalColor
    FROM Changes AS c
),
Pivoted AS (
    SELECT
        ObservationDate,
        MAX(ASXCode) AS ASXCode,
        MAX(CASE WHEN CapitalType = 'BC' THEN GEXDeltaPerc END) AS BC_GEXDeltaPerc,
        MAX(CASE WHEN CapitalType = 'BC' THEN AbsGEXDelta END) AS BCAbsGEXDelta,
        MAX(TotalAbsGEXDelta) AS TotalAbsGEXDelta,
        MAX(BCAbsGEXDelta) AS DailyBCAbsGEXDelta,
        MAX(BPAbsGEXDelta) AS DailyBPAbsGEXDelta,
        MAX(SCAbsGEXDelta) AS DailySCAbsGEXDelta,
        MAX(SPAbsGEXDelta) AS DailySPAbsGEXDelta,
        MAX([Close]) AS [Close],
        MAX(VWAP) AS VWAP,
        MAX(CASE WHEN CapitalType = 'BC' THEN CloseChangePct END) AS CloseChangePct,
        MAX(CASE WHEN CapitalType = 'BC' THEN PutCallRatio END) AS PutCallRatio,
        MAX(CASE WHEN CapitalType = 'BC' THEN PCRChangePct END) AS PCRChangePct,
        MAX(CASE WHEN CapitalType = 'BC' THEN Signal END) AS Signal,
        MAX(CASE WHEN CapitalType = 'BC' THEN SignalColor END) AS SignalColor
    FROM Signals
    GROUP BY ObservationDate
)
SELECT
    p.ObservationDate,
    DATEADD(hour, 5, CONVERT(datetime2(0), p.ObservationDate)) AS ObservationDateUS_EST_0500,
    @Ticker AS Ticker,
    p.BC_GEXDeltaPerc,
    p.Signal,
    p.SignalColor,
    p.[Close],
    p.VWAP,
    p.CloseChangePct,
    p.PutCallRatio,
    p.PCRChangePct,
    p.TotalAbsGEXDelta,
    p.DailyBCAbsGEXDelta,
    p.DailyBPAbsGEXDelta,
    p.DailySCAbsGEXDelta,
    p.DailySPAbsGEXDelta
FROM Pivoted AS p
ORDER BY p.ObservationDate ASC;
