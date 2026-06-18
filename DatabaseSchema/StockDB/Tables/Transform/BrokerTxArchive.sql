-- Table: [Transform].[BrokerTxArchive]

CREATE TABLE [Transform].[BrokerTxArchive] (
    [SourceTransactionID] [bigint] NOT NULL,
    [CaptureRunID] [bigint] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [PriceASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [TransactionDateTime] [datetime2] NOT NULL,
    [BuyerBrokerName] [nvarchar](100) NOT NULL,
    [BuyerBrokerCode] [varchar](50) NULL,
    [BuyerBrokerLevel] [smallint] NULL,
    [BuyerBrokerScore] [decimal](10,2) NULL,
    [SellerBrokerName] [nvarchar](100) NOT NULL,
    [SellerBrokerCode] [varchar](50) NULL,
    [SellerBrokerLevel] [smallint] NULL,
    [SellerBrokerScore] [decimal](10,2) NULL,
    [Price] [decimal](20,4) NOT NULL,
    [Volume] [bigint] NOT NULL,
    [Value] [decimal](20,2) NOT NULL,
    [Condition] [nvarchar](50) NULL,
    [Market] [nvarchar](10) NOT NULL,
    [CaptureSource] [varchar](20) NOT NULL,
    [BullishSetupScore] [decimal](18,8) NULL,
    [BearishSetupScore] [decimal](18,8) NULL,
    [ScoreVersion] [varchar](40) NOT NULL,
    [CreatedDate] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK_Transform_BrokerTxArchive] PRIMARY KEY (SourceTransactionID)
);

CREATE INDEX [IX_Transform_BrokerTxArchive_ASXDate] ON [Transform].[BrokerTxArchive] (ASXCode, ObservationDate, TransactionDateTime);
CREATE INDEX [IX_Transform_BrokerTxArchive_BuyerSeller] ON [Transform].[BrokerTxArchive] (BuyerBrokerName, SellerBrokerName, ObservationDate);
CREATE INDEX [IX_Transform_BrokerTxArchive_ObsDate_ASXCode] ON [Transform].[BrokerTxArchive] (ObservationDate, ASXCode);