-- Table: [HC].[QualityPoster]

CREATE TABLE [HC].[QualityPoster] (
    [QualityPosterID] [int] IDENTITY(1,1) NOT NULL,
    [Poster] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NULL,
    [Rating] [tinyint] NULL,
    [PosterType] [varchar](50) NULL,
    [UserID] [int] NULL
,
    CONSTRAINT [pk_hcqualityposter_qualityposterid] PRIMARY KEY (QualityPosterID)
);
