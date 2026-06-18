-- Stored procedure: [Transform].[usp_RefreshBrokerEffectiveScore]


  CREATE   PROCEDURE Transform.usp_RefreshBrokerEffectiveScore
      @pAsOfDate              date            = NULL,
      @pASXCode               varchar(10)     = NULL,
      @pLookbackTradingDays   int             = 252,
      @pMinNetParticipation   decimal(18,8)   = 0.00500000,   -- 0.5% of stock day value
      @pMinBuyValue           decimal(20,4)   = 100000.0000,  -- A$100k
      @pPriorWeight           decimal(18,8)   = 5.00000000,   -- Bayesian shrinkage toward 0.5
      @pHalfLifeDays          int             = 180,          -- recency half-life proxy
      @pMinEventCount         int             = 8,
      @pPersistEvents         bit             = 1
  AS
  BEGIN
      SET NOCOUNT ON;
      SET XACT_ABORT ON;

      DECLARE @vAsOfDate date =
          COALESCE(@pAsOfDate, (SELECT MAX(ObservationDate) FROM StockData.PriceHistory));

      DECLARE @vBaseASXCode varchar(10) =
          CASE
              WHEN @pASXCode IS NULL THEN NULL
              ELSE UPPER(LTRIM(RTRIM(REPLACE(@pASXCode, '.AX', ''))))
          END;

      DECLARE @vScoreVersion varchar(40) = 'v1_pctrank_daily_event';

      DROP TABLE IF EXISTS #PriceScored;
      DROP TABLE IF EXISTS #BrokerEvent;
      DROP TABLE IF EXISTS #ScoreRaw;
      DROP TABLE IF EXISTS #ScoreFinal;

      ;WITH PriceBase AS
      (
          SELECT
              p.ASXCode AS PriceASXCode,
              CASE
                  WHEN RIGHT(p.ASXCode, 3) = '.AX' THEN LEFT(p.ASXCode, LEN(p.ASXCode) - 3)
                  ELSE p.ASXCode
              END AS ASXCode,
              p.ObservationDate,
              CAST(p.[Close] AS decimal(20,8)) AS ClosePrice,
              CAST(p.[Value] AS decimal(20,4)) AS DayTradedValue,

              LEAD(CAST(p.[Close] AS decimal(20,8)), 1)  OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS Close1,
              LEAD(CAST(p.[Close] AS decimal(20,8)), 3)  OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS Close3,
              LEAD(CAST(p.[Close] AS decimal(20,8)), 5)  OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS Close5,
              LEAD(CAST(p.[Close] AS decimal(20,8)), 10) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS Close10,
              LEAD(CAST(p.[Close] AS decimal(20,8)), 20) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS Close20,

              ROW_NUMBER() OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate DESC) AS rn_desc
          FROM StockData.PriceHistory p
          WHERE p.ObservationDate <= @vAsOfDate
            AND (
                  @vBaseASXCode IS NULL
                  OR CASE
                         WHEN RIGHT(p.ASXCode, 3) = '.AX' THEN LEFT(p.ASXCode, LEN(p.ASXCode) - 3)
                         ELSE p.ASXCode
                     END = @vBaseASXCode
                )
      ),
      PriceEligible AS
      (
          SELECT *
          FROM PriceBase
          WHERE rn_desc <= (@pLookbackTradingDays + 20)
      ),
      PriceReturns AS
      (
          SELECT
              PriceASXCode,
              ASXCode,
              ObservationDate,
              ClosePrice,
              DayTradedValue,

              CAST((Close1  / NULLIF(ClosePrice, 0)) - 1.0 AS decimal(18,8)) AS Fwd1dReturn,
              CAST((Close3  / NULLIF(ClosePrice, 0)) - 1.0 AS decimal(18,8)) AS Fwd3dReturn,
              CAST((Close5  / NULLIF(ClosePrice, 0)) - 1.0 AS decimal(18,8)) AS Fwd5dReturn,
              CAST((Close10 / NULLIF(ClosePrice, 0)) - 1.0 AS decimal(18,8)) AS Fwd10dReturn,
              CAST((Close20 / NULLIF(ClosePrice, 0)) - 1.0 AS decimal(18,8)) AS Fwd20dReturn
          FROM PriceEligible
          WHERE Close20 IS NOT NULL
            AND DayTradedValue IS NOT NULL
            AND DayTradedValue > 0
      ),
      PriceScored AS
      (
          SELECT
              PriceASXCode,
              ASXCode,
              ObservationDate,
              ClosePrice,
              DayTradedValue,
              Fwd1dReturn,
              Fwd3dReturn,
              Fwd5dReturn,
              Fwd10dReturn,
              Fwd20dReturn,

              CAST(PERCENT_RANK() OVER (PARTITION BY ASXCode ORDER BY Fwd1dReturn)  AS decimal(18,8)) AS PctRank1d,
              CAST(PERCENT_RANK() OVER (PARTITION BY ASXCode ORDER BY Fwd3dReturn)  AS decimal(18,8)) AS PctRank3d,
              CAST(PERCENT_RANK() OVER (PARTITION BY ASXCode ORDER BY Fwd5dReturn)  AS decimal(18,8)) AS PctRank5d,
              CAST(PERCENT_RANK() OVER (PARTITION BY ASXCode ORDER BY Fwd10dReturn) AS decimal(18,8)) AS PctRank10d,
              CAST(PERCENT_RANK() OVER (PARTITION BY ASXCode ORDER BY Fwd20dReturn) AS decimal(18,8)) AS PctRank20d
          FROM PriceReturns
      )
      SELECT *
      INTO #PriceScored
      FROM PriceScored;

      SELECT
          @vAsOfDate AS ScoreAsOfDate,
          ps.ASXCode,
          ps.PriceASXCode,
          b.BrokerName,
          bn.BrokerCode,
          ps.ObservationDate,

          CAST(ISNULL(b.BuyValue, 0)  AS decimal(20,4)) AS BuyValue,
          CAST(ISNULL(b.SellValue, 0) AS decimal(20,4)) AS SellValue,
          CAST(ISNULL(b.NetValue, 0)  AS decimal(20,4)) AS NetValue,
          CAST(b.TotalValue           AS decimal(20,4)) AS TotalValue,
          ps.DayTradedValue,

          CAST(CAST(ISNULL(b.NetValue, 0) AS decimal(20,4)) / NULLIF(ps.DayTradedValue, 0) AS decimal(18,8)) AS NetParticipationRatio,
          CAST(CAST(ISNULL(b.BuyValue, 0) AS decimal(20,4)) / NULLIF(ps.DayTradedValue, 0) AS decimal(18,8)) AS BuyParticipationRatio,

          ps.ClosePrice,

          ps.Fwd1dReturn,
          ps.Fwd3dReturn,
          ps.Fwd5dReturn,
          ps.Fwd10dReturn,
          ps.Fwd20dReturn,

          ps.PctRank1d,
          ps.PctRank3d,
          ps.PctRank5d,
          ps.PctRank10d,
          ps.PctRank20d,

          CAST(
                0.10 * CAST(ps.PctRank1d  AS float)
              + 0.15 * CAST(ps.PctRank3d  AS float)
              + 0.20 * CAST(ps.PctRank5d  AS float)
              + 0.25 * CAST(ps.PctRank10d AS float)
              + 0.30 * CAST(ps.PctRank20d AS float)
              AS decimal(18,8)
          ) AS EventScore,

          CAST(
              EXP(
                  (-1.0 * DATEDIFF(day, ps.ObservationDate, @vAsOfDate))
                  / NULLIF(CAST(@pHalfLifeDays AS float), 0.0)
              ) AS decimal(18,8)
          ) AS RecencyWeight,

          @vScoreVersion AS ScoreVersion
      INTO #BrokerEvent
      FROM BrokerData.BrokerDayReport b
      INNER JOIN #PriceScored ps
          ON ps.ASXCode = b.ASXCode
         AND ps.ObservationDate = b.ObservationDate
      LEFT JOIN LookupRef.BrokerName bn
          ON bn.BrokerName = b.BrokerName
          OR bn.APIBrokerName = b.BrokerName
      WHERE ISNULL(b.NetValue, 0) > 0
        AND CAST(ISNULL(b.BuyValue, 0) AS decimal(20,4)) >= @pMinBuyValue
        AND CAST(ISNULL(b.NetValue, 0) AS decimal(20,4)) / NULLIF(ps.DayTradedValue, 0) >= @pMinNetParticipation
        AND (@vBaseASXCode IS NULL OR b.ASXCode = @vBaseASXCode);

      IF @pPersistEvents = 1
      BEGIN
          DELETE e
          FROM Transform.BrokerEffectiveEvent e
          WHERE e.ScoreAsOfDate = @vAsOfDate
            AND (@vBaseASXCode IS NULL OR e.ASXCode = @vBaseASXCode);

          INSERT INTO Transform.BrokerEffectiveEvent
          (
              ScoreAsOfDate, ASXCode, PriceASXCode, BrokerName, BrokerCode, ObservationDate,
              BuyValue, SellValue, NetValue, TotalValue, DayTradedValue,
              NetParticipationRatio, BuyParticipationRatio, ClosePrice,
              Fwd1dReturn, Fwd3dReturn, Fwd5dReturn, Fwd10dReturn, Fwd20dReturn,
              PctRank1d, PctRank3d, PctRank5d, PctRank10d, PctRank20d,
              EventScore, RecencyWeight, ScoreVersion
          )
          SELECT
              ScoreAsOfDate, ASXCode, PriceASXCode, BrokerName, BrokerCode, ObservationDate,
              BuyValue, SellValue, NetValue, TotalValue, DayTradedValue,
              NetParticipationRatio, BuyParticipationRatio, ClosePrice,
              Fwd1dReturn, Fwd3dReturn, Fwd5dReturn, Fwd10dReturn, Fwd20dReturn,
              PctRank1d, PctRank3d, PctRank5d, PctRank10d, PctRank20d,
              EventScore, RecencyWeight, ScoreVersion
          FROM #BrokerEvent;
      END

      SELECT
          @vAsOfDate AS ScoreAsOfDate,
          e.ASXCode,
          e.BrokerName,
          MAX(e.BrokerCode) AS BrokerCode,

          COUNT(*) AS EventCount,
          CAST(SUM(CAST(e.RecencyWeight AS float)) AS decimal(18,8)) AS WeightedEventCount,

          CAST(AVG(CAST(e.EventScore AS float)) AS decimal(18,8)) AS AvgEventScore,

          CAST(
              (
                  (0.5 * CAST(@pPriorWeight AS float))
                  + SUM(CAST(e.RecencyWeight AS float) * CAST(e.EventScore AS float))
              )
              /
              NULLIF(
                  CAST(@pPriorWeight AS float) + SUM(CAST(e.RecencyWeight AS float)),
                  0.0
              )
              AS decimal(18,8)
          ) AS BrokerEffectiveScore,

          CAST(AVG(CASE WHEN e.Fwd5dReturn  > 0 THEN 1.0 ELSE 0.0 END) AS decimal(18,8)) AS WinRate5d,
          CAST(AVG(CASE WHEN e.Fwd10dReturn > 0 THEN 1.0 ELSE 0.0 END) AS decimal(18,8)) AS WinRate10d,
          CAST(AVG(CASE WHEN e.Fwd20dReturn > 0 THEN 1.0 ELSE 0.0 END) AS decimal(18,8)) AS WinRate20d,

          CAST(AVG(CAST(e.Fwd1dReturn  AS float)) AS decimal(18,8)) AS AvgReturn1d,
          CAST(AVG(CAST(e.Fwd3dReturn  AS float)) AS decimal(18,8)) AS AvgReturn3d,
          CAST(AVG(CAST(e.Fwd5dReturn  AS float)) AS decimal(18,8)) AS AvgReturn5d,
          CAST(AVG(CAST(e.Fwd10dReturn AS float)) AS decimal(18,8)) AS AvgReturn10d,
          CAST(AVG(CAST(e.Fwd20dReturn AS float)) AS decimal(18,8)) AS AvgReturn20d,

          MIN(e.ObservationDate) AS FirstEventDate,
          MAX(e.ObservationDate) AS LastEventDate,

          @vScoreVersion AS ScoreVersion
      INTO #ScoreRaw
      FROM #BrokerEvent e
      GROUP BY e.ASXCode, e.BrokerName
      HAVING COUNT(*) >= @pMinEventCount;

      SELECT
          s.ScoreAsOfDate,
          s.ASXCode,
          s.BrokerName,
          s.BrokerCode,
          s.EventCount,
          s.WeightedEventCount,
          s.AvgEventScore,
          s.BrokerEffectiveScore,
          s.WinRate5d,
          s.WinRate10d,
          s.WinRate20d,
          s.AvgReturn1d,
          s.AvgReturn3d,
          s.AvgReturn5d,
          s.AvgReturn10d,
          s.AvgReturn20d,
          s.FirstEventDate,
          s.LastEventDate,

          DENSE_RANK() OVER (
              PARTITION BY s.ASXCode
              ORDER BY s.BrokerEffectiveScore DESC, s.WeightedEventCount DESC, s.EventCount DESC, s.BrokerName ASC
          ) AS TopRank,

          DENSE_RANK() OVER (
              PARTITION BY s.ASXCode
              ORDER BY s.BrokerEffectiveScore ASC, s.WeightedEventCount DESC, s.EventCount DESC, s.BrokerName ASC
          ) AS BottomRank,

          s.ScoreVersion
      INTO #ScoreFinal
      FROM #ScoreRaw s;

      DELETE s
      FROM Transform.BrokerEffectiveScore s
      WHERE s.ScoreAsOfDate = @vAsOfDate
        AND (@vBaseASXCode IS NULL OR s.ASXCode = @vBaseASXCode);

      INSERT INTO Transform.BrokerEffectiveScore
      (
          ScoreAsOfDate, ASXCode, BrokerName, BrokerCode,
          EventCount, WeightedEventCount, AvgEventScore, BrokerEffectiveScore,
          WinRate5d, WinRate10d, WinRate20d,
          AvgReturn1d, AvgReturn3d, AvgReturn5d, AvgReturn10d, AvgReturn20d,
          FirstEventDate, LastEventDate, TopRank, BottomRank, ScoreVersion,
          CreatedDate, ModifiedDate
      )
      SELECT
          ScoreAsOfDate, ASXCode, BrokerName, BrokerCode,
          EventCount, WeightedEventCount, AvgEventScore, BrokerEffectiveScore,
          WinRate5d, WinRate10d, WinRate20d,
          AvgReturn1d, AvgReturn3d, AvgReturn5d, AvgReturn10d, AvgReturn20d,
          FirstEventDate, LastEventDate, TopRank, BottomRank, ScoreVersion,
          SYSUTCDATETIME(), SYSUTCDATETIME()
      FROM #ScoreFinal;
  END
