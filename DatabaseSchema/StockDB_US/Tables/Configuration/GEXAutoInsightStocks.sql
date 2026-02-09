-- Table: [Configuration].[GEXAutoInsightStocks]

CREATE TABLE [Configuration].[GEXAutoInsightStocks] (
    [StockCode] [varchar](20) NOT NULL,
    [DisplayName] [nvarchar](100) NULL,
    [IsActive] [bit] NOT NULL DEFAULT ((1)),
    [Priority] [int] NOT NULL DEFAULT ((0)),
    [LLMModel] [varchar](100) NULL,
    [CreatedDate] [datetime] NOT NULL DEFAULT (getdate()),
    [UpdatedDate] [datetime] NOT NULL DEFAULT (getdate())
,
    CONSTRAINT [PK_Configuration_GEXAutoInsightStocks] PRIMARY KEY (StockCode)
);

CREATE INDEX [IX_GEXAutoInsightStocks_IsActive] ON [Configuration].[GEXAutoInsightStocks] (IsActive, Priority);