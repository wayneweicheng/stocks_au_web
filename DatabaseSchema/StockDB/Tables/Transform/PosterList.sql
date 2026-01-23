-- Table: [Transform].[PosterList]

CREATE TABLE [Transform].[PosterList] (
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Poster] [nvarchar](MAX) NULL
,
    CONSTRAINT [pk_transform_postlist_uniquekey] PRIMARY KEY (UniqueKey)
);
