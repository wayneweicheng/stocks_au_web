-- Table: [Transform].[TempDirectorCurrent]

CREATE TABLE [Transform].[TempDirectorCurrent] (
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [DirName] [nvarchar](MAX) NULL
,
    CONSTRAINT [pk_transform_TempDirectorCurrent_uniquekey] PRIMARY KEY (UniqueKey)
);
