-- Table: [StockData].[AnnouncementSearchResult]

CREATE TABLE [StockData].[AnnouncementSearchResult] (
    [AnnouncementSearchResultID] [int] IDENTITY(1,1) NOT NULL,
    [SearchItemID] [int] NOT NULL,
    [SearchResult] [varchar](MAX) NULL,
    [ASXCode] [varchar](20) NOT NULL,
    [AnnRetriveDateTime] [smalldatetime] NULL,
    [AnnDateTime] [smalldatetime] NOT NULL,
    [MarketSensitiveIndicator] [int] NULL,
    [AnnDescr] [varchar](200) NOT NULL,
    [AnnouncementID] [int] NULL,
    [ObservationDate] [date] NULL,
    [CreateDate] [smalldatetime] NULL DEFAULT (getdate())
);
