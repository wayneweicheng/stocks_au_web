-- Table: [StockData].[MarketDepth]

CREATE TABLE [StockData].[MarketDepth] (
    [MarketDepthID] [int] IDENTITY(1,1) NOT NULL,
    [OrderTypeID] [tinyint] NOT NULL,
    [OrderPosition] [smallint] NOT NULL,
    [NumberOfOrder] [smallint] NOT NULL,
    [Volume] [bigint] NOT NULL,
    [Price] [decimal](20,4) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [DateFrom] [datetime] NOT NULL,
    [DateTo] [datetime] NULL
,
    CONSTRAINT [pk_stockdatamarketdepth_marketdepthid] PRIMARY KEY (MarketDepthID)
);

CREATE INDEX [idx_stockdatamarketdepth_asxcodedatefrom] ON [StockData].[MarketDepth] (MarketDepthID, OrderTypeID, OrderPosition, NumberOfOrder, Volume, Price, DateTo, ASXCode, DateFrom);
CREATE INDEX [idx_stockdatamarketdepth_ordertypeidasxcodeIncpricedatefromdate] ON [StockData].[MarketDepth] (Price, DateFrom, DateTo, OrderTypeID, ASXCode);
CREATE INDEX [idx_stockdatamarketdepth_ordertypeidorderposIncprice] ON [StockData].[MarketDepth] (Price, ASXCode, DateFrom, DateTo, OrderTypeID, OrderPosition);