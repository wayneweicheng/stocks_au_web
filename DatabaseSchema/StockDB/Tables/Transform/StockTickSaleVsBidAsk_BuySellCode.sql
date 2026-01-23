-- Table: [Transform].[StockTickSaleVsBidAsk_BuySellCode]

CREATE TABLE [Transform].[StockTickSaleVsBidAsk_BuySellCode] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDateTime] [datetime] NULL,
    [ObservationDate] [date] NULL,
    [FormatBid1Volume] [nvarchar](4000) NULL,
    [Bid1Volume] [bigint] NULL,
    [Buy1NoOfOrder] [int] NOT NULL,
    [Buy1Price] [decimal](20,4) NULL,
    [Buy1DateFrom] [datetime] NULL,
    [Buy1DateTo] [datetime] NULL,
    [FormatAsk1Volume] [nvarchar](4000) NULL,
    [Ask1Volume] [bigint] NULL,
    [Sell1NoOfOrder] [int] NOT NULL,
    [Sell1Price] [decimal](20,4) NULL,
    [Sell1DateFrom] [datetime] NULL,
    [Sell1DateTo] [datetime] NULL,
    [TransPrice] [decimal](20,4) NULL,
    [TransQuantity] [bigint] NULL,
    [TransValue] [bigint] NULL,
    [ActBuySellInd] [varchar](1) NULL,
    [Exchange] [varchar](5) NULL,
    [DerivedInstitute] [varchar](10) NULL,
    [Close] [decimal](20,4) NOT NULL,
    [RowNumber] [bigint] NULL
);
