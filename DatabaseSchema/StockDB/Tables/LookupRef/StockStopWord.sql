-- Table: [LookupRef].[StockStopWord]

CREATE TABLE [LookupRef].[StockStopWord] (
    [StockStopWordID] [int] IDENTITY(1,1) NOT NULL,
    [StockStopWord] [varchar](200) NULL
,
    CONSTRAINT [pk_lookuprefstockstopword_stockstopwordid] PRIMARY KEY (StockStopWordID)
);
