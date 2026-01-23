-- Table: [StockData].[CourseOfSale]

CREATE TABLE [StockData].[CourseOfSale] (
    [CourseOfSaleID] [int] IDENTITY(1,1) NOT NULL,
    [SaleDateTime] [datetime] NOT NULL,
    [Price] [decimal](20,4) NOT NULL,
    [Quantity] [bigint] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CreateDate] [datetime] NOT NULL,
    [ActBuySellInd] [char](1) NULL
,
    CONSTRAINT [pk_stockdatacourseofsale_courseofsaleid] PRIMARY KEY (CourseOfSaleID)
);

CREATE INDEX [idx_stockcourseofsale_actbuysellind] ON [StockData].[CourseOfSale] (CourseOfSaleID, ActBuySellInd);
CREATE INDEX [idx_stockdata_asxcode] ON [StockData].[CourseOfSale] (CourseOfSaleID, SaleDateTime, Price, Quantity, CreateDate, ActBuySellInd, ASXCode);
CREATE INDEX [idx_stockdatacourseofsale_asxcodesaledatetimeIncpricequantitycreatedate] ON [StockData].[CourseOfSale] (CourseOfSaleID, Price, Quantity, CreateDate, ASXCode, SaleDateTime);
CREATE INDEX [idx_stockdatacourseofsale_saledatetime] ON [StockData].[CourseOfSale] (Price, Quantity, ASXCode, SaleDateTime);