-- Table: [HC].[PostScan]

CREATE TABLE [HC].[PostScan] (
    [PostScanID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [CreateDate] [datetime] NULL
,
    CONSTRAINT [pk_hcpostscan_postscanid] PRIMARY KEY (PostScanID)
);
