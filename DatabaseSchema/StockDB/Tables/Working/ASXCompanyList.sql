-- Table: [Working].[ASXCompanyList]

CREATE TABLE [Working].[ASXCompanyList] (
    [ASXCode] [varchar](10) NULL,
    [ASXCompanyName] [varchar](200) NULL,
    [IndustryGroup] [varchar](100) NULL,
    [ListingDate] [varchar](100) NULL,
    [MarketCap] [varchar](100) NULL,
    [CleansedListingDate] [date] NULL,
    [CleansedMarket] [decimal](20,4) NULL
);
