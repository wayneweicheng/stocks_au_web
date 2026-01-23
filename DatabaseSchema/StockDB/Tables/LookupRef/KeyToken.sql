-- Table: [LookupRef].[KeyToken]

CREATE TABLE [LookupRef].[KeyToken] (
    [Token] [varchar](200) NOT NULL,
    [TokenType] [varchar](20) NOT NULL,
    [CutoffThreshold] [decimal](10,2) NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [IsDisabled] [bit] NULL,
    [TokenOrder] [smallint] NULL,
    [TokenID] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_lookuprefkeytoken_token] PRIMARY KEY (Token)
);
