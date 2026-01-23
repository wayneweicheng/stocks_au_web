-- Table: [StockData].[Announcement]

CREATE TABLE [StockData].[Announcement] (
    [AnnouncementID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [AnnRetriveDateTime] [smalldatetime] NULL,
    [AnnDateTime] [smalldatetime] NOT NULL,
    [MarketSensitiveIndicator] [int] NULL,
    [AnnDescr] [varchar](200) NOT NULL,
    [AnnURL] [varchar](1000) NOT NULL,
    [AnnContent] [varchar](MAX) NOT NULL,
    [AnnNumPage] [int] NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_stockdataannouncement_announcementid] PRIMARY KEY (AnnouncementID)
);

CREATE INDEX [idx_stockdataannouncement_anndatetime] ON [StockData].[Announcement] (AnnouncementID, ASXCode, AnnDescr, AnnDateTime);
CREATE INDEX [idx_stockdataannouncement_asxcodeanndatemarketsensitiveanndescr] ON [StockData].[Announcement] (ASXCode, AnnDateTime, MarketSensitiveIndicator, AnnDescr);
CREATE INDEX [idx_stockdataannouncement_asxcodeannurl] ON [StockData].[Announcement] (ASXCode, AnnURL);