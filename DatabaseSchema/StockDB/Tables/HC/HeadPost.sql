-- Table: [HC].[HeadPost]

CREATE TABLE [HC].[HeadPost] (
    [HeadPostID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [PostUrl] [varchar](500) NOT NULL,
    [PostDateTime] [smalldatetime] NOT NULL,
    [PostSubject] [varchar](500) NOT NULL,
    [Poster] [varchar](200) NOT NULL,
    [PosterIsHeart] [bit] NOT NULL,
    [Rating] [varchar](100) NULL,
    [PostStats] [varchar](100) NULL,
    [CreateDate] [smalldatetime] NULL
,
    CONSTRAINT [pk_hcheadpost_headpostid] PRIMARY KEY (HeadPostID)
);

CREATE INDEX [idx_hcheadpost_posturl] ON [HC].[HeadPost] (PostUrl);