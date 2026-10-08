/* Supports current-report anti-joins used by report lists and overview. */
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[TradingSignal].[ReportSnapshot]')
      AND name = N'IX_TradingSignal_ReportSnapshot_SupersedesReportID'
)
BEGIN
    CREATE INDEX [IX_TradingSignal_ReportSnapshot_SupersedesReportID]
        ON [TradingSignal].[ReportSnapshot] ([SupersedesReportID])
        INCLUDE ([ReportSnapshotID]);
END;
GO
