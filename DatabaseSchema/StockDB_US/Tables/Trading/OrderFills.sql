-- Table: [Trading].[OrderFills]

CREATE TABLE [Trading].[OrderFills] (
    [FillId] [bigint] IDENTITY(1,1) NOT NULL,
    [OrderId] [bigint] NOT NULL,
    [FillTime] [datetime] NOT NULL,
    [FillPrice] [decimal](20,4) NOT NULL,
    [FillQty] [int] NOT NULL,
    [FillType] [varchar](10) NOT NULL,
    [Reason] [varchar](50) NULL
,
    CONSTRAINT [PK__OrderFil__6D593F15E1B7CB50] PRIMARY KEY (FillId)
);

ALTER TABLE [Trading].[OrderFills] ADD CONSTRAINT [FK_OrderFills_Orders] FOREIGN KEY (OrderId) REFERENCES [Trading].[Orders] (OrderId);