-- Table: [StockData].[S708Deal]

CREATE TABLE [StockData].[S708Deal] (
    [S708DealID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](200) NOT NULL,
    [DealType] [varchar](10) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [OfferPrice] [decimal](10,4) NULL,
    [BonusOptionDescr] [varchar](500) NULL,
    [AdditionalNotes] [varchar](2000) NULL,
    [CreatedBy] [varchar](200) NULL,
    [UpdatedBy] [varchar](200) NULL
,
    CONSTRAINT [pk_stockdatas708deal_s708dealid] PRIMARY KEY (S708DealID)
);
