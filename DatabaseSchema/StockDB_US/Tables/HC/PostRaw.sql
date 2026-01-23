-- Table: [HC].[PostRaw]

CREATE TABLE [HC].[PostRaw] (
    [PostRawID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [PostUrl] [varchar](500) NOT NULL,
    [PostDateTime] [smalldatetime] NOT NULL,
    [Poster] [varchar](200) NOT NULL,
    [PosterIsHeart] [bit] NOT NULL,
    [PostContent] [varchar](MAX) NULL,
    [PostFooter] [varchar](MAX) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [PriceAtPosting] [varchar](100) NULL,
    [Sentiment] [varchar](100) NULL,
    [Disclosure] [varchar](100) NULL,
    [QualityPosterRating] [tinyint] NULL
,
    CONSTRAINT [pk_hcpostraw_postrawid] PRIMARY KEY (PostRawID)
);

CREATE INDEX [idx_hcpostraw_asxcodecreatedate] ON [HC].[PostRaw] (ASXCode, CreateDate);
CREATE INDEX [idx_hcpostraw_asxcodeposterpostdatetime] ON [HC].[PostRaw] (ASXCode, Poster, PostDateTime);
CREATE INDEX [idx_hcpostraw_posturl] ON [HC].[PostRaw] (PostUrl);