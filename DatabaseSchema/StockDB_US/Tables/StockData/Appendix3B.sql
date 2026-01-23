-- Table: [StockData].[Appendix3B]

CREATE TABLE [StockData].[Appendix3B] (
    [AnnouncementID] [int] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [AnnDateTime] [smalldatetime] NOT NULL,
    [AnnDescr] [varchar](200) NOT NULL,
    [IssuePriceRaw] [nvarchar](MAX) NULL,
    [IssuePrice] [decimal](20,4) NULL,
    [SharesIssuedRaw] [nvarchar](MAX) NULL,
    [SharesIssued] [bigint] NULL,
    [PurposeOfIssue] [nvarchar](MAX) NULL,
    [CleansedAnnContent] [nvarchar](MAX) NULL,
    [IssueDateRaw] [nvarchar](MAX) NULL,
    [IssueDate] [date] NULL,
    [TotalSharesOnASXRaw] [nvarchar](MAX) NULL,
    [TotalSharesOnASX] [bigint] NULL,
    [IsPlacement] [bit] NULL
,
    CONSTRAINT [pk_stockdataappendix3b_asxcodeannouncementid] PRIMARY KEY (ASXCode, AnnouncementID)
);

CREATE INDEX [idx_stockdataappendix3b_asxcode] ON [StockData].[Appendix3B] (ASXCode);