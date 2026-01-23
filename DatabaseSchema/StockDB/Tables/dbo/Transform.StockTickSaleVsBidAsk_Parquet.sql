-- Table: [dbo].[Transform.StockTickSaleVsBidAsk_Parquet]

CREATE TABLE [dbo].[Transform.StockTickSaleVsBidAsk_Parquet] (
    [CourseOfSaleSecondaryID] [float] NULL,
    [SaleDateTime] [datetime] NULL,
    [ObservationDate] [date] NULL,
    [Price] [varchar](MAX) NULL,
    [Quantity] [float] NULL,
    [SaleValue] [float] NULL,
    [FormatedSaleValue] [varchar](MAX) NULL,
    [ASXCode] [varchar](MAX) NULL,
    [Exchange] [varchar](MAX) NULL,
    [SpecialCondition] [varchar](MAX) NULL,
    [ActBuySellInd] [varchar](MAX) NULL,
    [DerivedBuySellInd] [varchar](MAX) NULL,
    [DerivedInstitute] [bit] NULL,
    [StockBidAskID] [bigint] NULL,
    [PriceBid] [varchar](MAX) NULL,
    [SizeBid] [bigint] NULL,
    [PriceAsk] [varchar](MAX) NULL,
    [SizeAsk] [bigint] NULL,
    [DateFrom] [datetime] NULL,
    [DateTo] [datetime] NULL
);
