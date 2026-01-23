-- Table: [StockData].[PlaceHistory]

CREATE TABLE [StockData].[PlaceHistory] (
    [PlaceHistoryID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [PlacementDate] [date] NULL,
    [OfferPrice] [decimal](20,4) NULL,
    [Discount] [decimal](10,2) NULL,
    [MarketCapAtRaiseRaw] [varchar](200) NULL,
    [MarketCapAtRaise] [decimal](20,2) NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [ClosePriorToPlacement] [decimal](20,4) NULL,
    [Close5dAfterPlacementAnn] [decimal](20,4) NULL,
    [Close30dAfterPlacementAnn] [decimal](20,4) NULL,
    [Close60dAfterPlacementAnn] [decimal](20,4) NULL,
    [OpenAfterPlacementAnn] [decimal](20,4) NULL,
    [CloseAfterPlacementAnn] [decimal](20,4) NULL
,
    CONSTRAINT [pk_stockdataplacehistory_placehistoryid] PRIMARY KEY (PlaceHistoryID)
);
