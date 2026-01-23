-- Table: [Transform].[StockTickSaleVsBidAskASX]

CREATE TABLE [Transform].[StockTickSaleVsBidAskASX] (
    [CourseOfSaleSecondaryID] [int] NULL,
    [SaleDateTime] [datetime] NULL,
    [ObservationDate] [date] NULL,
    [Price] [decimal](20,4) NULL,
    [Quantity] [bigint] NULL,
    [SaleValue] [int] NULL,
    [FormatedSaleValue] [nvarchar](4000) NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Exchange] [varchar](3) NULL,
    [SpecialCondition] [int] NULL,
    [ActBuySellInd] [int] NULL,
    [DerivedBuySellInd] [varchar](1) NULL,
    [DerivedInstitute] [bit] NULL,
    [StockBidAskASXID] [int] NULL,
    [PriceBid] [decimal](20,4) NULL,
    [SizeBid] [bigint] NULL,
    [PriceAsk] [decimal](20,4) NULL,
    [SizeAsk] [bigint] NULL,
    [DateFrom] [datetime] NULL,
    [DateTo] [datetime] NULL
);
