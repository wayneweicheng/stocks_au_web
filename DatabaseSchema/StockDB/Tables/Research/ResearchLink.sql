-- Table: [Research].[ResearchLink]

CREATE TABLE [Research].[ResearchLink] (
    [ResearchLinkID] [int] IDENTITY(1,1) NOT NULL,
    [StockCode] [nvarchar](32) NOT NULL,
    [AddedBy] [nvarchar](128) NULL,
    [AddedAt] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
    [Content] [nvarchar](MAX) NULL
,
    CONSTRAINT [PK_ResearchLink] PRIMARY KEY (ResearchLinkID)
);

CREATE INDEX [IX_ResearchLink_AddedAt] ON [Research].[ResearchLink] (AddedAt);
CREATE INDEX [IX_ResearchLink_StockCode] ON [Research].[ResearchLink] (StockCode);