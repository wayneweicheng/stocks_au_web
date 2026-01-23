-- Table: [StockData].[AnnouncementToken]

CREATE TABLE [StockData].[AnnouncementToken] (
    [AnnouncementTokenID] [int] IDENTITY(1,1) NOT NULL,
    [AnnouncementID] [int] NOT NULL,
    [Token] [varchar](100) NOT NULL,
    [Cnt] [int] NOT NULL,
    [CreateDate] [smalldatetime] NULL
,
    CONSTRAINT [pk_stockdateannouncementtoken_announcementtokenid] PRIMARY KEY (AnnouncementTokenID)
);

CREATE INDEX [idx_stockdataannouncementtoken_tokenannidcnt] ON [StockData].[AnnouncementToken] (Token, AnnouncementID, Cnt);