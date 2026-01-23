-- Table: [Transform].[BrokerDataInflowTrend]

CREATE TABLE [Transform].[BrokerDataInflowTrend] (
    [BrokerDataInflowTrendID] [int] IDENTITY(1,1) NOT NULL,
    [MarketCap] [varchar](100) NOT NULL,
    [ObservationDate] [date] NULL,
    [BrokerCode] [varchar](10) NOT NULL,
    [NetValueInK] [int] NOT NULL,
    [NetValueInKMA10] [decimal](10,2) NULL,
    [NetValueInKMA20] [decimal](10,2) NULL,
    [Sector] [varchar](100) NULL,
    [CreateDate] [smalldatetime] NULL,
    [NetValueInKMA50] [decimal](10,2) NULL,
    [NetValueInKMA90] [decimal](10,2) NULL,
    [NetValueInKMA255] [decimal](10,2) NULL,
    [NNetValueInKMA10] [decimal](10,2) NULL,
    [NNetValueInKMA20] [decimal](10,2) NULL,
    [NNetValueInKMA50] [decimal](10,2) NULL,
    [XAO] [decimal](20,4) NULL
);
