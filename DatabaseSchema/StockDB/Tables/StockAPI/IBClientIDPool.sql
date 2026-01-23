-- Table: [StockAPI].[IBClientIDPool]

CREATE TABLE [StockAPI].[IBClientIDPool] (
    [ClientIDPoolID] [int] IDENTITY(1,1) NOT NULL,
    [AppName] [varchar](200) NOT NULL,
    [ClientID] [int] NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
);
