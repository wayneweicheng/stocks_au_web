-- Table: [Transform].[PutSellingPerc]

CREATE TABLE [Transform].[PutSellingPerc] (
    [ASXCode] [varchar](10) NOT NULL,
    [ObservationDate] [date] NULL,
    [PutSellPerc] [numeric](38,6) NULL,
    [CreateDate] [smalldatetime] NULL
);
