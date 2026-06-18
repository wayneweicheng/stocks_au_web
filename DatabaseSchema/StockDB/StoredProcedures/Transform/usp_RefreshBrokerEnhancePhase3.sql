-- Stored procedure: [Transform].[usp_RefreshBrokerEnhancePhase3]


CREATE   PROCEDURE Transform.usp_RefreshBrokerEnhancePhase3
    @pAsOfDate                    date            = NULL,
    @pASXCode                     varchar(10)     = NULL,
    @pLookbackCalendarDays        int             = 30,
    @pMinTotalValue               decimal(20,2)   = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @vAsOfDate date =
        COALESCE(@pAsOfDate, (SELECT MAX(SnapshotDate) FROM Transform.BrokerTxCoverage));

    DECLARE @vBaseASXCode varchar(10) =
        CASE
            WHEN @pASXCode IS NULL THEN NULL
            ELSE UPPER(LTRIM(RTRIM(REPLACE(@pASXCode, '.AX', ''))))
        END;

    DECLARE @vLookbackCalendarDays int = CASE WHEN ISNULL(@pLookbackCalendarDays, 0) > 0 THEN @pLookbackCalendarDays ELSE 30 END;
    DECLARE @vWindowStartDate date = DATEADD(DAY, 1 - @vLookbackCalendarDays, @vAsOfDate);
    DECLARE @vScoreVersion varchar(40) = 'broker_enhance_phase3_v3';

    DROP TABLE IF EXISTS #CoverageScope;
    DROP TABLE IF EXISTS #TxWindow;
    DROP TABLE IF EXISTS #MicroBase;

    SELECT
        c.SnapshotDate,
        c.ASXCode,
        c.PriceASXCode,
        c.ObservationDate,
        c.CaptureSource,
        c.BullishSetupScore,
        c.BearishSetupScore,
        c.TransactionCount,
        c.DistinctBuyerCount,
        c.DistinctSellerCount,
        c.TotalValue,
        c.TotalVolume,
        c.TopBuyerBrokerName,
        c.TopBuyerValue,
        c.TopSellerBrokerName,
        c.TopSellerValue
    INTO #CoverageScope
    FROM Transform.BrokerTxCoverage c
    WHERE c.SnapshotDate = @vAsOfDate
      AND c.ObservationDate >= @vWindowStartDate
      AND c.ObservationDate <= @vAsOfDate
      AND c.TotalValue >= @pMinTotalValue
      AND (@vBaseASXCode IS NULL OR c.ASXCode = @vBaseASXCode);

    SELECT
        t.ASXCode,
        t.ObservationDate,
        t.BuyerBrokerName,
        t.SellerBrokerName,
        t.Price,
        t.Value
    INTO #TxWindow
    FROM Transform.BrokerTxArchive t
    INNER JOIN #CoverageScope c
        ON c.ASXCode = t.ASXCode
       AND c.ObservationDate = t.ObservationDate;

    ;WITH BrokerSide AS
    (
        SELECT
            t.ASXCode,
            t.ObservationDate,
            t.BuyerBrokerName AS BrokerName,
            CAST(SUM(t.Value) AS decimal(20,2)) AS BuyValue,
            CAST(0 AS decimal(20,2)) AS SellValue
        FROM #TxWindow t
        GROUP BY t.ASXCode, t.ObservationDate, t.BuyerBrokerName

        UNION ALL

        SELECT
            t.ASXCode,
            t.ObservationDate,
            t.SellerBrokerName AS BrokerName,
            CAST(0 AS decimal(20,2)) AS BuyValue,
            CAST(SUM(t.Value) AS decimal(20,2)) AS SellValue
        FROM #TxWindow t
        GROUP BY t.ASXCode, t.ObservationDate, t.SellerBrokerName
    ),
    BrokerNet AS
    (
        SELECT
            b.ASXCode,
            b.ObservationDate,
            b.BrokerName,
            CAST(SUM(b.BuyValue) AS decimal(20,2)) AS BuyValue,
            CAST(SUM(b.SellValue) AS decimal(20,2)) AS SellValue,
            CAST(SUM(b.BuyValue - b.SellValue) AS decimal(20,2)) AS NetValue
        FROM BrokerSide b
        GROUP BY b.ASXCode, b.ObservationDate, b.BrokerName
    ),
    FlowAgg AS
    (
        SELECT
            n.ASXCode,
            n.ObservationDate,
            CAST(SUM(n.BuyValue) AS decimal(20,2)) AS TotalBuyValue,
            CAST(SUM(n.SellValue) AS decimal(20,2)) AS TotalSellValue,
            CAST(SUM(n.NetValue) AS decimal(20,2)) AS NetFlowValue,
            CAST(SUM(CASE WHEN n.NetValue > 0 THEN n.NetValue ELSE 0 END) AS decimal(20,2)) AS PositiveNetFlowValue,
            CAST(SUM(CASE WHEN n.NetValue < 0 THEN ABS(n.NetValue) ELSE 0 END) AS decimal(20,2)) AS NegativeNetFlowValue,
            COUNT(CASE WHEN n.NetValue > 0 THEN 1 END) AS PositiveBrokerCount,
            COUNT(CASE WHEN n.NetValue < 0 THEN 1 END) AS NegativeBrokerCount,
            MAX(CASE WHEN n.NetValue > 0 THEN n.NetValue END) AS TopPositiveNetValue,
            MAX(CASE WHEN n.NetValue < 0 THEN ABS(n.NetValue) END) AS TopNegativeNetValue
        FROM BrokerNet n
        GROUP BY n.ASXCode, n.ObservationDate
    ),
    BrokerLeads AS
    (
        SELECT
            n.ASXCode,
            n.ObservationDate,
            MAX(CASE WHEN rnBuy = 1 THEN n.BrokerName END) AS LeadAggressorBroker,
            MAX(CASE WHEN rnSell = 1 THEN n.BrokerName END) AS LeadDistributorBroker
        FROM
        (
            SELECT
                n.*,
                ROW_NUMBER() OVER (PARTITION BY n.ASXCode, n.ObservationDate ORDER BY n.NetValue DESC, n.BrokerName) AS rnBuy,
                ROW_NUMBER() OVER (PARTITION BY n.ASXCode, n.ObservationDate ORDER BY n.NetValue ASC, n.BrokerName) AS rnSell
            FROM BrokerNet n
        ) n
        GROUP BY n.ASXCode, n.ObservationDate
    ),
    BuyerBrokerAgg AS
    (
        SELECT
            t.ASXCode,
            t.ObservationDate,
            t.BuyerBrokerName AS BrokerName,
            CAST(SUM(t.Value) AS decimal(20,2)) AS BuyerValue
        FROM #TxWindow t
        GROUP BY t.ASXCode, t.ObservationDate, t.BuyerBrokerName
    ),
    BuyerBrokerNorm AS
    (
        SELECT
            b.ASXCode,
            b.ObservationDate,
            b.BrokerName,
            b.BuyerValue,
            CAST(SUM(b.BuyerValue) OVER (PARTITION BY b.ASXCode, b.ObservationDate) AS decimal(20,2)) AS TotalBuyerValue
        FROM BuyerBrokerAgg b
    ),
    BuyerConcentration AS
    (
        SELECT
            b.ASXCode,
            b.ObservationDate,
            CAST(
                SUM(
                    POWER(
                        CASE
                            WHEN b.TotalBuyerValue > 0 THEN b.BuyerValue / NULLIF(b.TotalBuyerValue, 0)
                            ELSE 0
                        END,
                        2
                    )
                )
                AS decimal(18,8)
            ) AS BuyerHHI
        FROM BuyerBrokerNorm b
        GROUP BY b.ASXCode, b.ObservationDate
    ),
    SellerBrokerAgg AS
    (
        SELECT
            t.ASXCode,
            t.ObservationDate,
            t.SellerBrokerName AS BrokerName,
            CAST(SUM(t.Value) AS decimal(20,2)) AS SellerValue
        FROM #TxWindow t
        GROUP BY t.ASXCode, t.ObservationDate, t.SellerBrokerName
    ),
    SellerBrokerNorm AS
    (
        SELECT
            s.ASXCode,
            s.ObservationDate,
            s.BrokerName,
            s.SellerValue,
            CAST(SUM(s.SellerValue) OVER (PARTITION BY s.ASXCode, s.ObservationDate) AS decimal(20,2)) AS TotalSellerValue
        FROM SellerBrokerAgg s
    ),
    SellerConcentration AS
    (
        SELECT
            s.ASXCode,
            s.ObservationDate,
            CAST(
                SUM(
                    POWER(
                        CASE
                            WHEN s.TotalSellerValue > 0 THEN s.SellerValue / NULLIF(s.TotalSellerValue, 0)
                            ELSE 0
                        END,
                        2
                    )
                )
                AS decimal(18,8)
            ) AS SellerHHI
        FROM SellerBrokerNorm s
        GROUP BY s.ASXCode, s.ObservationDate
    ),
    PriceRef AS
    (
        SELECT
            c.ASXCode,
            c.ObservationDate,
            px.DayOpen,
            px.DayClose,
            px.DayVWAP,
            CASE
                WHEN px.DayOpen IS NULL OR px.DayOpen <= 0 OR px.DayClose IS NULL THEN 1
                WHEN ABS(px.DayClose - px.DayOpen) / px.DayOpen <= 0.003 THEN 1
                ELSE 0
            END AS IsDojiDay,
            CASE
                WHEN px.DayOpen IS NULL OR px.DayClose IS NULL THEN 0
                WHEN ABS(px.DayClose - px.DayOpen) / NULLIF(px.DayOpen, 0) <= 0.003 THEN 0
                WHEN px.DayClose > px.DayOpen THEN 1
                ELSE 0
            END AS IsGreenDay,
            CASE
                WHEN px.DayOpen IS NULL OR px.DayClose IS NULL THEN 0
                WHEN ABS(px.DayClose - px.DayOpen) / NULLIF(px.DayOpen, 0) <= 0.003 THEN 0
                WHEN px.DayClose < px.DayOpen THEN 1
                ELSE 0
            END AS IsRedDay
        FROM #CoverageScope c
        OUTER APPLY
        (
            SELECT TOP (1)
                CAST(p.[Open] AS decimal(20,8)) AS DayOpen,
                CAST(p.[Close] AS decimal(20,8)) AS DayClose,
                CAST(CASE WHEN p.Volume > 0 THEN ISNULL(p.[Value], 0) / CAST(p.Volume AS decimal(20,8)) END AS decimal(20,8)) AS DayVWAP
            FROM StockData.PriceHistory p
            WHERE p.ObservationDate = c.ObservationDate
              AND (
                    p.ASXCode = c.PriceASXCode
                    OR p.ASXCode = c.ASXCode
                    OR p.ASXCode = c.ASXCode + '.AX'
                  )
            ORDER BY
                CASE
                    WHEN p.ASXCode = c.PriceASXCode THEN 0
                    WHEN p.ASXCode = c.ASXCode THEN 1
                    WHEN p.ASXCode = c.ASXCode + '.AX' THEN 2
                    ELSE 3
                END
        ) px
    ),
    TxClassified AS
    (
        SELECT
            t.ASXCode,
            t.ObservationDate,
            t.Price,
            t.Value,
            CAST(ISNULL(buyerLkp.BrokerScore, 0) AS decimal(18,8)) AS BuyerBrokerScore,
            CAST(ISNULL(sellerLkp.BrokerScore, 0) AS decimal(18,8)) AS SellerBrokerScore,
            CAST(
                CASE
                    WHEN 0.75
                         + (
                               ABS(ISNULL(CAST(buyerLkp.BrokerScore AS float), 0.0))
                             + ABS(ISNULL(CAST(sellerLkp.BrokerScore AS float), 0.0))
                           ) / 4.0 > 1.60 THEN 1.60
                    WHEN 0.75
                         + (
                               ABS(ISNULL(CAST(buyerLkp.BrokerScore AS float), 0.0))
                             + ABS(ISNULL(CAST(sellerLkp.BrokerScore AS float), 0.0))
                           ) / 4.0 < 0.75 THEN 0.75
                    ELSE 0.75
                         + (
                               ABS(ISNULL(CAST(buyerLkp.BrokerScore AS float), 0.0))
                             + ABS(ISNULL(CAST(sellerLkp.BrokerScore AS float), 0.0))
                           ) / 4.0
                END AS decimal(18,8)
            ) AS PairSignificanceWeight,
            CASE
                WHEN LOWER(t.BuyerBrokerName) LIKE '%commsec%'
                  OR LOWER(t.BuyerBrokerName) LIKE '%commonwealth securities%'
                  OR LOWER(t.BuyerBrokerName) LIKE '%wealthhub%'
                  OR LOWER(t.BuyerBrokerName) LIKE '%webull%'
                  OR LOWER(t.BuyerBrokerName) LIKE '%cmc markets%'
                  OR LOWER(t.BuyerBrokerName) LIKE '%selfwealth%'
                  OR LOWER(t.BuyerBrokerName) LIKE '%nabtrade%'
                  OR LOWER(t.BuyerBrokerName) LIKE '%bell direct%'
                  OR LOWER(t.BuyerBrokerName) LIKE '%stake%'
                  OR LOWER(t.BuyerBrokerName) LIKE '%pearler%' THEN 'retail'
                WHEN buyerLkp.BrokerCode IS NULL THEN 'unknown'
                ELSE 'institutional'
            END AS BuyerCategory,
            CASE
                WHEN LOWER(t.SellerBrokerName) LIKE '%commsec%'
                  OR LOWER(t.SellerBrokerName) LIKE '%commonwealth securities%'
                  OR LOWER(t.SellerBrokerName) LIKE '%wealthhub%'
                  OR LOWER(t.SellerBrokerName) LIKE '%webull%'
                  OR LOWER(t.SellerBrokerName) LIKE '%cmc markets%'
                  OR LOWER(t.SellerBrokerName) LIKE '%selfwealth%'
                  OR LOWER(t.SellerBrokerName) LIKE '%nabtrade%'
                  OR LOWER(t.SellerBrokerName) LIKE '%bell direct%'
                  OR LOWER(t.SellerBrokerName) LIKE '%stake%'
                  OR LOWER(t.SellerBrokerName) LIKE '%pearler%' THEN 'retail'
                WHEN sellerLkp.BrokerCode IS NULL THEN 'unknown'
                ELSE 'institutional'
            END AS SellerCategory,
            pr.DayVWAP
        FROM #TxWindow t
        LEFT JOIN PriceRef pr
            ON pr.ASXCode = t.ASXCode
           AND pr.ObservationDate = t.ObservationDate
        OUTER APPLY
        (
            SELECT TOP (1)
                l.BrokerCode,
                l.BrokerLevel,
                l.BrokerScore
            FROM LookupRef.BrokerName l
            WHERE l.BrokerName = t.BuyerBrokerName
               OR l.APIBrokerName = t.BuyerBrokerName
            ORDER BY
                CASE WHEN l.BrokerName = t.BuyerBrokerName THEN 0 ELSE 1 END,
                l.BrokerCode
        ) buyerLkp
        OUTER APPLY
        (
            SELECT TOP (1)
                l.BrokerCode,
                l.BrokerLevel,
                l.BrokerScore
            FROM LookupRef.BrokerName l
            WHERE l.BrokerName = t.SellerBrokerName
               OR l.APIBrokerName = t.SellerBrokerName
            ORDER BY
                CASE WHEN l.BrokerName = t.SellerBrokerName THEN 0 ELSE 1 END,
                l.BrokerCode
        ) sellerLkp
    ),
    RetailFlowAgg AS
    (
        SELECT
            t.ASXCode,
            t.ObservationDate,
            CAST(SUM(CASE WHEN t.BuyerCategory = 'institutional' AND t.SellerCategory = 'retail' THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS RetailToInstValue,
            CAST(SUM(CASE WHEN t.BuyerCategory = 'retail' AND t.SellerCategory = 'institutional' THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS InstToRetailValue,
            CAST(SUM(CASE WHEN t.BuyerCategory = 'institutional' AND t.SellerCategory = 'retail' AND t.DayVWAP IS NOT NULL AND t.Price <= t.DayVWAP * 0.997 THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS RetailToInstLowPxValue,
            CAST(SUM(CASE WHEN t.BuyerCategory = 'institutional' AND t.SellerCategory = 'retail' AND t.DayVWAP IS NOT NULL AND t.Price >= t.DayVWAP * 1.003 THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS RetailToInstHighPxValue,
            CAST(SUM(CASE WHEN t.BuyerCategory = 'retail' AND t.SellerCategory = 'institutional' AND t.DayVWAP IS NOT NULL AND t.Price >= t.DayVWAP * 1.003 THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS InstToRetailHighPxValue,
            CAST(SUM(CASE WHEN t.BuyerCategory = 'retail' AND t.SellerCategory = 'institutional' AND t.DayVWAP IS NOT NULL AND t.Price <= t.DayVWAP * 0.997 THEN t.Value * t.PairSignificanceWeight ELSE 0 END) AS decimal(20,2)) AS InstToRetailLowPxValue,
            CAST(SUM(CASE WHEN t.BuyerCategory = 'institutional' AND t.SellerCategory = 'institutional' THEN t.Value ELSE 0 END) AS decimal(20,2)) AS InstInstValue,
            CAST(SUM(CASE WHEN t.BuyerCategory = 'retail' AND t.SellerCategory = 'retail' THEN t.Value ELSE 0 END) AS decimal(20,2)) AS RetailRetailValue
        FROM TxClassified t
        GROUP BY t.ASXCode, t.ObservationDate
    )
    SELECT
        c.SnapshotDate,
        c.ASXCode,
        c.PriceASXCode,
        c.ObservationDate,
        c.CaptureSource,
        c.BullishSetupScore,
        c.BearishSetupScore,
        c.TransactionCount,
        c.DistinctBuyerCount,
        c.DistinctSellerCount,
        c.TotalValue,
        c.TotalVolume,
        ISNULL(rf.RetailToInstValue, 0) - ISNULL(rf.InstToRetailValue, 0) AS NetFlowValue,
        CAST(
            CASE
                WHEN c.TotalValue > 0 THEN (ISNULL(rf.RetailToInstValue, 0) - ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue
                ELSE 0
            END AS decimal(18,8)
        ) AS NetFlowPctTotal,
        CAST(CASE WHEN c.TotalValue > 0 THEN ISNULL(c.TopBuyerValue, 0) / c.TotalValue ELSE 0 END AS decimal(18,8)) AS TopBuyerValueShare,
        CAST(CASE WHEN c.TotalValue > 0 THEN ISNULL(c.TopSellerValue, 0) / c.TotalValue ELSE 0 END AS decimal(18,8)) AS TopSellerValueShare,
        CAST(
            CASE
                WHEN c.TotalValue <= 0 THEN 0
                ELSE PERCENT_RANK() OVER
                (
                    PARTITION BY c.SnapshotDate
                    ORDER BY CASE
                                 WHEN c.TotalValue <= 0 THEN 0
                                 ELSE
                                     0.70 * (ISNULL(c.TopBuyerValue, 0) / c.TotalValue)
                                   + 0.30 * ISNULL(bc.BuyerHHI, 0)
                             END
                )
            END AS decimal(18,8)
        ) AS BuyerAggressionScore,
        CAST(
            CASE
                WHEN c.TotalValue <= 0 THEN 0
                ELSE PERCENT_RANK() OVER
                (
                    PARTITION BY c.SnapshotDate
                    ORDER BY CASE
                                 WHEN c.TotalValue <= 0 THEN 0
                                 ELSE
                                     0.70 * (ISNULL(c.TopSellerValue, 0) / c.TotalValue)
                                   + 0.30 * ISNULL(sc.SellerHHI, 0)
                             END
                )
            END AS decimal(18,8)
        ) AS SellerAggressionScore,
        CAST(
              0.45 * CASE
                         WHEN c.TotalValue <= 0 THEN 0
                         ELSE
                             (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                             * CASE
                                   WHEN ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                   ELSE (ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue) / 0.20
                               END
                     END
            + 0.35 * CASE
                         WHEN c.TotalValue <= 0 THEN 0
                         ELSE
                             (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                             * CASE
                                   WHEN ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                   ELSE (ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue) / 0.20
                               END
                     END
            + 0.20 * CASE
                         WHEN c.TotalValue <= 0 THEN 0
                         WHEN ISNULL(rf.RetailToInstValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                         ELSE (ISNULL(rf.RetailToInstValue, 0) / c.TotalValue) / 0.35
                     END
            AS decimal(18,8)
        ) AS AbsorptionScore,
        CAST(
            CASE
                WHEN c.TotalValue <= 0 THEN 0
                WHEN (ISNULL(rf.RetailToInstValue, 0) + ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue >= 0.60 THEN 1.0
                ELSE ((ISNULL(rf.RetailToInstValue, 0) + ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue) / 0.60
            END AS decimal(18,8)
        ) AS TransferScore,
        CAST(
            (
                CASE
                    WHEN c.TransactionCount >= 4000 THEN 1.0
                    ELSE CAST(c.TransactionCount AS float) / 4000.0
                END
            )
            * (
                CASE
                    WHEN c.DistinctBuyerCount <= 0 OR c.DistinctSellerCount <= 0 THEN 0
                    WHEN c.DistinctBuyerCount <= c.DistinctSellerCount THEN CAST(c.DistinctBuyerCount AS float) / NULLIF(c.DistinctSellerCount, 0)
                    ELSE CAST(c.DistinctSellerCount AS float) / NULLIF(c.DistinctBuyerCount, 0)
                END
            ) AS decimal(18,8)
        ) AS ChurnScore,
        CAST(
              0.65 * (
                         0.45 * CASE
                                    WHEN c.TotalValue <= 0 THEN 0
                                    ELSE
                                        (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                        * CASE
                                              WHEN ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                              ELSE (ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue) / 0.20
                                          END
                                END
                       + 0.35 * CASE
                                    WHEN c.TotalValue <= 0 THEN 0
                                    ELSE
                                        (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                        * CASE
                                              WHEN ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                              ELSE (ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue) / 0.20
                                          END
                                END
                       + 0.20 * CASE
                                    WHEN c.TotalValue <= 0 THEN 0
                                    WHEN ISNULL(rf.RetailToInstValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                    ELSE (ISNULL(rf.RetailToInstValue, 0) / c.TotalValue) / 0.35
                                END
                    )
            + 0.35 * (
                         1.0 - (
                             0.45 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.35 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.20 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        WHEN ISNULL(rf.InstToRetailValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                        ELSE (ISNULL(rf.InstToRetailValue, 0) / c.TotalValue) / 0.35
                                    END
                         )
                    )
            AS decimal(18,8)
        ) AS SuppressionReacquisitionScore,
        CAST(
              0.50 * (
                         0.45 * CASE
                                    WHEN c.TotalValue <= 0 THEN 0
                                    ELSE
                                        (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                        * CASE
                                              WHEN ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                              ELSE (ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue) / 0.20
                                          END
                                END
                       + 0.35 * CASE
                                    WHEN c.TotalValue <= 0 THEN 0
                                    ELSE
                                        (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                        * CASE
                                              WHEN ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                              ELSE (ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue) / 0.20
                                          END
                                END
                       + 0.20 * CASE
                                    WHEN c.TotalValue <= 0 THEN 0
                                    WHEN ISNULL(rf.InstToRetailValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                    ELSE (ISNULL(rf.InstToRetailValue, 0) / c.TotalValue) / 0.35
                                END
                    )
            + 0.30 * (
                         1.0 - (
                             0.45 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.35 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.20 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        WHEN ISNULL(rf.RetailToInstValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                        ELSE (ISNULL(rf.RetailToInstValue, 0) / c.TotalValue) / 0.35
                                    END
                         )
                    )
            + 0.20 * CASE
                         WHEN c.TotalValue <= 0 THEN 0
                         WHEN (ISNULL(rf.InstToRetailValue, 0) - ISNULL(rf.RetailToInstValue, 0)) / c.TotalValue <= 0 THEN 0
                         WHEN (ISNULL(rf.InstToRetailValue, 0) - ISNULL(rf.RetailToInstValue, 0)) / c.TotalValue >= 0.15 THEN 1.0
                         ELSE ((ISNULL(rf.InstToRetailValue, 0) - ISNULL(rf.RetailToInstValue, 0)) / c.TotalValue) / 0.15
                     END
            AS decimal(18,8)
        ) AS LiveDistributionScore,
        CAST(
              0.50 * (
                         0.45 * CASE
                                    WHEN c.TotalValue <= 0 THEN 0
                                    ELSE
                                        (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                        * CASE
                                              WHEN ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                              ELSE (ISNULL(rf.RetailToInstLowPxValue, 0) / c.TotalValue) / 0.20
                                          END
                                END
                       + 0.35 * CASE
                                    WHEN c.TotalValue <= 0 THEN 0
                                    ELSE
                                        (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                        * CASE
                                              WHEN ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                              ELSE (ISNULL(rf.RetailToInstHighPxValue, 0) / c.TotalValue) / 0.20
                                          END
                                END
                       + 0.20 * CASE
                                    WHEN c.TotalValue <= 0 THEN 0
                                    WHEN ISNULL(rf.RetailToInstValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                    ELSE (ISNULL(rf.RetailToInstValue, 0) / c.TotalValue) / 0.35
                                END
                    )
            + 0.30 * (
                         1.0 - (
                             0.45 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsGreenDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.InstToRetailHighPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.35 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        ELSE
                                            (CASE WHEN pr.IsRedDay = 1 OR pr.IsDojiDay = 1 THEN 1.0 ELSE 0.4 END)
                                            * CASE
                                                  WHEN ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue >= 0.20 THEN 1.0
                                                  ELSE (ISNULL(rf.InstToRetailLowPxValue, 0) / c.TotalValue) / 0.20
                                              END
                                    END
                           + 0.20 * CASE
                                        WHEN c.TotalValue <= 0 THEN 0
                                        WHEN ISNULL(rf.InstToRetailValue, 0) / c.TotalValue >= 0.35 THEN 1.0
                                        ELSE (ISNULL(rf.InstToRetailValue, 0) / c.TotalValue) / 0.35
                                    END
                         )
                    )
            + 0.20 * CASE
                         WHEN c.TotalValue <= 0 THEN 0
                         WHEN (ISNULL(rf.RetailToInstValue, 0) - ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue <= 0 THEN 0
                         WHEN (ISNULL(rf.RetailToInstValue, 0) - ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue >= 0.15 THEN 1.0
                         ELSE ((ISNULL(rf.RetailToInstValue, 0) - ISNULL(rf.InstToRetailValue, 0)) / c.TotalValue) / 0.15
                     END
            AS decimal(18,8)
        ) AS LiveExecutionQualityScore,
        l.LeadAggressorBroker,
        l.LeadDistributorBroker
    INTO #MicroBase
    FROM #CoverageScope c
    LEFT JOIN RetailFlowAgg rf
        ON rf.ASXCode = c.ASXCode
       AND rf.ObservationDate = c.ObservationDate
    LEFT JOIN PriceRef pr
        ON pr.ASXCode = c.ASXCode
       AND pr.ObservationDate = c.ObservationDate
    LEFT JOIN BuyerConcentration bc
        ON bc.ASXCode = c.ASXCode
       AND bc.ObservationDate = c.ObservationDate
    LEFT JOIN SellerConcentration sc
        ON sc.ASXCode = c.ASXCode
       AND sc.ObservationDate = c.ObservationDate
    LEFT JOIN BrokerLeads l
        ON l.ASXCode = c.ASXCode
       AND l.ObservationDate = c.ObservationDate;

    DELETE m
    FROM Transform.BrokerTxMicrostructureDay m
    WHERE m.SnapshotDate = @vAsOfDate
      AND m.ObservationDate >= @vWindowStartDate
      AND m.ObservationDate <= @vAsOfDate
      AND (@vBaseASXCode IS NULL OR m.ASXCode = @vBaseASXCode);

    INSERT INTO Transform.BrokerTxMicrostructureDay
    (
        SnapshotDate,
        ASXCode,
        PriceASXCode,
        ObservationDate,
        CaptureSource,
        BullishSetupScore,
        BearishSetupScore,
        TransactionCount,
        DistinctBuyerCount,
        DistinctSellerCount,
        TotalValue,
        TotalVolume,
        NetFlowValue,
        NetFlowPctTotal,
        TopBuyerValueShare,
        TopSellerValueShare,
        BuyerAggressionScore,
        SellerAggressionScore,
        AbsorptionScore,
        TransferScore,
        ChurnScore,
        SuppressionReacquisitionScore,
        LiveDistributionScore,
        LiveExecutionQualityScore,
        LeadAggressorBroker,
        LeadDistributorBroker,
        ScoreVersion,
        CreatedDate
    )
    SELECT
        SnapshotDate,
        ASXCode,
        PriceASXCode,
        ObservationDate,
        CaptureSource,
        BullishSetupScore,
        BearishSetupScore,
        TransactionCount,
        DistinctBuyerCount,
        DistinctSellerCount,
        TotalValue,
        TotalVolume,
        NetFlowValue,
        NetFlowPctTotal,
        TopBuyerValueShare,
        TopSellerValueShare,
        BuyerAggressionScore,
        SellerAggressionScore,
        AbsorptionScore,
        TransferScore,
        ChurnScore,
        SuppressionReacquisitionScore,
        LiveDistributionScore,
        LiveExecutionQualityScore,
        LeadAggressorBroker,
        LeadDistributorBroker,
        @vScoreVersion,
        SYSUTCDATETIME()
    FROM #MicroBase;
END
