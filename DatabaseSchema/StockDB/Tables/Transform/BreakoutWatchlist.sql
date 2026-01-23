-- Table: [Transform].[BreakoutWatchlist]

CREATE TABLE [Transform].[BreakoutWatchlist] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [ObservationDate] [date] NOT NULL,
    [ASXCode] [varchar](20) NOT NULL,
    [Pattern] [varchar](50) NOT NULL,
    [Price] [decimal](10,4) NOT NULL,
    [ChangePercent] [decimal](10,2) NOT NULL,
    [VolumeValue] [decimal](18,2) NOT NULL,
    [VolumeRatio] [decimal](10,2) NOT NULL,
    [Note] [varchar](500) NULL,
    [TomorrowChange] [decimal](10,2) NULL,
    [Next2DaysChange] [decimal](10,2) NULL,
    [Next5DaysChange] [decimal](10,2) NULL,
    [Next10DaysChange] [decimal](10,2) NULL,
    [CreatedAt] [datetime2] NULL DEFAULT (getdate()),
    [BreakoutDate] [date] NULL
,
    CONSTRAINT [PK__Breakout__3214EC07178C4848] PRIMARY KEY (Id)
);

CREATE INDEX [IX_BreakoutWatchlist_BreakoutDate] ON [Transform].[BreakoutWatchlist] (BreakoutDate);
CREATE INDEX [IX_BreakoutWatchlist_Code] ON [Transform].[BreakoutWatchlist] (ASXCode);
CREATE INDEX [IX_BreakoutWatchlist_Date] ON [Transform].[BreakoutWatchlist] (ObservationDate);
CREATE INDEX [IX_BreakoutWatchlist_Pattern] ON [Transform].[BreakoutWatchlist] (Pattern);