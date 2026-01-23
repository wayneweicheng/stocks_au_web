-- Table: [LookupRef].[StockAnnSearchTermType]

CREATE TABLE [LookupRef].[StockAnnSearchTermType] (
    [SearchTermTypeID] [varchar](20) NOT NULL,
    [SearchTermTypeDescr] [varchar](2000) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookuprefstockannsearchtermtype_stocktermtypeid] PRIMARY KEY (SearchTermTypeID)
);
