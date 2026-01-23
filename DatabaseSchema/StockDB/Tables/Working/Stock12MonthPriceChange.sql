-- Table: [Working].[Stock12MonthPriceChange]

CREATE TABLE [Working].[Stock12MonthPriceChange] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [PriceChange] [decimal](8,2) NULL
);
