-- Table: [Transform].[StockTickSaleVsBidAsk]

CREATE TABLE [Transform].[StockTickSaleVsBidAsk] (
    [CourseOfSaleSecondaryID] [int] NULL,
    [SaleDateTime] [datetime] NULL,
    [ObservationDate] [date] NULL,
    [Price] [decimal](20,4) NULL,
    [Quantity] [bigint] NULL,
    [SaleValue] [bigint] NULL,
    [FormatedSaleValue] [nvarchar](4000) NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Exchange] [varchar](5) NULL,
    [SpecialCondition] [int] NULL,
    [ActBuySellInd] [int] NULL,
    [DerivedBuySellInd] [varchar](1) NULL,
    [DerivedInstitute] [bit] NULL,
    [StockBidAskID] [int] NULL,
    [PriceBid] [decimal](20,4) NULL,
    [SizeBid] [bigint] NULL,
    [PriceAsk] [decimal](20,4) NULL,
    [SizeAsk] [bigint] NULL,
    [DateFrom] [datetime] NULL,
    [DateTo] [datetime] NULL
);

CREATE INDEX [idx_StockTickSaleVsBidAsk_Composite] ON [Transform].[StockTickSaleVsBidAsk] (ObservationDate, ASXCode, SaleDateTime);
CREATE INDEX [idx_StockTickSaleVsBidAsk_ObsDateASXCode] ON [Transform].[StockTickSaleVsBidAsk] (SaleDateTime, Price, Quantity, ObservationDate, ASXCode);
CREATE INDEX [idx_transformstockticksalevsbidask_obdateasxcodeIncothers] ON [Transform].[StockTickSaleVsBidAsk] (Price, Quantity, SaleValue, FormatedSaleValue, Exchange, SpecialCondition, ActBuySellInd, DerivedBuySellInd, DerivedInstitute, PriceBid, SizeBid, PriceAsk, SizeAsk, DateFrom, DateTo, ObservationDate, ASXCode, SaleDateTime);