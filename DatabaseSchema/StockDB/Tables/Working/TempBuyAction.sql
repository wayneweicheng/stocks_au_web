-- Table: [Working].[TempBuyAction]

CREATE TABLE [Working].[TempBuyAction] (
    [TempBuyActionID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [BuyAction] [varchar](10) NOT NULL,
    [BuyValue] [decimal](20,4) NULL,
    [CreateDate] [datetime] NULL
);
