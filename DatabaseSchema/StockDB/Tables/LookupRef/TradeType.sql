-- Table: [LookupRef].[TradeType]

CREATE TABLE [LookupRef].[TradeType] (
    [TradeTypeID] [varchar](10) NOT NULL,
    [TradeTypeDescr] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookupreftradetpype_tradetypeid] PRIMARY KEY (TradeTypeID)
);
