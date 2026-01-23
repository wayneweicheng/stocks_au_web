-- Table: [StockData].[S708Bid]

CREATE TABLE [StockData].[S708Bid] (
    [S708BidID] [int] IDENTITY(1,1) NOT NULL,
    [S708DealID] [int] NOT NULL,
    [BidAmount] [decimal](20,4) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [CreatedBy] [varchar](200) NOT NULL,
    [CreatedByUserID] [varchar](50) NULL
);
