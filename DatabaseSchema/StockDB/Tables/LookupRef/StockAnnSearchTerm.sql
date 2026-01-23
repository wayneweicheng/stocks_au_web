-- Table: [LookupRef].[StockAnnSearchTerm]

CREATE TABLE [LookupRef].[StockAnnSearchTerm] (
    [StockAnnSearchTermID] [int] IDENTITY(1,1) NOT NULL,
    [SearchTerm] [varchar](500) NOT NULL,
    [SearchTermRegex] [varchar](500) NOT NULL,
    [SearchTermTypeID] [varchar](20) NOT NULL,
    [SearchTermNotes] [varchar](MAX) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [IsDisabled] [bit] NULL DEFAULT ((0)),
    [RegexIntercept] [varchar](500) NULL,
    [RegexDepth] [varchar](500) NULL,
    [RegexGrade] [varchar](500) NULL,
    [DepthMin] [int] NULL,
    [GradeMin] [decimal](20,5) NULL,
    [SearchAnnDescrOnly] [bit] NULL,
    [IsDisDisabled] [bit] NULL
,
    CONSTRAINT [pk_lookuprefstockannsearchterm_stockannsearchtermid] PRIMARY KEY (StockAnnSearchTermID)
);

ALTER TABLE [LookupRef].[StockAnnSearchTerm] ADD CONSTRAINT [fk_lookuprefstockannsearchterm_searchtermtypeid] FOREIGN KEY (SearchTermTypeID) REFERENCES [LookupRef].[StockAnnSearchTermType] (SearchTermTypeID);