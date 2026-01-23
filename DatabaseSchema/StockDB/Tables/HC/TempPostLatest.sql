-- Table: [HC].[TempPostLatest]

CREATE TABLE [HC].[TempPostLatest] (
    [PostRawID] [int] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Poster] [varchar](200) NOT NULL,
    [PostDateTime] [smalldatetime] NOT NULL,
    [PosterIsHeart] [bit] NOT NULL,
    [QualityPosterRating] [tinyint] NULL,
    [Sentiment] [varchar](100) NULL,
    [Disclosure] [varchar](100) NULL
);
