-- Table: [StockData].[CustomFilterDetail]

CREATE TABLE [StockData].[CustomFilterDetail] (
    [CustomFilterDetailID] [int] IDENTITY(1,1) NOT NULL,
    [CustomFilterID] [int] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [DisplayOrder] [int] NOT NULL,
    [CreateDate] [smalldatetime] NULL
);
