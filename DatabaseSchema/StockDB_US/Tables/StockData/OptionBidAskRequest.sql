-- Table: [StockData].[OptionBidAskRequest]

CREATE TABLE [StockData].[OptionBidAskRequest] (
    [OptionBidAskRequestID] [int] IDENTITY(1,1) NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [OptionSymbol] [varchar](100) NOT NULL,
    [StartDateTime] [datetime] NULL,
    [EndDateTime] [datetime] NULL,
    [CreateDate] [smalldatetime] NULL
);
