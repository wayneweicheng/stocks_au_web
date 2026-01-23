-- Table: [StockAPI].[HeartBeatHistory]

CREATE TABLE [StockAPI].[HeartBeatHistory] (
    [HeartBeatHistoryID] [int] IDENTITY(1,1) NOT NULL,
    [HeartBeatProfile] [varchar](50) NOT NULL,
    [ConnectionSuccess] [bit] NULL,
    [ConnectionError] [varchar](MAX) NULL,
    [ConnectionUpdateDateTime] [datetime] NULL,
    [GetDataSuccess] [bit] NULL,
    [GetDataError] [varchar](MAX) NULL,
    [GetDataUpdateDateTime] [datetime] NULL,
    [CreateDateTime] [datetime] NULL
);
