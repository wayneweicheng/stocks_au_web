-- Table: [Research].[StockRating]

CREATE TABLE [Research].[StockRating] (
    [StockRatingID] [int] IDENTITY(1,1) NOT NULL,
    [StockCode] [varchar](20) NOT NULL,
    [CommenterID] [int] NOT NULL,
    [Rating] [varchar](20) NOT NULL,
    [Comment] [nvarchar](MAX) NULL,
    [RatingDate] [date] NOT NULL DEFAULT (CONVERT([date],getdate())),
    [AddedAt] [datetime] NOT NULL DEFAULT (getdate()),
    [AddedBy] [varchar](50) NULL
,
    CONSTRAINT [PK__StockRat__7E17ACE35342185B] PRIMARY KEY (StockRatingID)
);

ALTER TABLE [Research].[StockRating] ADD CONSTRAINT [FK_StockRating_Commenter] FOREIGN KEY (CommenterID) REFERENCES [Research].[Commenter] (CommenterID);
CREATE INDEX [IX_StockRating_CommenterID] ON [Research].[StockRating] (CommenterID);
CREATE INDEX [IX_StockRating_StockCode] ON [Research].[StockRating] (StockCode);