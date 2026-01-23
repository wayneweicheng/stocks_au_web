-- Table: [Transform].[TempPostRaw]

CREATE TABLE [Transform].[TempPostRaw] (
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL,
    [PostRawID] [int] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Poster] [varchar](200) NOT NULL,
    [PostDateTime] [smalldatetime] NOT NULL,
    [PosterIsHeart] [bit] NOT NULL,
    [QualityPosterRating] [tinyint] NULL,
    [Sentiment] [varchar](100) NULL,
    [Disclosure] [varchar](100) NULL
,
    CONSTRAINT [pk_transform_TempPostRaw_uniquekey] PRIMARY KEY (UniqueKey)
);
