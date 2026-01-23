-- Table: [AutoTrade].[RequestProcessHistory]

CREATE TABLE [AutoTrade].[RequestProcessHistory] (
    [RequestProcessHistoryID] [int] IDENTITY(1,1) NOT NULL,
    [TradeRequestID] [int] NOT NULL,
    [ProcessTypeID] [tinyint] NOT NULL,
    [AccountNumber] [varchar](50) NULL,
    [CreateDate] [datetime] NOT NULL
,
    CONSTRAINT [pk_autotraderequestprocesshistory_requestprocesshistoryid] PRIMARY KEY (RequestProcessHistoryID)
);

ALTER TABLE [AutoTrade].[RequestProcessHistory] ADD CONSTRAINT [fk_autotraderequestprocesshistory_traderequestid] FOREIGN KEY (TradeRequestID) REFERENCES [AutoTrade].[TradeRequest] (TradeRequestID);