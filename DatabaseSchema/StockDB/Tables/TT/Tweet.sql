-- Table: [TT].[Tweet]

CREATE TABLE [TT].[Tweet] (
    [UserName] [varchar](200) NOT NULL,
    [TweetID] [varchar](50) NOT NULL,
    [CreateDateTimeUTC] [smalldatetime] NULL,
    [TweetJson] [varchar](MAX) NULL
);

CREATE INDEX [idx_tttweet_usernametweetid] ON [TT].[Tweet] (UserName, TweetID);