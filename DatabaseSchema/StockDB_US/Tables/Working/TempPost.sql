-- Table: [Working].[TempPost]

CREATE TABLE [Working].[TempPost] (
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
);
