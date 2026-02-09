-- Table: [Trading].[StopLossHistory]

CREATE TABLE [Trading].[StopLossHistory] (
    [StopLossHistoryId] [bigint] IDENTITY(1,1) NOT NULL,
    [OrderId] [bigint] NOT NULL,
    [ChangedAt] [datetime] NOT NULL,
    [OldStopPrice] [decimal](20,4) NULL,
    [NewStopPrice] [decimal](20,4) NOT NULL,
    [Reason] [varchar](50) NULL
,
    CONSTRAINT [PK__StopLoss__EDD1C1EA99F42DBA] PRIMARY KEY (StopLossHistoryId)
);

ALTER TABLE [Trading].[StopLossHistory] ADD CONSTRAINT [FK_StopLossHistory_Orders] FOREIGN KEY (OrderId) REFERENCES [Trading].[Orders] (OrderId);