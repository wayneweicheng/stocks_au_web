-- Table: [StockData].[StockTip]

CREATE TABLE [StockData].[StockTip] (
    [StockTipId] [int] IDENTITY(1,1) NOT NULL,
    [TipUser] [varchar](200) NOT NULL,
    [TipUserId] [varchar](50) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [TipType] [varchar](50) NOT NULL,
    [TipDateTime] [smalldatetime] NOT NULL,
    [AdditionalNotes] [varchar](2000) NULL,
    [CreatedBy] [varchar](200) NOT NULL,
    [CreatedByUserId] [varchar](50) NOT NULL,
    [CreateDateTime] [smalldatetime] NULL,
    [PriceAsAtTip] [decimal](20,4) NULL
);
