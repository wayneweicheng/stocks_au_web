-- Table: [HC].[PosterSummary]

CREATE TABLE [HC].[PosterSummary] (
    [Poster] [varchar](200) NOT NULL,
    [NumStock] [int] NULL,
    [OpenBalance] [decimal](20,4) NULL,
    [InitialAmountPerStock] [decimal](20,4) NULL,
    [CloseBalance] [decimal](20,4) NULL,
    [TotalHeldDays] [int] NULL,
    [SuccessRate] [int] NULL,
    [OverallPerf] [decimal](10,2) NULL
);
