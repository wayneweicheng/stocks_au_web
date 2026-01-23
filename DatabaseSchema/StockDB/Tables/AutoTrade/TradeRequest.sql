-- Table: [AutoTrade].[TradeRequest]

CREATE TABLE [AutoTrade].[TradeRequest] (
    [TradeRequestID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [BuySellFlag] [char](1) NOT NULL,
    [Price] [decimal](20,4) NOT NULL,
    [StopLossPrice] [decimal](20,4) NULL,
    [StopProfitPrice] [decimal](20,4) NULL,
    [MinVolume] [int] NOT NULL,
    [MaxVolume] [int] NOT NULL,
    [RequestValidTimeFrameInMin] [int] NOT NULL,
    [RequestValidUntil] [datetime] NOT NULL,
    [CreateDate] [datetime] NOT NULL,
    [LastTryDate] [datetime] NULL,
    [OrderPlaceDate] [datetime] NULL,
    [OrderPlaceVolume] [int] NULL,
    [OrderReceiptID] [varchar](50) NULL,
    [OrderFillDate] [datetime] NULL,
    [OrderFillVolume] [int] NULL,
    [RequestStatus] [char](1) NOT NULL,
    [RequestStatusMessage] [varchar](MAX) NULL,
    [PreReqTradeRequestID] [int] NULL,
    [AccountNumber] [varchar](50) NULL,
    [TradeStrategyID] [smallint] NULL,
    [ErrorCount] [int] NULL,
    [TradeStrategyMessage] [varchar](MAX) NULL,
    [TradeRank] [int] NULL,
    [IsNotificationSent] [bit] NULL,
    [TradeAccountName] [varchar](100) NULL
,
    CONSTRAINT [pk_autotrade_traderequest] PRIMARY KEY (TradeRequestID)
);

ALTER TABLE [AutoTrade].[TradeRequest] ADD CONSTRAINT [fk_autotradetraderequest_tradestrategyid] FOREIGN KEY (TradeStrategyID) REFERENCES [LookupRef].[TradeStrategy] (TradeStrategyID);
ALTER TABLE [AutoTrade].[TradeRequest] ADD CONSTRAINT [fk_autotradetraderequest_requeststatus] FOREIGN KEY (RequestStatus) REFERENCES [LookupRef].[TradeRequestStatus] (RequestStatus);