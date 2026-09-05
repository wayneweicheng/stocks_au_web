/* Persisted overlap groups for model-builder historical trade detail. */
IF OBJECT_ID(N'[TradingSignal].[HistoricalTradeDeduplication]', N'U') IS NULL
BEGIN
    CREATE TABLE [TradingSignal].[HistoricalTradeDeduplication]
    (
        [HistoricalTradeDeduplicationID] bigint IDENTITY(1,1) NOT NULL,
        [StrategyVersionID] bigint NOT NULL,
        [TradeFingerprint] char(64) NOT NULL,
        [SignalCode] varchar(200) NULL,
        [EntryDate] date NULL,
        [ExitDate] date NULL,
        [DeduplicationGroupID] uniqueidentifier NOT NULL,
        [CreatedUtc] datetime2(3) NOT NULL CONSTRAINT [DF_TradingSignal_HistoricalTradeDeduplication_CreatedUtc] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_TradingSignal_HistoricalTradeDeduplication] PRIMARY KEY CLUSTERED ([HistoricalTradeDeduplicationID]),
        CONSTRAINT [FK_TradingSignal_HistoricalTradeDeduplication_Version]
            FOREIGN KEY ([StrategyVersionID]) REFERENCES [TradingSignal].[StrategyVersion] ([StrategyVersionID]),
        CONSTRAINT [UQ_TradingSignal_HistoricalTradeDeduplication_VersionFingerprint]
            UNIQUE ([StrategyVersionID], [TradeFingerprint])
    );

    CREATE INDEX [IX_TradingSignal_HistoricalTradeDeduplication_Group]
        ON [TradingSignal].[HistoricalTradeDeduplication] ([StrategyVersionID], [SignalCode], [DeduplicationGroupID]);
END;
GO
