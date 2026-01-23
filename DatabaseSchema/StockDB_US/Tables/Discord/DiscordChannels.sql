-- Table: [Discord].[DiscordChannels]

CREATE TABLE [Discord].[DiscordChannels] (
    [ChannelId] [bigint] NOT NULL,
    [ChannelName] [nvarchar](255) NOT NULL,
    [FileName] [nvarchar](255) NULL,
    [IsActive] [bit] NOT NULL DEFAULT ((1)),
    [CreatedDate] [datetime2] NOT NULL DEFAULT (getdate()),
    [UpdatedDate] [datetime2] NOT NULL DEFAULT (getdate())
,
    CONSTRAINT [PK__DiscordC__38C3E8142F9D88F9] PRIMARY KEY (ChannelId)
);
