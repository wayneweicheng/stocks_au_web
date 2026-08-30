/*
   Capital-type GEX packets may emit more than one independently matched
   signal for a single observation (for example VST's D1 and D5 contracts).
   The original catalogue identity allowed only one signal per observation and
   version, which silently discarded valid co-emissions.  Run once after the
   base manual-trading-signal-ddl.sql deployment.
*/
USE [StockDB_US];
GO

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[TradingSignal].[Signal]')
      AND name = N'UQ_TradingSignal_Signal_ObservationVersion'
)
BEGIN
    ALTER TABLE [TradingSignal].[Signal]
        DROP CONSTRAINT [UQ_TradingSignal_Signal_ObservationVersion];
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[TradingSignal].[Signal]')
      AND name = N'UQ_TradingSignal_Signal_ObservationVersionClassification'
)
BEGIN
    CREATE UNIQUE INDEX [UQ_TradingSignal_Signal_ObservationVersionClassification]
        ON [TradingSignal].[Signal] ([ObservationID], [StrategyVersionID], [Classification]);
END;
GO
