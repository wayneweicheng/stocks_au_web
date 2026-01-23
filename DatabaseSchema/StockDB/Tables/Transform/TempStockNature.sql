-- Table: [Transform].[TempStockNature]

CREATE TABLE [Transform].[TempStockNature] (
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Nature] [nvarchar](MAX) NULL
,
    CONSTRAINT [pk_transform_tempstocknature_uniquekey] PRIMARY KEY (UniqueKey)
);
