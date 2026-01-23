-- Table: [Stock].[CachedAPIResponse]

CREATE TABLE [Stock].[CachedAPIResponse] (
    [CachedAPIResponseID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [SourceID] [varchar](4) NOT NULL,
    [ResponseType] [varchar](10) NOT NULL,
    [Response] [varchar](MAX) NULL,
    [CreateDate] [smalldatetime] NULL
,
    CONSTRAINT [pk_stockcachedapiresponse_cachedapiresponseid] PRIMARY KEY (CachedAPIResponseID)
);
