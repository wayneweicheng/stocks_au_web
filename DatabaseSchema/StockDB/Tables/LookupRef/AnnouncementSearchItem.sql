-- Table: [LookupRef].[AnnouncementSearchItem]

CREATE TABLE [LookupRef].[AnnouncementSearchItem] (
    [SearchItemID] [int] IDENTITY(1,1) NOT NULL,
    [SearchItemName] [varchar](100) NOT NULL,
    [SearchItemDescr] [varchar](500) NULL,
    [FullTextSearch] [varchar](200) NULL,
    [Regex1] [varchar](500) NULL,
    [Regex2] [varchar](500) NULL,
    [AnnSearchToDate] [date] NULL,
    [CreateDate] [smalldatetime] NULL
);
