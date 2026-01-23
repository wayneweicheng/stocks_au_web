-- Table: [Transform].[GapUpWatchlist]

CREATE TABLE [Transform].[GapUpWatchlist] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [ASXCode] [varchar](20) NOT NULL,
    [Price] [decimal](10,4) NOT NULL,
    [ChangePercent] [decimal](10,2) NOT NULL,
    [GapUpPercent] [decimal](10,2) NOT NULL,
    [VolumeValue] [decimal](18,2) NOT NULL,
    [VolumeRatio] [decimal](10,2) NOT NULL,
    [CloseLocation] [decimal](10,4) NOT NULL,
    [HighOf60Days] [decimal](10,4) NOT NULL,
    [TomorrowChange] [decimal](10,2) NULL,
    [Next2DaysChange] [decimal](10,2) NULL,
    [Next5DaysChange] [decimal](10,2) NULL,
    [Next10DaysChange] [decimal](10,2) NULL,
    [CreatedAt] [datetime2] NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__GapUpWat__3214EC0747B420C4] PRIMARY KEY (Id)
);

CREATE INDEX [IX_GapUpWatchlist_Code] ON [Transform].[GapUpWatchlist] (ASXCode);
CREATE INDEX [IX_GapUpWatchlist_Date] ON [Transform].[GapUpWatchlist] (ObservationDate);