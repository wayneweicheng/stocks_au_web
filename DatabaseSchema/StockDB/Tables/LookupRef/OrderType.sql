-- Table: [LookupRef].[OrderType]

CREATE TABLE [LookupRef].[OrderType] (
    [OrderTypeID] [tinyint] NOT NULL,
    [OrderType] [varchar](200) NOT NULL,
    [OrderTypeDescr] [varchar](4000) NULL,
    [IsDisabled] [bit] NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [BuySellFlag] [char](1) NULL,
    [DisplayOrder] [smallint] NULL
,
    CONSTRAINT [pk_lookuprefordertype_ordertypeid] PRIMARY KEY (OrderTypeID)
);
