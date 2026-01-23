-- Table: [Transform].[TweetSymbol]

CREATE TABLE [Transform].[TweetSymbol] (
    [UserName] [varchar](200) NOT NULL,
    [FriendlyName] [varchar](200) NOT NULL,
    [Rating] [tinyint] NULL,
    [Symbol] [nvarchar](4000) NULL,
    [CreateDateTimeUTC] [smalldatetime] NULL,
    [NumObservations] [int] NULL,
    [Hashtag] [nvarchar](4000) NULL,
    [FriendlyNameWithDate] [varchar](205) NULL
);
