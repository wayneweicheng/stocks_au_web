-- Table: [LookupRef].[KeyHolderAndCompany]

CREATE TABLE [LookupRef].[KeyHolderAndCompany] (
    [KeyHolderAndCompanyID] [int] IDENTITY(1,1) NOT NULL,
    [KeyHolder] [varchar](200) NOT NULL,
    [CompanyName] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NULL,
    [Notes] [varchar](MAX) NULL
);
