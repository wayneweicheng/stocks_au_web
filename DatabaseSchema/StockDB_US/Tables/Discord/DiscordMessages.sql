-- Table: [Discord].[DiscordMessages]

CREATE TABLE [Discord].[DiscordMessages] (
    [MessageId] [bigint] NOT NULL,
    [ChannelId] [bigint] NOT NULL,
    [TimeStamp] [datetimeoffset] NOT NULL,
    [UserName] [nvarchar](255) NOT NULL,
    [Content] [nvarchar](MAX) NOT NULL,
    [CreateDate] [datetime2] NOT NULL DEFAULT (getdate())
,
    CONSTRAINT [PK_DiscordMessages] PRIMARY KEY (MessageId, ChannelId)
);

ALTER TABLE [Discord].[DiscordMessages] ADD CONSTRAINT [FK_DiscordMessages_DiscordChannels] FOREIGN KEY (ChannelId) REFERENCES [Discord].[DiscordChannels] (ChannelId);
CREATE INDEX [IX_DiscordMessages_ChannelId_TimeStamp] ON [Discord].[DiscordMessages] (ChannelId, TimeStamp);