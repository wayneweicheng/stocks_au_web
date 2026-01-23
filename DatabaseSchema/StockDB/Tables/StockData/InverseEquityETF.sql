-- Table: [StockData].[InverseEquityETF]

CREATE TABLE [StockData].[InverseEquityETF] (
    [InverseEquityETFID] [int] IDENTITY(1,1) NOT NULL,
    [EquityCode] [varchar](20) NOT NULL,
    [SharesOutstandingInM] [decimal](20,4) NULL,
    [TotalNetAssetsInM] [decimal](20,4) NULL,
    [TotalNAV] [decimal](20,4) NULL,
    [NAVDate] [date] NULL,
    [AverageVolumeInM] [decimal](20,4) NULL,
    [CreateDate] [smalldatetime] NULL
);
