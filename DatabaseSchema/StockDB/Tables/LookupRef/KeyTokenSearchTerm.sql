-- Table: [LookupRef].[KeyTokenSearchTerm]

CREATE TABLE [LookupRef].[KeyTokenSearchTerm] (
    [KeyTokenSearchTermID] [int] IDENTITY(1,1) NOT NULL,
    [Token] [varchar](200) NOT NULL,
    [TokenSearchTerm] [varchar](200) NOT NULL,
    [TokenSearchRegex] [varchar](500) NULL,
    [CreateDate] [smalldatetime] NULL
,
    CONSTRAINT [pk_lookuprefkeytokensearchterm_keytokensearchtermid] PRIMARY KEY (KeyTokenSearchTermID)
);

ALTER TABLE [LookupRef].[KeyTokenSearchTerm] ADD CONSTRAINT [fk_lookuprefkeytokensearchterm_token] FOREIGN KEY (Token) REFERENCES [LookupRef].[KeyToken] (Token);