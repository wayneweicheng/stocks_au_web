-- Table: [Analysis].[PLLRSScannerResults]

CREATE TABLE [Analysis].[PLLRSScannerResults] (
    [ASXCode] [nvarchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [OpenPrice] [decimal](18,6) NULL,
    [ClosePrice] [decimal](18,6) NOT NULL,
    [PrevClose] [decimal](18,6) NULL,
    [TodayPriceChange] [decimal](18,6) NULL,
    [MeetsCriteria] [bit] NOT NULL,
    [SupportPrice] [decimal](18,6) NULL,
    [ResistancePrice] [decimal](18,6) NULL,
    [DistanceToSupportPct] [decimal](18,6) NULL,
    [NetAggressorFlow] [bigint] NULL,
    [AggressorBuyRatio] [decimal](18,6) NULL,
    [BidAskReloadRatio] [decimal](18,6) NULL,
    [TotalActiveBuyVolume] [bigint] NULL,
    [TotalActiveSellVolume] [bigint] NULL,
    [EntryPrice] [decimal](18,6) NULL,
    [TargetPrice] [decimal](18,6) NULL,
    [StopPrice] [decimal](18,6) NULL,
    [PotentialGainPct] [decimal](18,6) NULL,
    [PotentialLossPct] [decimal](18,6) NULL,
    [RewardRiskRatio] [decimal](18,6) NULL,
    [Reasons] [nvarchar](MAX) NULL,
    [ScanDateTime] [datetime2] NOT NULL DEFAULT (getdate()),
    [CreatedAt] [datetime2] NOT NULL DEFAULT (getdate()),
    [UpdatedAt] [datetime2] NOT NULL DEFAULT (getdate())
,
    CONSTRAINT [PK_PLLRSScannerResults] PRIMARY KEY (ASXCode, ObservationDate)
);

CREATE INDEX [IX_PLLRSScannerResults_MeetsCriteria] ON [Analysis].[PLLRSScannerResults] (ASXCode, ClosePrice, EntryPrice, TargetPrice, MeetsCriteria, ObservationDate);
CREATE INDEX [IX_PLLRSScannerResults_ObservationDate] ON [Analysis].[PLLRSScannerResults] (ASXCode, MeetsCriteria, ClosePrice, TodayPriceChange, ObservationDate);
CREATE INDEX [IX_PLLRSScannerResults_ScanDateTime] ON [Analysis].[PLLRSScannerResults] (ScanDateTime);