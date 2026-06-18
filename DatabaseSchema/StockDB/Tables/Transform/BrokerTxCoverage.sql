-- Table: [Transform].[BrokerTxCoverage]

CREATE TABLE [Transform].[BrokerTxCoverage] (
    [SnapshotDate] [date] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [PriceASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [CaptureSource] [varchar](20) NOT NULL,
    [BullishSetupScore] [decimal](18,8) NULL,
    [BearishSetupScore] [decimal](18,8) NULL,
    [TransactionCount] [bigint] NOT NULL,
    [DistinctBuyerCount] [int] NOT NULL,
    [DistinctSellerCount] [int] NOT NULL,
    [TotalValue] [decimal](20,2) NOT NULL,
    [TotalVolume] [bigint] NOT NULL,
    [FirstTransactionDateTime] [datetime2] NULL,
    [LastTransactionDateTime] [datetime2] NULL,
    [TopBuyerBrokerName] [nvarchar](100) NULL,
    [TopBuyerValue] [decimal](20,2) NULL,
    [TopSellerBrokerName] [nvarchar](100) NULL,
    [TopSellerValue] [decimal](20,2) NULL,
    [ScoreVersion] [varchar](40) NOT NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_BrokerTxCoverage] PRIMARY KEY (SnapshotDate, ASXCode, ObservationDate)
);

CREATE INDEX [IX_Transform_BrokerTxCoverage_Lookup] ON [Transform].[BrokerTxCoverage] (ASXCode, SnapshotDate, ObservationDate);