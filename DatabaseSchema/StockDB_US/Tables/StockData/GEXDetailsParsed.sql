-- Table: [StockData].[GEXDetailsParsed]

CREATE TABLE [StockData].[GEXDetailsParsed] (
    [GEXDetailsParsedID] [int] IDENTITY(1,1) NOT NULL,
    [ObservationDate] [date] NULL,
    [ASXCode] [varchar](10) NULL,
    [GEX] [decimal](20,4) NULL,
    [OpenInterest] [decimal](20,4) NULL,
    [PorC] [varchar](10) NULL,
    [Strike] [decimal](20,4) NULL,
    [ExpiryDate] [date] NULL,
    [ExpiryDateTotal] [decimal](20,4) NULL,
    [CreateDate] [smalldatetime] NULL
);
