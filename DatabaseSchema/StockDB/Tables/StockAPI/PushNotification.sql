-- Table: [StockAPI].[PushNotification]

CREATE TABLE [StockAPI].[PushNotification] (
    [PushNotificationID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NULL,
    [Title] [varchar](1000) NULL,
    [MessageBody] [varchar](MAX) NULL,
    [MessagePriority] [int] NULL,
    [Retry] [int] NULL,
    [Expire] [int] NULL,
    [CreateDate] [datetime] NULL,
    [PushType] [varchar](200) NULL
);
