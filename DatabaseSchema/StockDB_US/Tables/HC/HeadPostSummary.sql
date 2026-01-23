-- Table: [HC].[HeadPostSummary]

CREATE TABLE [HC].[HeadPostSummary] (
    [ASXCode] [varchar](10) NOT NULL,
    [NumPost1d] [int] NOT NULL,
    [NumPostAvg5d] [numeric](24,12) NOT NULL,
    [NumPostAvg30d] [numeric](24,12) NOT NULL
);
