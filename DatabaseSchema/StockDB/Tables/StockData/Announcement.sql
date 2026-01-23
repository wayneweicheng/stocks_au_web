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
    [CreateDate] [smalldatetime] NOT NULL,
    [ObservationDate] [date] NULL,
    [IsCleansed] [bit] NULL
,
    CONSTRAINT [pk_stockdataannouncement_announcementid] PRIMARY KEY (AnnouncementID)
);
