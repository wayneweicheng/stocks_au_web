-- Table: [StockData].[RetailParticipation]

CREATE TABLE [StockData].[RetailParticipation] (
    [ASXCode] [varchar](10) NOT NULL,
    [MediumTermRetailParticipationRate] [decimal](10,2) NULL,
    [MediumTermBroadRetailParticipationRate] [decimal](10,2) NULL,
    [ShortTermRetailParticipationRate] [decimal](10,2) NULL,
    [ShortTermBroadRetailParticipationRate] [decimal](10,2) NULL,
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_stockdata_retailparticipation_uniquekey] PRIMARY KEY (UniqueKey)
);
