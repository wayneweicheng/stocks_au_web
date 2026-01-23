-- Table: [StockData].[QU100Parsed]

CREATE TABLE [StockData].[QU100Parsed] (
    [QU100ParsedID] [int] IDENTITY(1,1) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [Mode] [varchar](20) NULL,
    [TimeFrame] [varchar](50) NULL,
    [Change] [int] NULL,
    [Industry] [nvarchar](4000) NULL,
    [LongShort] [varchar](100) NULL,
    [QURank] [int] NULL,
    [Sector] [nvarchar](4000) NULL,
    [Ticker] [varchar](20) NOT NULL,
    [ASXCode] [varchar](20) NOT NULL
);
