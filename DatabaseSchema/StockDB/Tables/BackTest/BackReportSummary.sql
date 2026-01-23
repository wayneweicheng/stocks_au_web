-- Table: [BackTest].[BackReportSummary]

CREATE TABLE [BackTest].[BackReportSummary] (
    [ExecutionID] [int] NOT NULL,
    [ASXCode] [varchar](10) NULL,
    [TotalTransaction] [int] NULL,
    [TotalProfitOrLoss] [decimal](38,4) NULL,
    [TotalTradeSize] [decimal](38,4) NULL,
    [TotalProfit] [decimal](38,4) NULL,
    [TotalRequiredInvestment] [decimal](20,4) NULL,
    [ProfitTransaction] [int] NULL,
    [LossTransaction] [int] NULL,
    [TradeProfitPercentage] [numeric](26,12) NULL,
    [TradeSuccessPercentage] [numeric](26,12) NULL,
    [TradeNumberOfDays] [int] NULL,
    [ROI] [numeric](38,6) NULL
);
