-- Table: [Transform].[PriceAnalysisResults]

CREATE TABLE [Transform].[PriceAnalysisResults] (
    [ASXCode] [varchar](20) NULL,
    [ObservationDate] [date] NULL,
    [Close] [decimal](18,4) NULL,
    [High] [decimal](18,4) NULL,
    [Low] [decimal](18,4) NULL,
    [Value] [decimal](18,2) NULL,
    [TodayChange] [decimal](10,4) NULL,
    [Next10DaysChange] [decimal](10,4) NULL,
    [Next2DaysChange] [decimal](10,4) NULL
);
