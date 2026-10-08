IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveScan]', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_VSOScan_AsAt' AND object_id = OBJECT_ID(N'[Analysis].[VolatilitySelectiveScan]'))
        CREATE INDEX [IX_VSOScan_AsAt] ON [Analysis].[VolatilitySelectiveScan] ([AsAt], [Status]);
END;
GO

IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveSnapshot]', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_VSOSnapshot_RunSymbol' AND object_id = OBJECT_ID(N'[Analysis].[VolatilitySelectiveSnapshot]'))
        CREATE INDEX [IX_VSOSnapshot_RunSymbol] ON [Analysis].[VolatilitySelectiveSnapshot] ([RunId], [Symbol]);
END;
GO

IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveCandidate]', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_VSOCandidate_RunRank' AND object_id = OBJECT_ID(N'[Analysis].[VolatilitySelectiveCandidate]'))
        CREATE INDEX [IX_VSOCandidate_RunRank] ON [Analysis].[VolatilitySelectiveCandidate] ([RunId], [Rank]);
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_VSOCandidate_Symbol' AND object_id = OBJECT_ID(N'[Analysis].[VolatilitySelectiveCandidate]'))
        CREATE INDEX [IX_VSOCandidate_Symbol] ON [Analysis].[VolatilitySelectiveCandidate] ([Symbol], [Expiration]);
END;
GO

IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveManualPosition]', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_VSOPosition_Open' AND object_id = OBJECT_ID(N'[Analysis].[VolatilitySelectiveManualPosition]'))
        CREATE INDEX [IX_VSOPosition_Open] ON [Analysis].[VolatilitySelectiveManualPosition] ([Status], [Symbol], [Expiration]);
END;
GO

IF OBJECT_ID(N'[Analysis].[VolatilitySelectiveAlert]', N'U') IS NOT NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_VSOAlert_Status' AND object_id = OBJECT_ID(N'[Analysis].[VolatilitySelectiveAlert]'))
        CREATE INDEX [IX_VSOAlert_Status] ON [Analysis].[VolatilitySelectiveAlert] ([Status], [CreatedAt]);
END;
GO
