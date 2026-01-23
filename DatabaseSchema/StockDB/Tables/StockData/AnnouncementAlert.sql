-- Table: [StockData].[AnnouncementAlert]

CREATE TABLE [StockData].[AnnouncementAlert] (
    [AnnouncementAlert] [int] IDENTITY(1,1) NOT NULL,
    [AnnouncementID] [int] NOT NULL,
    [SearchTerm] [varchar](500) NOT NULL,
    [SearchTermNotes] [varchar](500) NULL,
    [SearchTermTypeID] [varchar](20) NOT NULL,
    [MC] [decimal](20,5) NULL,
    [CreateDate] [datetime] NOT NULL
,
    CONSTRAINT [pk_stockdata_announcementalert_annalert] PRIMARY KEY (AnnouncementAlert)
);
