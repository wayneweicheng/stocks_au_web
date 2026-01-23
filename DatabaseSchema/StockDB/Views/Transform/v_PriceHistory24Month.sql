-- View: [Transform].[v_PriceHistory24Month]



CREATE   VIEW Transform.v_PriceHistory24Month
AS
WITH Base AS (
    SELECT
        PH.ASXCode,
        PH.ObservationDate,
        PH.[Close],
        PH.Volume,
        CAST(
            AVG(PH.[Close]) OVER (
                PARTITION BY PH.ASXCode
                ORDER BY PH.ObservationDate
                ROWS BETWEEN 9 PRECEDING AND CURRENT ROW
            ) AS DECIMAL(18,6)
        ) AS SMA10,
        CAST(
            AVG(PH.[Close]) OVER (
                PARTITION BY PH.ASXCode
                ORDER BY PH.ObservationDate
                ROWS BETWEEN 49 PRECEDING AND CURRENT ROW
            ) AS DECIMAL(18,6)
        ) AS SMA50,
        LAG(PH.[Close], 1) OVER (
            PARTITION BY PH.ASXCode
            ORDER BY PH.ObservationDate
        ) AS PrevClose
    FROM Transform.PriceHistory24Month AS PH
),
BaseWithChange AS (
    SELECT
        b.*,
        CAST(
            CASE
                WHEN b.PrevClose IS NULL OR b.PrevClose = 0 THEN NULL
                ELSE 100.0 * (b.[Close] - b.PrevClose) / b.PrevClose
            END AS DECIMAL(18,4)
        ) AS PriceChangePct
    FROM Base AS b
)
SELECT
    bwc.ASXCode,
    bwc.ObservationDate,
    bwc.[Close],
    bwc.Volume AS TodayVolume,

    bwc.SMA10 AS TodaySMA10,

    LAG(bwc.SMA10, 1) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T1_SMA10,
    LAG(bwc.SMA50, 1) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T1_SMA50,
    LAG(bwc.Volume, 1) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T1_Volume,
    LAG(bwc.PriceChangePct, 1) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T1_PriceChangePct,

    LAG(bwc.SMA10, 2) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T2_SMA10,
    LAG(bwc.SMA50, 2) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T2_SMA50,
    LAG(bwc.Volume, 2) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T2_Volume,
    LAG(bwc.PriceChangePct, 2) OVER (PARTITION BY bwc.ASXCode ORDER BY bwc.ObservationDate) AS T2_PriceChangePct
FROM BaseWithChange AS bwc;