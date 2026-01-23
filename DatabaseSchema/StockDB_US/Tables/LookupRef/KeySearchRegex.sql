-- Table: [LookupRef].[KeySearchRegex]

CREATE TABLE [LookupRef].[KeySearchRegex] (
    [KeySearchRegexID] [int] IDENTITY(1,1) NOT NULL,
    [KeySearch] [varchar](100) NOT NULL,
    [Regex] [varchar](4000) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL
);
