/*
Purpose: collapse repeated EVALUATE report snapshots created by recurring GEX
schedules. The logical signal is already deduplicated by SignalID; only the
immutable report snapshots were repeated for each two-minute StrategyRun.

Safety:
- No report rows are deleted.
- The latest snapshot in each duplicate group remains current.
- Older snapshots are retained and linked through SupersedesReportID.
- Groups that already contain a correction/revision are excluded by default.
  Review those separately because their existing revision chain is meaningful.

Run the preview first. Set @Apply = 1 only after reviewing the preview.
*/

USE [StockDB_US];
SET XACT_ABORT ON;

DECLARE @Apply bit = 0;
DECLARE @FromReportDate date = '2026-08-24';
DECLARE @StrategyCode nvarchar(200) = NULL; -- e.g. 'GEX_ZS_CONTROLLED_BULL_REBOUND'
DECLARE @DeploymentKey nvarchar(200) = NULL; -- e.g. 'gex-zs-production-1-0-0-production'
DECLARE @ReportKind nvarchar(100) = 'GEX_STRATEGY_EVALUATION';

IF OBJECT_ID('tempdb..#DuplicateReportChain') IS NOT NULL
    DROP TABLE #DuplicateReportChain;

;WITH CandidateRows AS
(
    SELECT
        r.ReportSnapshotID,
        r.PublicReportID,
        r.DeploymentKey,
        r.StrategyCode,
        r.StrategyVersionCode,
        r.ReportDate,
        r.SignalID,
        r.ReportKind,
        r.GeneratedUtc,
        LAG(r.ReportSnapshotID) OVER
        (
            PARTITION BY r.DeploymentKey, r.StrategyCode, r.StrategyVersionCode,
                         r.ReportDate, r.SignalID, r.ReportKind
            ORDER BY r.GeneratedUtc, r.ReportSnapshotID
        ) AS PreviousReportSnapshotID,
        COUNT(*) OVER
        (
            PARTITION BY r.DeploymentKey, r.StrategyCode, r.StrategyVersionCode,
                         r.ReportDate, r.SignalID, r.ReportKind
        ) AS GroupCount,
        MAX(CASE WHEN r.SupersedesReportID IS NOT NULL THEN 1 ELSE 0 END) OVER
        (
            PARTITION BY r.DeploymentKey, r.StrategyCode, r.StrategyVersionCode,
                         r.ReportDate, r.SignalID, r.ReportKind
        ) AS GroupHasExistingRevision
    FROM [TradingSignal].[ReportSnapshot] AS r
    WHERE r.SignalID IS NOT NULL
      AND r.ReportKind = @ReportKind
      AND r.ReportDate >= @FromReportDate
      AND r.StrategyCode LIKE 'GEX[_]%'
      AND (@StrategyCode IS NULL OR r.StrategyCode = @StrategyCode)
      AND (@DeploymentKey IS NULL OR r.DeploymentKey = @DeploymentKey)
)
SELECT *
INTO #DuplicateReportChain
FROM CandidateRows
WHERE GroupCount > 1
  AND GroupHasExistingRevision = 0
  AND PreviousReportSnapshotID IS NOT NULL;

-- Preview exactly what would be linked.
SELECT
    DeploymentKey,
    StrategyCode,
    StrategyVersionCode,
    ReportDate,
    SignalID,
    ReportKind,
    GroupCount,
    ReportSnapshotID AS OlderReportSnapshotID,
    PublicReportID AS OlderPublicReportID,
    GeneratedUtc AS OlderGeneratedUtc,
    PreviousReportSnapshotID AS SupersededReportSnapshotID
FROM #DuplicateReportChain
ORDER BY StrategyCode, ReportDate, SignalID, GeneratedUtc, ReportSnapshotID;

SELECT
    StrategyCode,
    ReportDate,
    COUNT(*) AS SnapshotsToLink,
    COUNT(DISTINCT SignalID) AS LogicalSignals,
    MIN(GeneratedUtc) AS FirstGeneratedUtc,
    MAX(GeneratedUtc) AS LastGeneratedUtc
FROM #DuplicateReportChain
GROUP BY StrategyCode, ReportDate
ORDER BY StrategyCode, ReportDate;

IF @Apply = 1
BEGIN
    BEGIN TRANSACTION;

    UPDATE r
       SET r.SupersedesReportID = c.PreviousReportSnapshotID
    OUTPUT
        inserted.ReportSnapshotID,
        inserted.PublicReportID,
        inserted.SupersedesReportID
    FROM [TradingSignal].[ReportSnapshot] AS r
    JOIN #DuplicateReportChain AS c
      ON c.ReportSnapshotID = r.ReportSnapshotID;

    COMMIT TRANSACTION;

    -- After applying, each affected logical group should have one current row.
    SELECT
        r.DeploymentKey,
        r.StrategyCode,
        r.StrategyVersionCode,
        r.ReportDate,
        r.SignalID,
        r.ReportKind,
        COUNT(*) AS SnapshotCount,
        SUM(CASE WHEN newer.ReportSnapshotID IS NULL THEN 1 ELSE 0 END) AS CurrentSnapshotCount
    FROM [TradingSignal].[ReportSnapshot] AS r
    LEFT JOIN [TradingSignal].[ReportSnapshot] AS newer
      ON newer.SupersedesReportID = r.ReportSnapshotID
    JOIN #DuplicateReportChain AS c
      ON c.ReportSnapshotID = r.ReportSnapshotID
    GROUP BY
        r.DeploymentKey,
        r.StrategyCode,
        r.StrategyVersionCode,
        r.ReportDate,
        r.SignalID,
        r.ReportKind;
END
ELSE
BEGIN
    PRINT 'Preview only. Set @Apply = 1 to apply the SupersedesReportID links.';
END;
