-- Table: [Transform].[StockMCAndCashPosition]

CREATE TABLE [Transform].[StockMCAndCashPosition] (
    [MC] [decimal](31,6) NULL,
    [CashPosition] [numeric](26,6) NULL,
    [AnnDateTime] [smalldatetime] NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [FloatingShares] [decimal](20,2) NULL,
    [FloatingSharesPerc] [decimal](10,2) NULL,
    [SharesIssued] [decimal](10,2) NULL,
    [BusinessDetails] [varchar](2000) NULL,
    [IndustrySubGroup] [varchar](200) NULL,
    [LastValidateDate] [smalldatetime] NULL,
    [Close] [decimal](20,4) NOT NULL,
    [ObservationDate] [date] NOT NULL
);
