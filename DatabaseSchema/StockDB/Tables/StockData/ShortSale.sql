-- Table: [StockData].[ShortSale]

CREATE TABLE [StockData].[ShortSale] (
    [ShortSaleID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NULL,
    [CompanyName] [varchar](200) NULL,
    [ShareClass] [varchar](50) NULL,
    [ShareSales] [bigint] NULL,
    [IssuedCapital] [bigint] NULL,
    [ObservationDate] [date] NULL,
    [CreateDateTime] [smalldatetime] NULL
);
