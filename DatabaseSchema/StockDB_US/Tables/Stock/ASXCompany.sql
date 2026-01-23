-- Table: [Stock].[ASXCompany]

CREATE TABLE [Stock].[ASXCompany] (
    [ASXCode] [varchar](10) NOT NULL,
    [ASXCompanyName] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [IndustryGroup] [varchar](100) NULL,
    [IsDisabled] [bit] NULL,
    [CompanyID] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_stockasxcompany_asxcode] PRIMARY KEY (ASXCode)
);
