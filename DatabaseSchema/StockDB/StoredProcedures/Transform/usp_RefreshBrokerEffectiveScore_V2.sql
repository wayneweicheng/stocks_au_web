-- Stored procedure: [Transform].[usp_RefreshBrokerEffectiveScore_V2]


  CREATE   PROCEDURE Transform.usp_RefreshBrokerEffectiveScore_V2
      @pAsOfDate                              date            = NULL,
      @pASXCode                               varchar(10)     = NULL,
      @pLookbackTradingDays                   int             = 252,
      @pMinNetParticipation                   decimal(18,8)   = 0.00500000,
      @pMinBuyValue                           decimal(20,4)   = 100000.0000,
      @pMaxGapTradingDaysBetweenAccumDays     int             = 1,
      @pFullStrengthParticipation             decimal(18,8)   = 0.02000000,
      @pPriorWeight                           decimal(18,8)   = 5.00000000,
      @pHalfLifeDays                          int             = 180,
      @pMinCampaignCount                      int             = 5,
      @pPersistCampaigns                      bit             = 1
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

      DECLARE @vScoreVersion varchar(40) = 'v2_campaign_clustered';

      DROP TABLE IF EXISTS #PriceScored;
      DROP TABLE IF EXISTS #RawAccumDays;
      DROP TABLE IF EXISTS #CampaignTagged;
      DROP TABLE IF EXISTS #CampaignAgg;
      DROP TABLE IF EXISTS #CampaignFinal;
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

              ROW_NUMBER() OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS TradingDaySeq,
              ROW_NUMBER() OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate DESC) AS rn_desc,

              LEAD(CAST(p.[Close] AS decimal(20,8)), 1)  OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS Close1,
              LEAD(CAST(p.[Close] AS decimal(20,8)), 3)  OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS Close3,
              LEAD(CAST(p.[Close] AS decimal(20,8)), 5)  OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS Close5,
              LEAD(CAST(p.[Close] AS decimal(20,8)), 10) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS Close10,
              LEAD(CAST(p.[Close] AS decimal(20,8)), 20) OVER (PARTITION BY p.ASXCode ORDER BY p.ObservationDate) AS Close20
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
              TradingDaySeq,
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
              TradingDaySeq,
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
          ps.ASXCode,
          ps.PriceASXCode,
          b.BrokerName,
          bn.BrokerCode,
          ps.ObservationDate,
          ps.TradingDaySeq,
          ps.ClosePrice,
          ps.DayTradedValue,
          CAST(ISNULL(b.BuyValue, 0)  AS decimal(20,4)) AS BuyValue,
          CAST(ISNULL(b.SellValue, 0) AS decimal(20,4)) AS SellValue,
          CAST(ISNULL(b.NetValue, 0)  AS decimal(20,4)) AS NetValue,
          CAST(b.TotalValue           AS decimal(20,4)) AS TotalValue,
          CAST(CAST(ISNULL(b.NetValue, 0) AS decimal(20,4)) / NULLIF(ps.DayTradedValue, 0) AS decimal(18,8)) AS NetParticipationRatio,
          CAST(CAST(ISNULL(b.BuyValue, 0) AS decimal(20,4)) / NULLIF(ps.DayTradedValue, 0) AS decimal(18,8)) AS BuyParticipationRatio
      INTO #RawAccumDays
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

      ;WITH x AS
      (
          SELECT
              r.*,
              LAG(r.TradingDaySeq) OVER (PARTITION BY r.ASXCode, r.BrokerName ORDER BY r.ObservationDate) AS PrevTradingDaySeq
          FROM #RawAccumDays r
      ),
      y AS
      (
          SELECT
              x.*,
              CASE
                  WHEN x.PrevTradingDaySeq IS NULL THEN 1
                  WHEN x.TradingDaySeq - x.PrevTradingDaySeq > (@pMaxGapTradingDaysBetweenAccumDays + 1) THEN 1
                  ELSE 0
              END AS NewCampaignFlag
          FROM x
      )
      SELECT
          y.*,
          SUM(y.NewCampaignFlag) OVER (
              PARTITION BY y.ASXCode, y.BrokerName
              ORDER BY y.ObservationDate
              ROWS UNBOUNDED PRECEDING
          ) AS CampaignId
      INTO #CampaignTagged
      FROM y;

      ;WITH CampaignAgg AS
      (
          SELECT
              @vAsOfDate AS ScoreAsOfDate,
              c.ASXCode,
              MAX(c.PriceASXCode) AS PriceASXCode,
              c.BrokerName,
              MAX(c.BrokerCode) AS BrokerCode,
              c.CampaignId,

              MIN(c.ObservationDate) AS CampaignStartDate,
              MAX(c.ObservationDate) AS CampaignEndDate,
              COUNT(*) AS CampaignTradingDays,

              CAST(SUM(c.BuyValue) AS decimal(20,4)) AS CampaignBuyValue,
              CAST(SUM(c.SellValue) AS decimal(20,4)) AS CampaignSellValue,
              CAST(SUM(c.NetValue) AS decimal(20,4)) AS CampaignNetValue,
              CAST(SUM(c.DayTradedValue) AS decimal(20,4)) AS CampaignTradedValue,

              CAST(SUM(c.NetValue) / NULLIF(SUM(c.DayTradedValue), 0) AS decimal(18,8)) AS CampaignNetParticipationRatio,
              CAST(SUM(c.BuyValue) / NULLIF(SUM(c.DayTradedValue), 0) AS decimal(18,8)) AS CampaignBuyParticipationRatio,
              CAST(MAX(c.NetParticipationRatio) AS decimal(18,8)) AS PeakDailyNetParticipationRatio
          FROM #CampaignTagged c
          GROUP BY c.ASXCode, c.BrokerName, c.CampaignId
      )
      SELECT
          a.ScoreAsOfDate,
          a.ASXCode,
          a.PriceASXCode,
          a.BrokerName,
          a.BrokerCode,
          a.CampaignId,
          a.CampaignStartDate,
          a.CampaignEndDate,
          a.CampaignTradingDays,
          a.CampaignBuyValue,
          a.CampaignSellValue,
          a.CampaignNetValue,
          a.CampaignTradedValue,
          a.CampaignNetParticipationRatio,
          a.CampaignBuyParticipationRatio,
          a.PeakDailyNetParticipationRatio,
          psStart.ClosePrice AS EntryClosePrice,
          psEnd.ClosePrice AS SignalClosePrice,

          psEnd.Fwd1dReturn,
          psEnd.Fwd3dReturn,
          psEnd.Fwd5dReturn,
          psEnd.Fwd10dReturn,
          psEnd.Fwd20dReturn,

          psEnd.PctRank1d,
          psEnd.PctRank3d,
          psEnd.PctRank5d,
          psEnd.PctRank10d,
          psEnd.PctRank20d,

          CAST(
                0.10 * CAST(psEnd.PctRank1d  AS float)
              + 0.15 * CAST(psEnd.PctRank3d  AS float)
              + 0.20 * CAST(psEnd.PctRank5d  AS float)
              + 0.25 * CAST(psEnd.PctRank10d AS float)
              + 0.30 * CAST(psEnd.PctRank20d AS float)
              AS decimal(18,8)
          ) AS RawEventScore,

          CAST(
              CASE
                  WHEN a.CampaignNetParticipationRatio >= @pFullStrengthParticipation THEN 1.0
                  WHEN a.CampaignNetParticipationRatio <= 0 THEN 0.0
                  ELSE CAST(a.CampaignNetParticipationRatio AS float) / NULLIF(CAST(@pFullStrengthParticipation AS float), 0.0)
              END
              AS decimal(18,8)
          ) AS CampaignStrengthFactor,

          CAST(
              0.5
              +
              (
                  (
                        0.10 * CAST(psEnd.PctRank1d  AS float)
                      + 0.15 * CAST(psEnd.PctRank3d  AS float)
                      + 0.20 * CAST(psEnd.PctRank5d  AS float)
                      + 0.25 * CAST(psEnd.PctRank10d AS float)
                      + 0.30 * CAST(psEnd.PctRank20d AS float)
                  ) - 0.5
              )
              *
              CASE
                  WHEN a.CampaignNetParticipationRatio >= @pFullStrengthParticipation THEN 1.0
                  WHEN a.CampaignNetParticipationRatio <= 0 THEN 0.0
                  ELSE CAST(a.CampaignNetParticipationRatio AS float) / NULLIF(CAST(@pFullStrengthParticipation AS float), 0.0)
              END
              AS decimal(18,8)
          ) AS AdjustedEventScore,

          CAST(
              EXP(
                  (-1.0 * DATEDIFF(day, a.CampaignEndDate, @vAsOfDate))
                  / NULLIF(CAST(@pHalfLifeDays AS float), 0.0)
              ) AS decimal(18,8)
          ) AS RecencyWeight,

          CAST(
              EXP(
                  (-1.0 * DATEDIFF(day, a.CampaignEndDate, @vAsOfDate))
                  / NULLIF(CAST(@pHalfLifeDays AS float), 0.0)
              )
              *
              CASE
                  WHEN a.CampaignNetParticipationRatio >= @pFullStrengthParticipation THEN 1.0
                  WHEN a.CampaignNetParticipationRatio <= 0 THEN 0.0
                  ELSE CAST(a.CampaignNetParticipationRatio AS float) / NULLIF(CAST(@pFullStrengthParticipation AS float), 0.0)
              END
              AS decimal(18,8)
          ) AS EffectiveWeight,

          @vScoreVersion AS ScoreVersion
      INTO #CampaignAgg
      FROM CampaignAgg a
      INNER JOIN #PriceScored psStart
          ON psStart.ASXCode = a.ASXCode
         AND psStart.ObservationDate = a.CampaignStartDate
      INNER JOIN #PriceScored psEnd
          ON psEnd.ASXCode = a.ASXCode
         AND psEnd.ObservationDate = a.CampaignEndDate;

      SELECT *
      INTO #CampaignFinal
      FROM #CampaignAgg
      WHERE Fwd20dReturn IS NOT NULL;

      IF @pPersistCampaigns = 1
      BEGIN
          DELETE c
          FROM Transform.BrokerEffectiveCampaign c
          WHERE c.ScoreAsOfDate = @vAsOfDate
            AND (@vBaseASXCode IS NULL OR c.ASXCode = @vBaseASXCode);

          INSERT INTO Transform.BrokerEffectiveCampaign
          (
              ScoreAsOfDate, ASXCode, PriceASXCode, BrokerName, BrokerCode, CampaignId,
              CampaignStartDate, CampaignEndDate, CampaignTradingDays,
              CampaignBuyValue, CampaignSellValue, CampaignNetValue, CampaignTradedValue,
              CampaignNetParticipationRatio, CampaignBuyParticipationRatio, PeakDailyNetParticipationRatio,
              EntryClosePrice, SignalClosePrice,
              Fwd1dReturn, Fwd3dReturn, Fwd5dReturn, Fwd10dReturn, Fwd20dReturn,
              PctRank1d, PctRank3d, PctRank5d, PctRank10d, PctRank20d,
              RawEventScore, CampaignStrengthFactor, AdjustedEventScore, RecencyWeight, EffectiveWeight,
              ScoreVersion
          )
          SELECT
              ScoreAsOfDate, ASXCode, PriceASXCode, BrokerName, BrokerCode, CampaignId,
              CampaignStartDate, CampaignEndDate, CampaignTradingDays,
              CampaignBuyValue, CampaignSellValue, CampaignNetValue, CampaignTradedValue,
              CampaignNetParticipationRatio, CampaignBuyParticipationRatio, PeakDailyNetParticipationRatio,
              EntryClosePrice, SignalClosePrice,
              Fwd1dReturn, Fwd3dReturn, Fwd5dReturn, Fwd10dReturn, Fwd20dReturn,
              PctRank1d, PctRank3d, PctRank5d, PctRank10d, PctRank20d,
              RawEventScore, CampaignStrengthFactor, AdjustedEventScore, RecencyWeight, EffectiveWeight,
              ScoreVersion
          FROM #CampaignFinal;
      END

      SELECT
          ScoreAsOfDate,
          ASXCode,
          BrokerName,
          MAX(BrokerCode) AS BrokerCode,
          COUNT(*) AS CampaignCount,
          CAST(SUM(CAST(EffectiveWeight AS float)) AS decimal(18,8)) AS WeightedCampaignCount,
          CAST(AVG(CAST(RawEventScore AS float)) AS decimal(18,8)) AS AvgRawEventScore,
          CAST(AVG(CAST(AdjustedEventScore AS float)) AS decimal(18,8)) AS AvgAdjustedEventScore,

          CAST(
              (
                  (0.5 * CAST(@pPriorWeight AS float))
                  + SUM(CAST(EffectiveWeight AS float) * CAST(AdjustedEventScore AS float))
              )
              /
              NULLIF(
                  CAST(@pPriorWeight AS float) + SUM(CAST(EffectiveWeight AS float)),
                  0.0
              )
              AS decimal(18,8)
          ) AS BrokerEffectiveScore,

          CAST(AVG(CASE WHEN Fwd5dReturn  > 0 THEN 1.0 ELSE 0.0 END) AS decimal(18,8)) AS WinRate5d,
          CAST(AVG(CASE WHEN Fwd10dReturn > 0 THEN 1.0 ELSE 0.0 END) AS decimal(18,8)) AS WinRate10d,
          CAST(AVG(CASE WHEN Fwd20dReturn > 0 THEN 1.0 ELSE 0.0 END) AS decimal(18,8)) AS WinRate20d,

          CAST(AVG(CAST(Fwd1dReturn  AS float)) AS decimal(18,8)) AS AvgReturn1d,
          CAST(AVG(CAST(Fwd3dReturn  AS float)) AS decimal(18,8)) AS AvgReturn3d,
          CAST(AVG(CAST(Fwd5dReturn  AS float)) AS decimal(18,8)) AS AvgReturn5d,
          CAST(AVG(CAST(Fwd10dReturn AS float)) AS decimal(18,8)) AS AvgReturn10d,
          CAST(AVG(CAST(Fwd20dReturn AS float)) AS decimal(18,8)) AS AvgReturn20d,

          MIN(CampaignStartDate) AS FirstCampaignDate,
          MAX(CampaignEndDate) AS LastCampaignDate,

          MAX(ScoreVersion) AS ScoreVersion
      INTO #ScoreRaw
      FROM #CampaignFinal
      GROUP BY ScoreAsOfDate, ASXCode, BrokerName
      HAVING COUNT(*) >= @pMinCampaignCount;

      SELECT
          s.ScoreAsOfDate,
          s.ASXCode,
          s.BrokerName,
          s.BrokerCode,
          s.CampaignCount,
          s.WeightedCampaignCount,
          s.AvgRawEventScore,
          s.AvgAdjustedEventScore,
          s.BrokerEffectiveScore,
          s.WinRate5d,
          s.WinRate10d,
          s.WinRate20d,
          s.AvgReturn1d,
          s.AvgReturn3d,
          s.AvgReturn5d,
          s.AvgReturn10d,
          s.AvgReturn20d,
          s.FirstCampaignDate,
          s.LastCampaignDate,

          DENSE_RANK() OVER (
              PARTITION BY s.ASXCode
              ORDER BY s.BrokerEffectiveScore DESC, s.WeightedCampaignCount DESC, s.CampaignCount DESC, s.BrokerName ASC
          ) AS TopRank,

          DENSE_RANK() OVER (
              PARTITION BY s.ASXCode
              ORDER BY s.BrokerEffectiveScore ASC, s.WeightedCampaignCount DESC, s.CampaignCount DESC, s.BrokerName ASC
          ) AS BottomRank,

          s.ScoreVersion
      INTO #ScoreFinal
      FROM #ScoreRaw s;

      DELETE s
      FROM Transform.BrokerEffectiveScoreV2 s
      WHERE s.ScoreAsOfDate = @vAsOfDate
        AND (@vBaseASXCode IS NULL OR s.ASXCode = @vBaseASXCode);

      INSERT INTO Transform.BrokerEffectiveScoreV2
      (
          ScoreAsOfDate, ASXCode, BrokerName, BrokerCode,
          CampaignCount, WeightedCampaignCount,
          AvgRawEventScore, AvgAdjustedEventScore, BrokerEffectiveScore,
          WinRate5d, WinRate10d, WinRate20d,
          AvgReturn1d, AvgReturn3d, AvgReturn5d, AvgReturn10d, AvgReturn20d,
          FirstCampaignDate, LastCampaignDate,
          TopRank, BottomRank, ScoreVersion,
          CreatedDate, ModifiedDate
      )
      SELECT
          ScoreAsOfDate, ASXCode, BrokerName, BrokerCode,
          CampaignCount, WeightedCampaignCount,
          AvgRawEventScore, AvgAdjustedEventScore, BrokerEffectiveScore,
          WinRate5d, WinRate10d, WinRate20d,
          AvgReturn1d, AvgReturn3d, AvgReturn5d, AvgReturn10d, AvgReturn20d,
          FirstCampaignDate, LastCampaignDate,
          TopRank, BottomRank, ScoreVersion,
          SYSUTCDATETIME(), SYSUTCDATETIME()
      FROM #ScoreFinal;
  END
