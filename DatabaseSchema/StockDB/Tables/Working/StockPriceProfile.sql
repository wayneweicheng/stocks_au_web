-- Table: [Working].[StockPriceProfile]

CREATE TABLE [Working].[StockPriceProfile] (
    [ObservationDate] [date] NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Close] [decimal](20,4) NULL,
    [VWAP] [decimal](20,4) NULL,
    [Price] [decimal](20,4) NULL,
    [SuppliedVolume] [nvarchar](4000) NULL,
    [SuppliedValue] [nvarchar](4000) NULL,
    [NoOfTimesSupplyAdded] [int] NULL,
    [S1AskVolume] [nvarchar](4000) NULL,
    [SuppliedVolumeConsumed] [nvarchar](4000) NULL,
    [SuppliedValueConsumed] [nvarchar](4000) NULL,
    [NoOfTimesSupplyConsumed] [int] NULL,
    [S2AskVolume] [nvarchar](4000) NULL,
    [DemandVolume] [nvarchar](4000) NULL,
    [DemandValue] [nvarchar](4000) NULL,
    [NoOfTimesDemandAdded] [int] NULL,
    [B1BidVolume] [nvarchar](4000) NULL,
    [DemandVolumeConsumed] [nvarchar](4000) NULL,
    [DemandValueConsumed] [nvarchar](4000) NULL,
    [NoOfTimesDemandConsumed] [int] NULL,
    [B2BidVolume] [nvarchar](4000) NULL
);
