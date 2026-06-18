-- Table: [Transform].[BrokerTxMicrostructureDay]

CREATE TABLE [Transform].[BrokerTxMicrostructureDay] (
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
    [NetFlowValue] [decimal](20,2) NOT NULL,
    [NetFlowPctTotal] [decimal](18,8) NOT NULL,
    [TopBuyerValueShare] [decimal](18,8) NOT NULL,
    [TopSellerValueShare] [decimal](18,8) NOT NULL,
    [BuyerAggressionScore] [decimal](18,8) NOT NULL,
    [SellerAggressionScore] [decimal](18,8) NOT NULL,
    [AbsorptionScore] [decimal](18,8) NOT NULL,
    [TransferScore] [decimal](18,8) NOT NULL,
    [ChurnScore] [decimal](18,8) NOT NULL,
    [SuppressionReacquisitionScore] [decimal](18,8) NOT NULL,
    [LiveDistributionScore] [decimal](18,8) NOT NULL,
    [LiveExecutionQualityScore] [decimal](18,8) NOT NULL,
    [LeadAggressorBroker] [nvarchar](100) NULL,
    [LeadDistributorBroker] [nvarchar](100) NULL,
    [ScoreVersion] [varchar](40) NOT NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_BrokerTxMicrostructureDay] PRIMARY KEY (SnapshotDate, ASXCode, ObservationDate)
);

CREATE INDEX [IX_Transform_BrokerTxMicrostructureDay_Lookup] ON [Transform].[BrokerTxMicrostructureDay] (ASXCode, SnapshotDate, ObservationDate);