-- Table: [LookupRef].[TradeStrategy]

CREATE TABLE [LookupRef].[TradeStrategy] (
    [TradeStrategyID] [smallint] NOT NULL,
    [TradeStrategyName] [varchar](100) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_lookupref_tradestrategy] PRIMARY KEY (TradeStrategyID)
);
