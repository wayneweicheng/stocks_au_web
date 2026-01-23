-- Table: [StockData].[CustomFilter]

CREATE TABLE [StockData].[CustomFilter] (
    [CustomFilterID] [int] IDENTITY(1,1) NOT NULL,
    [CustomFilter] [varchar](500) NOT NULL,
    [DisplayOrder] [int] NOT NULL,
    [CreateDate] [smalldatetime] NULL
,
    CONSTRAINT [pk_stockdata_customfilter_customfilterid] PRIMARY KEY (CustomFilterID)
);
